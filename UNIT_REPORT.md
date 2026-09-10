# Báo cáo tổng hợp và đơn vị — 10/09/2026

## Bổ sung đơn vị trực thuộc của học viên

User tự nhập `subUnit` (tổ/đội/bộ phận, tối đa 200 ký tự, có thể bỏ trống) tại Cá nhân → Hồ sơ và bảo mật → Cập nhật hồ sơ. `unit` là đơn vị quản lý theo admin phụ, vẫn do admin tổng phân. Đơn vị trực thuộc hiển thị trên hồ sơ, danh sách tài khoản/phân lớp và chi tiết báo cáo; tìm kiếm báo cáo bao gồm trường này. Đây là thông tin user tự khai, không phải phân quyền lớp hoặc danh mục tổ/đội đã được duyệt. Đổi đơn vị admin giữ nguyên thông tin trực thuộc user đã khai để không mất dữ liệu; user có thể cập nhật lại khi chuyển đơn vị.

Kiểm thử bổ sung: phân tích Flutter sạch, 12 ca liên quan hồ sơ/báo cáo/quyền admin đạt. Kiểm thử Rules xác nhận chỉ chủ tài khoản được ghi `subUnit`, không đổi được `unit`, giới hạn 200 ký tự và giữ `subUnit` khi admin đổi đơn vị quản lý.

- Admin tổng thuộc E09. Admin phụ được admin tổng nhập đơn vị lúc đề xuất hoặc gán tại Quản lý tài khoản → Phân đơn vị.
- Tạo lẻ/import học viên đều lấy đơn vị từ hồ sơ người tạo trên backend. Admin tổng tạo học viên thuộc E09. Admin phụ chưa có đơn vị phải được phân đơn vị trước khi tạo/import.
- Đổi đơn vị admin phụ đồng bộ học viên do admin đó tạo, không đổi vai trò, tên đăng nhập, mật khẩu hoặc lịch sử. Quyền quản trị tài khoản theo người tạo hiện có vẫn giữ nguyên.
- Học viên và admin phụ không tự sửa đơn vị trong hồ sơ/phân lớp. Đơn vị vẫn hiển thị; trường lớp và hồ sơ cá nhân vẫn sửa theo quyền hiện hành. Admin tổng quản lý đơn vị qua callable riêng.
- Báo cáo có lọc đơn vị, lớp, đề và tìm học viên/đơn vị; thống kê, phân bố điểm, bảng kết quả, danh sách 10 điểm cao nhất đều theo bộ lọc.
- Mỗi học viên–đề có một kết quả tốt nhất, gộp document cũ/mới. Lượt nộp vẫn cộng tất cả lượt; điểm trung bình và tỷ lệ đạt tính trên kết quả tốt nhất, không giả định là trung bình mọi lần thi. Kết quả thiếu điểm không tính thành 0.
- Tiến độ đơn vị: tổng học viên, số quản trị viên, số người đã nộp ít nhất một bài trong đề đang lọc, chưa nộp và phần trăm. Một người thi nhiều lần hoặc nhiều đề chỉ tính một lần trong số người đã làm. Không xem danh sách học viên chưa làm là danh sách được giao một đề, vì hệ thống chưa có phân công đề theo từng cá nhân.
- Đồng bộ dữ liệu cũ chỉ theo quan hệ người tạo đã biết. Admin phụ chưa có đơn vị hiển thị Chưa phân đơn vị, không tự đoán tên đơn vị.
- Theo xác nhận của người dùng: admin tổng tự phân đơn vị cho admin phụ hiện có. Không cần gán đơn vị thay admin tổng; học viên được chuyển theo khi admin tổng lưu đơn vị mới.

Kiểm chứng: Flutter analyze sạch; 84 kiểm thử Flutter đạt; 20 ca Firebase Emulator đạt, gồm bảo vệ đơn vị và kế thừa khi import; không build APK.

Triển khai: đã cập nhật 14 Cloud Functions, Firestore Rules và hai website. Smoke API production đạt, chặn đọc trực tiếp đáp án, chỉ mục READY, hai website trả HTTP 200. Đồng bộ 3 hồ sơ về đơn vị đã xác định; kiểm tra lại không còn hồ sơ cần đồng bộ tự động. Giữ 1 admin phụ chưa phân đơn vị để admin tổng tự gán theo yêu cầu. Không tạo APK.
