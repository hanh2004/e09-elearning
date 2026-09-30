# Cấu hình Firebase cũ

Không truyền các tệp JSON trong thư mục này trực tiếp cho Firebase CLI. Khi dùng
`--config config/firebase/<tệp>.json`, Firebase CLI lấy `config/firebase/` làm
gốc dự án và phân giải các đường dẫn `functions`, Rules, Storage và Hosting từ
đó. Các tài nguyên của dự án hiện nằm ở thư mục gốc, nên những đường dẫn này sẽ
không tồn tại.

Dùng `firebase.json` tại thư mục gốc để chạy emulator hoặc triển khai. Khi chạy
lệnh từ `functions/`, chỉ định `--config ../firebase.json`; với lệnh deploy luôn
chỉ định project bằng `--project e09-elearning`.
