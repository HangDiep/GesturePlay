# GesturePlay — DEAD SIGNAL Flutter 2D

Ứng dụng chính dùng **Flutter/Dart**, tập trung vào **một map Thị trấn bị phong tỏa** theo `Thiet_ke_hoan_thien_GesturePlay123.docx` và yêu cầu thu gọn mới nhất. Nhân vật áo tối, khăn đỏ đi lại trên phố cổ có nhà, xe tải, đèn lồng, cây, mưa và sương. Hình nhân vật/quái là atlas PNG có hoạt ảnh. Python nhận diện bàn tay.

Bộ cảnh mới dùng **góc nhìn chéo 2D**, ba mẫu nhà phố, quầy chợ, miếu và vườn cây; mặt đá nhỏ, vũng nước xanh và ánh đèn vàng. Mái/cây giảm đậm khi che người chơi. Chuột, cảm ứng và bàn tay đều đổi hướng theo camera mới. Xem [chi tiết đồ họa](docs/GRAPHICS_V2.md).

```powershell
cd D:\GesturePlay
npm run web
```

Mở http://127.0.0.1:8080. Dừng bản cũ bằng Ctrl+C trước khi chạy, Ctrl+F5 nếu trình duyệt còn hiển thị bản trước. Giữ terminal mở. Để chạy cửa sổ Windows, dùng `npm run windows` hoặc nhấp đúp `Chay_GesturePlay.bat`.

**Giao diện ứng dụng mới:** bắt đầu ở màn đăng nhập/đăng ký. Chọn **TRẢI NGHIỆM GIAO DIỆN** để vào game khi chưa có database. Trang chính có Hồ sơ, Lịch sử, Kết nối tay và Thực hành 11 bài; có độ khó Dễ/Thường. Xem [phạm vi và cách dùng](docs/APP_PORTAL_UI.md). Hồ sơ và kết quả thử chỉ giữ trong phiên; đăng nhập online sẽ được ghép sau khi có URL/key.

**Kết quả & lịch sử cá nhân:** xem chi tiết từng lượt, tài nguyên cuối lượt và thống kê theo Dễ/Thường. Đã chuẩn bị trạng thái lưu, hàng chờ theo tài khoản và gửi lại bằng cùng mã lượt để tránh trùng; lưu online chờ cấu hình dịch vụ thật. Xem [chi tiết mục 3.11](docs/RESULTS_HISTORY.md).

**Luật và điều khiển bản một map: [SINGLE_MAP.md](SINGLE_MAP.md).** Sống đủ 180 giây để thắng; ba lõi tín hiệu là mục tiêu phụ. Quái và người chơi đều có thể giết nhau. Chết có hoạt ảnh, nguyên nhân và nút chơi lại map, khôi phục tài nguyên đầu lượt.

**Quái có ma lực tầm xa, người chơi chỉ dùng súng.** Kẻ gây nhiễu phóng cầu xanh; boss tung ba cầu tím rồi hở giáp. Có tụ phép, đường nhắm và tiếng báo trước; né ngang hoặc dùng vật chắn. Bắn trúng quái gây nhiễu lúc nó tụ phép sẽ ngắt đòn. Đã bỏ đèn chớp/bẫy điện khỏi bản chính. Vòng bàn tay dùng nạp đạn / ẩn / lướt né. Xem [luật ma lực](docs/COMBAT_MAGIC.md).

**Trang bị và tương tác:** nhặt lục/trường/shotgun, **1/2/3** chọn hoặc **V** đổi súng, mỗi khẩu giữ đạn riêng. **I** mở túi, **H** băng bó 2,8 giây hồi 40 HP (tối đa ba túi máu). **E** đóng/mở cửa, lấy đồ; tìm chìa ở phố cổ để mở kho. Có phòng trú và cửa 120 độ bền bị quái phá được. Boss còn nửa máu chuyển giai đoạn hai, kết hợp cầu ma lực với hai vùng nổ báo trước. Vòng bàn tay có thêm hàng băng bó / đổi súng / tương tác. Xem [luật trang bị và boss](docs/SURVIVAL_SYSTEMS.md).

**Hai tay / Webcam:** tay trái đi, tay phải ngắm/bắn đồng thời. Có cử chỉ trực tiếp đổi tư thế, đổi súng, nạp đạn, băng bó, ẩn và mở cửa; bảng 12 thao tác cũng chọn bằng tay. Mất một tay tự dừng, có thể tiếp tục/chơi lại bằng chụm thả. Xem [hướng dẫn hai tay](docs/TWO_HAND_CONTROLS.md). Sau khi cập nhật cần khởi động lại `npm run web` để Python nạp nhận diện hai tay.

Map hiện rộng **4.400 × 3.600, gấp bốn diện tích cũ**, vẫn là một thị trấn liền mạch. **G** để ẩn nấp gần vòng xanh; **M** xem toàn khu vực. Có viền đỏ/nhịp tim khi ít máu, tiếng hú khi quái tới gần, quái tìm kiếm theo dấu và tiếng động, cùng các đợt mất điện. Các khu chợ đêm, sân đền và vườn hoang đi tới được ngay trong map này.

**X** chuyển ngồi/đứng, **Z** chuyển nằm/đứng; có ba nút tư thế cho cảm ứng và một hàng tư thế trong vòng kỹ năng bàn tay. Cả ba tư thế đều bắn và thay đạn được. Ngồi tận dụng vật chắn thấp, nằm bò chậm và kín hơn trong bụi; từ nằm phải đứng dậy trước khi lướt. Hình ngồi/nằm dùng atlas riêng, xem chi tiết tại [SINGLE_MAP.md](SINGLE_MAP.md).

Bản thiết kế nguồn: [Thiet_ke_hoan_thien_GesturePlay123.docx](Thiet_ke_hoan_thien_GesturePlay123.docx). Bản chơi hiện tại áp dụng màn phố cùng các luật chiến đấu, chết, kỹ năng và đồ họa. Chiến dịch bốn màn và đi cảnh ngang trong tài liệu được thu gọn theo yêu cầu chỉ chơi một map.

## Chuẩn bị môi trường Windows

Chạy Android giả lập bằng một lệnh tại thư mục dự án:

```powershell
cd D:\GesturePlay
npm run android
```

Lệnh tự tìm SDK/Flutter, mở Pixel_10_Pro_XL (hoặc giả lập duy nhất), chờ Android khởi động rồi chạy game bằng mã thiết bị thực tế. Giữ cửa sổ giả lập mở khi chơi. Nếu đã có giả lập đang online, lệnh dùng luôn thiết bị đó. Có thể chọn AVD bằng `npm run android -- --avd Ten_gia_lap`. Cần cài Android SDK, Emulator và tạo AVD trong Android Studio trước. Nhận diện tay vẫn cần Python trên laptop như [hướng dẫn Android](docs/DEAD_SIGNAL_CAMERA.md).

Bộ khởi chạy bỏ qua snapshot cũ và không gửi báo lỗi của giả lập, tránh hộp thoại báo crash cũ chặn khởi động. Nếu gặp lỗi GPU, thử `npm run android -- --gpu swiftshader` để dùng đồ họa phần mềm và tắt Vulkan; có thể chậm hơn GPU phần cứng. Các tùy chọn chỉ áp dụng cho giả lập do lệnh mở, không thay thiết lập điện thoại thật. Nhật ký mở giả lập nằm trong `.cache/android-launch*.log`.

Nếu Android chỉ hiện ở thanh tác vụ hoặc cửa sổ bị khuất, đóng giả lập rồi chạy `npm run android -- --reset-window`. Tùy chọn này đưa cửa sổ về vị trí nhỏ ở góc màn hình, có bản sao thiết lập cũ trong `.cache`, giữ nguyên ứng dụng và dữ liệu Android. Khi gặp hộp **Compatibility Warnings** về RAM, có thể chọn **Never show warnings for avd… again** rồi **OK** để cảnh báo không che cửa sổ ở lần mở sau.

Máy ảo Pixel trên máy phát triển đã được giảm xuống 720 × 1600, 256 DPI để giảm tải đồ họa. Cách tự chỉnh, kiểm tra và khôi phục cấu hình gốc nằm trong [hướng dẫn Android 720p](docs/ANDROID_720P.md).

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

Giao diện tài khoản đã có; dịch vụ đăng nhập và database chưa kết nối theo yêu cầu làm giao diện trước. Lịch sử trải nghiệm chỉ giữ trong phiên hiện tại. Cài đặt âm thanh/webcam, độ nhạy và độ khó được lưu trên thiết bị.

## Cấu trúc

- `flutter_app/lib/survival/`: trang chủ, giao diện, atlas, bộ vẽ và điều khiển tay cho map chính.
- `flutter_app/assets/town/`: nền và atlas nhân vật, quái, đồ vật tạo mới bằng image_gen; giữ alpha gốc. Yêu cầu tạo hình: `docs/design_assets/town_asset_prompts.txt`.
- `flutter_app/lib/exploration/`: luật chiến đấu và tìm đường dùng chung; các bản đồ thử trước đây không nằm trên trang chủ mới.
- `flutter_app/lib/services/hand_bridge.dart`: kết nối tay, preview và dữ liệu hết hạn.
- `core/`, `hand_service/server.py`: webcam, MediaPipe và cử chỉ Python.
- [GesturePlay_Flutter_Python_Kien_truc.md](GesturePlay_Flutter_Python_Kien_truc.md): kiến trúc hiện tại.
- `flutter_app/lib/dead_signal/`, `flutter_app/lib/game/`: phần chơi trước đây, giữ để tham khảo và kiểm tra hồi quy.
- `godot_game/`, `GAME_3D.md`: bản thử 3D cũ, không thuộc luồng chạy mặc định.
- `docs/LEGACY_README.md`, `docs/DEAD_SIGNAL_CAMERA.md`, `docs/LEGACY_ARCHITECTURE.md`: tài liệu lịch sử, không dùng làm hướng dẫn mở bản chính.
