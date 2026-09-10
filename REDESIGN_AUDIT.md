# Rà soát và nâng cấp giao diện E09 — 10/09/2026

## Phạm vi và nguyên tắc

Rà soát các nhóm mã nguồn Flutter học viên/quản trị, dịch vụ dữ liệu, backend tài khoản/thi, Rules, cấu hình Firebase và Android. Phân tích tĩnh toàn dự án, kiểm thử hồi quy và kiểm tra ảnh giao diện ở 390 px / 1440 px. Không phải chứng nhận mọi tình huống vận hành đều không có lỗi; chưa kiểm thử thiết bị vật lý, iOS hoặc tải lớn.

Giữ nguyên tệp `lib/assets/images/logo.png`. Không xóa màn hình, chức năng, tài khoản, nội dung hoặc lịch sử thật. Bài kiểm tra chuyển sang mục giữa thanh điều hướng; trang chủ mới là tổng quan. Các mục cũ khóa học, lịch, thông báo, hồ sơ, thi/lịch sử, quản trị tài khoản, nhập Excel, duyệt admin, đề/câu hỏi, báo cáo, phân lớp và cài đặt vẫn có đường truy cập. Chưa build APK; chỉ tạo APK khi người dùng yêu cầu.

## Đã bổ sung

- Giao diện đỏ–xanh đậm, nền sáng, thẻ bo góc theo ảnh tham khảo; đăng nhập và web admin dùng cùng màu và logo cũ. Không sao chép số liệu giả từ ảnh mẫu.
- Tổng quan học viên từ Firebase thật: khóa học được phép truy cập, bài đã học, bài yêu thích, liên kết lịch, danh mục khóa học.
- Điều hướng 5 mục trên điện thoại, thanh bên trên desktop. Mục Kiểm tra ở giữa, tất cả chức năng cũ vẫn truy cập được.
- Tìm kiếm/lọc đề có thể làm; vẫn cho tiếp tục phiên đang làm. Danh sách hiện đúng lượt cũ trước lần thi đầu tiên ở backend mới và đúng thời lượng đề cũ.
- Làm bài từng câu, câu trước/câu tiếp, thanh tiến độ; giữ chế độ toàn bộ câu. Chấm điểm, giới hạn giờ/lượt và lưu bài vẫn do máy chủ thực hiện.
- Giao diện kết quả dạng vòng điểm, giữ toàn bộ lời giải được phép xem và thông báo hết giờ.
- Tiếp tục tới bài đầu tiên chưa hoàn thành; đánh dấu đã học ngay trong trang đọc. Giữ checkbox hoàn thành, yêu thích, nội dung và liên kết tài liệu cũ.
- Thông báo có bộ lọc tất cả/chưa đọc và lưu trạng thái đọc riêng từng tài khoản. Không gửi thông báo mới tới người dùng trong đợt triển khai.
- Hồ sơ cập nhật tên/ảnh/lớp/đơn vị theo dữ liệu hiện hành, giữ email nếu có. Thêm hướng dẫn quên mật khẩu qua quản trị viên, không giả lập gửi email khôi phục.
- Web admin thêm sửa câu hỏi tại chỗ, giữ ID và trường dữ liệu khác; thêm tùy chọn trộn câu hỏi và trộn đáp án. Máy chủ lưu thứ tự trộn vào snapshot để mở lại không đổi đề.

## Lỗi đã sửa

1. Xóa tài khoản: chấp nhận tài khoản đang khóa; giữ hồ sơ trạng thái `deleting` và giữ tên đăng nhập cho đến khi Firebase Auth xóa thành công, cho phép thử lại khi lỗi mạng. Dọn thêm trạng thái đọc thông báo và dữ liệu riêng của yêu cầu tạo admin.
2. Báo cáo/lịch sử: dùng quyết định đạt/chưa đạt và ngưỡng điểm lưu từ máy chủ cho kết quả mới, thay vì luôn so với 5. Dữ liệu cũ thiếu ngưỡng vẫn dùng quy ước cũ 5/10; không tự viết lại lịch sử.
3. UI: sửa tràn ngang trang thi ở 390 px; sửa controller hộp thoại bị dispose trước khi đóng hết animation; sửa lựa chọn bài tiếp theo gây lỗi kiểu danh sách snapshot.
4. Backend: kiểm tra điểm đạt trong 0–10; danh sách ẩn đề đang xóa; tính cả lượt thi cũ trước khi học viên mở phiên mới.
5. Android: khai báo quyền Internet trực tiếp ở manifest chính; trước đó quyền này chỉ được khai báo rõ trong manifest debug/profile của ứng dụng.

## Đối chiếu danh sách chức năng ban đầu

| Nhóm | Hiện có | Còn thiếu/chưa hoàn chỉnh |
| --- | --- | --- |
| Tài khoản | Đăng nhập, hồ sơ, đổi mật khẩu, đăng xuất hiện tại; admin tạo/import/reset/khóa, hai cấp admin | Đăng ký tự phục vụ, khôi phục email, vai trò giáo viên riêng, quản lý nhiều thiết bị |
| Khóa học | Môn/chương theo nhãn, bài text/image, liên kết PDF/video, nháp/xuất bản, lớp, thứ tự, yêu thích/hoàn thành | Upload Storage, trình xem PDF/video nhúng, mô hình môn/chương độc lập |
| Kiểm tra | Một đáp án, giờ/lượt/lịch mở đóng, điểm đạt, trộn đề/đáp án, chấm máy chủ, lịch sử/lời giải | Nhiều đáp án, đúng/sai chuyên biệt, điền đáp án |
| Ngân hàng | Thêm/sửa/xóa câu hỏi và lời giải trong đề | Ngân hàng dùng chung, môn/chương/chủ đề/mức độ, import Excel câu hỏi, phát hiện trùng, sinh đề từ ngân hàng |
| Theo dõi | Hoàn thành, thống kê bài học, điểm tốt nhất, lịch và nhắc thi trong app | Điểm trung bình mọi lượt ở mọi báo cáo; hiện diện online; push nền |
| Báo cáo | Điểm/kết quả, lượt nộp, tổng quan học tập, lọc lớp/tên/chưa hoàn thành ở màn hình tương ứng | Xuất Excel/PDF, thống kê câu sai, bộ lọc môn nhất quán; nhật ký chưa bao phủ mọi sửa đổi |
| Thông báo | Toàn hệ thống/lớp/UID, thời điểm gửi, nhắc trước lịch thi, trạng thái đọc | Push qua FCM và tác vụ nền gửi theo lịch |
| QR/chứng chỉ trong ảnh | Chưa có; không tạo nút giả | Luồng quét QR bài học và cấp chứng chỉ cần triển khai thực |

## Kiểm chứng

- `flutter analyze`: không lỗi/cảnh báo.
- `flutter test`: 80 ca đạt, gồm kiểm tra sửa câu hỏi giữ dữ liệu, trang học/đọc/thông báo, điều hướng 5 mục ở 390/1440 px.
- Build release web học viên và web quản trị thành công, gồm kiểm tra biên dịch Wasm của Flutter; chưa chạy thử Wasm như một bản phát hành riêng.
- Node: 9 ca chính sách đạt.
- Firebase Emulator: 19 ca đạt (10 backend/Rules hiện hành + 9 hồi quy dữ liệu/Rules cũ). Không chạy Rules cũ trên production.
- Đã xem ảnh chụp giao diện app và đăng nhập; ảnh dùng dữ liệu kiểm thử, nằm tại `build/review/`.
- Cấu hình ký Android release hiện vẫn dùng debug key. Không tạo/đổi khóa ký hoặc Application ID trong đợt chỉ nâng cấp web này.

## Triển khai

Đã triển khai thành công 13 Cloud Functions, Rules/Indexes và hai website ngày 10/09/2026:

- Học viên: https://e09-elearning.web.app
- Quản trị: https://e09-elearning-admin.web.app
- Smoke production: `examList` và `examHistory` nhận yêu cầu đã đăng nhập; học viên đọc nguồn đáp án trực tiếp bị HTTP 403. Tài khoản thử đã được xóa.
- Chỉ mục khóa học/thông báo đều READY. Trang chủ và mã ứng dụng của hai website trả HTTP 200.
- Các kiểm thử ghi bài/điểm, xóa tài khoản, thông báo và trộn đề dùng Emulator/dữ liệu giả; không chạy những thao tác đó trên dữ liệu học viên thật.
