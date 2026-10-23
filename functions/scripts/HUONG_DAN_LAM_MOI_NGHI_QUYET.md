# Cập nhật dữ liệu học tập ngày 19/09/2026

`lam_moi_du_lieu_nghi_quyet.mjs` cập nhật project `e09-elearning` bằng phiên đăng nhập Firebase CLI hiện tại.

```powershell
node functions/scripts/lam_moi_du_lieu_nghi_quyet.mjs --dry-run
node functions/scripts/lam_moi_du_lieu_nghi_quyet.mjs --apply
node functions/scripts/lam_moi_du_lieu_nghi_quyet.mjs --verify
node --test functions/test/du_lieu_nghi_quyet.test.js
```

Chạy từ thư mục gốc repository. Mặc định chỉ xem trước. Không dùng cùng biến môi trường emulator.

- Nguồn bài học: Nghị quyết 57-NQ/TW ngày 22/12/2024, liên kết Cổng Thông tin điện tử Chính phủ trong `noi_dung_nghi_quyet_20260919.mjs`. Nội dung tóm lược và tình huống vận dụng được phân biệt với văn bản gốc.
- Hai khóa: học nội dung cốt lõi và ôn tập để kiểm tra; mỗi khóa có ba bài. Đề gồm 12 câu, 15 phút, đạt từ 6/10. Khóa kiểm tra yêu cầu học xong các bài trước khi thi.
- Kết thúc các khóa/đề cũ đang mở bằng mốc `endsAt` và trạng thái đóng, giữ `published` để học viên vẫn mở được nội dung đã lưu và lịch sử. Dùng mã nội dung mới để tránh dùng tiến độ cũ cho nghị quyết.
- Chỉ đổi tên đăng nhập và đặt lại mật khẩu học viên có trạng thái active/blocked. UID, vai trò, đơn vị, trạng thái và quản lý phụ trách được giữ nguyên. Không sửa quản trị viên.
- Tên đăng nhập mới có dạng hv01; mật khẩu riêng gồm tám chữ số. Firebase Auth và chỉ mục Firestore được cập nhật đồng bộ theo nhật ký có thể tiếp tục khi gián đoạn.
- Không ghi vào tin tức hoặc banner. Xác minh toàn bộ bản ghi trước/sau bằng SHA-256, đối chiếu hồ sơ, nội dung và đăng nhập thực tế của tài khoản đang hoạt động.

Bản sao lưu, nhật ký có mật khẩu và tệp `tai-khoan-hoc-vien.txt` nằm trong `.tmp/resolution-refresh-20260919/`, đã được `.gitignore` loại trừ. Không đưa các tệp này vào Git. Nếu thao tác bị gián đoạn, giữ nguyên thư mục này và chạy lại `--apply`; tài khoản đã hoàn tất không bị đặt mật khẩu lần nữa. Không xóa nhật ký rồi chạy lại vì sẽ tạo mật khẩu mới.

Mỗi lần chạy chỉ in số lượng và tên đăng nhập, không in mật khẩu hoặc token. Bản sao lưu không chứa mật khẩu cũ của Firebase Auth; mật khẩu đã đặt lại không thể khôi phục từ bản sao lưu Firestore.
