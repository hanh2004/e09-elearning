import {test} from 'node:test';
import assert from 'node:assert/strict';
import {missingCodeWrites,encode} from '../scripts/bo_sung_du_lieu_hoc_tap.mjs';
import {sampleDocuments} from '../scripts/du_lieu_mau_20260914.mjs';
import {normalizeQuestion} from '../src/bai_kiem_tra.js';
import {userCodeKey} from '../src/quy_tac.js';
const base='projects/demo-e09/databases/(default)/documents';
const doc=(path,value)=>({name:`${base}/${path}`,updateTime:'2026-09-14T00:00:00Z',fields:encode(value).mapValue.fields});
test('adds only absent learner codes, never changes unit, owner, profile or progress',()=>{
  const users=[doc('users/u',{role:'user',status:'active',unit:'D1',username:'an01',subUnit:'A',createdBy:'m'}),
    doc('users/old',{role:'user',status:'active',unit:'D2',username:'old',userCode:'D2-KEEP'}),
    doc('users/root',{role:'super_admin',status:'active',unit:'E09'})];
  const before=structuredClone(users),plan=missingCodeWrites(users,[],base);
  assert.deepEqual(plan.assigned,['D1-an01']); assert.equal(plan.writes.length,2);
  assert.deepEqual(plan.writes[1].updateMask.fieldPaths,['userCode','userCodeSuffix']);
  assert.deepEqual(plan.writes[1].currentDocument,{updateTime:users[0].updateTime});
  assert.deepEqual(plan.writes[0].currentDocument,{exists:false}); assert.deepEqual(users,before);
});
test('case insensitive collision aborts and missing units are not invented',()=>{
  const learner=doc('users/u',{role:'user',status:'active',unit:'D1',username:'an01'});
  const registry=doc(`user_codes/${userCodeKey('d1-AN01')}`,{uid:'other'});
  assert.throws(()=>missingCodeWrites([learner],[registry],base));
  assert.throws(()=>missingCodeWrites([doc('users/u',{role:'user',status:'active',username:'an01'})],[],base));
});
test('samples have working icons, lesson content and valid questions without fake results',()=>{
  const docs=sampleDocuments('root');
  assert.equal(new Set(docs.map(d=>d.path)).size,20);
  assert.equal(docs.filter(d=>d.path.includes('/lessons/')).length,6);
  assert.equal(docs.filter(d=>d.path.includes('/questions/')).length,10);
  for(const doc of docs) {
    assert.match(doc.path,/^(courses|exams)\/sample_/);
    if(doc.path.includes('/lessons/')) { assert.ok(doc.data.content.length>500); assert.ok(doc.data.minimumStudySeconds>0); }
    if(doc.path.startsWith('courses/')) assert.match(doc.data.coverUrl,/^icon:(math|book)$/);
    if(doc.path.includes('/questions/')) assert.ok(normalizeQuestion(doc.data,doc.path).explanation.length>0);
  }
});
