import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sampleDocuments} from '../scripts/du_lieu_mau_20260914.mjs';
import {normalizeQuestion} from '../src/bai_kiem_tra.js';
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
