# Hướng dẫn sửa và nâng cấp E09 E-Learning

Tài liệu này là bản đồ ngắn gọn cho người mới. App học viên và web admin dùng
chung Firebase nhưng được build từ hai entry point riêng.

## Bắt đầu nhanh

```powershell
# kiểm tra mã Dart và toàn bộ test giao diện
flutter analyze
flutter test

# test các hàm backend không cần Firebase Emulator
cd functions
npm test
cd ..

# web admin
flutter build web --target lib/diem_vao_quan_tri.dart --release --output build/admin_web

# app học viên lên Google Play (sau khi cấu hình ký phát hành)
flutter build appbundle --target lib/diem_vao_hoc_vien.dart --release

# app học viên lên App Store (trên macOS có Xcode và Apple signing)
flutter build ipa --target lib/diem_vao_hoc_vien.dart --release
```

Các bài test cần emulator không chạy bằng `npm test`. Chạy chúng qua Firebase
Emulator để không bao giờ chạm dữ liệu thật:

```powershell
cd functions
node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec `
  --config ../firebase.json --project demo-e09 --only firestore,auth `
  "node --test test/bao_mat.emulator.js"
cd ..
```

## Mã nguồn nằm ở đâu?

Backend dùng Firebase Admin 14 và Functions 7 trên Node 22. Trong
`functions/package.json`, override `qs` giữ bản đã vá lỗi từ 6.16.0 trở lên.
Sau khi nâng thư viện, dùng `npm ci` để xác nhận lockfile cài được;
`npm audit --omit=dev` kiểm tra thư viện chạy trên server, còn `npm audit`
kiểm tra thêm các công cụ phát triển. Nâng Firebase CLI từ 14 lên 15 cần
chuẩn bị Java 21 cho emulator và kiểm tra lại các lệnh triển khai.

| Việc cần sửa | Tệp nên bắt đầu |
| --- | --- |
| Màu, logo, nền chung | `lib/app/chu_de_ung_dung.dart`, `lib/widgets/giao_dien_quan_tri.dart`, `lib/widgets/bieu_trung_thuong_hieu.dart` |
| Chọn cổng User/Admin | `lib/diem_vao_hoc_vien.dart`, `lib/diem_vao_quan_tri.dart`, `lib/app/ung_dung_hoc_tap_so.dart` |
| Cấu hình vùng API, cổng emulator, bật backend | `lib/app/cau_hinh_ung_dung.dart` |
| Thanh menu web admin | `lib/screens/admin/khung_giao_dien_quan_tri.dart` |
| Trang chủ admin và tổng quan | `lib/screens/admin/trang_chu_quan_tri.dart`, `tong_quan_hoc_tap.dart` |
| Tài khoản, đơn vị, quyền tạo User | `lib/screens/admin/quan_ly_tai_khoan.dart`, `lib/services/du_lieu/dich_vu_firestore.dart`, `lib/services/du_lieu/thao_tac_tai_khoan_firestore.dart` |
| Quên và cấp lại mật khẩu | `functions/src/cap_lai_mat_khau.js` (yêu cầu và kiểm tra người quản lý hiện tại), `functions/src/tai_khoan.js` (ghép API) |
| Nhập học viên từ Excel | `lib/screens/admin/hop_thoai_nhap_hoc_vien.dart`, `functions/src/nhap_hoc_vien.js` (luồng nhập), `functions/src/tai_khoan.js` (ghép API) |
| Đổi đơn vị quản lý và đồng bộ mã học viên | `functions/src/gan_don_vi.js` (nghiệp vụ), `functions/src/tai_khoan.js` (ghép API), `functions/src/quy_tac.js` |
| Danh sách, tìm kiếm, xóa khóa học | `lib/screens/admin/quan_ly_khoa_hoc.dart` |
| Danh sách chương/bài học, nút triển khai/kết thúc | `lib/screens/admin/quan_ly_bai_hoc.dart` |
| Form tạo/sửa khóa học và bài học | `lib/screens/admin/forms/bieu_mau_khoa_hoc.dart`, `bieu_mau_bai_hoc.dart` |
| Nhãn, dữ liệu ban đầu, kiểm tra dữ liệu trước khi lưu | `lib/models/bieu_mau_khoa_hoc.dart`, `bieu_mau_bai_hoc.dart` |
| Quy tắc khóa học đang mở/đã kết thúc, tính tiến độ | `lib/models/quy_tac_hoc_tap.dart` |
| Đọc/ghi nội dung, tiến độ, thông báo và lịch sử thay đổi | `lib/services/nghiep_vu/dich_vu_hoc_tap.dart` |
| Báo cáo khóa học đã kết thúc | `lib/screens/admin/bao_cao_khoa_hoc.dart`, `lib/models/bao_cao_hoan_thanh_khoa_hoc.dart` |
| Cài đặt bài kiểm tra và ngân hàng câu hỏi | `lib/screens/admin/ngan_hang_cau_hoi.dart` |
| Màn hình học viên | `lib/screens/user/` |
| Thẻ nội dung học viên | `lib/widgets/the_hoc_vien.dart`, `the_ho_so_hoc_vien.dart` |
| Quyền Firebase | `firestore.rules`, `storage.rules` |
| Backend Cloud Functions | `functions/src/tai_khoan.js`, `functions/src/khoa_hoc.js`, `functions/src/bai_kiem_tra.js`, `functions/src/quy_tac.js` |
| Bật/tắt bảo trì app User | `lib/screens/admin/cai_dat_quan_tri.dart`, `lib/services/du_lieu/thao_tac_bao_tri_firestore.dart`, `lib/screens/user/cong_bao_tri_hoc_vien.dart`, `lib/screens/man_hinh_dang_nhap.dart`, `firestore.rules` |

## Chú thích chức năng trong code

Các tệp Dart viết tay trong `lib/` có chú thích tiếng Việt ngay đầu tệp:
chức năng, khu vực Admin/Học viên/dùng chung và nơi cần sửa. Các lớp màn hình
cũng có chú thích `///`. Firebase options là tệp sinh tự động, giữ nguyên.
Khi thêm trang mới, viết chú thích cùng cách này; giữ mã trường Firebase bằng tiếng Anh.

Tệp mã nguồn mới nên đặt tên tiếng Việt không dấu, ngắn gọn và nêu đúng vai trò
(ví dụ `nhap_hoc_vien.js`, `cong_bao_tri_hoc_vien.dart`). Tên lớp, hàm, API,
trường Firestore và các tệp cũ đang được tham chiếu rộng vẫn giữ ổn định; chỉ
Việt hóa tệp cũ theo từng nhóm, cập nhật toàn bộ import và kiểm tra build sau đó.

## Quy tắc dữ liệu dễ nhớ

- User có `role: user`; admin phụ có `role: admin`; admin tổng có
  `role: super_admin`.
- User do admin phụ tạo phải có `createdBy` bằng UID của admin đó và `unit`
  theo đơn vị admin phụ.
- Khóa học có `published`, `deploymentMode` (`manual` hoặc `scheduled`),
  `startsAt`, `endsAt`, `coverUrl`. Chế độ thủ công không cần ngày; chế độ tự
  động cần cả ngày bắt đầu và kết thúc.
- Bài học nằm trong `courses/{courseId}/lessons`. Mỗi bài có `chapter`,
  `order`, `coverUrl`, `content`, `minimumStudySeconds`.
- Tiến độ nằm trong `users/{uid}/learning`. Không xóa hoặc sửa tiến độ từ
  phía học viên; Rules kiểm tra thời gian tối thiểu.

## Cách thêm một form nhập liệu

Ưu tiên dùng `editLearningRecord` trong `lib/widgets/tien_ich_giao_dien_hoc_tap.dart`.

- Dùng mã trường ổn định trong `fields`, ví dụ `title`; đặt chữ hiển thị trong
  `labels`, ví dụ `{'title': 'Tên chuyên đề'}`. Đổi nhãn không đổi mã dữ liệu.
- Trường chọn danh sách: thêm vào `selectFields`.
- Trường ngày giờ: thêm nhãn vào `dateTimeFields`; người dùng sẽ chọn lịch rồi
  chọn giờ, không phải tự gõ định dạng.
- Trường dài: thêm vào `richTextFields`.
- Ảnh: truyền `imageFolder` và `imageRequired: true`.

Sau khi thêm trường, cập nhật phần `save` và Rules tương ứng. Không lưu mật khẩu,
đáp án đúng hoặc quyền quản trị trong dữ liệu do client tự quyết định.

Các cấu hình `optional`, `selectFields`, `dateTimeFields`, `richTextFields`
dùng **mã trường** giống `fields`. Form cũ chưa truyền `labels` vẫn dùng nhãn
làm mã như trước; không cần chuyển tất cả màn hình cùng lúc.

## Ví dụ sửa phần khóa học/bài học

Luồng xử lý hiện tại:

```text
quan_ly_khoa_hoc.dart / quan_ly_bai_hoc.dart
  → forms/bieu_mau_khoa_hoc.dart / forms/bieu_mau_bai_hoc.dart (mở form)
  → CourseForm / LessonForm (kiểm tra và chuyển dữ liệu)
  → LearningService.saveContent (ghi nội dung + lịch sử + thông báo)
```

### Đổi tên một ô nhập

Trong `lib/models/bieu_mau_khoa_hoc.dart`, sửa giá trị trong `CourseForm.labels`:

```dart
'title': 'Tên khóa học',
```

Giữ nguyên mã `title`. `initialValues` đọc dữ liệu cũ vào form;
`toFirestore` chuyển dữ liệu vừa nhập thành các trường cần lưu.

### Thêm một trường không bắt buộc, ví dụ ghi chú khóa học

1. Trong `CourseForm.labels`, thêm `'note': 'Ghi chú'`.
2. Trong `CourseForm.initialValues`, thêm `'note': data['note'] ?? ''`.
3. Trong `CourseForm.toFirestore`, thêm `'note': values['note']`.
4. Trong `forms/bieu_mau_khoa_hoc.dart`, thêm `note` vào `optional`.
5. Kiểm tra Rules có cho phép trường mới và bổ sung nơi hiển thị nếu cần.

Không tạo bản ghi mới khi sửa: form truyền lại reference của khóa học/bài học
đang mở. `saveContent` giữ các trường bổ sung chưa có trong form và ghi lịch sử.

### Đổi thời lượng học mặc định

Sửa `LessonForm.defaultStudySeconds` trong `lib/models/bieu_mau_bai_hoc.dart`.
Giá trị này dùng cho form và danh sách bài học admin khi bản ghi chưa có thời lượng;
không thay đổi thời lượng của các bài đã lưu. Nếu đổi giới hạn
`minStudySeconds`/`maxStudySeconds`, phải cập nhật quy tắc tương ứng trong
`firestore.rules` và chạy Rules Emulator. Học viên vẫn chịu kiểm tra thời gian
ở phía Firebase.

### Kiểm tra phần vừa sửa

```powershell
flutter test test/cac_bieu_mau_hoc_tap_test.dart test/hoc_tap_test.dart test/luu_tru_khoa_hoc_quan_tri_test.dart
```

Các test này kiểm tra lưu bản ghi cũ, đổi nhãn vẫn lưu đúng mã trường, lịch
triển khai, thời lượng, tiến độ và khóa học đã kết thúc. Trước khi bàn giao,
chạy thêm `flutter analyze` và toàn bộ `flutter test`.

### Phạm vi đã đơn giản hóa

Phần khóa học/bài học được tách theo màn hình, biểu mẫu, model và service.
Các thao tác Firestore của tài khoản/bài thi được tách thành các `part` trong
`lib/services/du_lieu/`; khi sửa dữ liệu tài khoản, bắt đầu từ
`thao_tac_tai_khoan_firestore.dart`, còn truy vấn và hàm dùng chung nằm trong
`dich_vu_firestore.dart`. Báo cáo lớn được chia giữa màn hình, bảng, phần lấy
lượt thi và phần xuất Excel. Giữ thay đổi nhỏ theo từng luồng để không làm đổi
cấu trúc dữ liệu Firebase ngoài ý muốn.

## Quy trình thay đổi an toàn

1. Sửa một nhóm nhỏ trong đúng thư mục.
2. Chạy `dart format` cho các tệp đã sửa.
3. Chạy `flutter analyze` và test liên quan; trước khi bàn giao chạy `flutter test`.
4. Nếu đổi quyền hoặc schema, chạy Rules Emulator rồi mới deploy.
5. Build đúng cổng: web dùng `diem_vao_quan_tri.dart`; AAB cho Google Play và IPA cho
   App Store đều dùng `diem_vao_hoc_vien.dart`. Xem trạng thái mã định danh, ký và quyền
   riêng tư trong README.
6. Chỉ deploy web admin bằng `firebase.json` ở thư mục gốc. Chỉ xuất bản đóng gói hoặc
   tải lên cửa hàng khi có yêu cầu; APK dành cho cài trực tiếp khi cần thử nghiệm.
   Không truyền các tệp trong `config/firebase/` trực tiếp cho Firebase CLI: CLI xem
   thư mục chứa tệp cấu hình là gốc dự án, nên các đường dẫn `functions`, `firestore.rules`
   và `build/admin_web` trong đó không trỏ tới tài nguyên ở thư mục gốc. Dùng `firebase.json`
   gốc để triển khai; khi chạy từ `functions/`, dùng `--config ../firebase.json`.
   Repository không có `.firebaserc`, vì vậy lệnh deploy phải chỉ rõ `--project e09-elearning`.
7. Giữ mã nguồn nền tảng `android/`, `ios/`, cấu hình Firebase và tài nguyên app
   khi dọn dự án. Giữ khóa ký và chứng chỉ phát hành an toàn ngoài Git.

### Phát hành nội bộ và nhắc bản mới

Tăng `version` (cả tên phiên bản và build number) trong `pubspec.yaml`, sau đó chạy:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\publish_internal_release.ps1
```

Script build APK và Admin web, sinh `web/app-release.json` từ mã build thật của APK,
lưu APK vào `outputs/internal/` và cập nhật Firebase Hosting. App học viên tự đọc
manifest này sau đăng nhập thành công; không cần Admin báo bản mới trong trang quản trị.
Chỉ các APK đã có chức năng kiểm tra phiên bản mới nhận được lời nhắc.

### Thao tác trên nhiều tài khoản

Nhập Excel nhận đến 200 dòng bằng các bước có thể tiếp tục sau lỗi. Đổi đơn vị
quản lý kiểm tra trùng trước, rồi đồng bộ mỗi đợt 60 hồ sơ; nếu thao tác bị gián
đoạn, chạy lại cùng mã đơn vị để tiếp tục. Trong lúc chạy, hệ thống tạm khóa các
thay đổi tài khoản liên quan. Cần hoàn tất backfill trước khi dùng luồng đổi đơn
vị theo đợt; luồng này dùng reservation để tránh quét toàn bộ hồ sơ.

Backfill chỉ mục mã cũ ở `functions/scripts/bo_sung_ma_hoc_vien.js` xử lý 80 hồ sơ
mỗi transaction. Nếu bị gián đoạn, chạy lại `--apply` để tiếp tục từ cursor trong
`system/code_indexes`; chỉ khi hoàn tất mới đặt trạng thái `complete`, cho phép
thao tác cấp mã dựa vào chỉ mục thay vì quét toàn bộ tài khoản. Chạy preview trước,
sửa dữ liệu trùng/không hợp lệ nếu được báo lỗi, rồi mới áp dụng. Trên Firebase thật,
chỉ chạy trong đợt bảo trì sau khi sao lưu và có kế hoạch khôi phục.

## Trang chủ, Tin tức và Tiện ích học viên

Thanh menu học viên gồm Trang chủ, Tin tức, Học tập, Kiểm tra và Tiện ích.
Tiện ích tập hợp các chức năng hiện có: học tập, kiểm tra, lịch sử kiểm tra,
tin tức, bài đã lưu, thông báo, cá nhân và cập nhật hồ sơ.

Trong mục quản trị Tin tức, chọn danh mục và trạng thái Đăng tin để bài xuất
hiện trong ứng dụng. Tin nổi bật được ưu tiên hiển thị ảnh lớn ở mục Tin tức.
Ảnh tiêu đề của tối đa 5 tin đã đăng mới nhất tự động được dùng làm banner trang
chủ và chuyển sau 5 giây. Không cần quản lý banner riêng; banner cũ trong
`home_banners` chỉ còn được dùng dự phòng cho dữ liệu đã tồn tại khi chưa có tin
đã đăng kèm ảnh tiêu đề.
Các bài cũ chưa có danh mục mặc định thuộc Điểm tin.

Tìm kiếm hỗ trợ tiếng Việt có hoặc không dấu, danh mục và bộ lọc thời gian.
Bài viết tin tức hiện không còn chức năng đánh dấu/lưu. Dữ liệu đánh dấu cũ
(nếu có) vẫn còn trong Firestore nhưng ứng dụng và quy tắc bảo mật không cho
người dùng đọc hoặc thay đổi dữ liệu này. Bài bị chuyển về nháp sẽ không còn
hiển thị cho học viên.
Trong mục Học tập chỉ có bài “Chỉ học”; mục Kiểm tra chỉ có bài “Học xong kiểm
tra ngay”. Với bài kiểm tra, học viên phải đọc tới cuối nội dung và bấm hoàn
thành thì đề riêng đã gắn với bài mới được mở. Web admin có hai nhóm tương ứng
để tạo và quản lý riêng.
Micro chỉ được khởi động khi bấm nút; Android/iOS cần quyền nhận dạng giọng
nói và thiết bị có dịch vụ hỗ trợ. Cần kiểm tra micro trên thiết bị thật.

Kiểm thử liên quan: `tinh_nang_tin_tuc_test.dart`, `tin_tuc_va_che_do_bai_hoc_test.dart`,
`bo_cuc_di_dong_hoc_vien_test.dart` và `functions/test/tin_tuc_bai_hoc.emulator.js`.
Khi được yêu cầu phát hành, cần cập nhật `firestore.rules` cùng ứng dụng/admin
để quyền lưu bài và các trường tin tức mới hoạt động. Sửa nguồn và chạy test
không cập nhật website đang dùng, không xuất APK.

## Những phần còn cần nâng cấp riêng

Đăng ký/khôi phục tài khoản qua email, upload tài liệu được bảo vệ, xuất báo cáo
Excel/PDF, push notification khi app đóng, và một số dạng câu hỏi nâng cao vẫn
cần thiết kế và kiểm thử riêng. Không đánh dấu các phần này là hoàn thành chỉ vì
build thành công.
