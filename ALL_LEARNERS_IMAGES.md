# Nội dung chung, ảnh thiết bị và đơn vị ghép — 10/09/2026

- Bỏ trường/chức năng phân lớp khỏi giao diện quản trị và hồ sơ. Khóa học đã xuất bản được tất cả học viên đang hoạt động truy cập, kể cả khóa cũ còn nhãn lớp. Không xóa trường dữ liệu lịch sử. Bản nháp vẫn bị chặn.
- Khóa học/lịch học tạo mới có audience `all`. Thông báo mới không còn chọn lớp; thông báo riêng theo UID vẫn giữ quyền riêng tư. Không sửa hàng loạt đối tượng nhận của dữ liệu cũ. Kiểm tra production thấy một khóa học có nhãn lớp, không có lịch học theo lớp.
- Hồ sơ giữ `unit` do admin tổng phân cho admin phụ và backend truyền xuống học viên. Học viên sửa `subUnit` phía trước; giao diện hồ sơ/báo cáo ghép thành `subUnit-unit`, ví dụ `c1-d1`. Firebase vẫn cấm học viên tự sửa `unit`.
- Thay ô nhập link ở hồ sơ/bài học bằng chọn JPG/JPEG/PNG/WebP từ thiết bị, tối đa 5 MB. Giữ tài liệu liên kết cũ để không mất nội dung; không còn tạo mới bằng link.
- Storage mặc định được tạo ở asia-southeast1. Rules chỉ cho học viên tải ảnh đại diện của mình, admin tải ảnh bài học. Service agent Storage được cấp vai trò tiêu chuẩn để đọc hồ sơ trong lúc kiểm tra Rules.
- 85 kiểm thử Flutter, 13 kiểm thử Emulator đạt; 5 kiểm thử hồ sơ/báo cáo đạt sau chỉnh tìm kiếm đơn vị ghép. Analyze cuối sạch. Kiểm thử production qua SDK tải ảnh và lấy URL thành công, nguồn đáp án vẫn chặn học viên. Ảnh và tài khoản thử đã xóa.
- Chưa tạo APK. Hai bản web đã build thành công.

Ảnh được tải lên khi chọn; nếu hủy hộp thoại sau đó, ảnh đã tải có thể còn trong Storage nhưng chưa được gắn vào hồ sơ/bài học.
