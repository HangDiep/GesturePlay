# GesturePlay — DEAD SIGNAL Flutter 2D

Ứng dụng chính dùng **Flutter/Dart**, có nhân vật đi lại trong **4 bản đồ 2D khác nhau**: rừng thông, thị trấn bỏ hoang, bến cảng và nhà máy. Python chỉ nhận diện bàn tay. Các lệnh mặc định không yêu cầu Godot.

```powershell
cd D:\GesturePlay
npm run web
```

Mở http://127.0.0.1:8080. Dừng bản cũ bằng Ctrl+C trước khi chạy, Ctrl+F5 nếu trình duyệt còn hiển thị bản trước. Giữ terminal mở. Để chạy cửa sổ Windows, dùng `npm run windows` hoặc nhấp đúp `Chay_GesturePlay.bat`.

Luật, điều khiển, nhận diện tay, bản Android và kiểm tra: **[DEAD_SIGNAL.md](DEAD_SIGNAL.md)**.

## Chuẩn bị môi trường Windows

Cần Node.js 20+, Flutter SDK và Python 3.10 64-bit. Chạy web cần trình duyệt hỗ trợ Flutter Web. Chạy Windows cần Visual Studio/Build Tools với workload Desktop development with C++, MSVC, CMake và Windows SDK.

```powershell
flutter doctor -v
flutter devices
```

Nếu chưa có môi trường Python:

```powershell
cd D:\GesturePlay
py -3.10 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe download_model.py
.\.venv\Scripts\python.exe -m pip check
cd flutter_app
flutter pub get
```

Nếu `.venv` đã có thì dùng môi trường hiện tại. Python chỉ mở webcam/model khi bật bàn tay. Web dùng dịch vụ nội bộ cổng 8766; bản Windows tự mở dịch vụ khi cần. Không cần `npm install` vì launcher không dùng thư viện npm bên ngoài.

## Dựng và kiểm tra

```powershell
cd D:\GesturePlay\flutter_app
flutter analyze
flutter test --reporter expanded
flutter build web --no-web-resources-cdn --dart-define=HAND_SERVICE_URL=ws://127.0.0.1:8766
flutter build windows --release
flutter build apk --debug
```

Trên máy này, launcher chuẩn bị junction trong thư mục build để nạp plugin Windows mà không đổi cài đặt hệ điều hành. Bản Windows cần giữ DLL và thư mục data bên cạnh file chạy; nhận diện tay vẫn cần Python/model trong cây dự án.

Tài khoản, database và lịch sử lượt chơi chưa triển khai theo yêu cầu hiện tại. Cài đặt âm thanh/webcam được lưu trên thiết bị.

## Cấu trúc

- `flutter_app/lib/exploration/`: trò chơi Flutter 2D hiện tại.
- `flutter_app/lib/services/hand_bridge.dart`: kết nối tay, preview và dữ liệu hết hạn.
- `core/`, `hand_service/server.py`: webcam, MediaPipe và cử chỉ Python.
- [GesturePlay_Flutter_Python_Kien_truc.md](GesturePlay_Flutter_Python_Kien_truc.md): kiến trúc hiện tại.
- `flutter_app/lib/dead_signal/`, `flutter_app/lib/game/`: phần chơi trước đây, giữ để tham khảo và kiểm tra hồi quy.
- `godot_game/`, `GAME_3D.md`: bản thử 3D cũ, không thuộc luồng chạy mặc định.
- `docs/LEGACY_README.md`, `docs/DEAD_SIGNAL_CAMERA.md`, `docs/LEGACY_ARCHITECTURE.md`: tài liệu lịch sử, không dùng làm hướng dẫn mở bản chính.
