# GesturePlay — Flutter + Flame, Python nhận diện tay

Bản ứng dụng chính hiện chạy trên **Windows bằng Flutter + Flame**. Python chỉ mở webcam, nhận diện bàn tay và gửi trạng thái/lệnh điều khiển sang Flutter. Mọi giao diện, nhân vật, chuyển động, va chạm, thời gian, điểm và lưu kết quả đều viết bằng **Dart**.

Game đầu tiên: **Sky Runner — Chạy vượt chướng ngại vật**. Ba độ khó, tránh gai, thu xu, tạm dừng, chơi lại, hiệu chỉnh tay và kết quả local. Chưa triển khai đăng nhập, database tài khoản hay bảng xếp hạng online.

## Chạy ứng dụng Flutter Windows

Đóng bản Pygame thử nghiệm đang mở trước khi chuyển sang bản Flutter. Nhấp đúp **Chay_GesturePlay.bat**, hoặc chạy:

```powershell
cd D:\GesturePlay\flutter_app
flutter run -d windows
```

Flutter tự tìm thư mục dự án và tự mở Python khi bạn chọn **Chơi bằng bàn tay**. Không cần mở riêng cửa sổ Python. Tại menu và chế độ bàn phím, webcam/model chưa được mở.

Để Enter ở menu mặc định chọn bàn phím, dùng **Chay_Bang_Ban_Phim.bat** hoặc:

```powershell
flutter run -d windows --dart-define=DEFAULT_KEYBOARD=true
```

Bạn cũng có thể bấm **Luyện bằng bàn phím** trong menu thông thường. Chế độ này chạy hoàn toàn trong Flutter/Flame, không cần Python hoặc webcam.

**Lưu ý lệnh đã đổi:** `python main.py` hiện chỉ chạy dịch vụ nhận diện, không mở cửa sổ trò chơi. Dùng `flutter run -d windows` để mở ứng dụng chính.

## Điều khiển và luật

- Robot tự chạy; chỉ nhảy khi chạm đất, không nhảy lần hai ở trên không.
- **Bàn tay:** mở ngón cái–trỏ rồi chụm lại để nhảy. Giữ chụm chỉ tính một lệnh; phải thả trước lần sau.
- **Bàn phím:** Space hoặc ↑ để nhảy.
- Vượt một cụm gai: +10 điểm. Thu một xu: +20 điểm. Mỗi vật chỉ tính một lần.
- Va gai kết thúc ván (`lost`); sống đủ 120 giây chơi thực kết thúc (`time_up`).
- P / Esc khi đang chơi: tạm dừng. P / Enter tại màn pause: yêu cầu tiếp tục.
- R khi chơi/pause/kết thúc: tạo ván local mới, reset toàn bộ trạng thái và trở lại chuẩn bị.
- V: bật/tắt preview nhỏ khi chơi bằng tay. F3: FPS game, camera, AI, tuổi dữ liệu và ngưỡng chụm.
- Esc ở chuẩn bị/đếm ngược/pause/kết quả: về menu. Esc ở menu hoặc X của cửa sổ: thoát.

Mất tay, mất kết nối nhận diện hoặc dữ liệu quá 250 ms sẽ tạm dừng ngay. Có tay lại cần mở hai ngón, giữ ổn định rồi bấm **Tiếp tục**. Đếm ngược, tạm dừng và thời gian chờ không cộng vào 120 giây chơi. Rời cửa sổ cũng tạm dừng.

## Hiệu chỉnh nếu chụm chưa nhảy

Tại **Chơi bằng bàn tay → Sẵn sàng xuất phát**:

1. Đưa lòng bàn tay rõ vào camera. Hai dấu chấm đánh dấu đầu ngón cái và trỏ.
2. Mở hai ngón, giữ khoảng nửa giây rồi nhấn **F1** hoặc **1. Ghi tay mở**.
3. Chụm hai đầu ngón, giữ khoảng nửa giây rồi nhấn **F2** hoặc **2. Ghi tay chụm**.
4. Khi báo đã hiệu chỉnh, thả rồi chụm thử; trạng thái phải chuyển thành **Đã nhận chụm**.
5. Thả hai ngón để nút **Bắt đầu** được bật; game đếm ngược ba giây.

Hiệu chỉnh dùng các mẫu gần nhất, từ chối hai tư thế quá giống nhau hoặc còn dao động. Có hai ngưỡng riêng cho chụm/thả để hạn chế rung trạng thái. Hiệu chỉnh được giữ trong RAM của dịch vụ nhận diện; nút **Mặc định** khôi phục ngưỡng ban đầu. Đổi camera cần hiệu chỉnh lại.

Nút **Camera 0 · DSHOW / Đổi** cho phép chọn camera 0–3 và DSHOW/MSMF/AUTO ngay trong Flutter. Ứng dụng đợi camera cũ đóng rồi mới đổi cấu hình. Nếu gặp lỗi, dùng **Thử lại nhận diện** hoặc **Dùng bàn phím**.

## Cách Flutter và Python kết nối

- WebSocket tại `ws://127.0.0.1:8765`, chỉ trên cùng laptop, không mở ra mạng LAN.
- Một client điều khiển, một camera và một HandLandmarker.
- Trạng thái tay tối đa 20 packet/giây; preview JPEG 320 × 240 tối đa 8 FPS khi được yêu cầu.
- Python dùng `jump_id` tăng dần để giữ lệnh chụm qua các lần gửi. Flutter nhận mỗi ID một lần, bỏ lệnh quá cũ hoặc lệnh phát trong thời gian chuẩn bị/đếm ngược/pause.
- MediaPipe và tính tuổi ảnh dùng đồng hồ monotonic. Flutter cộng thời gian nhận/vận chuyển trên cùng máy khi kiểm tra hết hạn.
- Không gửi nhân vật, vật lý, điểm hoặc game state sang Python. Không lưu ảnh webcam lên đĩa.
- Về menu/kết thúc ván gửi stop để đóng camera/model ngoài vòng vẽ. Kết nối nhẹ được giữ để bảo lưu hiệu chỉnh.
- Nếu cửa sổ Flutter bị đóng, socket mất và Python tự đóng tài nguyên/thoát khi idle. Không dựa vào một tiến trình Pygame để chạy game.

Để chạy nhận diện thủ công khi cần kiểm tra:

```powershell
cd D:\GesturePlay
.\.venv\Scripts\python.exe main.py --port 8765 --idle-timeout 0
```

Giữ cửa sổ đó rồi chạy Flutter ở cửa sổ khác. Ctrl+C dừng dịch vụ. Mặc định camera chỉ được mở khi Flutter gửi yêu cầu bắt đầu. Ảnh AI vẫn chỉ giữ khung mới nhất, metadata có giới hạn 64 mục; không có hàng đợi ảnh vô hạn.

## Môi trường Windows

Cần Flutter SDK trong PATH và bộ công cụ C++ của Visual Studio/Build Tools: workload **Desktop development with C++**, MSVC, CMake và Windows SDK. Kiểm tra:

```powershell
flutter doctor -v
flutter devices
```

Thiết bị `windows` phải có trong danh sách. Các lỗi Android SDK không ảnh hưởng bản Windows này. SDK hiện có trên máy là Flutter 3.47.0, Dart 3.13.0; Flame khóa tại 1.38.2 trong `flutter_app/pubspec.lock`.

Python 3.10 64-bit, thư viện và model:

```powershell
cd D:\GesturePlay
py -3.10 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe download_model.py
.\.venv\Scripts\python.exe -m pip check
cd flutter_app
flutter pub get
flutter run -d windows
```

Nếu `.venv` đã có, dùng môi trường hiện tại. `requirements.txt` trỏ đến `requirements-hand-lock.txt`, không yêu cầu Pygame. `requirements-hand.txt` liệt kê các phụ thuộc trực tiếp. Không cài thêm các biến thể OpenCV khác vào cùng môi trường.

Dựng bản Windows để chạy trong thư mục dự án:

```powershell
cd D:\GesturePlay\flutter_app
flutter build windows --release
```

Thư mục Release cần được giữ trong cây dự án hoặc cung cấp `--dart-define=GESTUREPLAY_ROOT=D:\GesturePlay` khi build để Flutter tìm Python/model. Hiện chưa đóng gói Python thành bộ cài độc lập.

## Thành tích local

Flutter ghi bất đồng bộ vào `flutter_app/data/runner_results.json`. Tối đa 100 bản ghi và bảo lưu kỷ lục theo độ khó/kiểu điều khiển, chống lưu trùng theo UUID local. Lỗi lưu có nút thử lại. Dữ liệu chứa kết quả game, không chứa ảnh, token hoặc mật khẩu.

Đây chưa phải database tài khoản hay kết quả được server xác nhận. Tính điểm local không phải cơ chế chống gian lận cho xếp hạng online. Thành tích thử nghiệm từ bản Pygame cũ vẫn nằm riêng trong `client/data/`; không trộn vào kết quả Flutter.

## Mã nguồn chính

| Đường dẫn | Vai trò |
|---|---|
| `flutter_app/lib/ui/runner_app.dart` | Tất cả màn hình Flutter, menu, HUD, camera, hiệu chỉnh |
| `flutter_app/lib/game/runner_game.dart` | FlameGame và thành phần vẽ cảnh/robot/gai/xu |
| `flutter_app/lib/game/runner_model.dart` | Vật lý, va chạm tam giác, sinh vật, điểm và báo cáo bằng Dart |
| `flutter_app/lib/game/runner_controller.dart` | Chuyển cảnh, đếm ngược, pause, điều khiển và kết thúc ván |
| `flutter_app/lib/services/hand_bridge.dart` | WebSocket, tự chạy Python khi cần, hết hạn và giữ lệnh một lần |
| `flutter_app/lib/services/local_scores.dart` | Lưu kết quả/kỷ lục bằng Dart |
| `main.py`, `hand_service/server.py` | Điểm chạy và giao thức nhận diện Python |
| `core/camera.py`, `hand_tracker.py`, `gestures.py`, `runtime.py` | Webcam, MediaPipe và cử chỉ, không có luật game |
| `models/hand_landmarker.task` | Mô hình local |
| `legacy_pygame_main.py`, `client/`, `ui/` | Bản thử cũ giữ làm tham khảo, không chạy từ launcher chính |

Chi tiết kiến trúc đã chốt: `GesturePlay_Flutter_Python_Kien_truc.md`. Tài liệu backend cũ có ghi chú cập nhật để tránh nhầm lại công nghệ.

## Kiểm tra

```powershell
cd D:\GesturePlay\flutter_app
flutter analyze
flutter test --reporter expanded
cd ..
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Kiểm tra Dart gồm luật/va chạm, vượt đủ 120 giây mô phỏng ở ba độ khó, không tăng số vật vô hạn, một lệnh/một nhảy, mất tay phải xác nhận tiếp tục, lưu kết quả và thao tác Flutter. Có kiểm tra Flutter kết nối dịch vụ Python thật bằng WebSocket mà không mở webcam. Kiểm tra Python gồm giao thức, độc quyền client, cử chỉ và vòng đời nhận diện.

Đã xác nhận trên máy Windows ngày 16/10/2026: `flutter analyze` không có lỗi, **16 kiểm tra Flutter** và **64 kiểm tra Python** đều đạt. Trong 64 kiểm tra Python có các kiểm tra hồi quy của bản thử cũ; 16 kiểm tra Flutter xác minh ứng dụng mới. Kiểm tra kết nối bao gồm việc đóng một kết nối đến trễ để không chiếm dịch vụ nhận diện.

`flutter build windows --release` đã thành công. File chạy: `flutter_app/build/windows/x64/runner/Release/gestureplay.exe`; giữ nguyên các DLL và thư mục `data` đi kèm trong Release. Máy hiện có Visual Studio Build Tools 2022 ổn định cùng MSVC/CMake/Windows SDK để biên dịch Windows.

Mô phỏng và headless không thay thế thử tay thật, camera thật và đo liên tục 5 phút. FPS vẽ cao không bảo đảm nhận diện tay ít trễ; cần xem cả FPS camera/AI và tuổi dữ liệu bằng F3.
