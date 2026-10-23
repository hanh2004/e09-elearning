import test from 'node:test';
import assert from 'node:assert/strict';
import {copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {dirname, join, resolve} from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const projectRoot = fileURLToPath(new URL('../../', import.meta.url));
const temporaryRoot = resolve(projectRoot, '.tmp');
const windowsOnly = {skip: process.platform !== 'win32'};

function fixture(t, {versionName = '1.0.5', failAt = null} = {}) {
  mkdirSync(temporaryRoot, {recursive: true});
  const root = mkdtempSync(join(temporaryRoot, 'publish-test-'));
  t.after(() => {
    assert.equal(dirname(root), temporaryRoot);
    rmSync(root, {recursive: true, force: true});
  });
  for (const folder of ['tooling', 'web', 'functions/node_modules/.bin']) {
    mkdirSync(join(root, folder), {recursive: true});
  }
  const script = join(root, 'tooling/publish_internal_release.ps1');
  copyFileSync(join(projectRoot, 'tooling/publish_internal_release.ps1'), script);
  for (const file of ['functions/scripts/kiem_tra_cau_hinh_firebase.mjs',
    'firebase.json', 'lib/firebase_options.dart', 'lib/app/cau_hinh_ung_dung.dart',
    'android/app/google-services.json', 'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml', 'functions/src/diem_vao.js',
    'firestore.indexes.json', 'firestore.rules', 'storage.rules']) {
    mkdirSync(dirname(join(root, file)), {recursive: true});
    copyFileSync(join(projectRoot, file), join(root, file));
  }
  const manifest = join(root, 'web/app-release.json');
  const original = '{"versionName":"1.0.4","buildNumber":9}\n';
  writeFileSync(manifest, original);
  writeFileSync(join(root, 'scenario.json'), JSON.stringify({versionName, failAt}));
  const flutter = join(root, 'flutter.ps1');
  writeFileSync(flutter, String.raw`
$scenario = Get-Content (Join-Path $PSScriptRoot 'scenario.json') -Raw | ConvertFrom-Json
Set-Content (Join-Path $PSScriptRoot ('flutter-called-' + $args[1] + '.txt')) 'called'
if ($args[1] -eq 'apk') {
  $metadata = Join-Path $PSScriptRoot 'build/app/outputs/apk/release'
  $apk = Join-Path $PSScriptRoot 'build/app/outputs/flutter-apk'
  New-Item -ItemType Directory -Path $metadata,$apk -Force | Out-Null
  @{elements = @(@{versionName = $scenario.versionName; versionCode = 10})} |
    ConvertTo-Json -Depth 4 | Set-Content (Join-Path $metadata 'output-metadata.json')
  Set-Content (Join-Path $apk 'app-release.apk') 'mock apk'
}
$global:LASTEXITCODE = if ($args[1] -eq 'web' -and $scenario.failAt -eq 'web') { 1 } else { 0 }
`);
  // This CLI is local to the disposable fixture; it never calls Firebase.
  writeFileSync(join(root, 'functions/node_modules/.bin/firebase.cmd'),
    `@echo off\r\necho called>"%~dp0../../../deploy-called.txt"\r\nexit /b ${failAt === 'deploy' ? 1 : 0}\r\n`);
  const run = (project = 'e09-elearning') => spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', script, '-FlutterExe', flutter, '-FirebaseProject', project],
  {encoding: 'utf8', timeout: 30000, windowsHide: true});
  return {root, manifest, original, run};
}

for (const failAt of ['web', 'deploy']) {
  test(`failed ${failAt} preserves the previous release manifest`, windowsOnly, t => {
    const state = fixture(t, {failAt});
    const result = state.run();
    assert.equal(result.error, undefined);
    assert.notEqual(result.status, 0);
    assert.equal(existsSync(join(state.root,
      failAt === 'web' ? 'flutter-called-web.txt' : 'deploy-called.txt')), true,
    result.stderr);
    assert.equal(readFileSync(state.manifest, 'utf8'), state.original);
  });
}

test('same-version releases record the build locally and reject reuse', windowsOnly, t => {
  const state = fixture(t, {versionName: '1.0.4'});
  rmSync(join(state.root, 'functions/node_modules/.bin/firebase.cmd'));
  const result = state.run();
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(state.manifest, 'utf8')),
    {versionName: '1.0.4', buildNumber: 10});
  assert.equal(existsSync(join(state.root, 'deploy-called.txt')), false);
  const repeated = state.run();
  assert.equal(repeated.error, undefined);
  assert.notEqual(repeated.status, 0);
});

test('successful version updates keep the manifest and archive the APK', windowsOnly, t => {
  const state = fixture(t);
  const result = state.run();
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(readFileSync(state.manifest, 'utf8')),
    {versionName: '1.0.5', buildNumber: 10});
  assert.equal(existsSync(join(state.root, 'deploy-called.txt')), true);
  assert.equal(existsSync(join(state.root,
    'outputs/internal/e09-hoc-vien-1.0.5-build10.apk')), true);
});

test('mismatched Firebase project stops release before building', windowsOnly, t => {
  const state = fixture(t);
  const result = state.run('wrong-project');
  assert.equal(result.error, undefined);
  assert.notEqual(result.status, 0);
  assert.equal(existsSync(join(state.root, 'flutter-called-apk.txt')), false);
  assert.equal(existsSync(join(state.root, 'deploy-called.txt')), false);
  assert.equal(readFileSync(state.manifest, 'utf8'), state.original);
});
