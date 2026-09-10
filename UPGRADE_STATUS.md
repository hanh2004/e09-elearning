# Trạng thái nâng cấp ngày 09/09/2026

> Cập nhật 10/09/2026: backend Firebase Blaze và hai cổng web đã được nâng cấp. Xem [BLAZE_UPGRADE.md](BLAZE_UPGRADE.md) cho luồng thi và quản trị hiện hành. Chưa tạo APK mới, chờ người dùng yêu cầu.

## Đã bổ sung trong mã nguồn

- Học viên: cập nhật họ tên, đơn vị, ảnh đại diện bằng URL HTTPS; đổi mật khẩu có xác thực mật khẩu cũ; đăng xuất thiết bị hiện tại dùng luồng có sẵn.
- Khóa học: tìm theo tên/môn, lọc môn; đọc nội dung văn bản/hình ảnh; liên kết HTTPS cho PDF/video; đánh dấu đã học, yêu thích, lọc yêu thích; phần trăm hoàn thành.
- Quản trị: tạo/sửa khóa học, môn dưới dạng nhãn, chương dưới dạng nhãn trong bài; thứ tự bài học bằng số; bản nháp/xuất bản; cấp quyền toàn bộ hoặc một lớp theo mã lớp.
- Phân lớp và đơn vị học viên theo quyền sở hữu tài khoản hiện có.
- Tổng quan: tổng học viên, khóa học, bài học, lượt thi; trung bình điểm tốt nhất; biểu đồ thanh tiến độ từng học viên và lọc chưa hoàn thành.
- Lịch học/lịch thi theo lớp; thông báo trong ứng dụng theo toàn hệ thống/lớp/UID học viên và thời điểm gửi. Tự tạo thông báo khi xuất bản khóa học hoặc thêm bài học vào khóa đã xuất bản; nhắc trước lịch thi một giờ.
- Lưu riêng từng lượt nộp bài mới ở `exam_attempts/{id}/runs/{runNumber}`, giữ kết quả tốt nhất để tương thích màn hình cũ. Hồ sơ → Chi tiết từng lần thi để xem.
- Nhật ký các thao tác lưu khóa học/bài học/thông báo/phân lớp/lịch được tạo cùng batch. Nhật ký chỉ ghi thêm, không sửa trong client.
- Firestore Rules bảo vệ bản nháp, quyền theo lớp, tiến độ cá nhân, lịch thông báo và lịch sử lượt thi. Học viên không tự sửa mã lớp/quyền.

## Chưa triển khai đầy đủ so với danh sách yêu cầu

- Tự đăng ký, quên mật khẩu qua email, thu hồi phiên trên các thiết bị khác, vai trò giáo viên. Tài khoản cũ dùng email băm `@accounts.invalid`, không thể nhận email khôi phục; cần thiết kế chuyển đổi email xác thực cùng backend tài khoản.
- Tải file lên kho lưu trữ; xem PDF/video nhúng. Hiện dùng URL HTTPS, PDF/video có nút sao chép liên kết để mở ngoài ứng dụng. Không coi URL công khai là tệp được bảo vệ theo lớp.
- Ngân hàng câu hỏi độc lập theo môn/chương/chủ đề/độ khó, import câu hỏi Excel, dò trùng, đề ngẫu nhiên.
- Đa đáp án/đúng sai/điền đáp án; trộn câu/đáp án; điểm đạt; mở đề theo lịch; cấu hình xem lời giải. Luồng thi cơ bản cũ vẫn được sử dụng.
- Xuất báo cáo Excel/PDF, thống kê câu sai, người đang online; điểm trung bình tất cả lượt thi chưa thay thế thống kê điểm tốt nhất cũ.
- Push notification khi ứng dụng đóng, nhắc hạn theo thời gian đóng đề thực tế. Lịch học/thi mới là lịch kế hoạch riêng, không tự sửa thời gian mở/đóng đề.
- Nhật ký chưa bao phủ mọi thao tác cũ và chưa được cưỡng chế bằng backend; client được sửa có thể bỏ qua việc tạo nhật ký.
- Bảng xếp hạng chưa thêm vì là chức năng tùy chọn.

## Chạy và triển khai

Dùng hai entry point trong README. Các collection mới chỉ xuất hiện khi tạo dữ liệu qua giao diện; không nạp dữ liệu giả vào Firebase thật.

Trước khi sử dụng bản mới trên Firebase thật, phải triển khai `firestore.rules` và `firestore.indexes.json` bằng cấu hình `firebase.secure.json`, chờ index sẵn sàng rồi phát hành frontend. Chưa có triển khai production trong thay đổi này.

Thông báo trong ứng dụng truy vấn lại mỗi phút khi màn hình được giữ trong cây widget. Thời gian nhập theo múi giờ thiết bị. Học viên chỉ xem được thông báo đã đến giờ.

Thống kê tổng quan hiện tải dữ liệu khi mở/làm mới; phù hợp quy mô nhỏ. Khi dữ liệu lớn cần tổng hợp phía backend và phân trang. Các lượt thi trước bản nâng cấp không thể khôi phục điểm đã bị ghi đè.

## Kiểm chứng

- `flutter analyze`: không có lỗi/cảnh báo.
- `flutter test`: 68 kiểm thử đạt, gồm kiểm tra giao diện khóa học ở chiều rộng 390 và 1440.
- Firebase Emulator: 7 kiểm thử tích hợp đạt; dùng project `demo-e09`, cấu hình `firebase.test.json` khi cổng mặc định bận.
- Build web quản trị thành công tại `build/admin_web`.

Đợt rà soát tiếp theo đã bổ sung dọn tiến độ và lịch sử lượt thi khi xóa tài khoản ở cả Spark và backend. Xem AUDIT_REPORT.md để biết các lỗi đã sửa, kết quả kiểm chứng mới và các vấn đề còn mở.
- Build web học viên thành công tại `build/user_web`.

