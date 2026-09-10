# Nâng cấp Firebase Blaze — 10/09/2026

> Bản giao diện và rà soát tiếp theo: [REDESIGN_AUDIT.md](REDESIGN_AUDIT.md), bổ sung trộn đề/đáp án, thông báo đã đọc và các sửa lỗi. Tài liệu này mô tả lần chuyển backend ban đầu.

## Phạm vi bản này

App học viên chuyển mặc định sang Cloud Functions (`USE_SECURE_BACKEND=true`). Web quản trị chuyển thao tác tạo/import/sửa mật khẩu/duyệt/xóa/khóa tài khoản sang backend. Chỉ build và triển khai web trong đợt này; không tạo APK mới. APK cũ không còn được hỗ trợ sau chuyển Rules.

- Máy chủ cấp lượt thi bằng transaction, một phiên tổng hợp cho mỗi học viên/đề. Hai thiết bị mở đồng thời nhận cùng lượt, không cộng lượt hai lần.
- Máy chủ giữ snapshot câu hỏi/đáp án riêng. App chỉ nhận nội dung và lựa chọn; không thể đọc đáp án từ Firestore. Khi giáo viên sửa đề, lượt đang làm vẫn chấm theo snapshot cũ.
- App lưu lựa chọn kèm revision; ghi từ phiên cũ bị từ chối để không đè bài đã lưu trên thiết bị khác.
- Máy chủ chấm điểm, client không gửi điểm để ghi. Nộp lặp trả cùng kết quả.
- Lượt đã hết hạn được chốt từ lựa chọn đã lưu khi người dùng mở lại/lưu/nộp; không chấp nhận thêm đáp án sau hạn và không bị kẹt như bản cũ. Không có tác vụ nền chốt tất cả phiên theo lịch trong phiên bản này.
- Số lượt cũ được tính vào giới hạn: lượt hoàn thành cộng với lượt đang bỏ dở. Điểm lịch sử cũ vẫn giữ; không thể tái chấm các dữ liệu đã mất.
- Web Admin có khóa/mở khóa tài khoản, điểm đạt, lịch mở/đóng đề, lựa chọn cho xem lời giải và ô lời giải khi thêm câu hỏi.
- Xóa tài khoản/đề dọn cả dữ liệu phiên mới, snapshot riêng và lịch sử. Tài khoản được đánh dấu đang xóa để chặn phát sinh bài làm mới trong lúc dọn.

## Dữ liệu và quy tắc

`exam_sessions`: bộ đếm/các phiên của từng học viên–đề. `exam_private_runs`: nội dung đáp án và snapshot, cấm mọi client đọc/ghi. `exam_sessions/{id}/runs`: kết quả đã chấm. `exam_attempts/secure_{sessionId}`: tổng hợp tương thích báo cáo cũ.

`firestore.rules` là cấu hình hiện hành cho backend mới. `firestore.spark.rules` chỉ để kiểm thử tương thích dữ liệu cũ, không triển khai trở lại. Rule hiện hành chặn học viên đọc document đề/câu hỏi và ghi điểm trực tiếp; thao tác tài khoản đặc quyền qua backend.

Đã xác minh billing bật trên `e09-elearning`. Hai admin tổng được đối chiếu giữa hồ sơ và Firebase Authentication rồi ghi cấu hình `system/access` theo UID hiện hữu. Không thay tài khoản hoặc mật khẩu.

## Kiểm chứng

- Đã triển khai 13 Cloud Functions, Firestore Rules/Indexes và hai Hosting site lên `e09-elearning` ngày 10/09/2026. Container triển khai cũ được tự dọn sau 30 ngày.
- Web học viên: https://e09-elearning.web.app. Web quản trị: https://e09-elearning-admin.web.app.
- Kiểm tra sau triển khai: chỉ mục `courses` và `learning_notifications` đều `READY`; trang chủ và `main.dart.js` của cả hai site trả HTTP 200.
- Smoke production đạt: tài khoản học viên tạm gọi được `examList`/`examHistory`, bị từ chối đọc trực tiếp document đề (HTTP 403). Tài khoản thử đã xóa. Chưa kiểm tra thủ công toàn bộ luồng bằng tài khoản thật hoặc trên điện thoại vật lý.

- Flutter analyze sạch; 76 kiểm thử Flutter đạt, bao gồm giao diện thi máy chủ ở 390/1440 px.
- 9 kiểm thử chính sách Node đạt.
- 16 kiểm thử tích hợp Emulator đạt: 7 cho backend thi mới và 9 hồi quy hệ thống cũ/dọn dữ liệu.
- Script preflight và smoke chỉ in trạng thái, không in mật khẩu hoặc token. Smoke tạo tài khoản kỹ thuật tạm để kiểm tra gọi API rồi xóa trong `finally`.

## Còn ngoài phạm vi bản backend này

Vai trò giáo viên riêng, đăng ký/khôi phục email, upload tài liệu, nhiều loại câu hỏi, ngân hàng/import câu hỏi nâng cao, xuất báo cáo và push notification vẫn chưa được hoàn thành toàn bộ như danh sách mở rộng ban đầu. Không coi việc nâng cấp gói Firebase là tự hoàn thành các tính năng đó. Bản này giải quyết luồng thi máy chủ và chuyển quản trị tài khoản sang backend.
