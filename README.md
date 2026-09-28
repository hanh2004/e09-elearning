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
flutter run -t lib/diem_vao_hoc_vien.dart -d <device-id>

# Web Admin trên Chrome
flutter run -t lib/diem_vao_quan_tri.dart -d chrome --web-port 8081

# Tùy chọn: xem thử User trên trình duyệt, dùng cổng khác Admin
flutter run -t lib/diem_vao_hoc_vien.dart -d chrome --web-port 8082
```

Dùng `flutter devices` để lấy device ID. Trong VS Code có cấu hình **User App**
và **Admin Web**. Hai điểm chạy cố định vai trò, không có nút chuyển cổng.

## Build và phát hành riêng

Mục tiêu phát hành: app học viên lên Google Play và Apple App Store;
web Admin triển khai riêng lên Firebase Hosting. Giữ thư mục `android/`,
`ios/`, cấu hình Firebase, icon và tài nguyên được khai báo trong `pubspec.yaml`.

Các lệnh sau chỉ dùng sau khi đã hoàn thiện cấu hình ký phát hành:

```powershell
# Google Play: Android App Bundle
flutter build appbundle --release -t lib/diem_vao_hoc_vien.dart

# App Store: chạy trên macOS có Xcode và cấu hình ký của Apple Developer
flutter build ipa --release -t lib/diem_vao_hoc_vien.dart

# Web Admin
flutter build web --release -t lib/diem_vao_quan_tri.dart --output build/admin_web
```

Google Play: tệp `.aab` trong `build/app/outputs/bundle/release/`.
App Store: tệp `.ipa` trong `build/ios/ipa/`, archive trong `build/ios/archive/`.
Máy Windows hiện tại không build/ký iOS trực tiếp; cần Mac hoặc CI chạy macOS.
APK chỉ dùng khi cần cài Android trực tiếp để thử nghiệm.
Web Admin: `build/admin_web/`. Chỉ triển khai thư mục này cho cổng Admin.
Không dùng bản `build/web` cũ vì nó có thể là ứng dụng gộp trước khi tách.

### Trạng thái phát hành

- Application ID Android được giữ là `com.example.e09_elearning` theo quyết định
  của chủ dự án; Firebase đã có cấu hình Android khớp mã này. Không đổi mã sau
  khi app đã phát hành.
- Android signing đã được cấu hình cục bộ bằng `android/key.properties` và keystore
  riêng. Không commit hai tệp này; mỗi máy/CI phát hành phải tự cấu hình khóa.
- Bundle ID iOS vẫn là `com.example.e09Elearning`, chưa có `DEVELOPMENT_TEAM`.
  Muốn phát hành App Store cần chốt Bundle ID, chọn Apple Developer Team và ký
  bản iOS trên macOS/Xcode.
- Chưa có chính sách quyền riêng tư công khai trong dự án. Trước khi phát hành,
  cần công bố URL chính sách và khai báo trung thực dữ liệu thu thập/chia sẻ trên
  từng cửa hàng; nội dung phải được chủ đơn vị xác nhận.
- Quản lý phiên bản tại `pubspec.yaml`, ví dụ `1.0.0+1`; tăng build number
  cho lần tải bản mới. Cấu hình ký xong vẫn cần kiểm thử trên thiết bị và
  hoàn thiện thông tin ứng dụng trên từng cửa hàng.

Hướng dẫn chính thức: [Android](https://docs.flutter.dev/deployment/android),
[iOS](https://docs.flutter.dev/deployment/ios).
Khi mở phát hành công khai, đối chiếu [chính sách dữ liệu Google Play](https://support.google.com/googleplay/android-developer/answer/10144311)
và [khai báo quyền riêng tư App Store](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).

Có thể build User Web để kiểm tra bằng:
`flutter build web -t lib/diem_vao_hoc_vien.dart --output build/user_web`.

Cập nhật frontend Admin không cần phát hành lại User và ngược lại. Hai bên vẫn
dùng Firebase project `e09-elearning`, nên thay đổi dữ liệu sẽ phản ánh sang cả
hai. Khi đổi schema/backend cần tương thích ngược với app đã phát hành.

### Phát hành APK nội bộ và nhắc cập nhật tự động

Tăng phiên bản/build trong `pubspec.yaml`, rồi chạy:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\publish_internal_release.ps1
```

Script build APK đã ký và Admin web, lấy mã phiên bản trực tiếp từ metadata APK,
tạo `web/app-release.json`, lưu APK vào `outputs/internal/` rồi cập nhật Hosting.
App học viên tự đọc manifest sau khi đăng nhập; không cần Admin nhập phiên bản hay
gửi thông báo thủ công. Học viên bấm **Đã rõ** vẫn dùng tiếp app cũ. Các APK cũ
chưa có chức năng kiểm tra này cần được cài bản mới một lần trước khi nhận nhắc
cập nhật cho các đợt phát hành tiếp theo.

## Vai trò và bảo mật — trạng thái hiện tại

### Tin tức và hai mục học của học viên

- Admin → **Tin tức** → **Thêm tin tức**: nhập tiêu đề, tóm tắt, nội dung và ảnh tùy chọn;
  chọn **Bản nháp** hoặc **Đăng tin**. Tin đã đăng hiển thị ở trang chủ học viên.
- Admin → **Quản lý khóa học** → bài học → **Loại bài học**:
  **Chỉ học** hiển thị trong mục **Học tập**, hoàn thành sau thời gian học;
  **Học xong kiểm tra ngay** hiển thị trong mục **Kiểm tra**, học nội dung trước rồi kéo tới cuối bài và bấm hoàn thành để mở đề riêng đi kèm.
- Tạo đề và câu hỏi trong **Bài thi**, sau đó chọn đề ở bài học loại kiểm tra.
  Đề chưa gắn nội dung học không có lối vào thi trực tiếp trong ứng dụng học viên.
- Trong web admin, danh sách bài học được tách thành **Học để biết** và **Học để làm bài kiểm tra**.
- API bắt đầu, tiếp tục và nộp bài kiểm tra xác thực bài học, đề đi kèm và tiến độ của
  chính học viên. Chưa học xong thì không cấp câu hỏi; không tin cờ hoàn thành do client gửi.
- Bài học cũ chưa có `learningMode` được xem là **Chỉ học**.
  Cần cập nhật ứng dụng học viên, web admin, Functions và Rules cùng đợt phát hành để dùng luồng mới.

- User chỉ nhận vai trò User; web Admin nhận `super_admin` hoặc `admin`.
- Đúng hai admin tổng: `admintong1`, `admintong2`, nhận diện bằng UID do script khởi tạo.
- Hai Admin tổng là tài khoản hệ thống cố định: không thêm, sửa hoặc xóa trong ứng dụng.
  Muốn thay danh sách phải sửa mã khởi tạo và triển khai có kiểm soát; mật khẩu không nhúng trong app.
- Admin phụ cần một admin tổng đề xuất và admin tổng còn lại duyệt.
- Admin tổng được khóa mọi User và Admin phụ; không được xóa Admin tổng còn lại.
- Admin phụ xem được mọi User nhưng chỉ sửa hoặc xóa User do chính mình tạo.
  User của admin phụ khác chỉ Admin tổng mới được thay đổi.
- Admin tổng có công tắc **Cập nhật ứng dụng**. Khi bật, app User đang mở và
  kết nối mạng sẽ hiện màn hình bảo trì, đăng xuất học viên và chặn tiếp tục dùng
  app; người dùng cần tự đóng ứng dụng rồi mở lại sau khi bảo trì kết thúc. Đăng
  nhập User mới cũng bị chặn. Cổng Admin vẫn hoạt động. Đây là chặn trong ứng dụng,
  không phải lệnh đóng cưỡng bức hệ điều hành; app cần đang chạy và nhận được
  cập nhật Firestore để hiện thông báo ngay.
- Bài thi có thể đặt ngày giờ tự đóng hoặc đóng/mở thủ công. Lượt làm
  không được kéo dài quá hạn đóng.
- Việc tạo user bằng Firebase Authentication phía client và một số giới hạn của
  Rules còn phụ thuộc gói Firebase đang dùng. Dự án hiện có Cloud Functions trong
  `functions/` và cấu hình triển khai tại `firebase.json`; các thao tác như xóa
  khóa học/bài học, quản lý tài khoản và bài thi gọi backend. Xác nhận gói Firebase
  và Functions đã triển khai trước khi phát hành; không dùng mô tả “Spark, không
  Functions” để suy ra hành vi môi trường đang chạy.
- Đăng nhập dùng Firebase Auth, không đọc mật khẩu từ Firestore. Không có 2FA.
- Đăng nhập sai cổng vẫn báo cùng thông báo sai tài khoản/mật khẩu. Đăng xuất xóa phiên Auth.
- Học viên bấm **Quên mật khẩu?** ở màn hình đăng nhập để gửi yêu cầu. Một quản lý tổng
  duyệt lần đầu, quản lý tổng còn lại duyệt lần hai; sau đó quản lý phụ trách mới được
  nhập mật khẩu mới trong mục **Cấp lại mật khẩu**. Mật khẩu không lưu trong Firestore.
- Firestore Rules chặn User tự xóa lượt làm, ghi cho người khác, nộp sau hạn
  và ghi điểm ngoài miền hợp lệ. Chấm điểm tuyệt đối chống can thiệp vẫn cần
  backend tin cậy; app phát hành phải dùng backend đã triển khai, không tắt
  `USE_SECURE_BACKEND` để thay thế bằng đường Rules-only thử nghiệm.

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
- Import luôn tạo `role: user`, không ghi đè tài khoản cũ. Cloud Function tạo Firebase
  Auth và hồ sơ; nếu gián đoạn, có thể thử lại cùng dữ liệu trong cùng phiên để tiếp tục.
- Backend giữ trước tên đăng nhập và mã người dùng, tạo hồ sơ theo nhóm rồi mới kích hoạt
  cả nhóm. Nếu thao tác bị gián đoạn, giữ nguyên dữ liệu và thử lại trong cùng phiên;
  không tạo yêu cầu mới hoặc tự xóa các bản ghi `provisioning`.
- File chứa mật khẩu: không đưa file đã điền lên GitHub hoặc chia sẻ công khai.

Đã bỏ tùy chọn thêm Giáo viên và gán trực tiếp vai trò Admin. Tạo Admin phải qua đề xuất/duyệt.
Import dùng Firebase Authentication và lưu người tạo từ phiên Admin đang đăng nhập.

Khi xóa User, Cloud Function xóa Firebase Authentication, hồ sơ, chỉ mục tên đăng nhập,
tiến độ và các lượt thi/dữ liệu con đã biết. Đây là thao tác vĩnh viễn; cần bản sao lưu
nếu muốn có khả năng phục hồi.

## Kiểm thử

```powershell
flutter analyze
flutter test
```

Test kiểm tra vai trò hợp lệ/không hợp lệ, chặn đăng nhập chéo cổng, sai mật khẩu,
giữ cổng khi đăng xuất và đồ thị import không chứa màn hình bên còn lại.
Các test không đăng nhập hoặc sửa dữ liệu Firebase thật.

Chạy thêm backend từ thư mục `functions` (Node.js 22 theo cấu hình dự án):

```powershell
cd functions
npm test
npm run test:all-emulators
```

`test:all-emulators` dùng `firebase.full.test.json` tại gốc dự án và project giả
`demo-e09`. Bộ chạy tự tìm các tệp test, chạy từng tệp riêng và xóa dữ liệu
Firestore/Auth **trong emulator cục bộ** trước mỗi tệp để tránh lẫn dữ liệu test.
Không dùng các cổng của cấu hình này cho phiên emulator khác đang cần giữ dữ liệu.
Nếu báo cổng đang bận, xác định và dừng đúng emulator của lượt test trước;
không dừng toàn bộ Java hay các ứng dụng khác.

Test bộ chọn Excel trên trình duyệt phải chạy riêng từ gốc dự án:

```powershell
flutter test --platform chrome test/chon_bang_tinh_trinh_duyet_test.dart
```

Nếu test dừng ở `loading` và Chrome báo 404 `/canvaskit/chromium/`, đó là lỗi
phục vụ tài nguyên của môi trường test, chưa phải kết quả kiểm tra chức năng.
Lượt kiểm tra trên Windows đã chạy được bằng bản sao tạm `canvaskit.js` và
`canvaskit.wasm` từ `flutter/bin/cache/flutter_web_sdk/canvaskit/chromium/`
sang `test/canvaskit/chromium/`; xóa đúng hai bản sao và thư mục tạm sau khi test.
Không sửa SDK hoặc đưa các bản sao tài nguyên này vào Git.

Test đạt và build thành công không thay thế kiểm thử OTP thật, thiết bị thật,
kiểm thử tải nhiều người dùng, hoặc xác minh bản đã triển khai lên Firebase.

Hướng dẫn cấu trúc và cách sửa cho người mới: [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md).
