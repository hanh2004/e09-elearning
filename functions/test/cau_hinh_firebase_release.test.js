import test from 'node:test';
import assert from 'node:assert/strict';
import {copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {verifyFirebaseConfiguration} from '../scripts/kiem_tra_cau_hinh_firebase.mjs';
import {verifyFirebaseDeployment, verifyRequiredFieldIndexes, verifyRequiredIndexes} from '../scripts/xac_minh_web.mjs';

const projectRoot = fileURLToPath(new URL('../../', import.meta.url));
function fixture(t) {
  const temporaryRoot = resolve(projectRoot, '.tmp');
  mkdirSync(temporaryRoot, {recursive: true});
  const root = mkdtempSync(join(temporaryRoot, 'firebase-config-test-'));
  t.after(() => {
    assert.equal(dirname(root), temporaryRoot);
    rmSync(root, {recursive: true, force: true});
  });
  for (const file of ['firebase.json', 'lib/firebase_options.dart', 'lib/app/cau_hinh_ung_dung.dart',
    'android/app/google-services.json', 'android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml',
    'functions/src/diem_vao.js', 'firestore.indexes.json', 'firestore.rules', 'storage.rules']) {
    mkdirSync(dirname(join(root, file)), {recursive: true});
    copyFileSync(join(projectRoot, file), join(root, file));
  }
  return root;
}

test('current release configuration agrees across Flutter, Android and Functions', () => {
  const config = verifyFirebaseConfiguration({env: {}});
  assert.equal(config.projectId, 'e09-elearning');
  assert.equal(config.region, 'asia-southeast1');
  assert.ok(config.callables.includes('adminSessionClaim'));
  assert.ok(config.callables.includes('examStart'));
});

test('release refuses a different project and an emulator environment', () => {
  assert.throws(() => verifyFirebaseConfiguration({project: 'demo-e09', env: {}}), /differs/);
  for (const name of ['FIREBASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
    assert.throws(() => verifyFirebaseConfiguration({env: {[name]: '127.0.0.1:8080'}}), /Release environment/);
  }
});

for (const [description, file, before, after, error] of [
  ['Android package', 'android/app/build.gradle.kts', 'applicationId = "com.example.e09_elearning"', 'applicationId = "com.other.app"', /no client/],
  ['Android network permission', 'android/app/src/main/AndroidManifest.xml', 'android.permission.INTERNET', 'android.permission.OTHER', /Internet permission/],
  ['Functions region', 'lib/app/cau_hinh_ung_dung.dart', "functionsRegion = 'asia-southeast1'", "functionsRegion = 'us-central1'", /regions differ/],
  ['Firebase project', 'lib/firebase_options.dart', "projectId: 'e09-elearning'", "projectId: 'other-project'", /different project/],
]) {
  test(`release rejects mismatched ${description}`, t => {
    const root = fixture(t);
    const path = join(root, file);
    const source = readFileSync(path, 'utf8');
    assert.ok(source.includes(before));
    writeFileSync(path, source.replace(before, after));
    assert.throws(() => verifyFirebaseConfiguration({root, env: {}}), error);
  });
}

const requiredIndex = {collectionGroup: 'learning', queryScope: 'COLLECTION_GROUP',
  fields: [{fieldPath: 'courseId', order: 'ASCENDING'}, {fieldPath: 'lessonId', order: 'ASCENDING'}]};
const deployedIndex = {name: 'projects/p/databases/(default)/collectionGroups/learning/indexes/one',
  queryScope: 'COLLECTION_GROUP', state: 'READY', fields: [...requiredIndex.fields, {fieldPath: '__name__', order: 'ASCENDING'}]};
const requiredField = {collectionGroup: 'learning', fieldPath: 'courseId',
  indexes: [{order: 'ASCENDING', queryScope: 'COLLECTION_GROUP'}]};
const deployedField = {name: 'projects/p/databases/(default)/collectionGroups/learning/fields/courseId',
  indexConfig: {indexes: [{queryScope: 'COLLECTION_GROUP', state: 'READY', fields: [{fieldPath: 'courseId', order: 'ASCENDING'}]}]}};

test('missing, incorrectly scoped and building indexes fail despite other READY indexes', () => {
  for (const deployed of [[], [{...deployedIndex, queryScope: 'COLLECTION'}], [{...deployedIndex, state: 'CREATING'}]]) {
    assert.throws(() => verifyRequiredIndexes([requiredIndex], deployed), /index unavailable/);
  }
  verifyRequiredIndexes([requiredIndex], [deployedIndex]);
  assert.throws(() => verifyRequiredFieldIndexes([requiredField], []), /field index unavailable/);
  verifyRequiredFieldIndexes([requiredField], [deployedField]);
});

function deployment({missingFunction = false, emailEnabled = true} = {}) {
  const requests = [];
  return {
    requests,
    config: {projectId: 'p', region: 'asia-southeast1', hostingSite: 'p-admin',
      indexes: {indexes: [requiredIndex], fieldOverrides: [requiredField]}, callables: ['examStart']},
    get: async (service, path, query) => {
      requests.push({service, path, query});
      if (path.endsWith('/indexes')) return query?.pageToken
        ? {indexes: [deployedIndex]} : {indexes: [], nextPageToken: 'more-indexes'};
      if (path.endsWith('/fields/courseId')) return deployedField;
      if (path.endsWith('/functions')) return query?.pageToken
        ? {functions: missingFunction ? [] : [{name: 'projects/p/locations/asia-southeast1/functions/examStart', state: 'ACTIVE'}]}
        : {functions: [], nextPageToken: 'more-functions'};
      if (service === 'auth') return {signIn: {email: {enabled: emailEnabled}}, authorizedDomains: ['p.web.app']};
      assert.fail('Unexpected metadata request');
    },
    head: async (url, options) => {
      assert.equal(options.method, 'HEAD');
      assert.match(url, /^https:\/\/p(?:-admin)?\.web\.app\/(?:main\.dart\.js)?$/);
      return {ok: true, status: 200};
    },
    log: () => {},
  };
}

test('metadata preflight follows all pages and checks only public Hosting headers', async () => {
  const state = deployment();
  await verifyFirebaseDeployment(state);
  assert.ok(state.requests.some(request => request.query?.pageToken === 'more-indexes'));
  assert.ok(state.requests.some(request => request.query?.pageToken === 'more-functions'));
});

test('metadata preflight rejects missing Functions and disabled password authentication', async () => {
  await assert.rejects(verifyFirebaseDeployment(deployment({missingFunction: true})), /callable is missing/);
  await assert.rejects(verifyFirebaseDeployment(deployment({emailEnabled: false})), /sign-in is disabled/);
});
