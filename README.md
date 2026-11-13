# Quản lý công việc theo lịch biểu cá nhân

Ứng dụng di động (Flutter) giúp quản lý công việc và sự kiện cá nhân theo lịch: nhập thủ công hoặc từ file Excel, thống kê theo tuần/học kỳ/năm, tự xóa dữ liệu cũ hơn 1 năm và nhắc lịch bằng âm thanh lúc 6:00 sáng mỗi ngày.

## 1. Tính năng

| Tính năng                                                                      | Trạng thái |
| ------------------------------------------------------------------------------ | ---------- |
| Xem danh sách sự kiện (xếp theo ngày)                                          | Hoàn thành |
| Thêm sự kiện (tên, ngày tổ chức, người tổ chức)                                | Hoàn thành |
| Sửa sự kiện (bấm vào thẻ)                                                      | Hoàn thành |
| Xóa sự kiện (vuốt thẻ sang trái, có xác nhận)                                  | Hoàn thành |
| Lưu dữ liệu cục bộ bằng SQLite                                                 | Hoàn thành |
| Tự động xóa sự kiện cũ hơn 1 năm (chạy mỗi lần mở app)                         | Hoàn thành |
| Giờ bắt đầu/kết thúc và cảnh báo trùng lịch                                    | Dự kiến    |
| Nhập dữ liệu từ file Excel (STT, Tên sự kiện, Ngày tổ chức, Tên người tổ chức) | Dự kiến    |
| Thông báo nhắc có âm thanh lúc 6:00 sáng cho các việc trong ngày               | Dự kiến    |
| Biểu đồ công việc theo tuần, theo học kỳ                                       | Dự kiến    |
| Thống kê và tra cứu theo học kỳ, tên sự kiện, năm                              | Dự kiến    |
| Đóng gói file cài đặt (APK)                                                    | Dự kiến    |

## 2. Công nghệ

- **Flutter** (ngôn ngữ Dart), phiên bản đang dùng: Flutter 3.47.8 (stable), Dart 3.13.7
- **SQLite** thông qua thư viện `sqflite` (cơ sở dữ liệu quan hệ, lưu cục bộ trong thiết bị)
- Thư viện `path` để ghép đường dẫn file
- Thư viện dự kiến thêm: `file_picker`, `excel`, `fl_chart`, `flutter_local_notifications`, `table_calendar`

## 3. Cấu trúc thư mục

```
quan_ly_lich/
├── lib/                        # Toàn bộ code của ứng dụng
│   ├── main.dart               # Điểm bắt đầu, cài đặt chung (tên app, màu chủ đạo)
│   ├── models/
│   │   └── event.dart          # Lớp Event (id, name, date, organizer) + toMap/fromMap
│   ├── database/
│   │   └── database_helper.dart  # Quản lý SQLite: tạo bảng, thêm/sửa/xóa/đọc, xóa dữ liệu quá 1 năm
│   ├── screens/
│   │   ├── home_screen.dart    # Màn hình chính: danh sách sự kiện
│   │   └── add_event_screen.dart  # Màn hình thêm/sửa sự kiện
│   └── utils/
│       └── format.dart         # Hàm định dạng ngày dd/MM/yyyy
├── pubspec.yaml                # Khai báo thư viện của app
├── android/                    # Phần Android do Flutter tạo (thường không cần sửa)
└── README.md
```

Quy ước: màn hình đặt trong `screens/`, lớp dữ liệu đặt trong `models/`, thao tác dữ liệu đặt trong `database/`, hàm dùng chung đặt trong `utils/`.

## 4. Yêu cầu môi trường (Windows)

1. **Git**: https://git-scm.com
2. **Flutter SDK**: cài qua extension Flutter của VS Code hoặc tải từ https://docs.flutter.dev/get-started/install
3. **Android Studio**: cài với chế độ Standard, sau đó vào **SDK Manager → SDK Tools** và cài:
    - **Android SDK Command-line Tools (latest)**
    - **NDK (Side by side)** đúng phiên bản `28.2.13676358` (tick _Show Package Details_ để chọn đúng phiên bản)
4. **VS Code** với extension **Flutter** (Dart sẽ cài kèm theo)

Kiểm tra môi trường:

```bash
flutter doctor
```

Các mục **Flutter**, **Android toolchain**, **Connected device** phải có dấu `[√]`. Mục _Visual Studio_ báo `[!]` có thể bỏ qua vì dự án chỉ build cho Android.

> Nếu gõ `flutter` báo "not recognized": thêm thư mục `bin` của Flutter vào biến môi trường **Path** (ví dụ `C:\Users\Hi\source\flutter\bin`), sau đó **đóng hẳn** mọi cửa sổ CMD/VS Code/Android Studio rồi mở lại.

## 5. Mở dự án để phát triển

```bash
cd C:\Users\Hi\Documents\quan_ly_lich
code .
```

Lệnh `code .` mở dự án trong VS Code. Lần đầu (hoặc sau khi tải dự án từ Git về) cần lấy thư viện:

```bash
flutter pub get
```

## 6. Chạy ứng dụng

### Cách 1: Máy ảo Android (khuyên dùng)

1. Mở **Android Studio → Tools → Device Manager**, tạo máy ảo (ví dụ Pixel 8) nếu chưa có, bấm **▶ Start** và đợi đến khi thấy màn hình chính Android.
2. Kiểm tra Flutter đã nhận máy ảo:
    ```bash
    flutter devices
    ```
3. Chạy ứng dụng (thay `emulator-5554` bằng mã thiết bị hiện trong danh sách):
    ```bash
    flutter run -d emulator-5554
    ```

### Cách 2: Điện thoại Android thật

1. Bật chế độ nhà phát triển: **Cài đặt → Giới thiệu về thiết bị → Phiên bản → bấm 7 lần vào Số bản dựng**.
2. Bật **Gỡ lỗi USB**: **Cài đặt bổ sung → Tùy chọn nhà phát triển** (menu có thể khác tùy hãng máy).
3. Cắm cáp USB, chọn chế độ **Truyền tệp**, bấm **Cho phép gỡ lỗi USB** trên điện thoại.
4. Kiểm tra thiết bị rồi chạy:
    ```bash
    flutter devices
    flutter run -d <mã-thiết-bị>
    ```

### Cách 3: Chạy thử trên Chrome (chỉ để xem giao diện)

```bash
flutter run -d chrome
```

Lưu ý: SQLite (`sqflite`) không chạy trên web, cách này chỉ phù hợp để xem giao diện khi chưa dùng cơ sở dữ liệu.

### Phím tắt khi app đang chạy (gõ trong terminal)

| Phím | Tác dụng                                             |
| ---- | ---------------------------------------------------- |
| `r`  | Hot reload: nạp lại code đã sửa ngay, giữ trạng thái |
| `R`  | Hot restart: khởi động lại app từ đầu                |
| `q`  | Thoát                                                |

> Sau khi **thêm thư viện mới** hoặc **sửa `pubspec.yaml`**, phải tắt app (`q`) và chạy lại `flutter run`, hot reload không đủ.

## 7. Các lệnh thường dùng

```bash
flutter pub get                  # Tải thư viện theo pubspec.yaml
flutter pub add <tên_thư_viện>   # Thêm thư viện mới (tự ghi vào pubspec.yaml)
flutter devices                  # Liệt kê thiết bị/máy ảo đang kết nối
flutter doctor                   # Kiểm tra môi trường
flutter analyze                  # Kiểm tra lỗi và cảnh báo trong code
flutter clean                    # Xóa file build cũ (dùng khi build lỗi lạ)
flutter build apk --release      # Đóng gói file cài đặt APK
```

File APK sau khi build nằm tại:

```
build\app\outputs\flutter-apk\app-release.apk
```

## 8. Lưu ý quan trọng

- **Dữ liệu lưu ở đâu**: trong file SQLite `lich.db` nằm trong bộ nhớ riêng của app trên thiết bị đang chạy (Android: `/data/data/com.example.quan_ly_lich/databases/lich.db`). Mỗi thiết bị/máy ảo có dữ liệu riêng. **Gỡ app hoặc xóa dữ liệu app sẽ mất toàn bộ sự kiện.**
- **Tự xóa sau 1 năm**: mỗi lần mở màn hình chính, app xóa các sự kiện có ngày tổ chức cũ hơn 365 ngày. Vì vậy thống kê chỉ nhìn được dữ liệu trong khoảng 1 năm gần nhất.
- **Đổi cấu trúc bảng**: nếu thêm hoặc đổi cột trong bảng `events`, phải tăng `version` trong `database_helper.dart` và viết `onUpgrade`, nếu không dữ liệu cũ sẽ không khớp cấu trúc mới (trong lúc phát triển có thể gỡ app khỏi máy ảo để tạo lại database từ đầu).
- **Ngày lưu dưới dạng số**: cột `date` lưu mili giây (`millisecondsSinceEpoch`) để dễ so sánh và lọc theo khoảng thời gian.
- **Cảnh báo `WARNING` màu đỏ khi build** (ví dụ về Gradle, sdkmanager) thường không phải lỗi. Chỉ cần chú ý khi thấy `FAILURE` hoặc `BUILD FAILED`.
- **Lần build đầu tiên** mất vài phút vì phải tải Gradle và thư viện; các lần sau nhanh hơn.
- **Thông báo nhắc 6:00 sáng** (tính năng dự kiến): trên một số hãng máy (realme, Oppo, Xiaomi...) hệ thống có thể chặn app chạy nền nên thông báo không kêu; cần tắt tối ưu pin cho app và cấp quyền thông báo, báo thức chính xác. Nên kiểm tra trên điện thoại thật.
- **iOS**: chỉ build được trên máy Mac. Dự án hiện tập trung vào Android.
- **Không sửa tay** các thư mục `build/` và `.dart_tool/`; chúng được tạo tự động và không đưa lên Git.

## 9. Xử lý sự cố thường gặp

flutter
| Lỗi | Cách xử lý |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `'flutter' is not recognized` | Thêm thư mục `bin` của Flutter vào Path, đóng hẳn rồi mở lại CMD/VS Code |
| `cmdline-tools component is missing` | Cài **Android SDK Command-line Tools** trong SDK Manager |
| `Android sdkmanager did not install NDK ...` | Cài NDK đúng phiên bản (`28.2.13676358`) bằng Android Studio → SDK Manager → SDK Tools |
| `flutter devices` không thấy điện thoại | Chọn chế độ USB **Truyền tệp**, bật Gỡ lỗi USB, chạy `adb kill-server` rồi `adb devices`, bấm **Cho phép** trên điện thoại |
| Không thấy máy ảo | Mở máy ảo trong Device Manager trước, đợi vào màn hình chính rồi chạy lại `flutter devices` |
| Build lỗi khó hiểu sau khi đổi thư viện | `flutter clean` rồi `flutter pub get` rồi `flutter run` |
| Lỗi `adb` | `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb kill-server` rồi `adb devices` |

## 10. Làm việc với Git và GitHub

Repo: https://github.com/haidu349/app_quan_ly_lich_mobile

### 10.1. Cài đặt Git lần đầu trên một máy

```bash
git config --global user.name "Tên của bạn"
git config --global user.email "email-đăng-ký-github@example.com"
git config --global --list        # kiểm tra lại
```

### 10.2. Đưa dự án mới lên GitHub lần đầu (đã làm một lần)

1. Tạo repo trống trên GitHub (không tick README/.gitignore/license).
2. Trong thư mục dự án:

```bash
git init
git add .
git commit -m "Khởi tạo dự án"
git branch -M main
git remote add origin https://github.com/haidu349/app_quan_ly_lich_mobile.git
git push -u origin main
```

Lần push đầu sẽ mở trình duyệt để đăng nhập GitHub. Không dùng mật khẩu tài khoản trong terminal.

### 10.3. Lấy dự án về máy mới (clone)

Cài đủ môi trường ở **mục 4** trước (Git, Flutter, Android Studio, NDK), sau đó:

```bash
cd C:\Users\<tên-người-dùng>\Documents
git clone https://github.com/haidu349/app_quan_ly_lich_mobile.git
cd app_quan_ly_lich_mobile
flutter pub get
code .
```

- `git clone` tạo thư mục mới tên `app_quan_ly_lich_mobile` chứa toàn bộ mã nguồn và lịch sử commit.
- `flutter pub get` bắt buộc chạy sau khi clone, vì thư mục thư viện không được đưa lên Git.
- Nếu repo ở chế độ **Private**, đăng nhập đúng tài khoản `haidu349` khi trình duyệt hiện cửa sổ xác thực.
- Sau đó mở máy ảo (hoặc cắm điện thoại), chạy `flutter devices` và `flutter run -d <mã-thiết-bị>` như **mục 6**.

> Dữ liệu sự kiện trong SQLite **không** nằm trong Git, nên máy mới sẽ bắt đầu với danh sách trống.

### 10.4. Cập nhật code từ GitHub về máy đã có dự án (pull)

Dùng khi bạn đã sửa code ở máy khác rồi push lên, hoặc khi muốn đồng bộ lại:

```bash
cd đường-dẫn-tới-dự-án
git status                # xem có thay đổi chưa commit không
git pull                  # kéo code mới nhất về nhánh hiện tại
flutter pub get           # nếu pubspec.yaml có thay đổi
```

- Nếu `git status` báo có thay đổi chưa commit, hãy **commit hoặc cất tạm (`git stash`)** trước khi `git pull`, tránh xung đột.
- Nếu `git pull` báo xung đột (conflict), mở các file bị đánh dấu `<<<<<<<`, chọn đoạn cần giữ, lưu lại rồi `git add .` và `git commit`.

### 10.5. Quy trình hằng ngày

```bash
git status                          # xem file nào đã thay đổi
git add .                           # đưa tất cả thay đổi vào vùng chuẩn bị
git commit -m "Mô tả ngắn thay đổi"  # lưu một bản ghi
git push                            # đẩy lên GitHub
```

Trước khi bắt đầu làm việc ở máy đã có dự án: `git pull` để lấy bản mới nhất.

Quy tắc commit:

- Commit sau mỗi tính năng nhỏ chạy được (thêm, sửa, xóa, import...).
- Viết thông điệp commit ngắn, rõ: "Thêm giờ bắt đầu cho sự kiện", "Sửa lỗi xóa sự kiện".
- Chỉ commit khi app còn chạy được, để luôn có một bản đáng tin cậy để quay lại.

### 10.6. Làm việc với nhánh (branch)

Tạo nhánh riêng cho mỗi tính năng lớn để nhánh `main` luôn ổn định:

```bash
git checkout -b them-gio-su-kien     # tạo và chuyển sang nhánh mới
# ... code, commit nhiều lần ...
git push -u origin them-gio-su-kien   # đẩy nhánh lên GitHub (lần đầu)
git checkout main                     # quay về nhánh chính
git pull                              # cập nhật main
git merge them-gio-su-kien            # gộp tính năng vào main
git push                              # đẩy main lên GitHub
git branch -d them-gio-su-kien        # xóa nhánh đã gộp (tùy chọn)
```

Các lệnh liên quan:

```bash
git branch                 # xem danh sách nhánh, dấu * là nhánh hiện tại
git checkout <tên-nhánh>   # chuyển sang nhánh khác
git log --oneline          # xem lịch sử commit gọn
```

### 10.7. Hoàn tác khi gặp sự cố

| Tình huống                                               | Lệnh                                       |
| -------------------------------------------------------- | ------------------------------------------ |
| Bỏ thay đổi chưa commit của **một file**                 | `git restore <đường-dẫn-file>`             |
| Bỏ **toàn bộ** thay đổi chưa commit (không lấy lại được) | `git restore .`                            |
| Bỏ file khỏi vùng chuẩn bị (đã `git add` nhầm)           | `git restore --staged <file>`              |
| Sửa thông điệp commit **vừa tạo, chưa push**             | `git commit --amend -m "Thông điệp mới"`   |
| Cất tạm thay đổi để chuyển nhánh                         | `git stash` rồi `git stash pop` để lấy lại |
| Xem lại một thay đổi trước khi commit                    | `git diff`                                 |

Lưu ý: tránh dùng `git push --force` và `git reset --hard` khi chưa hiểu rõ, vì chúng có thể xóa mất công việc không lấy lại được.

### 10.8. Những thứ không đưa lên Git

- Flutter đã tạo sẵn `.gitignore`, tự bỏ qua `build/`, `.dart_tool/` và các file sinh tự động. Không cần tự thêm.
- **Không commit** thông tin nhạy cảm (mật khẩu, khóa API, file keystore ký APK).
- Nếu lỡ tạo file rác trong thư mục dự án (ví dụ file `run`, `.flutter` do gõ nhầm lệnh), hãy xóa trước khi `git add .`.
- File APK thành phẩm nên đính kèm ở mục **Releases** trên GitHub thay vì commit vào repo.

### 10.9. Lỗi thường gặp với Git

| Lỗi                                             | Cách xử lý                                                                                                                         |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `Repository not found`                          | Sai địa chỉ repo hoặc đăng nhập nhầm tài khoản. Kiểm tra bằng `git remote -v`, sửa bằng `git remote set-url origin <địa-chỉ-đúng>` |
| `remote origin already exists`                  | Dùng `git remote set-url origin <địa-chỉ>` thay cho `git remote add`                                                               |
| `rejected ... fetch first` / `non-fast-forward` | Trên GitHub có commit mà máy chưa có. Chạy `git pull` rồi `git push` lại                                                           |
| `Please tell me who you are`                    | Chưa cấu hình tên/email, làm lại mục 10.1                                                                                          |
| Cảnh báo `LF will be replaced by CRLF`          | Chuyện xuống dòng trên Windows, bỏ qua được                                                                                        |
| `Authentication failed`                         | Đăng nhập lại GitHub qua trình duyệt khi Git yêu cầu, không nhập mật khẩu tài khoản vào terminal                                   |

## 11. Thông tin

- Môn học: Lập trình trên thiết bị di động
- Đề tài: Quản lý công việc theo lịch biểu cá nhân
- Sản phẩm bàn giao: file cài đặt (APK) và mã nguồn
