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
flutter build web --target lib/main_admin.dart --release --output build/admin_web

# app học viên lên Google Play (sau khi cấu hình ký phát hành)
flutter build appbundle --target lib/main_user.dart --release

# app học viên lên App Store (trên macOS có Xcode và Apple signing)
flutter build ipa --target lib/main_user.dart --release
```

Các bài test cần emulator không chạy bằng `npm test`. Chạy chúng qua Firebase
Emulator để không bao giờ chạm dữ liệu thật:

```powershell
cd functions
node node_modules/firebase-tools/lib/bin/firebase.js emulators:exec `
  --config ../firebase.json --project demo-e09 --only firestore,auth `
  "node --test test/security.emulator.js"
cd ..
```

## Mã nguồn nằm ở đâu?

| Việc cần sửa | Tệp nên bắt đầu |
| --- | --- |
| Màu, logo, nền chung | `lib/app/app_theme.dart`, `lib/widgets/admin_ui.dart`, `lib/widgets/brand_logo.dart` |
| Chọn cổng User/Admin | `lib/main_user.dart`, `lib/main_admin.dart`, `lib/app/elearning_app.dart` |
| Cấu hình vùng API, cổng emulator, bật backend | `lib/app/app_config.dart` |
| Thanh menu web admin | `lib/screens/admin/admin_responsive_shell.dart` |
| Trang chủ admin và tổng quan | `lib/screens/admin/admin_home_screen.dart`, `admin_learning_dashboard.dart` |
| Tài khoản, đơn vị, quyền tạo User | `lib/screens/admin/admin_account_screen.dart`, `lib/services/firestore_service.dart` |
| Danh sách, tìm kiếm, xóa khóa học | `lib/screens/admin/admin_courses_screen.dart` |
| Danh sách chương/bài học, nút triển khai/kết thúc | `lib/screens/admin/admin_lessons_screen.dart` |
| Form tạo/sửa khóa học và bài học | `lib/screens/admin/forms/course_editor.dart`, `lesson_editor.dart` |
| Nhãn, dữ liệu ban đầu, kiểm tra dữ liệu trước khi lưu | `lib/models/course_form.dart`, `lesson_form.dart` |
| Quy tắc khóa học đang mở/đã kết thúc, tính tiến độ | `lib/models/learning_policy.dart` |
| Đọc/ghi nội dung, tiến độ, thông báo và lịch sử thay đổi | `lib/services/learning_service.dart` |
| Báo cáo khóa học đã kết thúc | `lib/screens/admin/admin_course_report_screen.dart`, `lib/models/course_completion_report.dart` |
| Bài thi và ngân hàng câu hỏi | `lib/screens/admin/admin_exam_screen.dart`, `admin_question_bank_screen.dart` |
| Màn hình học viên | `lib/screens/user/` |
| Thẻ nội dung học viên | `lib/widgets/learner_card.dart`, `profile_card.dart` |
| Quyền Firebase | `firestore.rules`, `storage.rules` |
| Backend Blaze | `functions/src/accounts.js`, `functions/src/exams.js`, `functions/src/policy.js` |

## Chú thích chức năng trong code

Các tệp Dart viết tay trong `lib/` có chú thích tiếng Việt ngay đầu tệp:
chức năng, khu vực Admin/Học viên/dùng chung và nơi cần sửa. Các lớp màn hình
cũng có chú thích `///`. Firebase options là tệp sinh tự động, giữ nguyên.
Khi thêm trang mới, viết chú thích cùng cách này; giữ mã trường Firebase bằng tiếng Anh.

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

Ưu tiên dùng `editLearningRecord` trong `lib/widgets/learning_widgets.dart`.

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
admin_courses_screen.dart / admin_lessons_screen.dart
  → forms/course_editor.dart / forms/lesson_editor.dart (mở form)
  → CourseForm / LessonForm (kiểm tra và chuyển dữ liệu)
  → LearningService.saveContent (ghi nội dung + lịch sử + thông báo)
```

### Đổi tên một ô nhập

Trong `lib/models/course_form.dart`, sửa giá trị trong `CourseForm.labels`:

```dart
'title': 'Tên khóa học',
```

Giữ nguyên mã `title`. `initialValues` đọc dữ liệu cũ vào form;
`toFirestore` chuyển dữ liệu vừa nhập thành các trường cần lưu.

### Thêm một trường không bắt buộc, ví dụ ghi chú khóa học

1. Trong `CourseForm.labels`, thêm `'note': 'Ghi chú'`.
2. Trong `CourseForm.initialValues`, thêm `'note': data['note'] ?? ''`.
3. Trong `CourseForm.toFirestore`, thêm `'note': values['note']`.
4. Trong `forms/course_editor.dart`, thêm `note` vào `optional`.
5. Kiểm tra Rules có cho phép trường mới và bổ sung nơi hiển thị nếu cần.

Không tạo bản ghi mới khi sửa: form truyền lại reference của khóa học/bài học
đang mở. `saveContent` giữ các trường bổ sung chưa có trong form và ghi lịch sử.

### Đổi thời lượng học mặc định

Sửa `LessonForm.defaultStudySeconds` trong `lib/models/lesson_form.dart`.
Giá trị này dùng cho form và danh sách bài học admin khi bản ghi chưa có thời lượng;
không thay đổi thời lượng của các bài đã lưu. Nếu đổi giới hạn
`minStudySeconds`/`maxStudySeconds`, phải cập nhật quy tắc tương ứng trong
`firestore.rules` và chạy Rules Emulator. Học viên vẫn chịu kiểm tra thời gian
ở phía Firebase.

### Kiểm tra phần vừa sửa

```powershell
flutter test test/learning_forms_test.dart test/learning_test.dart test/admin_course_archive_test.dart
```

Các test này kiểm tra lưu bản ghi cũ, đổi nhãn vẫn lưu đúng mã trường, lịch
triển khai, thời lượng, tiến độ và khóa học đã kết thúc. Trước khi bàn giao,
chạy thêm `flutter analyze` và toàn bộ `flutter test`.

### Phạm vi đã đơn giản hóa

Đã tách phần quản lý khóa học/bài học và giữ các import cũ hoạt động bằng
`export`. Những màn hình tài khoản, bài thi, báo cáo và `firestore_service.dart`
vẫn còn dài; có thể áp dụng cách tách này từng phần khi nâng cấp chúng.
Chưa đưa thêm thư viện quản lý trạng thái hay thay cấu trúc dữ liệu Firebase.

## Quy trình thay đổi an toàn

1. Sửa một nhóm nhỏ trong đúng thư mục.
2. Chạy `dart format` cho các tệp đã sửa.
3. Chạy `flutter analyze` và test liên quan; trước khi bàn giao chạy `flutter test`.
4. Nếu đổi quyền hoặc schema, chạy Rules Emulator rồi mới deploy.
5. Build đúng cổng: web dùng `main_admin.dart`; AAB cho Google Play và IPA cho
   App Store đều dùng `main_user.dart`. Xem cấu hình ký còn thiếu trong README.
6. Chỉ deploy web admin bằng `firebase.json` ở thư mục gốc. Chỉ xuất bản đóng gói hoặc
   tải lên cửa hàng khi có yêu cầu; APK dành cho cài trực tiếp khi cần thử nghiệm.
7. Giữ mã nguồn nền tảng `android/`, `ios/`, cấu hình Firebase và tài nguyên app
   khi dọn dự án. Giữ khóa ký và chứng chỉ phát hành an toàn ngoài Git.

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

Kiểm thử liên quan: `news_features_test.dart`, `news_and_lesson_modes_test.dart`,
`learner_mobile_layout_test.dart` và `functions/test/news-lessons.emulator.js`.
Khi được yêu cầu phát hành, cần cập nhật `firestore.rules` cùng ứng dụng/admin
để quyền lưu bài và các trường tin tức mới hoạt động. Sửa nguồn và chạy test
không cập nhật website đang dùng, không xuất APK.

## Những phần còn cần nâng cấp riêng

Đăng ký/khôi phục tài khoản qua email, upload tài liệu được bảo vệ, xuất báo cáo
Excel/PDF, push notification khi app đóng, và một số dạng câu hỏi nâng cao vẫn
cần thiết kế và kiểm thử riêng. Không đánh dấu các phần này là hoàn thành chỉ vì
build thành công.
