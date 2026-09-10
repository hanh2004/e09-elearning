# Trạng thái hiện hành: Firebase Blaze

Giao diện và rà soát mới nhất: [REDESIGN_AUDIT.md](REDESIGN_AUDIT.md). Giữ logo cũ, thêm trang chủ học tập, trạng thái đọc thông báo, tiếp tục học, sửa/trộn câu hỏi và sửa lỗi báo cáo/tài khoản. Chưa tạo APK.

Xem [BLAZE_UPGRADE.md](BLAZE_UPGRADE.md) cho bản ngày 10/09/2026. App và web dùng Cloud Functions mặc định. Các mô tả Spark bên dưới là lịch sử; không dùng Rules Spark cho bản hiện hành. Chưa tạo APK mới theo yêu cầu.

# E09 E-Learning — User App và Admin Web

Hai ứng dụng được build riêng từ một Flutter repository. Model, service và
theme dùng chung; các màn hình User/Admin có đồ thị import riêng. Đây là hai
entry point, không phải hai repository hay hai backend độc lập.

## Chạy

Mỗi lệnh chỉ chạy **một** ứng dụng. Chạy hai lệnh ở hai terminal nếu cần cả hai.

```powershell
# Mặc định: chỉ User, chọn thiết bị khi Flutter hỏi
flutter run

# App User trên điện thoại/emulator
flutter run -t lib/main_user.dart -d <device-id>

# Web Admin trên Chrome
flutter run -t lib/main_admin.dart -d chrome --web-port 8081

# Tùy chọn: xem thử User trên trình duyệt, dùng cổng khác Admin
flutter run -t lib/main_user.dart -d chrome --web-port 8082
```

Dùng `flutter devices` để lấy device ID. Trong VS Code có cấu hình **User App**
và **Admin Web**. Hai điểm chạy cố định vai trò, không có nút chuyển cổng.

## Build và phát hành riêng

```powershell
flutter build apk -t lib/main_user.dart
flutter build web -t lib/main_admin.dart --output build/admin_web
```

APK User: `build/app/outputs/flutter-apk/app-release.apk`.
Web Admin: `build/admin_web/`. Chỉ triển khai thư mục này cho cổng Admin.
Không dùng bản `build/web` cũ vì nó có thể là ứng dụng gộp trước khi tách.

Có thể build User Web để kiểm tra bằng:
`flutter build web -t lib/main_user.dart --output build/user_web`.

Cập nhật frontend Admin không cần phát hành lại User và ngược lại. Hai bên vẫn
dùng Firebase project `e09-elearning`, nên thay đổi dữ liệu sẽ phản ánh sang cả
hai. Khi đổi schema/backend cần tương thích ngược với app đã phát hành.
Không có bước deploy tự động trong thay đổi này.

## Vai trò và bảo mật — trạng thái hiện tại

- User chỉ nhận vai trò User; web Admin nhận `super_admin` hoặc `admin`.
- Đúng hai admin tổng: `admintong1`, `admintong2`, nhận diện bằng UID do script khởi tạo.
- Hai Admin tổng là tài khoản hệ thống cố định: không thêm, sửa hoặc xóa trong ứng dụng.
  Muốn thay danh sách phải sửa mã khởi tạo và triển khai có kiểm soát; mật khẩu không nhúng trong app.
- Admin phụ cần một admin tổng đề xuất và admin tổng còn lại duyệt.
- Admin tổng được khóa mọi User và Admin phụ; không được xóa Admin tổng còn lại.
- Admin phụ xem được mọi User nhưng chỉ sửa hoặc xóa User do chính mình tạo.
  User của admin phụ khác chỉ Admin tổng mới được thay đổi.
- Admin tổng có công tắc **Cập nhật ứng dụng**. Khi bật, cổng User chặn đăng
  nhập và báo ứng dụng đang được cập nhật; cổng Admin vẫn hoạt động.
- Bài thi có thể đặt ngày giờ tự đóng hoặc đóng/mở thủ công. Lượt làm
  không được kéo dài quá hạn đóng.
- Bản Spark miễn phí tạo tài khoản bằng Firebase Authentication phía client và giới hạn
  thao tác bằng Firestore Rules; không dùng Cloud Functions/Blaze. Đây là cấu hình thử nghiệm,
  bảo mật và khả năng khôi phục thao tác kém hơn backend trả phí.
- Đăng nhập dùng Firebase Auth, không đọc mật khẩu từ Firestore. Không có 2FA.
- Đăng nhập sai cổng vẫn báo cùng thông báo sai tài khoản/mật khẩu. Đăng xuất xóa phiên Auth.
- Firestore Rules chặn User tự xóa lượt làm, ghi cho người khác, nộp sau hạn
  và ghi điểm ngoài miền hợp lệ. Chấm điểm tuyệt đối chống can thiệp vẫn cần
  backend tin cậy; bản Spark hiện tại chỉ phù hợp dữ liệu thử nghiệm.

Web Admin và Firestore Rules hiện đã được triển khai trên Firebase project thật.
Khi thay đổi schema hoặc quy tắc quyền, phải kiểm thử bằng emulator trước khi triển khai.

Xem [ADMIN_SETUP.md](ADMIN_SETUP.md) để chạy thử bằng emulator, khởi tạo hai tài khoản tổng
với mật khẩu thử nghiệm và thực hiện chuyển đổi có kiểm soát. Không đưa khóa quản trị vào app.
Các mật khẩu tạm phải đổi riêng cho từng admin trước khi sử dụng thực tế.

## Nhập User từ Excel

Trong Web Admin: **Quản lý Tài khoản → Nhập User từ Excel → Tải mẫu Excel**.
Điền sheet `Users` từ dòng 2 với đúng 3 cột:
`Họ và tên | Tên đăng nhập | Mật khẩu`.

- Chỉ nhận `.xlsx` không mã hóa, tối đa 2 MB và 200 User mỗi lần.
- Tất cả ô nhập phải là Text. Giữ nguyên số 0 đầu của tên đăng nhập/mật khẩu;
  không dùng ô số, ngày hay công thức. Không thêm cột vai trò.
- Tên đăng nhập: 3–64 ký tự gồm chữ không dấu, số, `_`, `.`, `@`, `-`.
- Mật khẩu: 6–128 ký tự; họ tên tối đa 100 ký tự. Khoảng trắng đầu/cuối được bỏ.
- Dòng trắng bỏ qua; dòng thiếu dữ liệu hoặc trùng tên (không phân biệt hoa/thường)
  được báo lỗi. Phải sửa hết lỗi trước khi xác nhận.
- Xem trước không hiện mật khẩu và chưa lưu dữ liệu. Nhấn **Xác nhận thêm** mới lưu.
- Import luôn tạo `role: user`, không ghi đè tài khoản cũ. Bản Spark tạo Firebase Auth
  bằng ứng dụng phụ rồi ghi hồ sơ; nếu gián đoạn có thể thử lại với cùng mật khẩu để tiếp tục.
- File chứa mật khẩu: không đưa file đã điền lên GitHub hoặc chia sẻ công khai.

Đã bỏ tùy chọn thêm Giáo viên và gán trực tiếp vai trò Admin. Tạo Admin phải qua đề xuất/duyệt.
Import dùng Firebase Authentication và lưu người tạo từ phiên Admin đang đăng nhập.

Khi xóa User, hồ sơ, chỉ mục tên đăng nhập và toàn bộ bài làm bị xóa vĩnh viễn.
Trên bản Spark, bản ghi kỹ thuật trong Firebase Authentication có thể còn nhưng không còn
hồ sơ hợp lệ nên không thể đăng nhập. Muốn xóa cả Auth cần backend Admin SDK.

## Kiểm thử

```powershell
flutter analyze
flutter test
```

Test kiểm tra vai trò hợp lệ/không hợp lệ, chặn đăng nhập chéo cổng, sai mật khẩu,
giữ cổng khi đăng xuất và đồ thị import không chứa màn hình bên còn lại.
Các test không đăng nhập hoặc sửa dữ liệu Firebase thật.

## Nâng cấp học tập 09/09/2026

Đã thêm khóa học/bài học, tiến độ, yêu thích, phân lớp, hồ sơ/bảo mật,
lịch học/thi, thông báo có lịch và lịch sử từng lượt thi mới.
Xem [UPGRADE_STATUS.md](UPGRADE_STATUS.md) để biết chức năng đã hoàn thành,
giới hạn hiện tại và các hạng mục còn thiếu so với yêu cầu mở rộng.

## Rà soát chất lượng

Xem [AUDIT_REPORT.md](AUDIT_REPORT.md) để biết lỗi đã sửa, các vấn đề bảo mật/lượt thi còn mở và phạm vi kiểm thử. Build thành công không đồng nghĩa đã đáp ứng yêu cầu chống gian lận cho kỳ thi chính thức.
