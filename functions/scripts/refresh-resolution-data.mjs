import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {mkdirSync,writeFileSync,readFileSync,existsSync} from 'node:fs';
import {createHash,randomInt} from 'node:crypto';
import {resolve} from 'node:path';
import {encode} from './supplement-learning-data.mjs';
import {usernameKey,loginEmail,rootIds} from '../src/policy.js';
import {resolutionDocuments,batch} from './resolution-content-20260919.mjs';
export const project='e09-elearning';
const base=`projects/${project}/databases/(default)/documents`;
const fields=v=>encode(v).mapValue.fields;
export function decode(v) {
  if('stringValue' in v)return v.stringValue;
  if('booleanValue' in v)return v.booleanValue;
  if('integerValue' in v)return Number(v.integerValue);
  if('doubleValue' in v)return v.doubleValue;
  if('timestampValue' in v)return v.timestampValue;
  if('arrayValue' in v)return (v.arrayValue.values||[]).map(decode);
  if('mapValue' in v)return Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,x])=>[k,decode(x)]));
  return null;
}
export const data=d=>decode({mapValue:{fields:d?.fields||{}}});
const id=d=>d.name.split('/').pop();
const digest=docs=>createHash('sha256').update(JSON.stringify([...docs].sort((a,b)=>a.name.localeCompare(b.name)))).digest('hex');
export function accountPlan(users,names) {
  const occupied=new Map(names.map(d=>[id(d),data(d).uid]));
  for(const d of users) if(data(d).username) occupied.set(usernameKey(data(d).username),id(d));
  let next=1;
  return users.filter(d=>data(d).role==='user'&&['active','blocked'].includes(data(d).status))
    .sort((a,b)=>a.name.localeCompare(b.name)).map(d=>{
      let username;
      do {username=`hv${String(next++).padStart(2,'0')}`;} while(occupied.has(usernameKey(username))&&occupied.get(usernameKey(username))!==id(d));
      occupied.set(usernameKey(username),id(d));
      return {uid:id(d),oldUsername:data(d).username,username,name:data(d).name||'',status:data(d).status};
    });
}
export function contentWrites(courses,exams,existing,actor) {
  const writes=[];
  const archiveAt=new Date().toISOString();
  for(const d of [...courses,...exams]) {
    if(data(d).contentBatch===batch)continue;
    const isCourse=d.name.includes('/courses/');
    if(isCourse?data(d).published!==true:data(d).isOpen!==true)continue;
    const value=isCourse?{deploymentMode:'manual'}:{isOpen:false,status:'Đã đóng'};
    const updateFields=fields(value);
    const fieldPaths=Object.keys(value);
    if(isCourse) {
      updateFields.endsAt={timestampValue:archiveAt};
      fieldPaths.push('endsAt');
    }
    writes.push({update:{name:d.name,fields:updateFields},updateMask:{fieldPaths},currentDocument:{updateTime:d.updateTime}});
  }
  for(const d of resolutionDocuments(actor)) {
    const old=existing.find(x=>x.name===`${base}/${d.path}`);
    if(old) {
      if(data(old).contentBatch!==batch)throw new Error('Content ID collision');
      continue;
    }
    writes.push({update:{name:`${base}/${d.path}`,fields:fields(d.data)},currentDocument:{exists:false},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'},{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]});
  }
  return writes;
}
export async function run(mode) {
  if(process.env.FIRESTORE_EMULATOR_HOST||process.env.FIREBASE_AUTH_EMULATOR_HOST)throw new Error('Do not mix emulator and production');
  const require=createRequire(import.meta.url);
  const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
  const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
  const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
  await requireAuth({project,...getGlobalDefaultAccount()});
  const db=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
  const auth=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1',auth:true});
  const query=async path=>{
    const parts=path.split('/'),collectionId=parts.pop();
    return (await db.post(`/${base}${parts.length?'/'+parts.join('/'):''}:runQuery`,{structuredQuery:{from:[{collectionId}]}})).body.filter(r=>r.document).map(r=>r.document);
  };
  const get=async path=>(await db.get(`/${base}/${path}`)).body;
  const lookup=async key=>(await auth.post(`/projects/${project}/accounts:lookup`,key)).body.users||[];
  const snapshot={};
  for(const collection of ['users','usernames','courses','exams','news','home_banners'])snapshot[collection]=await query(collection);
  if(mode==='--apply') {
    const active=(await db.post(`/${base}:runQuery`,{structuredQuery:{from:[{collectionId:'exam_private_runs'}],where:{fieldFilter:{field:{fieldPath:'status'},op:'EQUAL',value:{stringValue:'in_progress'}}}}})).body.filter(r=>r.document).map(r=>data(r.document));
    if(active.some(r=>Date.parse(r.endsAt)>Date.now()))throw new Error('A learner is taking an exam; retry after it finishes');
  }
  for(const d of snapshot.courses)snapshot[`courses/${id(d)}/lessons`]=await query(`courses/${id(d)}/lessons`);
  for(const d of snapshot.exams)snapshot[`exams/${id(d)}/questions`]=await query(`exams/${id(d)}/questions`);
  const roots=rootIds(data(await get('system/access')));
  const actor=snapshot.users.find(d=>roots.includes(id(d))&&data(d).role==='super_admin'&&data(d).status==='active');
  if(!actor)throw new Error('No active root admin');
  const dir=resolve('.tmp/resolution-refresh-20260919');
  const journalPath=resolve(dir,'account-journal.json');
  const journal=existsSync(journalPath)?JSON.parse(readFileSync(journalPath,'utf8')):null;
  const plan=journal?.accounts||accountPlan(snapshot.users,snapshot.usernames);
  const authUsers=plan.length?await lookup({localId:plan.map(p=>p.uid)}):[];
  for(const p of plan) {
    const u=authUsers.find(u=>u.localId===p.uid);
    if(!u||![loginEmail(p.oldUsername),loginEmail(p.username)].includes(u.email))throw new Error(`Auth identity mismatch: ${p.uid}`);
    const collisions=await lookup({email:[loginEmail(p.username)]});
    if(collisions.some(u=>u.localId!==p.uid))throw new Error(`Auth name collision: ${p.username}`);
  }
  const newsHash=digest(snapshot.news),bannersHash=digest(snapshot.home_banners);
  const writes=contentWrites(snapshot.courses,snapshot.exams,Object.values(snapshot).flat(),id(actor));
  const report={mode,learners:plan.length,usernames:plan.map(p=>p.username),newsPreserved:snapshot.news.length,bannersPreserved:snapshot.home_banners.length,contentWrites:writes.length};
  if(mode==='--dry-run')return report;
  mkdirSync(dir,{recursive:true});
  if(mode==='--apply') {
    if(!existsSync(resolve(dir,'backup.json')))writeFileSync(resolve(dir,'backup.json'),JSON.stringify(snapshot,null,2),{flag:'wx'});
    const state=journal||{project,batch,newsHash,bannersHash,accounts:plan.map(p=>({...p,password:String(randomInt(10000000,100000000)),done:false}))};
    if(state.project!==project||state.batch!==batch)throw new Error('Journal mismatch');
    const save=()=>writeFileSync(journalPath,JSON.stringify(state,null,2));
    save();
    for(const p of state.accounts) {
      if(p.done)continue;
      const profile=await get(`users/${p.uid}`),profileData=data(profile);
      if(profileData.role!=='user'||![p.oldUsername,p.username].includes(profileData.username))throw new Error('Profile changed during migration');
      const names=await query('usernames');
      const old=names.find(d=>id(d)===usernameKey(p.oldUsername));
      const target=names.find(d=>id(d)===usernameKey(p.username));
      if((old&&data(old).uid!==p.uid)||(target&&data(target).uid!==p.uid))throw new Error('Username registry collision');
      // Auth and Firestore cannot share a transaction. Journal makes interruption recoverable.
      await auth.post(`/projects/${project}/accounts:update`,{localId:p.uid,email:loginEmail(p.username),password:p.password});
      const accountWrites=[{update:{name:profile.name,fields:fields({username:p.username})},updateMask:{fieldPaths:['username']},currentDocument:{updateTime:profile.updateTime}}];
      if(!target)accountWrites.push({update:{name:`${base}/usernames/${usernameKey(p.username)}`,fields:fields({uid:p.uid,username:p.username})},currentDocument:{exists:false}});
      if(old&&old.name!==`${base}/usernames/${usernameKey(p.username)}`)accountWrites.push({delete:old.name,currentDocument:{updateTime:old.updateTime}});
      await db.post(`/${base}:commit`,{writes:accountWrites});
      p.done=true;save();
    }
    if(writes.length)await db.post(`/${base}:commit`,{writes});
    writeFileSync(resolve(dir,'tai-khoan-hoc-vien.txt'),'TÀI KHOẢN HỌC VIÊN E09\nMật khẩu gồm 8 chữ số, nhập đúng như bên dưới.\n\n'+state.accounts.map(p=>`${p.name}\nTài khoản cũ: ${p.oldUsername}\nTài khoản mới: ${p.username}\nMật khẩu: ${p.password}\nTrạng thái: ${p.status}\n`).join('\n'));
  }
  const saved=JSON.parse(readFileSync(journalPath,'utf8'));
  if(digest(await query('news'))!==saved.newsHash||digest(await query('home_banners'))!==saved.bannersHash)throw new Error('News/banner snapshot changed; investigate concurrent changes');
  const usersNow=await query('users'),authNow=await lookup({localId:saved.accounts.map(p=>p.uid)}),namesNow=await query('usernames');
  for(const p of saved.accounts) {
    if(data(usersNow.find(d=>id(d)===p.uid)).username!==p.username||authNow.find(u=>u.localId===p.uid)?.email!==loginEmail(p.username)||data(namesNow.find(d=>id(d)===usernameKey(p.username))).uid!==p.uid)throw new Error(`Account verification failed: ${p.username}`);
  }
  const configText=readFileSync(new URL('../../lib/firebase_options.dart',import.meta.url),'utf8');
  const apiKey=configText.match(/static const FirebaseOptions web = FirebaseOptions\(\s*apiKey: '([^']+)'/)?.[1];
  if(!apiKey)throw new Error('Web API key missing');
  let loginsVerified=0;
  for(const p of saved.accounts) {
    if(p.status!=='active'||authNow.find(u=>u.localId===p.uid)?.disabled)continue;
    const response=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:loginEmail(p.username),password:p.password,returnSecureToken:true})});
    const result=await response.json();
    if(!response.ok||result.localId!==p.uid)throw new Error(`Login verification failed: ${p.username}`);
    loginsVerified++;
  }
  for(const d of resolutionDocuments(id(actor))) {
    const actual=data(await get(d.path));
    if(Object.entries(d.data).some(([k,v])=>JSON.stringify(actual[k])!==JSON.stringify(v)))throw new Error(`Content verification failed: ${d.path}`);
  }
  const backup=JSON.parse(readFileSync(resolve(dir,'backup.json'),'utf8'));
  for(const before of backup.users) {
    const after=usersNow.find(d=>d.name===before.name);
    const expected={...before.fields};
    const p=saved.accounts.find(p=>p.uid===id(before));
    if(p)expected.username={stringValue:p.username};
    if(JSON.stringify(Object.entries(expected).sort())!==JSON.stringify(Object.entries(after?.fields||{}).sort()))throw new Error('Unrelated profile fields changed');
  }
  return {...report,verified:true,loginsVerified,credentialsFile:resolve(dir,'tai-khoan-hoc-vien.txt')};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href) {
  const mode=process.argv[2]||'--dry-run';
  if(process.argv.length>3||!['--dry-run','--apply','--verify'].includes(mode))throw new Error('Use --dry-run, --apply or --verify');
  console.log(JSON.stringify(await run(mode),null,2));
}
