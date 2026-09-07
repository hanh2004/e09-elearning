# Admin tổng và admin phụ

Mã nguồn hiện dùng **Firebase Authentication + Firestore Rules trên gói Spark miễn phí**.
Không cần Gmail cá nhân cho User và không dùng Cloud Functions. Việc tạo tài khoản chạy
trong phiên Auth phụ ở Web Admin; phù hợp thử nghiệm với dữ liệu không quan trọng.
Không còn đăng nhập bằng cách đọc mật khẩu trong collection `users`. Không có 2FA.
**Chưa triển khai cấu hình này lên project thật `e09-elearning`.** Không chạy bản mới
với dữ liệu cũ trước khi hoàn thành chuyển đổi; không tự thêm `role` để cấp quyền.

## Quyền

| Tài khoản | Quyền |
| --- | --- |
| `admintong1`, `admintong2` | Quản lý nội dung, tài khoản User, đề xuất và duyệt Admin phụ |
| Admin phụ đã duyệt | Xem mọi User nhưng chỉ sửa/xóa User do mình tạo; không tạo bài thi/câu hỏi hoặc quản lý Admin |
| Admin phụ chờ duyệt / bị từ chối | Không đăng nhập được |

- Mỗi yêu cầu phải do **hai UID admin tổng khác nhau** đề xuất và đồng ý. Cả hai chiều đều hỗ trợ.
- Không có nút tạo thêm admin tổng, không xóa/hạ quyền hai admin tổng trong app.
- Không sửa hồ sơ hoặc mật khẩu Admin tổng trong app. Muốn thay đổi phải thực hiện ở mã
  khởi tạo/Firebase Auth rồi triển khai có kiểm soát; tuyệt đối không nhúng mật khẩu vào app.
- Tài khoản được quản lý bằng UID, không cấp quyền bằng cách so sánh tên đăng nhập.
- `createdBy` và `approvedBy` chỉ server ghi. Web Admin hiện tên người tạo dưới mỗi User;
  app User không hiển thị thông tin này. User cũ không rõ người tạo giữ `createdBy: null`.
- Chỉ Admin tổng thấy công tắc cập nhật ứng dụng. Trạng thái được lưu tại
  `system/app_status`; khi bật, đăng nhập User bị chặn nhưng Admin vẫn đăng nhập được.
- Xóa là **thu hồi quyền đăng nhập**, giữ hồ sơ/lịch sử và giữ chỗ tên đăng nhập để đối chiếu.
- Mật khẩu không lưu trong Firestore hoặc hồ sơ yêu cầu; Firebase Auth quản lý mật khẩu.
- Mật khẩu tạm giống nhau chỉ dành cho thử nghiệm. Firebase Authentication không cho xem
  lại mật khẩu và Firestore không lưu mật khẩu.

## Chạy thử trên máy, không dùng dữ liệu thật

Cần Node 22, Java 17 trở lên cho Firebase CLI 14 (khuyến nghị Java 21), Flutter.
Trên máy hiện tại Node 22 đã tải ở `.tmp/node22/node.exe`; đây là công cụ tạm,
không đưa vào Git. Máy khác cài Node 22 và npm bình thường.

Terminal 1, tại thư mục dự án:

Trên Windows, có thể chạy `./start-admin-local.ps1`: script tự khởi tạo hai admin tổng
trên emulator và giữ backend chạy. Sau đó mở terminal khác chạy lệnh Flutter bên dưới.
Các bước thủ công tương đương:

```powershell
cd functions
npm ci
cd ..
node functions/node_modules/firebase-tools/lib/bin/firebase.js emulators:start --config firebase.secure.json --project demo-e09 --only auth,firestore,functions --import .tmp/firebase-local --export-on-exit .tmp/firebase-local
```

Terminal 2, tại thư mục `functions`, khởi tạo hai admin tổng:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node scripts/bootstrap.js --project demo-e09 --apply
```

Hai tài khoản `admintong1`, `admintong2` có mật khẩu thử nghiệm `123456`.
Script chạy lại không đặt lại mật khẩu. Chỉ bật lại tài khoản nếu lần khởi tạo trước bị gián đoạn.

Terminal 3, tại thư mục dự án:

```powershell
flutter run -d chrome -t lib/main_admin.dart --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

App User thử nghiệm dùng cùng emulator:

```powershell
flutter run -d chrome -t lib/main_user.dart --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Dùng hai trình duyệt hoặc cửa sổ riêng tư để đăng nhập hai admin đồng thời. Trong Admin tổng:
**Quản lý Tài khoản → Đề xuất Admin phụ**, sau đó tài khoản tổng còn lại vào
**Duyệt Admin phụ → Đồng ý**. Đổi mật khẩu của chính mình ở **Quản lý Tài khoản → Sửa tài khoản**.

## Kích hoạt trên Firebase thật — cần bước phối hợp riêng

Không chạy các bước này chỉ để thử giao diện. Chuyển đổi cần khoảng bảo trì vì app cũ
không có phiên Firebase Auth. Sau khi bật Rules mới, các bản User cũ phải cập nhật.

1. Sao lưu Firestore, Firebase Auth (nếu đã có), Rules đang triển khai và bản ứng dụng cũ.
   Kiểm kê collection thực tế: Rules mới chỉ liệt kê các collection đang được mã nguồn sử dụng.
2. Bật Authentication → Sign-in method → Email/Password. Người dùng vẫn nhập username;
   ứng dụng ánh xạ nội bộ sang email SHA-256 tại `accounts.invalid`, không cần email cá nhân.
   Không dùng chức năng quên mật khẩu qua email với địa chỉ nội bộ này.
3. Chuẩn bị quyền triển khai Cloud Functions và cấu hình thanh toán phù hợp. Không đưa
   service-account key vào Flutter, Git, ảnh chụp hoặc hội thoại. Dùng Application Default Credentials
   của người triển khai khi chạy script. Không gửi mật khẩu admin qua hội thoại.
4. Trong thời gian bảo trì, chặn các client cũ ghi dữ liệu. Chạy dry-run:

   ```powershell
   node scripts/migrate.js --project e09-elearning
   node scripts/bootstrap.js --project e09-elearning
   ```

   Sửa các lỗi trùng tên, UID không hợp lệ hoặc dữ liệu cũ thiếu trường trước khi tiếp tục.
   Script không tự ghi đè tài khoản tên `admintong1`/`admintong2` có sẵn ở UID khác.
5. Sau khi kiểm tra sao lưu và đồng ý chuyển đổi, đặt `ACCOUNT_MIGRATION_APPROVED=e09-elearning`
   trong môi trường của tiến trình triển khai. Đặt `ROOT_PASSWORD_1`, `ROOT_PASSWORD_2` bằng
   hai mật khẩu riêng. Script **không nhận `123456` cho project thật** và không in mật khẩu.
6. Chạy migration `--apply`, bootstrap `--apply`, triển khai backend/Rules và bản ứng dụng mới
   trong cùng đợt bảo trì:

   ```powershell
   node scripts/migrate.js --project e09-elearning --apply
   node scripts/bootstrap.js --project e09-elearning --apply
   npx firebase deploy --config ../firebase.secure.json --project e09-elearning --only functions:accounts,firestore:rules
   ```

7. Kiểm thử bằng hai admin tổng, một admin phụ và một User; chỉ mở lại dịch vụ khi tất cả đạt.
   Xóa các biến mật khẩu khỏi terminal sau khi dùng. Không bỏ `--project` trong các lệnh thao tác dữ liệu.

Migration giữ UID tài khoản/hồ sơ và lịch sử cũ, xóa trường mật khẩu sau khi chuyển thành công.
Admin/giáo viên cũ **không tự được nâng quyền**, chuyển thành `legacy_disabled`. Để cấp quyền mới,
hai admin tổng tạo và duyệt tài khoản Admin phụ với tên mới. Phải thống nhất việc này trước khi migrate.
Không tự rollback Rules cũ sau migration: khôi phục dữ liệu/Auth/app phải theo bộ sao lưu đồng bộ.

## Khi một thao tác bị gián đoạn

Auth và Firestore không hỗ trợ một transaction chung. Import giữ tất cả hồ sơ ở `provisioning`
cho tới khi tạo Auth xong, rồi kích hoạt cả nhóm trong một transaction. Không có nhóm User hoạt động dở dang.
Trong cùng phiên màn hình, gửi lại cùng dữ liệu sẽ dùng cùng mã thao tác, không ghi đè tài khoản cũ.
Giữ trang và dữ liệu để thử lại nếu báo chưa hoàn tất. Nếu đã đóng app khi bị lỗi, cần người vận hành
kiểm tra `account_operations` / `admin_requests` để xử lý bản ghi chờ; không sửa role hoặc tạo hàng loạt lại.
Yêu cầu admin đã quyết định có nút **Đồng bộ lại trạng thái đăng nhập** để hoàn tất cập nhật Auth bị gián đoạn.

## Kiểm thử

```powershell
flutter analyze
flutter test
cd functions
npm test
npm run test:rules
npx firebase emulators:exec --config ../firebase.secure.json --project demo-e09 --only firestore,auth,functions "node --test test/bootstrap.emulator.js"
```

Các kiểm thử `*.emulator.js` từ chối chạy nếu thiếu emulator; không dùng tài khoản hoặc dữ liệu thật.
Rules bảo vệ phân quyền quản trị. Luồng làm bài/chấm điểm hiện vẫn giữ cách xử lý client-side cũ;
đây chưa phải bản nâng cấp chống gian lận thi cử phía server.

Tài liệu kỹ thuật: [Firebase callable functions](https://firebase.google.com/docs/functions/callable),
[quản lý Auth bằng Admin SDK](https://firebase.google.com/docs/auth/admin/manage-users),
[kiểm tra quyền qua hồ sơ trong Firestore Rules](https://firebase.google.com/docs/firestore/security/rules-conditions).
