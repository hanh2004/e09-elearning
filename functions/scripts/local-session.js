import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Run only through the demo Firebase emulator launcher.');
}
execFileSync(process.execPath, ['scripts/bootstrap.js', '--project', 'demo-e09', '--apply'], {
  env: process.env, stdio: 'inherit', cwd: fileURLToPath(new URL('..', import.meta.url)),
});
console.log('LOCAL DEMO READY: admintong1 / admintong2. Initial password is 123456; existing passwords are not reset.');
console.log('In another terminal at the project root:');
console.log('flutter run -d chrome -t lib/main_admin.dart --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1');
console.log('Leave this terminal running. Ctrl+C stops the demo and exports local data.');
const keepAlive = setInterval(() => {}, 60_000);
await new Promise((resolve) => {
  process.once('SIGINT', resolve);
  process.once('SIGTERM', resolve);
});
clearInterval(keepAlive);
