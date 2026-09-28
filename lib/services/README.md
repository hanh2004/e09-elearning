# Dịch vụ của ứng dụng

Màn hình gọi các lớp ở đây thay vì tự chứa toàn bộ truy vấn Firebase, quy tắc
nghiệp vụ và xử lý tệp. Khi sửa một chức năng, tìm service theo loại công việc:

- `tai_khoan/xac_thuc_tai_khoan.dart`: đăng nhập và đăng xuất Firebase Auth.
- `du_lieu/dich_vu_firestore.dart`: truy vấn Firestore dùng chung; các phần tài
  khoản, bài thi và bảo trì được khai báo trong các tệp `firestore_*_operations.dart`.
- `nghiep_vu/dich_vu_hoc_tap.dart`: khóa học, bài học, tiến độ và thông báo học tập.
- `nghiep_vu/dich_vu_tin_tuc.dart`, `dich_vu_anh_bia_trang_chu.dart`: tin tức và banner.
- `ket_noi_api/api_tai_khoan.dart`, `dich_vu_bai_kiem_tra_bao_mat.dart`: gọi Cloud Functions.
- `tep/`: nhập Excel, chọn tệp, tải báo cáo và tải ảnh lên Storage.

Quyền cuối cùng vẫn do Firestore Rules hoặc Cloud Functions kiểm tra. Nếu đổi
trường dữ liệu, hãy tìm các chỗ đọc/ghi tương ứng và cập nhật Rules cùng đợt.
