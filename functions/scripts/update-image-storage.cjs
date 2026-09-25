// Patch only image settings on the deployed project; preserve unrelated rules.
// Dry run by default. Pass --apply after reviewing the printed changes.
const {getGlobalDefaultAccount} = require('../node_modules/firebase-tools/lib/auth.js');
const {requireAuth} = require('../node_modules/firebase-tools/lib/requireAuth.js');
const {Client} = require('../node_modules/firebase-tools/lib/apiv2.js');
const {testRuleset, createRuleset, updateRelease} = require('../node_modules/firebase-tools/lib/gcp/rules.js');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const project = 'e09-elearning';
const bucket = 'e09-elearning.firebasestorage.app';

(async () => {
  await requireAuth({project, ...getGlobalDefaultAccount()});
  const rules = new Client({urlPrefix: 'https://firebaserules.googleapis.com', apiVersion: 'v1', auth: true});
  const changes = [];
  for (const releaseName of [`firebase.storage/${bucket}`, 'cloud.firestore']) {
    const path = `/projects/${project}/releases/${releaseName}`;
    const release = (await rules.get(path)).body;
    const source = (await rules.get('/' + release.rulesetName)).body.source;
    if (source.files.length !== 1) throw new Error('Unexpected multi-file ruleset; manual review required.');
    const file = source.files[0];
    let content;
    if (releaseName.startsWith('firebase.storage/')) {
      content = file.content.replace('request.resource.size <= 5 * 1024 * 1024', 'request.resource.size <= 20 * 1024 * 1024');
      if (!content.includes('request.resource.size <= 20 * 1024 * 1024')) throw new Error('Unexpected image limit.');
      console.log('Storage: raise image limit from 5 MB to 20 MB; retain existing permissions.');
    } else {
      const pattern = /function hasCover\(data\) \{[\s\S]*?\}/;
      const original = file.content.match(pattern)?.[0];
      const replacement = readFileSync(join(__dirname, '../../firestore.rules'), 'utf8').match(pattern)?.[0];
      if (!original || !replacement || !original.includes("matches('https://.*')")) throw new Error('Unexpected cover validator.');
      content = file.content.replace(pattern, replacement);
      console.log('Firestore cover validator before:', original);
      console.log('Firestore cover validator after:', replacement);
    }
    if (content === file.content) continue;
    const files = [{name: file.name, content}];
    const validation = await testRuleset(project, files);
    if (validation.body.issues?.some(issue => issue.severity === 'ERROR')) throw new Error(JSON.stringify(validation.body.issues));
    changes.push({releaseName, path, previous: release.rulesetName, files});
    console.log('Previous ruleset retained for rollback:', release.rulesetName);
  }
  if (!process.argv.includes('--apply')) {
    console.log('Dry run complete. No deployed settings changed.');
    return;
  }
  for (const change of changes) {
    const current = (await rules.get(change.path)).body;
    if (current.rulesetName !== change.previous) throw new Error('Rules changed during deployment; retry after review.');
    const created = await createRuleset(project, change.files);
    await updateRelease(project, created, change.releaseName);
    if ((await rules.get(change.path)).body.rulesetName !== created) throw new Error('Release verification failed.');
    console.log('Verified deployed image rules:', change.releaseName);
  }
})().catch(error => {console.error(error.message); process.exitCode = 1;});
