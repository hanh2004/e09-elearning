# Logo và trang chủ quản trị

- Học viên (native và web): logo E09 gốc `lib/assets/images/logo.png`.
- Admin: huy hiệu CSCĐ gốc; widget BrandLogo cắt vùng trắng ngoài huy hiệu, không thay hình bên trong bằng ảnh AI. File ảnh gốc vẫn giữ nguyên.
- Trang chủ admin: banner đỏ, thẻ thống kê dữ liệu thật, tỷ lệ tham gia theo đơn vị, các lối tắt quản lý. Không còn mục lịch sử chỉnh sửa trên giao diện; dữ liệu nhật ký cũ không bị xóa.
- Sau mỗi build web, favicon/manifest học viên lấy từ `web/`; favicon admin lấy `lib/assets/images/web_logo.png`, manifest admin khai báo kích thước 250x286.
- 86 kiểm thử Flutter đạt; kiểm thử trang chủ có dữ liệu giả xác nhận đếm tham gia 1/1 và bố cục 390/1200 không tràn. Không tạo APK.
