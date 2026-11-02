# DEAD SIGNAL — bản Flutter phòng trực

Trò chơi mặc định đã chuyển sang nhân vật di chuyển trong bốn bản đồ 3D theo yêu cầu mới. Xem [GAME_3D.md](GAME_3D.md). Tài liệu dưới đây chỉ mô tả bản Flutter cũ; mở bằng `npm run web:classic` hoặc `npm run windows:classic`.

Ứng dụng Flutter chính đã chuyển từ Sky Runner sang trò chơi sinh tồn phòng thủ trong bản thuyết minh. Bản này tập trung vào phần chơi và nhận diện tay. Theo yêu cầu hiện tại, chưa triển khai tài khoản, database hoặc lịch sử lượt chơi. Kết quả chỉ được hiển thị khi ván kết thúc; âm lượng, webcam và độ nhạy được lưu trên thiết bị.

## Chạy trên trình duyệt

Tại thư mục dự án:

```powershell
npm run web:classic
```

Mở http://127.0.0.1:8080 nếu trình duyệt chưa tự mở. Python nhận diện chạy ở nền, chỉ mở webcam khi chọn bàn tay. Giữ terminal chạy và nhấn Ctrl+C khi cần dừng cả web lẫn dịch vụ nhận diện. `npm run web:classic -- --clear` làm sạch bộ nhớ đệm biên dịch; không xóa cài đặt.

## Chạy bản Windows

```powershell
npm run windows:classic
```

Bản đã biên dịch nằm tại `flutter_app/build/windows/x64/runner/Release/gestureplay.exe`. Giữ các DLL và thư mục `data` đi kèm, đồng thời giữ vị trí trong cây dự án để ứng dụng tìm thấy Python và model khi dùng bàn tay.

Các launcher tạo directory junction bên trong thư mục build của Flutter để nạp plugin Windows. Không cần thay đổi chế độ nhà phát triển của hệ điều hành.

## Chạy trên Android giả lập

Mở Python tại laptop trước:

```powershell
.\.venv\Scripts\python.exe main.py --port 8765 --idle-timeout 0
```

Sau đó mở giả lập Android và chạy:

```powershell
cd flutter_app
flutter run -d <ma-gia-lap>
```

Dùng `flutter devices` để xem mã giả lập. Flutter trên Android mặc định kết nối `ws://10.0.2.2:8765`, tức dịch vụ trên laptop của Android Emulator. Android không tự chạy Python. Đã thêm quyền Internet, chế độ ngang và cấu hình kết nối nội bộ cho giả lập. Không hỗ trợ chạy bộ nhận diện trực tiếp trên điện thoại hoặc tự kết nối điện thoại qua LAN.

File cài bản thử là `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`. Bản web, Windows và Android đều dùng cùng logic Dart. Bố cục tự đổi giữa màn hình máy tính và màn hình nhỏ.

## Nhiệm vụ và luật chơi

- Giữ phòng trực an toàn trong 180 giây chơi thực. Thời gian chuẩn bị và tạm dừng không tính vào thời gian sinh tồn.
- Chuyển giữa camera trung tâm, hành lang trái và hành lang phải. Camera là cảnh 2D mô phỏng; webcam thật chỉ nhận diện bàn tay.
- Cảm biến cho biết khu vực có chuyển động. Sơ đồ không hiển thị vị trí chính xác của từng sinh vật.
- Chế độ dễ: 130 điện, 7 đợt gồm 12 sinh vật và tốc độ di chuyển chậm hơn. Chế độ thường: 100 điện, 7 đợt gồm 15 sinh vật, nhiều đợt tấn công phối hợp từ hai hướng.
- Mặc định bật **Đầy đủ loại quái**, gồm Kẻ săn đuổi, Kẻ phá cửa, Kẻ gây nhiễu và Vật chủ. Tắt tùy chọn này để luyện với hai loại cơ bản. Vật chủ xuất hiện ở giây 125 của mức dễ và giây 118 của mức thường.
- Camera đang xem tiêu hao điện; cửa khóa tiêu hao liên tục. Ngắt điện cửa sẽ mở khóa. Hết điện khiến camera, súng và khóa điện ngừng hoạt động, nhưng chưa lập tức kết thúc ván.
- Cửa có độ bền. Quái phá cửa gây sát thương cao hơn. Khi cửa vỡ, không thể khóa hoặc gia cố lại trong ván đó.
- Thua khi sinh vật ở cửa không được ngăn chặn và xâm nhập phòng trực. Rời lượt giữa chừng không tính là thắng.

| Loại quái | Máu | Di chuyển | Sát thương cửa mỗi đòn | Cách đối phó |
| --- | ---: | --- | ---: | --- |
| Kẻ săn đuổi | 45 | Nhanh nhất | 12 | Đèn hoặc bẫy để giữ chân, bắn một phát trúng đích |
| Kẻ phá cửa | 135 | Chậm nhất | 27 | Gia cố cửa, bắn trước khi nó phá hết độ bền |
| Kẻ gây nhiễu | 70 | Trung bình | 16 | Cảm biến xác định khu vực; loa dụ sang vùng khác hoặc đèn để tạm ngắt nhiễu rồi bắn |
| Vật chủ | 300 | Chậm hơn quái gây nhiễu | 57 khi đánh mạnh | Chờ lõi sáng sau đòn mạnh; bắn vào giáp chỉ gây một phần ba sát thương |

## Súng và thiết bị

Súng chỉ bắn trong camera đang xem, khi camera còn tín hiệu, có điện và súng hết hồi. Mỗi phát tốn 2 điện, hồi 0,75 giây; gây 45 sát thương kèm đẩy lùi quái thường. Bắn hụt vẫn tiêu hao điện và tạo tiếng động. Chi phí được cân bằng cho các đợt nhiều quái.

Vật chủ có 300 máu và giáp giảm sát thương xuống 15. Khi đến cửa đang khóa, nó cảnh báo và nạp đòn trong 1,4 giây, sau đó đánh mạnh gây 57 sát thương cửa. Điểm yếu phát sáng mở trong 3,2 giây sau đòn đánh. Bắn trúng lõi sáng gây đủ 45 sát thương; bắn phần giáp vẫn chỉ gây 15. Có thể dùng đèn chớp hoặc bẫy điện để ngắt đòn đang nạp. Súng không đẩy lùi boss đang mặc giáp.

Khi trúng đạn, quái lóe sáng, có tia va chạm và số sát thương; trạng thái choáng có màu và biểu tượng riêng. Quái bị tiêu diệt ngừng tấn công, gây nhiễu và kích hoạt cảm biến ngay, sau đó ngã và tan biến trong 0,85 giây. Các hiệu ứng, đòn boss và thời gian hồi đều đóng băng khi tạm dừng.

## Cấu hình các đợt

Chọn **Xem các đợt** ở màn chuẩn bị để xem lịch theo độ khó và tùy chọn loại quái hiện tại. Sinh vật trong cùng đợt vào lần lượt, cách nhau 1,5–4 giây và có hướng tiếp cận riêng. Các cấu hình nằm tại `flutter_app/lib/dead_signal/waves.dart`.

| Đợt | Mức dễ | Mức thường |
| --- | --- | --- |
| 1 | 00:03 · 1 chạy nhanh | 00:03 · 1 chạy nhanh |
| 2 | 00:27 · 1 phá cửa | 00:22 · 1 chạy nhanh + 1 phá cửa |
| 3 | 00:50 · 2 chạy nhanh | 00:43 · 1 gây nhiễu + 1 chạy nhanh |
| 4 | 01:13 · 1 gây nhiễu + 1 phá cửa | 01:06 · 1 phá cửa + 2 chạy nhanh |
| 5 | 01:37 · 1 chạy nhanh + 1 phá cửa | 01:31 · 1 gây nhiễu + 1 phá cửa + 1 chạy nhanh |
| 6 | 02:05 · 1 boss + 1 chạy nhanh | 01:58 · 1 boss + 1 chạy nhanh |
| 7 | 02:33 · 1 chạy nhanh + 1 phá cửa | 02:29 · 1 phá cửa + 1 chạy nhanh |

| Thiết bị | Tác dụng | Điện | Hồi |
| --- | --- | ---: | ---: |
| Loa dụ | Dụ quái về vùng chọn trong 8 giây; không ngắt quái đang đánh cửa | 4 | 24 giây |
| Đèn chớp | Choáng quái trong vùng chọn 3,5 giây; boss 1,5 giây | 5 | 14 giây |
| Bẫy điện | Choáng 5 giây, boss 2,5 giây, khi mục tiêu trong đoạn 35–90% hành lang; kích hoạt hụt vẫn mất điện | 9 | 20 giây |
| Chặn đường | Chặn hành lang trái hoặc phải trong 7 giây, buộc quái đổi tuyến | 5 | 22 giây |
| Im lặng | Giảm tốc truy tìm; tắt camera, súng và loa trong lúc bật | 0 | Bật hoặc tắt |
| Gia cố cửa | Tăng độ bền tối đa thêm 50, phục hồi tối đa 70; có 2 vật phẩm mỗi ván | 0 | Theo vật phẩm |

Chọn khu vực trên sơ đồ trước khi dùng thiết bị. Ở màn hình nhỏ, chọn **Thiết bị** để mở sơ đồ và các biện pháp phòng thủ; chọn **Nguồn điện** để cấp/ngắt điện.

Điểm = 5 × số giây sống sót làm tròn xuống + 100 × số quái tiêu diệt. Nếu thắng, thưởng thêm 1.000 điểm và 5 × điện còn lại làm tròn xuống. Các thông số này bổ sung cho những phần chưa được định lượng trong bản thuyết minh.

## Điều khiển

Chuột/chạm: chọn camera và thiết bị; chọn Ngắm bắn, sau đó chọn mục tiêu trong hình camera. Kéo biểu tượng NGUỒN vào camera, cửa hoặc súng để cấp điện; cũng có nút bật/tắt nguồn trực tiếp.

Bàn tay: vào kiểm tra webcam, ghi tay mở và tay chụm khi cần. Di chuyển đầu ngón trỏ để đưa con trỏ đến mục tiêu. Chụm rồi thả để chọn hoặc bắn; chụm và giữ để kéo. Chọn cửa rồi nắm tay để khóa khẩn cấp. Cử chỉ nắm tay phải ổn định trước khi nhận và không phát thêm lệnh chụm. Mất tay, mất kết nối hoặc tín hiệu cũ hơn 250 ms sẽ tạm dừng; khi có tay lại, người chơi chủ động tiếp tục.

Phím tắt: 1/2/3 đổi camera; A/D đóng mở cửa trái/phải; G bật/tắt ngắm bắn; Space bắn tại tâm ngắm; P hoặc Esc tạm dừng/tiếp tục; F1/F2 ghi hai tư thế tại màn hiệu chỉnh. Có thể đổi sang chuột/chạm khi tạm dừng.

## Mã nguồn và kiểm tra

Nếu có hình webcam nhưng chưa điều khiển được, xem dòng trạng thái nhận diện. Lần mở đầu có thể mất khoảng 10 giây để nạp mô hình trên laptop. Khi sẵn sàng, hai đầu ngón được đánh dấu trên hình webcam. Giữ lòng bàn tay rõ trong khung hình, di chuyển ngón trỏ và thử chụm rồi thả; màu dấu chỉ chuyển khi game nhận được cử chỉ. Ghi lại tay mở/chụm bằng F1/F2 nếu cần.

Con trỏ giữ vị trí đã trỏ trong khi chụm–thả để ngón tay co lại không làm lệch nút bấm. Khi giữ chụm và dịch chuyển cả bàn tay, con trỏ theo lòng bàn tay để kéo thả. Mất tín hiệu sẽ hủy thao tác đang giữ, không phát thêm một lần chọn.

- `flutter_app/lib/dead_signal/model.dart`: điện, camera, cửa, súng, quái, thiết bị, thời gian, điểm và kết quả.
- `flutter_app/lib/dead_signal/waves.dart`: cấu hình thành phần, số lượng, thời điểm và hướng đi của từng đợt.
- `flutter_app/lib/dead_signal/enemy_painter.dart`: bốn hình dạng quái, chuyển động, lóe sáng, sát thương, giáp, điểm yếu, choáng và tan biến.
- `flutter_app/lib/dead_signal/controller.dart`: luồng màn hình, đếm ngược, tạm dừng và tín hiệu điều khiển.
- `flutter_app/lib/dead_signal/gesture_pointer.dart`: chuỗi nhấn, kéo, thả, hủy và nắm tay; chống thao tác lặp sau mất tín hiệu.
- `flutter_app/lib/dead_signal/app.dart`, `compact.dart`, `scene.dart`: giao diện máy tính/màn hình nhỏ và cảnh 2D.
- `core/hand_tracker.py`, `core/gestures.py`, `hand_service/server.py`: nhận diện một bàn tay, lọc trạng thái nắm và truyền dữ liệu qua WebSocket. Giữ tương thích với bản thử Sky Runner.
- `flutter_app/assets/audio/`: hiệu ứng và âm nền tổng hợp riêng cho bản thử.

```powershell
cd flutter_app
flutter analyze
flutter test --reporter expanded
cd ..
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Kiểm tra bao gồm mô phỏng trọn 180 giây thắng được ở cả hai độ khó, điện/cửa/súng/thiết bị/quái, tạm dừng, mất tay, nút bấm và kéo nguồn bằng dữ liệu tay, các bố cục màn hình nhỏ và hồi quy của nền tảng cũ. Cần tiếp tục thử bằng tay thật để đánh giá độ trễ và độ ổn định theo ánh sáng, khoảng cách và webcam của người chơi.
