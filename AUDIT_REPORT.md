# Rà soát app học viên và web quản trị — 09/09/2026

> Cập nhật 10/09/2026: đây là báo cáo bản cũ. Luồng mặc định hiện đã chuyển sang backend chấm thi, giữ đáp án riêng và cấp lượt bằng transaction để xử lý các P1 về thi bên dưới. Xem trạng thái triển khai và giới hạn kiểm chứng tại [BLAZE_UPGRADE.md](BLAZE_UPGRADE.md).

## Kết luận

Đã rà soát mã nguồn và chạy kiểm thử cho hai cổng. Đã sửa lỗi phân quyền khi lưu tiến độ thi, giữ lịch sử thi lại, dọn dữ liệu tài khoản, mã lớp và một số tình huống nhập/lưu dữ liệu. Không kết luận hệ thống đã sẵn sàng cho kỳ thi có yêu cầu chống gian lận: ba vấn đề P1 bên dưới vẫn cần xử lý.

Phạm vi: entry point User/Admin và đồ thị import; đăng nhập/đăng xuất/vai trò; quản trị tài khoản/import Excel; khóa học/bài học/phân lớp; hồ sơ/mật khẩu; tạo đề/câu hỏi/làm bài/kết quả/lịch sử; báo cáo/tiến độ; lịch/thông báo; Firestore Rules và backend tài khoản. Kiểm thử UI tự động bao phủ đăng nhập, shell, tài khoản/import và danh sách khóa học ở kích thước điện thoại/desktop. Chưa thao tác thủ công toàn bộ luồng bằng tài khoản thật, chưa chạy trên điện thoại vật lý, chưa kiểm tra iOS. Không ghi dữ liệu hoặc triển khai Firebase production.

## Đã sửa

1. **P1 — Sửa thời hạn/điểm khi lưu tiến độ:** trước đây nhánh cập nhật `in_progress` cho phép thay `endsAt`, `startedAt` và điểm tốt nhất. Nay chỉ cho cập nhật lựa chọn, vị trí câu và thời điểm lưu; nhánh bắt đầu lại cũng không được thay điểm cũ; khi nộp không được đổi thời hạn. Có kiểm thử Emulator xác nhận.
2. **P1 — Lấy cấu hình đề từ client:** `getOrCreateAttempt` nay lấy thời lượng và số lượt từ document đề vừa đọc, tránh dùng cấu hình cũ được truyền qua màn hình. Đây không phải biện pháp chống tạo nhiều document lượt thi; xem P1 còn lại.
3. **P1 — Thi lại với nhiều document cũ:** trước đây batch thử xóa lượt cũ dù học viên không có quyền xóa, có thể làm cả thao tác thất bại và bỏ lại lịch sử con. Nay chỉ mở lại document giữ kết quả tốt nhất, bảo toàn các document còn lại và không ghi đè bộ đếm bằng tổng của các document khác.
4. **P2 — Xóa tài khoản còn dữ liệu con:** cả luồng Spark và backend tài khoản nay dọn `users/{uid}/learning`; backend cũng dọn `exam_attempts/{id}/runs`. Luồng Spark đã dọn runs và được bổ sung kiểm thử xóa cả hai loại dữ liệu con.
5. **P2 — Mã lớp chứa `all` bị biến đổi:** tách đúng tiền tố `class:`; giữ nguyên các mã như `all`, `small-A`.
6. **P2 — Xuất bản đồng thời:** đọc trạng thái cũ, ghi nội dung, thông báo và nhật ký trong transaction để tránh quyết định xuất bản trên dữ liệu vừa bị thay đổi.
7. **P2 — Chấm sai đề không hỗ trợ:** kiểm tra loại câu, số đáp án đúng và nội dung đáp án; khóa nút bắt đầu nếu đề chứa câu không hợp lệ thay vì âm thầm bỏ câu. Chặn chọn đáp án khi chưa khởi tạo lượt hoặc đã hết giờ.
8. **P2 — Lưu đề/câu hỏi lỗi mạng và bấm lặp:** thêm chặn gửi lặp, bắt lỗi và thông báo để thử lại; dịch vụ kiểm tra đầu vào. Đồng bộ giới hạn độ dài họ tên/đơn vị/URL với Rules.

## Các phát hiện còn mở

| Mức | Vị trí | Điều kiện và ảnh hưởng | Hướng xử lý |
|---|---|---|---|
| P1 | `firestore.rules`, hàm `validCompletedAttempt`; `lib/services/firestore_service.dart`, `submitExam` | Client tự chấm và gửi điểm; Rules chỉ kiểm tra miền 0–10, không đối chiếu đáp án. Client bị sửa có thể nộp điểm giả trong miền hợp lệ. | Chấm và ghi kết quả tại backend tin cậy, tách đáp án khỏi dữ liệu học viên đọc. |
| P1 | `firestore.rules`, `validStudentAttemptCreate`; `lib/services/firestore_service.dart`, dòng tạo `exam_attempts.add` | Mỗi document mới bắt đầu bộ đếm 0; Rules không kiểm tra tổng lượt của cùng học viên/đề. Client tùy chỉnh hoặc hai phiên đồng thời có thể vượt giới hạn. | Dùng một bản ghi duy nhất cho học viên/đề cùng transaction/bộ đếm phía server; thiết kế migration document cũ. |
| P1 | `lib/screens/user/user_exam_screen.dart`, nhánh `session.endsAt`; `firestore.rules`, giới hạn `endsAt + 1 phút` | Quay lại lượt bỏ dở sau hơn một phút kể từ hết giờ: app thử nộp, Rules từ chối; lượt vẫn `in_progress`, lần sau tiếp tục bị kẹt. | Backend chốt lượt hết hạn và cho phép mở lượt tiếp theo theo chính sách; không nới thời hạn nộp điểm tùy ý. |
| P2 | `android/app/build.gradle.kts:37` | Build release đang ký bằng debug key. | Dùng keystore phát hành của chủ dự án trước khi phân phối chính thức. Không tự tạo/thay khóa trong đợt rà soát. |
| P2 | Tổng quan học tập và luồng danh sách | Một số màn hình tải toàn bộ dữ liệu, tổng quan còn đọc lần lượt theo học viên/khóa. | Thêm phân trang và dữ liệu thống kê tổng hợp khi quy mô tăng. |

Các chức năng chưa xây dựng (email khôi phục/giáo viên, câu hỏi nâng cao, upload media, xuất báo cáo…) vẫn được liệt kê tại UPGRADE_STATUS.md. Chúng không được tính là đã hoàn thành chỉ vì các kiểm thử hiện có đạt.

## Kiểm chứng

- Flutter: 73 kiểm thử đạt; `flutter analyze` cuối cùng không có vấn đề.
- Backend policy: 7 kiểm thử đạt.
- Firebase Emulator: 9 kiểm thử tích hợp đạt, dùng project `demo-e09` và `firebase.audit.json`; các kiểm thử có tình huống từ chối ghi/đọc và dọn dữ liệu con.
- Cấu hình audit dùng cổng riêng vì cổng emulator thường dùng đang bận, không dừng dịch vụ khác.
- Kết quả build được ghi bổ sung sau khi hoàn tất.

Các bài kiểm thử đạt xác nhận phạm vi đã kiểm thử, không phủ nhận các P1 còn mở được phát hiện bằng rà soát mã.

## Kết quả build trong đợt rà soát

- Android: `flutter build apk -t lib/main_user.dart` thành công; `build/app/outputs/flutter-apk/app-release.apk`, 52.7 MB. Đã kiểm tra manifest đã merge có quyền Internet. APK vẫn ký debug như phát hiện P2, chưa thử trên máy thật.
- Web quản trị: `flutter build web -t lib/main_admin.dart --output build/admin_web` thành công.
