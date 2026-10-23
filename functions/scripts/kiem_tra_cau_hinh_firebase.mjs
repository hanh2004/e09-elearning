// Offline release checks. Read configuration only; never print API keys or signing inputs.
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export function verifyFirebaseConfiguration({
  root = fileURLToPath(new URL('../../', import.meta.url)),
  project,
  env = process.env,
} = {}) {
  const read = file => readFileSync(resolve(root, file), 'utf8');
  const json = file => JSON.parse(read(file));
  const check = (condition, message) => {
    if (!condition) throw new Error(message);
  };
  const match = (text, pattern, name) => {
    const value = text.match(pattern)?.[1];
    check(value, `Missing Firebase configuration: ${name}`);
    return value;
  };
  for (const name of ['FIREBASE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST',
    'FIRESTORE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'FUNCTIONS_EMULATOR']) {
    check(!env[name], `Release environment still contains ${name}.`);
  }
  const firebase = json('firebase.json');
  const expected = firebase.flutter?.platforms?.android?.default;
  check(expected?.projectId && !expected.projectId.startsWith('demo-'),
    'Missing production Firebase project in firebase.json.');
  project ??= expected.projectId;
  check(project === expected.projectId, 'Release project differs from the Firebase app configuration.');
  const source = read('lib/firebase_options.dart');
  const options = {};
  for (const platform of ['android', 'web']) {
    const block = match(source,
      new RegExp(`static const FirebaseOptions ${platform} = FirebaseOptions\\(([\\s\\S]*?)\\n\\s*\\);`), platform);
    options[platform] = Object.fromEntries(['projectId', 'appId', 'messagingSenderId', 'storageBucket', 'apiKey']
      .map(field => [field, match(block, new RegExp(`${field}:\\s*'([^']+)'`), `${platform}.${field}`)]));
    check(options[platform].projectId === project, `Firebase ${platform} points to a different project.`);
    check(firebase.flutter.platforms.dart['lib/firebase_options.dart'].configurations[platform] === options[platform].appId,
      `Firebase ${platform} app ID differs from firebase.json.`);
  }
  check(options.android.appId === expected.appId, 'Android Firebase app ID differs from firebase.json.');
  const google = json('android/app/google-services.json');
  const packageName = match(read('android/app/build.gradle.kts'), /applicationId\s*=\s*"([^"]+)"/, 'Android applicationId');
  const client = google.client?.find(value => value.client_info?.android_client_info?.package_name === packageName);
  check(client, 'google-services.json has no client for the Android applicationId.');
  check(google.project_info?.project_id === project &&
    String(google.project_info?.project_number) === options.android.messagingSenderId &&
    google.project_info?.storage_bucket === options.android.storageBucket &&
    client.client_info.mobilesdk_app_id === options.android.appId &&
    client.api_key?.some(value => value.current_key === options.android.apiKey),
  'Android Firebase options do not match google-services.json.');
  check(options.web.storageBucket === options.android.storageBucket &&
    options.web.messagingSenderId === options.android.messagingSenderId,
  'Web and Android Firebase storage or sender configuration differs.');
  check(read('android/app/src/main/AndroidManifest.xml').includes('android.permission.INTERNET'),
    'Release Android manifest is missing Internet permission.');
  const config = read('lib/app/cau_hinh_ung_dung.dart');
  const region = match(config, /functionsRegion\s*=\s*'([^']+)'/, 'Functions region');
  const functionsSource = read('functions/src/diem_vao.js');
  const regions = [...functionsSource.matchAll(/region:\s*'([^']+)'/g)].map(value => value[1]);
  check(regions.length && regions.every(value => value === region), 'App and deployed Functions regions differ.');
  const indexes = json(firebase.firestore?.indexes);
  check(Array.isArray(indexes.indexes) && Array.isArray(indexes.fieldOverrides), 'Invalid Firestore index configuration.');
  check(read(firebase.firestore?.rules).trim() && read(firebase.storage?.rules).trim(), 'Firebase rules are missing.');
  const callables = [...functionsSource.matchAll(/export const (\w+) = (?:callable\(|onCall\()/g)].map(value => value[1]);
  return {projectId: project, region, indexes, callables, hostingSite: firebase.hosting?.site};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const config = verifyFirebaseConfiguration({project: process.argv[2]});
    console.log(`Firebase release configuration verified: ${config.projectId} (${config.region}).`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
