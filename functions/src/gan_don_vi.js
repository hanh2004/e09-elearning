// NGHIỆP VỤ TÀI KHOẢN: đổi mã đơn vị và đồng bộ mã học viên theo từng đợt.
import {randomUUID} from 'node:crypto';
import {FieldPath} from 'firebase-admin/firestore';

const PAGE_SIZE = 60;
const OPERATION_COLLECTION = 'unit_change_operations';

export function createSetUnitHandler({
  coSoDuLieu,
  userRef,
  nguCanh,
  requireRoot,
  requireThat,
  validateUnit,
  userCodeKey,
  makeUserCode,
  userCodeSuffix,
  unitReservation,
  assignment,
  stamp,
}) {
  return async function setUnit(maNguoiDung, dauVao) {
    const donVi = validateUnit(dauVao.unit);
    const quanLyRef = userRef(dauVao.userId);
    const thaoTacRef = coSoDuLieu.doc(`${OPERATION_COLLECTION}/${quanLyRef.id}`);

    const started = await coSoDuLieu.runTransaction(async giaoDich => {
      const {actor, config} = await nguCanh(giaoDich, maNguoiDung);
      requireRoot(actor, config);
      const [managerSnapshot, operationSnapshot, indexSnapshot] = await Promise.all([
        giaoDich.get(quanLyRef), giaoDich.get(thaoTacRef),
        giaoDich.get(coSoDuLieu.doc('system/code_indexes')),
      ]);
      const quanLy = managerSnapshot.data();
      requireThat(quanLy?.role === 'admin' && ['active', 'pending'].includes(quanLy.status),
        'failed-precondition', 'Chọn quản lý đang hoạt động hoặc chờ duyệt.');
      requireThat(quanLy.adminDeletionPending !== true, 'failed-precondition',
        'Không thể đổi đơn vị cho quản lý đang chờ duyệt xóa.');
      requireThat(indexSnapshot.data()?.status === 'complete', 'failed-precondition',
        'Cần hoàn tất backfill mã cũ trước khi đổi đơn vị theo đợt.');
      if (userCodeKey(quanLy.unit || '') === userCodeKey(donVi)) return {complete: true};

      const oldOperation = operationSnapshot.data();
      if (oldOperation?.status === 'running') {
        requireThat(oldOperation.newUnit === donVi &&
          quanLy.unitChangePending === true &&
          quanLy.unitChangeOperationId === oldOperation.operationId,
        'failed-precondition', 'Đang có thao tác đổi đơn vị khác. Hãy tiếp tục thao tác đang chạy trước.');
        return {complete: false};
      }

      const reserve = await unitReservation(giaoDich, donVi, quanLyRef.id);
      const operationId = randomUUID();
      reserve();
      giaoDich.update(quanLyRef, {
        unitChangePending: true,
        unitChangeOperationId: operationId,
        unitChangeTarget: donVi,
        updatedAt: stamp(),
        updatedBy: maNguoiDung,
      });
      giaoDich.set(thaoTacRef, {
        operationId,
        managerId: quanLyRef.id,
        actorId: maNguoiDung,
        oldUnit: quanLy.unit,
        newUnit: donVi,
        status: 'running',
        phase: 'checking',
        checkCursor: null,
        learnerCursor: null,
        requestCursor: null,
        checked: 0,
        processed: 0,
        createdAt: stamp(),
        updatedAt: stamp(),
      });
      return {complete: false};
    });
    if (started.complete) return {updated: true, processed: 0};

    while (true) {
      const result = await coSoDuLieu.runTransaction(async giaoDich => {
        const {actor, config} = await nguCanh(giaoDich, maNguoiDung);
        requireRoot(actor, config);
        const [managerSnapshot, operationSnapshot] = await Promise.all([
          giaoDich.get(quanLyRef), giaoDich.get(thaoTacRef),
        ]);
        const quanLy = managerSnapshot.data();
        const thaoTac = operationSnapshot.data();
        requireThat(thaoTac?.status === 'running' && thaoTac.newUnit === donVi &&
          quanLy?.unitChangePending === true &&
          quanLy.unitChangeOperationId === thaoTac.operationId,
        'failed-precondition', 'Không tìm thấy thao tác đổi đơn vị có thể tiếp tục.');
        const childrenQuery = coSoDuLieu.collection('users')
          .where('createdBy', '==', quanLyRef.id)
          .orderBy(FieldPath.documentId()).limit(PAGE_SIZE);

        if (thaoTac.phase === 'checking') {
          const pageQuery = thaoTac.checkCursor ? childrenQuery.startAfter(thaoTac.checkCursor) : childrenQuery;
          const page = await giaoDich.get(pageQuery);
          if (page.empty) {
            giaoDich.update(thaoTacRef, {
              phase: 'applying', learnerCursor: null, requestCursor: null, updatedAt: stamp(),
            });
            return {phase: 'applying'};
          }

          const candidates = new Map();
          let collision = null;
          for (const child of page.docs) {
            const data = child.data();
            if (data.role !== 'user' || data.status === 'deleting') continue;
            const suffix = userCodeSuffix(data, child.id);
            const code = makeUserCode(donVi, suffix);
            const key = userCodeKey(code);
            if (candidates.has(key)) {
              collision = key;
              break;
            }
            candidates.set(key, {uid: child.id, code});
          }
          const reservationRefs = collision ? [] : [...candidates.keys()].map(key =>
            coSoDuLieu.doc(`user_codes/${key}`));
          const reservations = reservationRefs.length
            ? await giaoDich.getAll(...reservationRefs) : [];
          reservations.forEach(snapshot => {
            if (snapshot.exists && snapshot.data().uid !== candidates.get(snapshot.id)?.uid) {
              collision = snapshot.id;
            }
          });
          if (collision) {
            const targetUnitRef = coSoDuLieu.doc(`unit_codes/${userCodeKey(donVi)}`);
            const targetUnit = await giaoDich.get(targetUnitRef);
            if (targetUnit.exists && targetUnit.data().managerId === quanLyRef.id) {
              giaoDich.delete(targetUnitRef);
            }
            giaoDich.update(quanLyRef, {
              unitChangePending: false, unitChangeOperationId: null, unitChangeTarget: null,
            });
            giaoDich.update(thaoTacRef, {status: 'failed', errorCode: 'already-exists', updatedAt: stamp()});
            return {collision};
          }
          giaoDich.update(thaoTacRef, {
            checkCursor: page.docs.at(-1).id,
            checked: (thaoTac.checked || 0) + page.size,
            updatedAt: stamp(),
          });
          return {phase: 'checking'};
        }

        requireThat(thaoTac.phase === 'applying', 'failed-precondition',
          'Giai đoạn đổi đơn vị không hợp lệ.');
        const requestsQuery = coSoDuLieu.collection('admin_requests')
          .where('targetUid', '==', quanLyRef.id)
          .orderBy(FieldPath.documentId()).limit(PAGE_SIZE);
        const childrenPageQuery = thaoTac.learnerCursor
          ? childrenQuery.startAfter(thaoTac.learnerCursor) : childrenQuery;
        const requestsPageQuery = thaoTac.requestCursor
          ? requestsQuery.startAfter(thaoTac.requestCursor) : requestsQuery;
        const [children, requests] = await Promise.all([
          giaoDich.get(childrenPageQuery), giaoDich.get(requestsPageQuery),
        ]);
        if (children.empty && requests.empty) {
          const oldUnitRef = thaoTac.oldUnit
            ? coSoDuLieu.doc(`unit_codes/${userCodeKey(thaoTac.oldUnit)}`) : null;
          const oldUnit = oldUnitRef ? await giaoDich.get(oldUnitRef) : null;
          if (oldUnit?.exists && oldUnit.data().managerId === quanLyRef.id) {
            giaoDich.delete(oldUnitRef);
          }
          giaoDich.update(quanLyRef, {
            unit: donVi, unitChangePending: false,
            unitChangeOperationId: null, unitChangeTarget: null,
            updatedAt: stamp(), updatedBy: maNguoiDung,
          });
          giaoDich.update(thaoTacRef, {status: 'complete', completedAt: stamp(), updatedAt: stamp()});
          giaoDich.create(coSoDuLieu.collection('account_audit').doc(), {
            actorId: maNguoiDung, targetUid: quanLyRef.id,
            action: 'assign_unit', unit: donVi, at: stamp(),
          });
          return {complete: true, processed: thaoTac.processed || 0};
        }

        const assignments = [];
        const learners = {docs: []};
        for (const child of children.docs) {
          if (child.data().role !== 'user' || child.data().status === 'deleting') continue;
          assignments.push(await assignment({
            giaoDich, thamChieu: child.ref, dich: child.data(), donVi,
            managerId: quanLyRef.id, actorId: maNguoiDung,
            existingLearners: learners, unitChangeOperationId: thaoTac.operationId,
          }));
        }
        const oldUnitRef = thaoTac.oldUnit
          ? coSoDuLieu.doc(`unit_codes/${userCodeKey(thaoTac.oldUnit)}`) : null;
        if (oldUnitRef) await giaoDich.get(oldUnitRef);
        for (const applyAssignment of assignments) applyAssignment();
        for (const request of requests.docs) giaoDich.update(request.ref, {unit: donVi});
        giaoDich.update(thaoTacRef, {
          learnerCursor: children.empty ? thaoTac.learnerCursor : children.docs.at(-1).id,
          requestCursor: requests.empty ? thaoTac.requestCursor : requests.docs.at(-1).id,
          processed: (thaoTac.processed || 0) + assignments.length,
          updatedAt: stamp(),
        });
        return {complete: false, processed: (thaoTac.processed || 0) + assignments.length};
      });

      if (result.collision) {
        requireThat(false, 'already-exists',
          `Mã học viên ${result.collision} đã được tài khoản khác sử dụng. Chưa đổi hồ sơ nào.`);
      }
      if (result.complete) return {updated: true, processed: result.processed};
    }
  };
}
