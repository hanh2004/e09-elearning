// Read production metadata and public Hosting headers. No user/document writes.
import {createRequire} from 'node:module';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {verifyFirebaseConfiguration} from './kiem_tra_cau_hinh_firebase.mjs';

const fieldsKey = fields => JSON.stringify(fields.filter(field => field.fieldPath !== '__name__')
  .map(({fieldPath, order, arrayConfig}) => ({fieldPath, ...(order ? {order} : {}), ...(arrayConfig ? {arrayConfig} : {})})));

export function verifyRequiredIndexes(required, deployed) {
  for (const index of required) {
    const found = deployed.find(value => value.name?.split('/').at(-3) === index.collectionGroup &&
      value.queryScope === index.queryScope && fieldsKey(value.fields ?? []) === fieldsKey(index.fields));
    if (!found || found.state !== 'READY') {
      throw new Error(`Required Firestore index unavailable: ${index.collectionGroup} (${found?.state ?? 'MISSING'}).`);
    }
  }
}

export function verifyRequiredFieldIndexes(required, deployed) {
  for (const field of required) {
    const found = deployed.find(value => value.name?.endsWith(`/collectionGroups/${field.collectionGroup}/fields/${field.fieldPath}`));
    for (const index of field.indexes ?? []) {
      const actual = found?.indexConfig?.indexes?.find(value => value.queryScope === index.queryScope &&
        fieldsKey(value.fields ?? []) === fieldsKey([{fieldPath: field.fieldPath, ...index}]));
      if (!actual || actual.state !== 'READY') {
        throw new Error(`Required Firestore field index unavailable: ${field.collectionGroup}.${field.fieldPath} (${index.queryScope}).`);
      }
    }
  }
}

export async function verifyFirebaseDeployment({config = verifyFirebaseConfiguration(), get, head = fetch, log = console.log} = {}) {
  const parent = `/projects/${config.projectId}/databases/(default)`;
  const list = async (service, path, key) => {
    const all = [];
    let pageToken;
    do {
      const body = await get(service, path, pageToken ? {pageToken} : {});
      all.push(...(body[key] ?? []));
      pageToken = body.nextPageToken;
    } while (pageToken);
    return all;
  };
  const indexes = await list('firestore', `${parent}/collectionGroups/-/indexes`, 'indexes');
  verifyRequiredIndexes(config.indexes.indexes, indexes);
  const fields = await Promise.all(config.indexes.fieldOverrides.map(field => get('firestore',
    `${parent}/collectionGroups/${field.collectionGroup}/fields/${field.fieldPath}`)));
  verifyRequiredFieldIndexes(config.indexes.fieldOverrides, fields);
  log(`Firestore: ${config.indexes.indexes.length} composite indexes and ${fields.length} field overrides READY.`);
  const functions = await list('functions', `/projects/${config.projectId}/locations/${config.region}/functions`, 'functions');
  for (const name of config.callables) {
    if (!functions.some(value => value.name?.endsWith(`/functions/${name}`) && value.state === 'ACTIVE')) {
      throw new Error(`Required callable is missing or inactive: ${name} (${config.region}).`);
    }
  }
  log(`Functions: ${config.callables.length} required callables ACTIVE in ${config.region}.`);
  const auth = await get('auth', `/admin/v2/projects/${config.projectId}/config`);
  if (auth.signIn?.email?.enabled !== true) throw new Error('Firebase email/password sign-in is disabled.');
  log(`Firebase Auth: email/password enabled (${auth.authorizedDomains?.length ?? 0} authorized domains).`);
  for (const site of new Set([config.projectId, config.hostingSite].filter(Boolean))) {
    for (const asset of ['/', '/main.dart.js']) {
      const result = await head(`https://${site}.web.app${asset}`, {method: 'HEAD'});
      if (!result.ok) throw new Error(`Hosting check failed: ${site}${asset} (${result.status}).`);
      log(`${site}${asset}: ${result.status}`);
    }
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const config = verifyFirebaseConfiguration({project: process.argv[2]});
    const require = createRequire(import.meta.url);
    const {getGlobalDefaultAccount} = require('../node_modules/firebase-tools/lib/auth.js');
    const {requireAuth} = require('../node_modules/firebase-tools/lib/requireAuth.js');
    const {Client} = require('../node_modules/firebase-tools/lib/apiv2.js');
    await requireAuth({project: config.projectId, ...getGlobalDefaultAccount()});
    const clients = {
      firestore: new Client({urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1', auth: true}),
      functions: new Client({urlPrefix: 'https://cloudfunctions.googleapis.com', apiVersion: 'v2', auth: true}),
      auth: new Client({urlPrefix: 'https://identitytoolkit.googleapis.com', auth: true}),
    };
    await verifyFirebaseDeployment({config, get: async (service, path, queryParams) =>
      (await clients[service].get(path, {queryParams})).body});
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
