// API GÓP Ý: chỉ nhận nội dung từ tài khoản học viên đang hoạt động.
// Mật khẩu chỉ được xác thực lại ở Firebase Auth phía client, không gửi vào đây.
import { FieldValue } from 'firebase-admin/firestore';
import { requireThat } from './policy.js';

const categories = new Set(['bug', 'idea', 'other']);

export function feedbackHandlers(db) {
  async function submitFeedback(uid, input) {
    requireThat(typeof uid === 'string' && uid.length > 0,
      'unauthenticated', 'Cần đăng nhập.');
    requireThat(input && typeof input === 'object' &&
      Object.keys(input).every((key) => ['category', 'message'].includes(key)),
    'invalid-argument', 'Dữ liệu góp ý không hợp lệ.');
    requireThat(categories.has(input.category), 'invalid-argument',
      'Chọn nhóm góp ý hợp lệ.');
    requireThat(typeof input.message === 'string' &&
      input.message.trim().length >= 10 && input.message.trim().length <= 2000,
    'invalid-argument', 'Nội dung góp ý cần từ 10 đến 2.000 ký tự.');

    const profile = (await db.doc(`users/${uid}`).get()).data();
    requireThat(profile?.status === 'active' && profile.role === 'user',
      'permission-denied', 'Chỉ học viên đang hoạt động mới được gửi góp ý.');

    const limitRef = db.doc(`feedback_limits/${uid}`);
    const now = Date.now();
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(limitRef);
      const previous = snapshot.data() ?? {};
      const lastAt = previous.lastAt?.toMillis?.() ?? 0;
      const dayStart = previous.dayStart?.toMillis?.() ?? 0;
      const count = now - dayStart < 86_400_000 ? previous.count ?? 0 : 0;
      requireThat(now - lastAt >= 30_000, 'resource-exhausted',
        'Vui lòng đợi 30 giây trước khi gửi góp ý tiếp theo.');
      requireThat(count < 20, 'resource-exhausted',
        'Bạn đã đạt giới hạn 20 góp ý trong ngày.');
      transaction.set(limitRef, {
        lastAt: FieldValue.serverTimestamp(),
        dayStart: count === 0 ? FieldValue.serverTimestamp() : previous.dayStart,
        count: count + 1,
      });
    });

    const feedback = db.collection('feedback').doc();
    await feedback.create({
      userId: uid,
      username: typeof profile.username === 'string' ? profile.username : '',
      name: typeof profile.name === 'string' ? profile.name : '',
      category: input.category,
      message: input.message.trim(),
      status: 'new',
      createdAt: FieldValue.serverTimestamp(),
    });
    return { submitted: true, feedbackId: feedback.id };
  }

  return { submitFeedback };
}
