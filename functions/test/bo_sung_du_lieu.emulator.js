import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,getDoc} from 'firebase/firestore';
import {supplement} from '../scripts/bo_sung_du_lieu_hoc_tap.mjs';
import {examHandlers} from '../src/bai_kiem_tra.js';
if(!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Local emulator required');

test('supplement adds sample content atomically, preserves account records and is repeatable',async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-e09',firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
  const app=initializeApp({projectId:'demo-e09'},'supplement-test'),db=getFirestore(app);
  const request=async(method,path,body,options={})=>{
    const url=new URL(`http://${process.env.FIRESTORE_EMULATOR_HOST}/v1${path}`);
    for(const [k,v] of Object.entries(options.queryParams||{})) url.searchParams.set(k,v);
    const res=await fetch(url,{method,headers:{'Content-Type':'application/json','Authorization':'Bearer owner'},...(body?{body:JSON.stringify(body)}:{})});
    const result=await res.json(); if(!res.ok) throw new Error(JSON.stringify(result));
    return {body:result};
  };
  const client={post:(p,b)=>request('POST',p,b),get:(p,o)=>request('GET',p,undefined,o)};
  try {
    await env.clearFirestore();
    await db.doc('system/access').set({rootUids:['root1','root2']});
    await db.doc('users/root1').set({role:'super_admin',status:'active'});
    const user={role:'user',status:'active',unit:'D1',username:'example1',name:'Test',createdBy:'manager',subUnit:'Team',unitNeedsConfirmation:false};
    await db.doc('users/u').set(user);
    const existing={
      'users/u/learning/old_one':{completed:true},
      'exam_attempts/old':{userId:'u',bestScore:8},
      'courses/old':{title:'Existing course',published:true},
      'courses/old/lessons/one':{title:'User edits'},
    };
    for(const [path,data] of Object.entries(existing)) await db.doc(path).set(data);
    const preview=await supplement(client,'demo-e09');
    assert.equal(preview.coursesAdded,2);
    assert.deepEqual((await db.doc('users/u').get()).data(),user);
    assert.equal((await db.doc('courses/sample_math_20260914').get()).exists,false);
    const result=await supplement(client,'demo-e09',true);
    assert.deepEqual(result, {
      mode:'applied', coursesAdded:2, lessonsAdded:6,
      examsAdded:2, questionsAdded:10, totalWrites:20,
    });
    assert.deepEqual((await db.doc('users/u').get()).data(),user);
    for(const [path,data] of Object.entries(existing)) assert.deepEqual((await db.doc(path).get()).data(),data);
    assert.equal((await db.collection('learning_notifications').get()).size,0);
    const pupil=env.authenticatedContext('u').firestore();
    await assertSucceeds(getDoc(doc(pupil,'courses/sample_math_20260914')));
    await assertSucceeds(getDoc(doc(pupil,'courses/sample_math_20260914/lessons/operations')));
    await assertFails(getDoc(doc(pupil,'exams/sample_math_20260914_practice/questions/q1')));
    await db.doc('courses/exam-fixture').set({published:true});
    await db.doc('courses/exam-fixture/lessons/one').set({learningMode:'study_exam',examId:'sample_math_20260914_practice'});
    await db.doc('users/u/learning/exam-fixture_one').set({courseId:'exam-fixture',lessonId:'one',completed:true});
    const run=await examHandlers(db).start('u',{examId:'sample_math_20260914_practice',courseId:'exam-fixture',lessonId:'one'});
    assert.equal(run.questions.length,5);
    assert.ok(run.questions.every(q=>q.correctIndex===undefined));
    await db.doc('courses/sample_math_20260914/lessons/operations').update({title:'User changed this'});
    const again=await supplement(client,'demo-e09',true);
    assert.equal(again.totalWrites,0);
    assert.equal((await db.doc('courses/sample_math_20260914/lessons/operations').get()).data().title,'User changed this');
  } finally {await env.cleanup();await deleteApp(app);}
});
