import {test} from 'node:test';
import assert from 'node:assert/strict';
import {resolutionDocuments,lessons,questions} from '../scripts/noi_dung_nghi_quyet_20260919.mjs';
import {accountPlan,contentWrites} from '../scripts/lam_moi_du_lieu_nghi_quyet.mjs';
import {encode} from '../scripts/bo_sung_du_lieu_hoc_tap.mjs';
import {usernameKey} from '../src/quy_tac.js';
import {normalizeQuestion} from '../src/bai_kiem_tra.js';
const base='projects/e09-elearning/databases/(default)/documents';
const doc=(path,value)=>({name:`${base}/${path}`,fields:encode(value).mapValue.fields,updateTime:'2026-09-19T00:00:00Z'});
test('content provides separate study and exam paths with valid sourced questions',()=>{
  const docs=resolutionDocuments('root');
  assert.equal(docs.length,21);
  const courses=docs.filter(d=>d.path.split('/').length===2&&d.path.startsWith('courses/'));
  assert.equal(courses.length,2);
  for(const c of courses) {
    const ls=docs.filter(d=>d.path.startsWith(c.path+'/lessons/'));
    assert.equal(ls.length,3);
    assert.ok(ls.every(l=>l.data.minimumStudySeconds===120&&l.data.content.includes(l.data.sourceUrl)));
    if(c.data.learningMode==='study_exam') {
      const exam=docs.find(d=>d.path===`exams/${c.data.examId}`);
      assert.equal(exam.data.courseId,c.path.split('/')[1]);
      assert.equal(exam.data.questions,12);
      assert.ok(ls.every(l=>l.data.examId===c.data.examId));
    } else assert.equal(c.data.examId,'');
  }
  for(const [i,q] of questions.entries()) {
    assert.ok(normalizeQuestion(q,String(i)).explanation.length>10);
    assert.ok(lessons.some(l=>l.id===q.lessonId));
  }
});
test('short usernames skip occupied names and leave admin accounts untouched',()=>{
  const users=[doc('users/b',{role:'user',status:'active',username:'long_b'}),doc('users/a',{role:'user',status:'blocked',username:'long_a'}),doc('users/admin',{role:'admin',status:'active',username:'hv01'})];
  const names=[doc(`usernames/${usernameKey('hv02')}`,{uid:'someone'})];
  const before=structuredClone(users),plan=accountPlan(users,names);
  assert.deepEqual(plan.map(p=>p.username),['hv03','hv04']);
  assert.deepEqual(plan.map(p=>p.uid),['a','b']);
  assert.deepEqual(users,before);
});
test('migration only closes old courses, creates new content, and is repeatable',()=>{
  const courses=[doc('courses/old',{published:true})];
  const writes=contentWrites(courses,[],'root');
  assert.equal(writes.length,22);
  assert.deepEqual(writes[0].updateMask.fieldPaths,['deploymentMode','endsAt']);
  assert.equal(writes[0].update.fields.published, undefined);
  assert.ok(writes.every(w=>!w.delete&&/\/documents\/(courses|exams)\//.test(w.update.name)&&w.currentDocument));
  assert.equal(writes.some(w=>w.update.name.endsWith('/exams/old')),false);
  const existing=resolutionDocuments('root').map(d=>doc(d.path,d.data));
  assert.deepEqual(contentWrites([doc('courses/old',{published:false})],existing,'root'),[]);
  assert.throws(()=>contentWrites([],[doc('courses/nq57_study_only_20260919',{title:'someone else'})],'root'));
});
