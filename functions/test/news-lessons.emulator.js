import { before, after, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, query, where, serverTimestamp, updateDoc, deleteDoc } from 'firebase/firestore';

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Emulator required');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-e09',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await setDoc(doc(db, 'system/access'), {rootUids: ['news-root']});
    await setDoc(doc(db, 'users/news-root'), {role: 'super_admin', status: 'active'});
    await setDoc(doc(db, 'users/news-user'), {role: 'user', status: 'active'});
    await setDoc(doc(db, 'courses/news-course'), {published: true});
    await setDoc(doc(db, 'exams/news-exam'), {title: 'Test'});
  });
});
after(async () => { await env?.cleanup(); });

test('root publishes news; learners read only published news and cannot write', async () => {
  const root = env.authenticatedContext('news-root').firestore();
  const user = env.authenticatedContext('news-user').firestore();
  const item = {title: 'Tin', summary: '', content: 'Nội dung', coverUrl: '',
    contentFormat: 'rich_text_v1', published: false, updatedBy: 'news-root', updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(root, 'news/draft'), item));
  await assertSucceeds(setDoc(doc(root, 'news/published'), {...item, published: true}));
  await assertSucceeds(getDoc(doc(root, 'news/draft')));
  await assertFails(getDoc(doc(user, 'news/draft')));
  await assertSucceeds(getDoc(doc(user, 'news/published')));
  await assertSucceeds(getDocs(query(collection(user, 'news'), where('published', '==', true))));
  await assertFails(getDocs(collection(user, 'news')));
  await assertFails(setDoc(doc(user, 'news/forged'), {...item, updatedBy: 'news-user'}));
  await assertFails(setDoc(doc(root, 'news/empty'), {...item, content: ''}));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'news/published')));
});

test('news accepts custom categories and legacy defaults but rejects invalid category values', async () => {
  const root = env.authenticatedContext('news-root').firestore();
  const item = {title: 'Tin danh mục', summary: '', content: 'Nội dung', coverUrl: '',
    published: true, updatedBy: 'news-root', updatedAt: serverTimestamp()};
  const ref = doc(root, 'news/custom-category');
  await assertSucceeds(setDoc(ref, item));
  for (const category of ['Điểm tin', 'Chủ trương chính sách', 'Thông tin học tập', 'Hoạt động đơn vị', 'a'.repeat(100)]) {
    await assertSucceeds(updateDoc(ref, {category, updatedAt: serverTimestamp()}));
    const saved = await getDoc(ref);
    if (saved.data().category !== category) throw new Error('Category was not preserved');
  }
  await assertSucceeds(setDoc(doc(root, 'news/custom-category-new'), {...item, category: 'Tin địa phương'}));
  for (const category of ['', '   ', '\t\n', 'a'.repeat(101), null, 5, true, ['Điểm tin'], {name: 'Điểm tin'}]) {
    await assertFails(updateDoc(ref, {category, updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(root, 'news/invalid-category'), {...item, category}));
  }
});

test('lesson modes accept legacy and two valid modes, reject invalid exam links', async () => {
  const root = env.authenticatedContext('news-root').firestore();
  const ref = doc(root, 'courses/news-course/lessons/one');
  const item = {title: 'Lesson', order: 1, type: 'text', content: 'Text',
    coverUrl: 'https://example.org/cover.png', minimumStudySeconds: 1, updatedBy: 'news-root'};
  await assertSucceeds(setDoc(ref, item));
  await assertSucceeds(setDoc(ref, {...item, learningMode: 'study_only', examId: ''}));
  await assertSucceeds(setDoc(ref, {...item, learningMode: 'study_exam', examId: 'news-exam'}));
  await assertFails(setDoc(ref, {...item, learningMode: 'study_exam', examId: ''}));
  await assertFails(setDoc(ref, {...item, learningMode: 'study_exam', examId: 'missing'}));
  await assertFails(setDoc(ref, {...item, learningMode: 'unknown', examId: ''}));
  await assertFails(setDoc(ref, {...item, learningMode: 'study_only', examId: 'news-exam'}));
});

test('learners cannot read or write saved news bookmarks', async () => {
  const user = env.authenticatedContext('news-user').firestore();
  const bookmark = doc(user,'users/news-user/saved_news/metadata');
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'users/news-user/saved_news/metadata'),{savedAt:serverTimestamp()});
  });
  await assertFails(getDoc(bookmark));
  await assertFails(getDocs(collection(user,'users/news-user/saved_news')));
  await assertFails(setDoc(doc(user,'users/news-user/saved_news/new'),{savedAt:serverTimestamp()}));
  await assertFails(deleteDoc(bookmark));
});

test('home banner images are editable by root and visible only when active', async () => {
  const root = env.authenticatedContext('news-root').firestore();
  const user = env.authenticatedContext('news-user').firestore();
  const item = {imageUrl:'https://example.org/banner.png', title:'Banner E09', order:1,
    active:true, updatedBy:'news-root', updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(root,'home_banners/one'),item));
  await assertSucceeds(getDocs(query(collection(user,'home_banners'), where('active','==',true))));
  await assertFails(setDoc(doc(user,'home_banners/forged'),item));
  await assertFails(setDoc(doc(root,'home_banners/bad-order'),{...item,order:6}));
  await assertSucceeds(updateDoc(doc(root,'home_banners/one'),{active:false,updatedAt:serverTimestamp()}));
  await assertSucceeds(getDocs(query(collection(user,'home_banners'), where('active','==',true))));
  await assertSucceeds(deleteDoc(doc(root,'home_banners/one')));
});
