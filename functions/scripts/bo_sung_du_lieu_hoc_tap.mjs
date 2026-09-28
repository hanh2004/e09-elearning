// Chỉ thêm mã còn thiếu và nội dung mẫu mới. Mặc định xem trước, --apply mới ghi.
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {makeUserCode,userCodeKey,rootIds} from '../src/quy_tac.js';
import {sampleDocuments} from './du_lieu_mau_20260914.mjs';

export function encode(value) {
  if(value===null) return {nullValue:null};
  if(typeof value==='string') return {stringValue:value};
  if(typeof value==='boolean') return {booleanValue:value};
  if(typeof value==='number') return Number.isInteger(value)?{integerValue:String(value)}:{doubleValue:value};
  if(Array.isArray(value)) return {arrayValue:{values:value.map(encode)}};
  return {mapValue:{fields:fields(value)}};
}
const fields=value=>Object.fromEntries(Object.entries(value).map(([key,value])=>[key,encode(value)]));
function decode(value) {
  if('stringValue' in value) return value.stringValue;
  if('booleanValue' in value) return value.booleanValue;
  if('integerValue' in value) return Number(value.integerValue);
  if('arrayValue' in value) return (value.arrayValue.values||[]).map(decode);
  if('mapValue' in value) return Object.fromEntries(Object.entries(value.mapValue.fields||{}).map(([key,v])=>[key,decode(v)]));
  return null;
}
const data=doc=>Object.fromEntries(Object.entries(doc.fields||{}).map(([key,v])=>[key,decode(v)]));

export function missingCodeWrites(users,reservations,base) {
  const occupied=new Map();
  for(const record of reservations) {
    const d=data(record);
    occupied.set(record.name.split('/').pop(),d.uid);
  }
  // Bảo vệ cả mã đã cấp trước khi có bảng giữ mã.
  for(const user of users) {
    const d=data(user),uid=user.name.split('/').pop();
    if(typeof d.userCode==='string'&&d.userCode.trim()) {
      const key=userCodeKey(d.userCode);
      if(occupied.has(key)&&occupied.get(key)!==uid) throw new Error('Mã đang có bị trùng hoặc không khớp bản ghi giữ mã. Chưa ghi dữ liệu.');
      occupied.set(key,uid);
    }
  }
  const writes=[],assigned=[];
  for(const user of users) {
    const d=data(user),uid=user.name.split('/').pop();
    if(d.role!=='user'||!['active','blocked'].includes(d.status)||d.userCode?.trim()) continue;
    // Giữ nguyên đơn vị hiện tại, không chuyển chủ quản lý hay xóa đơn vị trực thuộc.
    const suffix=(d.userCodeSuffix||d.username||uid).trim();
    const code=makeUserCode(d.unit,suffix),key=userCodeKey(code);
    if(occupied.has(key)&&occupied.get(key)!==uid) throw new Error(`Mã ${code} đã được sử dụng. Chưa ghi dữ liệu.`);
    const reserved=reservations.find(r=>r.name.split('/').pop()===key);
    if(!reserved) writes.push({update:{name:`${base}/user_codes/${key}`,fields:fields({uid,code})},currentDocument:{exists:false}});
    writes.push({update:{name:user.name,fields:fields({userCode:code,userCodeSuffix:suffix})},
      updateMask:{fieldPaths:['userCode','userCodeSuffix']},currentDocument:{updateTime:user.updateTime}});
    occupied.set(key,uid);assigned.push(code);
  }
  return {writes,assigned};
}

export async function supplement(client,project,apply=false) {
  if(!['e09-elearning','demo-e09'].includes(project)) throw new Error('Unexpected project');
  const base=`projects/${project}/databases/(default)/documents`;
  const transaction=(await client.post(`/${base}:beginTransaction`,{options:{readWrite:{}}})).body.transaction;
  let committed=false;
  try {
    const query=async collection=>{
      const select=collection==='users'?{fields:['role','status','unit','createdBy','userCode','userCodeSuffix','username'].map(fieldPath=>({fieldPath}))}:undefined;
      return (await client.post(`/${base}:runQuery`,{transaction,structuredQuery:{from:[{collectionId:collection}],...(select?{select}:{})}}))
        .body.filter(row=>row.document).map(row=>row.document);
    };
    // Firestore Emulator không xử lý ổn GET document kèm transaction query param;
    // batchGet vẫn giữ transaction và hoạt động giống nhau trên production.
    const accessRows=(await client.post(`/${base}:batchGet`,{
      transaction,documents:[`${base}/system/access`],
    })).body;
    const config=data(accessRows.find(row=>row.found)?.found||{});
    const users=await query('users'),codes=await query('user_codes');
    const roots=rootIds(config);
    const actor=users.find(doc=>roots.includes(doc.name.split('/').pop())&&data(doc).role==='super_admin'&&data(doc).status==='active');
    if(!actor) throw new Error('Không tìm thấy quản lý tổng đang hoạt động.');
    const plan=missingCodeWrites(users,codes,base);
    const documents=sampleDocuments(actor.name.split('/').pop());
    const existing=(await client.post(`/${base}:batchGet`,{transaction,documents:documents.map(doc=>`${base}/${doc.path}`)})).body;
    const found=new Set(existing.filter(row=>row.found).map(row=>row.found.name));
    const groups=new Map();
    for(const doc of documents) {
      const parent=doc.path.split('/').slice(0,2).join('/');
      groups.set(parent,[...(groups.get(parent)||[]),doc]);
    }
    const added=[];
    for(const [parent,group] of groups) {
      if(found.has(`${base}/${parent}`)) continue;
      if(group.some(doc=>found.has(`${base}/${doc.path}`))) throw new Error('Có dữ liệu mẫu con chưa gắn bản ghi cha. Chưa ghi dữ liệu.');
      for(const doc of group) {
        plan.writes.push({update:{name:`${base}/${doc.path}`,fields:fields(doc.data)},currentDocument:{exists:false},
          updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'},{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]});
        added.push(doc.path);
      }
    }
    const result={mode:apply?'applied':'dry-run',codesAdded:plan.assigned.length,codes:plan.assigned,
      coursesAdded:added.filter(p=>p.startsWith('courses/')&&p.split('/').length===2).length,
      lessonsAdded:added.filter(p=>p.includes('/lessons/')).length,
      examsAdded:added.filter(p=>p.startsWith('exams/')&&p.split('/').length===2).length,
      questionsAdded:added.filter(p=>p.includes('/questions/')).length,totalWrites:plan.writes.length};
    if(apply&&plan.writes.length) {
      await client.post(`/${base}:commit`,{transaction,writes:plan.writes});
      committed=true;
    }
    return result;
  } finally {
    if(!committed) await client.post(`/${base}:rollback`,{transaction});
  }
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href) {
  if(process.argv.slice(2).some(arg=>arg!=='--apply')) throw new Error('Chỉ dùng --apply, hoặc không có tham số để xem trước.');
  if(process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Không trộn môi trường giả lập với dữ liệu thật.');
  const require=createRequire(import.meta.url);
  const {getGlobalDefaultAccount}=require('../node_modules/firebase-tools/lib/auth.js');
  const {requireAuth}=require('../node_modules/firebase-tools/lib/requireAuth.js');
  const {Client}=require('../node_modules/firebase-tools/lib/apiv2.js');
  await requireAuth({project:'e09-elearning',...getGlobalDefaultAccount()});
  const client=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1',auth:true});
  console.log(JSON.stringify(await supplement(client,'e09-elearning',process.argv.includes('--apply')),null,2));
}
