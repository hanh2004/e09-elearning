// Mặc định chỉ rà dữ liệu. Chạy --apply sau khi xem dry-run và cho phép cập nhật dữ liệu.
import {initializeApp, applicationDefault, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {pathToFileURL} from 'node:url';
import {makeUserCode, userCodeKey, userCodeSuffix, validateUnit, requireThat, rootIds} from '../src/policy.js';

export async function backfillUserCodes(db, apply = false) {
  return db.runTransaction(async tx => {
    const config = (await tx.get(db.doc('system/access'))).data();
    const roots = rootIds(config);
    const users = await tx.get(db.collection('users'));
    const byId = new Map(users.docs.map(doc => [doc.id, doc.data()]));
    const unitRecords = await tx.get(db.collection('unit_codes'));
    const codes = await tx.get(db.collection('user_codes'));
    const usedUnits = new Map(unitRecords.docs.map(doc=>[doc.id,doc.data().managerId]));
    const usedCodes = new Map(codes.docs.map(doc=>[doc.id,doc.data().uid]));
    const writes = [];
    let managers = 0, learners = 0;
    for (const doc of users.docs) {
      const data = doc.data();
      if (data.role !== 'admin' || !['active','pending'].includes(data.status)) continue;
      const unit = validateUnit(data.unit), key = userCodeKey(unit);
      requireThat(key !== userCodeKey('E09') && (!usedUnits.has(key) || usedUnits.get(key) === doc.id),
        'already-exists', `Mã đơn vị cần xử lý trước: ${doc.id}`);
      usedUnits.set(key,doc.id);
      writes.push(()=>tx.set(db.doc(`unit_codes/${key}`),{unit,managerId:doc.id}));
      managers++;
    }
    for (const doc of users.docs) {
      const data=doc.data();
      if (data.role !== 'user' || !['active','blocked'].includes(data.status)) continue;
      const manager=byId.get(data.createdBy);
      requireThat(manager && (roots.includes(data.createdBy) || manager.role === 'admin'),
        'failed-precondition', `Cần phân quản lý cho học viên trước: ${doc.id}`);
      const unit = roots.includes(data.createdBy) ? 'E09' : validateUnit(manager.unit);
      const suffix = userCodeSuffix(data,doc.id), code = makeUserCode(unit,suffix), key = userCodeKey(code);
      requireThat(!usedCodes.has(key) || usedCodes.get(key) === doc.id,
        'already-exists', `Mã học viên bị trùng, cần xử lý trước: ${doc.id}`);
      usedCodes.set(key,doc.id);
      const moved = data.unit !== unit;
      const oldKey = data.userCode ? userCodeKey(data.userCode) : null;
      writes.push(()=>{
        tx.set(db.doc(`user_codes/${key}`),{uid:doc.id,code,createdBy:data.createdBy});
        if (oldKey && oldKey !== key && usedCodes.get(oldKey) === doc.id) tx.delete(db.doc(`user_codes/${oldKey}`));
        tx.update(doc.ref,{unit,userCode:code,userCodeSuffix:suffix,
          originalCreatedBy:data.originalCreatedBy || data.createdBy,
          ...(moved ? {subUnit:'',unitNeedsConfirmation:true,unitAssignmentVersion:(data.unitAssignmentVersion||0)+1} : {}),
        });
      });
      learners++;
    }
    if (apply) for (const write of writes) write();
    return {mode:apply?'applied':'dry-run',managers,learners};
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args=process.argv.slice(2), index=args.indexOf('--project'), projectId=args[index+1];
  if (index<0 || !projectId || projectId.startsWith('--')) throw new Error('Specify --project <id>. Default: dry-run.');
  const demo=projectId.startsWith('demo-');
  if (demo !== Boolean(process.env.FIRESTORE_EMULATOR_HOST)) throw new Error('Project and emulator environment do not match.');
  const app=initializeApp({projectId,...(demo?{}:{credential:applicationDefault()})});
  try { console.log(JSON.stringify(await backfillUserCodes(getFirestore(app),args.includes('--apply')))); }
  finally { await deleteApp(app); }
}
