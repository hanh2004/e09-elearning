// Discover tests and pass file paths as separate arguments on every platform.
import { readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const mode = process.argv[2] ?? 'unit';
if (!['unit', 'emulator'].includes(mode)) throw new Error('Use unit or emulator.');
const directory = fileURLToPath(new URL('../', import.meta.url));
if (mode === 'emulator') {
  if (process.env.GCLOUD_PROJECT !== 'demo-e09') {
    throw new Error('Emulator tests require GCLOUD_PROJECT=demo-e09.');
  }
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST']) {
    if (!/^127\.0\.0\.1:\d+$/.test(process.env[key] ?? '')) {
      throw new Error(`A local emulator is required: ${key}`);
    }
  }
}
const suffix = mode === 'unit' ? '.test.js' : '.emulator.js';
const files = readdirSync(new URL('../test/', import.meta.url))
  .filter(file => file.endsWith(suffix)).sort().map(file => `test/${file}`);
if (!files.length) throw new Error('No tests discovered.');
console.log(`Running ${files.length} ${mode} test files.`);
let failedFiles = 0;
for (const file of files) {
  if (mode === 'emulator') {
    // These suites use the same demo project. Reset only the guarded local
    // emulators so bootstrap/migration never inherit another suite's fixtures.
    const resets = [
      `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-e09/databases/(default)/documents`,
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/demo-e09/accounts`,
    ];
    for (const url of resets) {
      const response = await fetch(url, {method:'DELETE', signal:AbortSignal.timeout(30000)});
      if (!response.ok) throw new Error(`Local emulator reset failed: HTTP ${response.status}`);
    }
  }
  console.log(`Test file: ${file}`);
  const result = spawnSync(process.execPath, ['--test', file], {
    cwd: directory,
    env: process.env,
    stdio: 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) failedFiles++;
}
console.log(`Test files: ${files.length - failedFiles} passed; ${failedFiles} failed.`);
process.exitCode = failedFiles ? 1 : 0;
