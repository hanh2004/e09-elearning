import {test} from 'node:test';
import assert from 'node:assert/strict';
import {normalizeQuestion,gradeRun} from '../src/exams.js';
test('question snapshot requires exactly one correct answer',()=>{
  assert.throws(()=>normalizeQuestion({questionText:'Q',options:['A','B']},'q'));
  const q=normalizeQuestion({questionText:'Q',options:['A','B'],correctAnswerIndex:1},'q');
  assert.equal(q.correctIndex,1);
});
test('grading is exact and solutions are only included when permitted',()=>{
  const q=normalizeQuestion({questionText:'Q',options:['A','B'],correctAnswerIndex:1,explanation:'Reason'},'q');
  const run={questions:[q],passScore:7,showSolutions:false};
  assert.deepEqual(gradeRun(run,{}),{score:0,correctAnswers:0,totalQuestions:1,passed:false});
  assert.equal(gradeRun(run,{q:1}).score,10);
  assert.equal(gradeRun(run,{q:1}).review,undefined);
  assert.equal(gradeRun({...run,showSolutions:true},{q:1}).review[0].explanation,'Reason');
});
