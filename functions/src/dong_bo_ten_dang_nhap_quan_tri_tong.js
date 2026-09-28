// Đồng bộ tên đăng nhập admin tổng khi người phát triển sửa users/{uid}.username
// trực tiếp trong Firebase Console. UID và mật khẩu giữ nguyên; email giả được đồng bộ.
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { loginEmail, usernameKey } from './quy_tac.js';

const validUsername = (value) => typeof value === 'string' && value === value.trim() &&
  /^[A-Za-z0-9_.@-]{3,64}$/.test(value);

export function createRootUsernameSyncHandler(db, auth) {
  return async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const oldUsername = before?.username;
    const newUsername = after?.username;
    if (typeof oldUsername !== 'string' || oldUsername === newUsername) return;

    const profileRef = db.doc(`users/${uid}`);
    const isValidUsername = validUsername(newUsername);
    const newNameRef = isValidUsername
      ? db.doc(`usernames/${usernameKey(newUsername)}`)
      : null;
    let result;
    await db.runTransaction(async (tx) => {
      const [profileSnap, configSnap, newNameSnap, oldNames] = await Promise.all([
        tx.get(profileRef),
        tx.get(db.doc('system/access')),
        newNameRef ? tx.get(newNameRef) : Promise.resolve({ exists: false }),
        tx.get(db.collection('usernames').where('uid', '==', uid)),
      ]);
      const current = profileSnap.data();
      const roots = configSnap.data()?.rootUids;
      if (current?.username !== newUsername) {
        result = 'stale';
        return;
      }
      if (!Array.isArray(roots) || roots.length !== 2 || new Set(roots).size !== 2 ||
        !roots.includes(uid) || current.role !== 'super_admin') {
        result = 'not-root';
        return;
      }
      if (!isValidUsername) {
        result = 'invalid';
        return;
      }
      if (newNameSnap.exists && newNameSnap.data()?.uid !== uid) {
        result = 'taken';
        return;
      }

      for (const nameDoc of oldNames.docs) {
        if (nameDoc.id !== newNameRef.id) tx.delete(nameDoc.ref);
      }
      tx.set(newNameRef, { uid, username: newUsername });
      result = 'synced';
    });

    if (result === 'stale') return;
    if (result === 'not-root') {
      console.error('Root username sync ignored: target is not a configured root account.');
      return;
    }
    if (result !== 'synced') {
      // Firestore triggers run after the edit. Revert invalid/colliding names;
      // the resulting event restores the old index without changing Auth.
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(profileRef);
        if (latest.data()?.username === newUsername) {
          tx.update(profileRef, { username: oldUsername });
        }
      });
      console.error(`Root username sync rejected: ${result}`);
      return;
    }

    try {
      const user = await auth.getUser(uid);
      const newEmail = loginEmail(newUsername);
      if (user.email === newEmail) return; // Safe retry after a partial success.
      await auth.updateUser(uid, { email: newEmail });
    } catch (error) {
      // Restore the profile; its next update event will restore the old index.
      await db.runTransaction(async (tx) => {
        const latest = await tx.get(profileRef);
        if (latest.data()?.username === newUsername) {
          tx.update(profileRef, { username: oldUsername });
        }
      });
      console.error(`Root username Auth sync failed: ${error.code ?? error.name}`);
      throw error;
    }
  };
}

export function rootUsernameSyncTrigger(db, auth) {
  return onDocumentUpdated({
    document: 'users/{uid}',
    region: 'asia-southeast1',
    retry: true,
  }, createRootUsernameSyncHandler(db, auth));
}
