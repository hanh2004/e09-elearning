import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Local Firestore emulator required.');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-e09',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/normalize-reader'), { role: 'user', status: 'active' });
  });
});
after(async () => { await env?.cleanup(); });

async function studiedLesson(courseId, course, lesson) {
  const path = `users/normalize-reader/learning/${courseId}_one`;
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, `courses/${courseId}`), { published: true, ...course });
    await setDoc(doc(db, `courses/${courseId}/lessons/one`), { minimumStudySeconds: 1, ...lesson });
    await setDoc(doc(db, path), {
      courseId, lessonId: 'one', completed: false, studyCompleted: true,
      startedAt: Timestamp.fromMillis(Date.now() - 60000),
      studyCompletedAt: Timestamp.fromMillis(Date.now() - 1000),
      updatedAt: Timestamp.fromMillis(Date.now() - 1000),
    });
  });
  return doc(env.authenticatedContext('normalize-reader').firestore(), path);
}

const completion = () => ({
  completed: true, completedAt: serverTimestamp(), updatedAt: serverTimestamp(),
});

test('legacy lesson exam cannot be normalized into final completion before submission', async () => {
  const progress = await studiedLesson('legacy-lesson-exam', {}, {
    learningMode: 'study_exam', examId: 'lesson-exam',
  });
  await assertFails(updateDoc(progress, completion()));
  assert.equal((await getDoc(progress)).data().completed, false);
});

test('legacy course exam cannot be normalized into final completion before submission', async () => {
  const progress = await studiedLesson('legacy-course-exam', { examId: 'course-exam' }, {});
  await assertFails(updateDoc(progress, completion()));
  assert.equal((await getDoc(progress)).data().completed, false);
});

test('legacy study-only lessons can normalize a saved study completion', async () => {
  const progress = await studiedLesson('legacy-study-only', {}, {});
  await assertSucceeds(updateDoc(progress, completion()));
  assert.equal((await getDoc(progress)).data().completed, true);
});

test('explicit study-only course overrides old lesson exam fields during normalization', async () => {
  const progress = await studiedLesson('converted-study-only', { learningMode: 'study_only' }, {
    learningMode: 'study_exam', examId: 'previous-exam',
  });
  await assertSucceeds(updateDoc(progress, completion()));
  assert.equal((await getDoc(progress)).data().completed, true);
});
