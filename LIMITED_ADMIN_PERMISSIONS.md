# Quyền admin phụ

- Tạo/import học viên dưới tài khoản mình; backend tự gắn người tạo và đơn vị.
- Chỉ sửa, đặt lại mật khẩu, khóa hoặc xóa học viên do mình tạo. Không sửa/xóa học viên của admin khác hay tài khoản admin.
- Xem bảng tổng hợp, tiến độ, báo cáo, danh sách khóa học, bài thi.
- Không tạo/sửa/xóa khóa học, bài học, câu hỏi, đề thi; không xuất bản hay tải ảnh bài học. Lịch học và thông báo cũng chỉ xem.
- Admin tổng giữ quyền quản lý nội dung và phân đơn vị.

Đã khóa ở Firestore/Storage Rules và ẩn nút trên giao diện. Backend quản lý tài khoản đã có kiểm tra ownership nên không cần thay Cloud Functions. Không đổi dữ liệu hoặc tạo APK.

Kiểm chứng: 85 kiểm thử Flutter hiện có đạt; thêm kiểm thử màn khóa học admin phụ và chạy 8 kiểm thử quyền giao diện đều đạt. 21 kiểm thử backend/Rules/Storage đạt, gồm từ chối admin phụ sửa nội dung, đọc báo cáo thành công và kiểm tra quyền theo người tạo. Analyze sạch.
