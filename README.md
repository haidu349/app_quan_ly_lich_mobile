# Quản lý công việc theo lịch biểu cá nhân

Ứng dụng di động (Flutter, đích chính là Android) quản lý lịch cá nhân: xem lịch dạng bảng giờ Ngày/Tuần/Tháng, kéo thả để dời, nhập từ Excel, nhắc lịch mỗi sáng, thống kê và sao lưu dữ liệu.

## 1. Tính năng

| Nhóm | Chức năng |
| ---- | --------- |
| Lịch | Bảng giờ Ngày/Tuần, lưới Tháng; chạm ô trống để tạo lịch 1 giờ; chọn một lịch rồi kéo để dời, giãn để đổi độ dài; vuốt để đổi trang |
| Danh sách | Danh sách sự kiện theo ngày, ẩn lịch đã qua, chọn nhiều để xóa hàng loạt |
| Sự kiện | Tên, giờ bắt đầu/kết thúc, người tổ chức, địa điểm, ghi chú, nhãn màu; cảnh báo trùng giờ và gợi ý khung giờ trống |
| Nhãn | Thêm, đổi tên, đổi màu, xóa nhãn |
| Nhập Excel | Đọc file `.xlsx`, xem trước và báo lỗi từng dòng, gán nhãn, tự động dời dòng trùng giờ, xem lịch tạm trên bảng tuần (kéo thả được) rồi mới nhập |
| Dời hàng loạt | Dời cả chuỗi lịch theo khoảng ngày (có chọn nhanh), dạy bù, chỉnh tay trên bảng tuần trước khi áp dụng |
| Nhắc nhở | Thông báo có âm thanh lúc 06:00 (đổi được giờ) liệt kê lịch trong ngày; ngày không có lịch thì không báo |
| Thống kê | Theo tuần, tháng, năm và theo nhãn |
| Sao lưu | Xuất toàn bộ lịch và nhãn ra file `.json`, khôi phục từ file đó |
| Dữ liệu | SQLite cục bộ; tự xóa sự kiện kết thúc quá 365 ngày (chạy mỗi lần mở app) |

### Nhập từ Excel

File `.xlsx`, dòng tiêu đề nằm trên các dòng dữ liệu.

- Bắt buộc: `Tên sự kiện`, `Ngày tổ chức` (ví dụ `30/11/2026`).
- Không bắt buộc: `Giờ bắt đầu`, `Giờ kết thúc` (ví dụ `8:30`), `Tên người tổ chức`, `Địa điểm`, `Nhãn` (hoặc `Loại`, `Phân loại`), `Ghi chú`, `STT` (bỏ qua).
- Không có cột giờ thì dùng 08:00 - 09:00, đổi được ở bước xem trước.
- Nhãn trong file ưu tiên hơn nhãn mặc định chọn lúc nhập. Chưa có gì được lưu cho tới khi bấm Nhập.

### Sao lưu và khôi phục

Vào **Cài đặt**, mục **Dữ liệu**:

- **Sao lưu ra file**: chọn nơi lưu `sao_luu_lich_YYYYMMDD.json`.
- **Khôi phục từ file sao lưu**: **thay toàn bộ** lịch và nhãn hiện tại bằng nội dung file (có hộp xác nhận). File sai định dạng thì báo lỗi và dữ liệu cũ giữ nguyên.
- Cài đặt nhắc nhở không nằm trong file sao lưu. Lịch quá 365 ngày vẫn sẽ bị xóa ở lần mở app kế tiếp.

## 2. Công nghệ

- Flutter 3.47.8 (stable), Dart 3.13.7
- `provider` (một `ChangeNotifier` duy nhất: `AppData`), `sqflite` + `path` (SQLite), `table_calendar`
- `excel` + `file_picker` (nhập Excel, ghi/đọc file sao lưu)
- `flutter_local_notifications` + `timezone` (nhắc lịch)

## 3. Cấu trúc thư mục

```
lib/
  main.dart            Điểm vào, theme, AppData
  models/              Event, EventLabel
  database/            database_helper.dart (SQLite, nâng cấp schema)
  providers/           app_data.dart (trạng thái chung, mọi thay đổi đi qua đây)
  services/            Logic thuần Dart, không import Flutter, có unit test:
                       bulk_reschedule, conflict, free_slot, import_parser,
                       reminder_planner, stats, timetable_layout/pages, backup
                       (reminder_service, excel_reader, file_pick_service
                       là chỗ duy nhất chạm plugin)
  screens/             Các màn hình (lịch, danh sách, thống kê, cài đặt, nhập, dời...)
  widgets/             Bảng giờ Ngày/Tuần (calendar_timetable, week_timetable), thẻ sự kiện...
  utils/               Định dạng ngày, bảng màu
test/                  Unit test cho services/
```

Quy ước: logic mới đặt trong `services/` và không import Flutter để dễ test. Màn hình không gọi thẳng `DatabaseHelper` mà đi qua `AppData`.

## 4. Cơ sở dữ liệu

- File `lich.db`, bảng `events`, `labels`, `settings`; hiện là `_dbVersion = 3`.
- Giờ lưu dạng `millisecondsSinceEpoch` ở cột `start_time` / `end_time`.
- Đổi cấu trúc bảng: tăng `_dbVersion`, thêm bước `if (oldVersion < N)` trong `onUpgrade` và cập nhật `onCreate`, để máy đang dùng không mất dữ liệu.
- Dữ liệu nằm trong bộ nhớ riêng của app. **Gỡ app hoặc xóa dữ liệu app là mất hết**, hãy dùng chức năng sao lưu.

## 5. Môi trường phát triển (Windows)

1. **Git**: https://git-scm.com
2. **Flutter SDK**: https://docs.flutter.dev/get-started/install
3. **Android Studio** (Standard), vào **SDK Manager > SDK Tools** cài **Android SDK Command-line Tools** và **NDK (Side by side)** đúng phiên bản `28.2.13676358`.
4. **VS Code** với extension **Flutter**.

Kiểm tra bằng `flutter doctor`; mục _Visual Studio_ báo `[!]` có thể bỏ qua vì chỉ build Android. Nếu gõ `flutter` báo "not recognized", thêm thư mục `bin` của Flutter vào **Path** rồi mở lại terminal.

## 6. Chạy ứng dụng

```bash
flutter pub get
flutter devices
flutter run -d <ma-thiet-bi>
```

- Máy thật: bật **Gỡ lỗi USB** trong Tùy chọn nhà phát triển, cắm cáp, chọn **Truyền tệp**.
- `flutter run -d chrome` chỉ xem được giao diện, `sqflite` không chạy trên web.
- Phím khi đang chạy: `r` hot reload, `R` hot restart, `q` thoát. Sau khi sửa `pubspec.yaml` hoặc thêm thư viện phải tắt và chạy lại. Đổi kiểu của biến trong `State` thì dùng `R`, vì `r` giữ giá trị cũ và báo lỗi kiểu.

## 7. Kiểm tra và đóng gói

```bash
flutter analyze                  # kiểm tra lỗi và cảnh báo
flutter test                     # chạy unit test
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

Đưa file APK lên mục **Releases** của GitHub, không commit vào repo.

## 8. Lưu ý

- **Thông báo 06:00**: một số hãng máy (realme, Oppo, Xiaomi, Samsung...) chặn thông báo hẹn giờ khi app bị tối ưu pin. Hãy cấp quyền thông báo và tắt tối ưu pin cho app. Trong Cài đặt có nút gửi thông báo thử.
- **Xóa hàng loạt** ở tab Danh sách không hoàn tác được.
- **Cảnh báo `WARNING` màu đỏ khi build** thường không phải lỗi; chỉ cần để ý khi thấy `FAILURE` hoặc `BUILD FAILED`.
- **iOS** chỉ build được trên máy Mac; dự án tập trung vào Android.
- Không sửa tay `build/` và `.dart_tool/`.

## 9. Git

Repo: https://github.com/haidu349/app_quan_ly_lich_mobile (nhánh `main`).

```bash
git status
git add .
git commit -m "Mô tả ngắn một tính năng"
git push
```

- Commit sau mỗi tính năng nhỏ chạy được; viết thông điệp ngắn bằng tiếng Việt.
- Không commit mật khẩu, khóa API, keystore hay `auth.json`.
- Máy mới: `git clone ...` rồi `flutter pub get`. Dữ liệu sự kiện không nằm trong Git, hãy khôi phục bằng file sao lưu.
- Tránh `git push --force` và `git reset --hard` khi chưa hiểu rõ.

| Lỗi thường gặp | Cách xử lý |
| -------------- | ---------- |
| `cmdline-tools component is missing` | Cài **Android SDK Command-line Tools** trong SDK Manager |
| `sdkmanager did not install NDK` | Cài NDK `28.2.13676358` trong SDK Manager |
| `flutter devices` không thấy điện thoại | Chọn **Truyền tệp**, bật Gỡ lỗi USB, chạy `adb kill-server` rồi `adb devices` |
| Build lỗi khó hiểu sau khi đổi thư viện | `flutter clean`, `flutter pub get`, `flutter run` |
| `rejected ... fetch first` | Chạy `git pull` rồi `git push` lại |
| Cảnh báo `LF will be replaced by CRLF` | Bình thường trên Windows, bỏ qua |

## 10. Thông tin

- Môn học: Lập trình trên thiết bị di động
- Đề tài: Quản lý công việc theo lịch biểu cá nhân
- Sản phẩm bàn giao: file cài đặt (APK) và mã nguồn
