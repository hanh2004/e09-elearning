// Mặc định chỉ rà dữ liệu. Chạy --apply sau khi xem dry-run và cho phép cập nhật dữ liệu.
import {initializeApp, applicationDefault, deleteApp} from 'firebase-admin/app';
import {FieldPath, FieldValue, getFirestore} from 'firebase-admin/firestore';
import {pathToFileURL} from 'node:url';
import {makeUserCode, userCodeKey, userCodeSuffix, validateUnit, requireThat, rootIds} from '../src/quy_tac.js';

const PAGE_SIZE = 80;
const INDEX_MIGRATION = 'system/code_indexes';

function planPage(docs, managersById, roots, unitOwners, codeOwners) {
  const unitWrites = new Map();
  const codeWrites = new Map();
  const updates = [];
  let managers = 0;
  let learners = 0;
  let requiredWrites = 0;

  for (const doc of docs) {
    const data = doc.data();
    if (data.role !== 'admin' || data.status === 'rejected' || typeof data.unit !== 'string') continue;
    const unit = validateUnit(data.unit);
    const key = userCodeKey(unit);
    requireThat(key !== userCodeKey('E09') && (!unitOwners.has(key) || unitOwners.get(key) === doc.id),
      'already-exists', `Mã đơn vị cần xử lý trước: ${doc.id}`);
    unitOwners.set(key, doc.id);
    unitWrites.set(key, {unit, managerId: doc.id});
    managers++;
    requiredWrites++;
  }

  for (const doc of docs) {
    const data = doc.data();
    if (data.role !== 'user' || !['active', 'blocked'].includes(data.status)) continue;
    const manager = managersById.get(data.createdBy);
    requireThat(manager && (roots.includes(data.createdBy) || manager.role === 'admin'),
      'failed-precondition', `Cần phân quản lý cho học viên trước: ${doc.id}`);
    const unit = roots.includes(data.createdBy) ? 'E09' : validateUnit(manager.unit);
    const suffix = userCodeSuffix(data, doc.id);
    const code = makeUserCode(unit, suffix);
    const key = userCodeKey(code);
    requireThat(!codeOwners.has(key) || codeOwners.get(key) === doc.id,
      'already-exists', `Mã học viên bị trùng, cần xử lý trước: ${doc.id}`);
    codeOwners.set(key, doc.id);
    codeWrites.set(key, {uid: doc.id, code, createdBy: data.createdBy});
    const oldKey = data.userCode ? userCodeKey(data.userCode) : null;
    const deleteOld = oldKey && oldKey !== key && codeOwners.get(oldKey) === doc.id;
    updates.push({ref: doc.ref, unit, code, suffix, data, key, oldKey, deleteOld});
    learners++;
    requiredWrites += 2 + (deleteOld ? 1 : 0);
  }
  for (const doc of docs) {
    const data = doc.data();
    if (data.role !== 'user' || ['active', 'blocked'].includes(data.status) || typeof data.userCode !== 'string') continue;
    const key = userCodeKey(data.userCode);
    requireThat(!codeOwners.has(key) || codeOwners.get(key) === doc.id,
      'already-exists', `Mã học viên bị trùng, cần xử lý trước: ${doc.id}`);
    codeOwners.set(key, doc.id);
    codeWrites.set(key, {uid: doc.id, code: data.userCode, createdBy: data.createdBy});
    requiredWrites++;
  }
  return {unitWrites, codeWrites, updates, managers, learners, requiredWrites};
}

export async function backfillUserCodes(db, apply = false) {
  const preview = {mode: apply ? 'applied' : 'dry-run', managers: 0, learners: 0, requiredWrites: 0};
  const unitOwners = new Map();
  const codeOwners = new Map();
  const migrationRef = db.doc(INDEX_MIGRATION);
  let cursor = null;
  let resumed = false;

  if (apply) {
    const state = (await migrationRef.get()).data();
    if (state?.status === 'running' && typeof state.lastUserId === 'string') {
      cursor = state.lastUserId;
      resumed = true;
    }
  }

  while (true) {
    const query = db.collection('users').orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
    const pageQuery = cursor ? query.startAfter(cursor) : query;
    let pageDocs;

    if (apply) {
      const result = await db.runTransaction(async tx => {
        const state = (await tx.get(migrationRef)).data();
        const effectiveCursor = resumed && state?.status === 'running' ? state.lastUserId : cursor;
        const currentQuery = effectiveCursor
          ? query.startAfter(effectiveCursor) : query;
        const page = await tx.get(currentQuery);
        if (page.empty) return {empty: true, lastUserId: effectiveCursor};

        const docs = page.docs;
        const ids = new Set(docs.map(doc => doc.id));
        const managerIds = [...new Set(docs.map(doc => doc.data().createdBy)
          .filter(id => typeof id === 'string' && !ids.has(id)))];
        const managerRefs = managerIds.map(id => db.doc(`users/${id}`));
        const managerSnapshots = managerRefs.length ? await tx.getAll(...managerRefs) : [];
        const managersById = new Map(docs.map(doc => [doc.id, doc.data()]));
        managerSnapshots.forEach(snapshot => { if (snapshot.exists) managersById.set(snapshot.id, snapshot.data()); });
        const config = (await tx.get(db.doc('system/access'))).data();
        const roots = rootIds(config);

        const plannedUnits = new Map();
        const plannedCodes = new Map();
        for (const doc of docs) {
          const data = doc.data();
          if (data.role === 'admin' && data.status !== 'rejected' && typeof data.unit === 'string') {
            const key = userCodeKey(validateUnit(data.unit));
            plannedUnits.set(key, db.doc(`unit_codes/${key}`));
          }
          if (data.role === 'user' && (['active', 'blocked'].includes(data.status) || typeof data.userCode === 'string')) {
            if (!['active', 'blocked'].includes(data.status)) {
              const key = userCodeKey(data.userCode);
              plannedCodes.set(key, db.doc(`user_codes/${key}`));
              continue;
            }
            const manager = managersById.get(data.createdBy);
            requireThat(manager && (roots.includes(data.createdBy) || manager.role === 'admin'),
              'failed-precondition', `Cần phân quản lý cho học viên trước: ${doc.id}`);
            const unit = roots.includes(data.createdBy) ? 'E09' : validateUnit(manager.unit);
            const key = userCodeKey(makeUserCode(unit, userCodeSuffix(data, doc.id)));
            plannedCodes.set(key, db.doc(`user_codes/${key}`));
            if (data.userCode) {
              const oldKey = userCodeKey(data.userCode);
              if (oldKey !== key) plannedCodes.set(oldKey, db.doc(`user_codes/${oldKey}`));
            }
          }
        }
        const indexRefs = [...plannedUnits.values(), ...plannedCodes.values()];
        const indexSnapshots = indexRefs.length ? await tx.getAll(...indexRefs) : [];
        const unitOwners = new Map();
        const codeOwners = new Map();
        indexSnapshots.forEach(snapshot => {
          if (snapshot.ref.parent.id === 'unit_codes' && snapshot.exists) unitOwners.set(snapshot.id, snapshot.data().managerId);
          if (snapshot.ref.parent.id === 'user_codes' && snapshot.exists) codeOwners.set(snapshot.id, snapshot.data().uid);
        });
        const plan = planPage(docs, managersById, roots, unitOwners, codeOwners);

        for (const [key, value] of plan.unitWrites) tx.set(db.doc(`unit_codes/${key}`), value);
        for (const [key, value] of plan.codeWrites) tx.set(db.doc(`user_codes/${key}`), value);
        for (const update of plan.updates) {
          if (update.deleteOld) tx.delete(db.doc(`user_codes/${update.oldKey}`));
          const moved = update.data.unit !== update.unit;
          tx.update(update.ref, {
            unit: update.unit,
            userCode: update.code,
            userCodeSuffix: update.suffix,
            originalCreatedBy: FieldValue.delete(),
            ...(moved ? {subUnit: '', unitNeedsConfirmation: true,
              unitAssignmentVersion: (update.data.unitAssignmentVersion || 0) + 1} : {}),
          });
        }
        const lastUserId = docs.at(-1).id;
        tx.set(migrationRef, {status: 'running', lastUserId,
          processedUsers: (state?.processedUsers || 0) + docs.length,
          updatedAt: new Date()}, {merge: true});
        return {...plan, lastUserId, docsCount: docs.length};
      });

      if (result.empty) {
        await migrationRef.set({status: 'complete', completedAt: new Date()}, {merge: true});
        break;
      }
      preview.managers += result.managers;
      preview.learners += result.learners;
      preview.requiredWrites += result.requiredWrites;
      cursor = result.lastUserId;
      resumed = false;
    } else {
      const page = await pageQuery.get();
      if (page.empty) break;
      pageDocs = page.docs;
      const ids = new Set(pageDocs.map(doc => doc.id));
      const managerIds = [...new Set(pageDocs.map(doc => doc.data().createdBy)
        .filter(id => typeof id === 'string' && !ids.has(id)))];
      const managerSnapshots = managerIds.length
        ? await db.getAll(...managerIds.map(id => db.doc(`users/${id}`))) : [];
      const managersById = new Map(pageDocs.map(doc => [doc.id, doc.data()]));
      managerSnapshots.forEach(snapshot => { if (snapshot.exists) managersById.set(snapshot.id, snapshot.data()); });
      const config = (await db.doc('system/access').get()).data();
      const roots = rootIds(config);
      const candidateUnits = new Set();
      const candidateCodes = new Set();
      for (const doc of pageDocs) {
        const data = doc.data();
        if (data.role === 'admin' && data.status !== 'rejected' && typeof data.unit === 'string') candidateUnits.add(userCodeKey(validateUnit(data.unit)));
        if (data.role === 'user' && (['active', 'blocked'].includes(data.status) || typeof data.userCode === 'string')) {
          if (!['active', 'blocked'].includes(data.status)) {
            candidateCodes.add(userCodeKey(data.userCode));
            continue;
          }
          const manager = managersById.get(data.createdBy);
          requireThat(manager && (roots.includes(data.createdBy) || manager.role === 'admin'),
            'failed-precondition', `Cần phân quản lý cho học viên trước: ${doc.id}`);
          const unit = roots.includes(data.createdBy) ? 'E09' : validateUnit(manager.unit);
          const key = userCodeKey(makeUserCode(unit, userCodeSuffix(data, doc.id)));
          candidateCodes.add(key);
          if (data.userCode) candidateCodes.add(userCodeKey(data.userCode));
        }
      }
      const [unitSnapshots, codeSnapshots] = await Promise.all([
        candidateUnits.size ? db.getAll(...[...candidateUnits].map(key => db.doc(`unit_codes/${key}`))) : [],
        candidateCodes.size ? db.getAll(...[...candidateCodes].map(key => db.doc(`user_codes/${key}`))) : [],
      ]);
      unitSnapshots.forEach(snapshot => { if (snapshot.exists) unitOwners.set(snapshot.id, snapshot.data().managerId); });
      codeSnapshots.forEach(snapshot => { if (snapshot.exists) codeOwners.set(snapshot.id, snapshot.data().uid); });
      const plan = planPage(pageDocs, managersById, roots, unitOwners, codeOwners);
      for (const [key, value] of plan.unitWrites) unitOwners.set(key, value.managerId);
      for (const [key, value] of plan.codeWrites) codeOwners.set(key, value.uid);
      preview.managers += plan.managers;
      preview.learners += plan.learners;
      preview.requiredWrites += plan.requiredWrites;
      cursor = pageDocs.at(-1).id;
    }
  }
  return preview;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2), index = args.indexOf('--project'), projectId = args[index + 1];
  if (index < 0 || !projectId || projectId.startsWith('--')) throw new Error('Specify --project <id>. Default: dry-run.');
  const demo = projectId.startsWith('demo-');
  if (demo !== Boolean(process.env.FIRESTORE_EMULATOR_HOST)) throw new Error('Project and emulator environment do not match.');
  const app = initializeApp({projectId, ...(demo ? {} : {credential: applicationDefault()})});
  try { console.log(JSON.stringify(await backfillUserCodes(getFirestore(app), args.includes('--apply')))); }
  finally { await deleteApp(app); }
}
