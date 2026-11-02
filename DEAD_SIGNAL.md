# DEAD SIGNAL bản bốn map tham khảo

**Bản chính đã chuyển sang một map. Xem [SINGLE_MAP.md](SINGLE_MAP.md) để biết luật và điều khiển hiện tại.** Nội dung dưới đây mô tả bản thử bốn bản đồ còn lưu trong `lib/exploration/app.dart`, không phải giao diện mở từ lệnh mặc định.

## Chạy

```powershell
cd D:\GesturePlay
npm run web
```

Mở http://127.0.0.1:8080. Dừng lần chạy cũ bằng Ctrl+C; nhấn Ctrl+F5 nếu còn thấy bản trước. Giữ terminal mở. Lệnh mở Flutter Web và Python ở cổng 8766. Webcam chỉ mở khi bật **Điều khiển bằng bàn tay**. `npm run web -- --clear` làm sạch bộ nhớ đệm biên dịch.

```powershell
npm run windows
```

Có thể nhấp đúp `Chay_GesturePlay.bat` hoặc `Chay_Bang_Ban_Phim.bat`. File Windows đã biên dịch: `flutter_app/build/windows/x64/runner/Release/gestureplay.exe`; giữ DLL và thư mục `data` đi kèm. Bản Windows tự mở Python khi cần tay. Launcher chuẩn bị junction cho plugin, không đổi chế độ nhà phát triển Windows.

## Nhiệm vụ và bản đồ

Thu hồi **3 lõi tín hiệu**, sống sót **180 giây** chờ cứu hộ, rồi trở về vòng xanh tại điểm xuất phát. Nhặt đủ lõi sớm vẫn phải chờ cứu hộ. Có thể tiếp tục tìm lõi sau khi cứu hộ tới. Hết máu sẽ thua. Kết quả chỉ hiển thị cuối ván; chưa có tài khoản, database hoặc lịch sử lưu.

| Bản đồ | Môi trường |
| --- | --- |
| 01 — Rừng thông | Đường mòn, cây, trạm gác và đá; cây/đá chặn đi lại và đạn. |
| 02 — Thị trấn bỏ hoang | Các dãy nhà, đường giao nhau và quảng trường; chưa có nội thất nhà. |
| 03 — Bến cảng | Các hàng container, cần cẩu và mặt nước; không đi xuyên mặt nước. |
| 04 — Nhà máy | Bồn chứa, máy móc, đường ống và vùng nhiễm gây 9 sát thương mỗi giây. |

Bốn bản đồ có bố cục va chạm và đường đi riêng. Khung nhìn theo nhân vật. Sơ đồ nhỏ hiển thị người chơi, lõi và cứu hộ. Quái gần người chơi xuất hiện trên cảm biến; quái gây nhiễu làm mất các dấu quái này trong vùng ảnh hưởng.

## Điều khiển

- **WASD hoặc mũi tên:** đi; **Shift:** chạy, tiêu hao thể lực.
- **Chuột:** ngắm; giữ chuột trái hoặc **F** để bắn. Tâm ngắm theo chuột khi khung nhìn di chuyển.
- **R:** thay đạn trong 1,65 giây. Súng có 24 viên/băng, 120 viên dự trữ ban đầu, mỗi phát gây 28 sát thương trước giáp.
- **Space:** lướt theo hướng di chuyển gần nhất, tốn 25 thể lực, hồi 3 giây; không đi xuyên vật cản.
- **Q — Đèn chớp:** choáng quái trong bán kính 250, có 3 lượt, hồi 6 giây. Choáng quái thường 3,5 giây, boss 1,5 giây và ngắt đòn đang nạp.
- **E — Bẫy điện:** đặt tại chỗ đứng, có 3 lượt, hồi 3 giây. Tồn tại tối đa 20 giây; mục tiêu đầu tiên vào vòng bị choáng 4 giây, boss 2 giây, rồi bẫy tắt.
- **Esc hoặc P:** tạm dừng/tiếp tục. Có thể chọn bản đồ khác hoặc chơi lại sau kết quả.
- **Chạm:** cần trái để đi; nút phải để ngắm/bắn. Chạm gần tâm nút bắn chọn quái nhìn thấy gần nhất; kéo lệch tâm chọn hướng. Nút đèn, bẫy và thay đạn ở dưới màn hình.

Đi gần để nhặt lõi vàng, túi hồi tối đa 40 máu và hộp 48 viên đạn. Túi máu còn nguyên nếu đang đủ máu.

## Quái và các đợt

| Loại | Máu | Di chuyển | Sát thương mỗi đòn |
| --- | ---: | --- | ---: |
| Kẻ săn đuổi | 45 | Nhanh nhất | 8 |
| Kẻ bọc giáp | 135 | Chậm, chịu nhiều đạn | 17 |
| Kẻ gây nhiễu | 70 | Trung bình, nhiễu cảm biến gần người chơi | 10 |
| Vật chủ | 300 | Giáp giảm sát thương còn một phần ba | 32 khi đánh mạnh |

Boss cảnh báo bằng vòng đỏ, nạp đòn 1,4 giây. Lùi khỏi vòng hoặc dùng đèn/bẫy ngắt đòn. Sau đòn mạnh, vòng vàng báo điểm yếu mở 3,2 giây: bắn lúc này gây đủ sát thương. Quái chết ngừng tác động ngay và tan biến trong 0,85 giây.

Các đợt ở giây 3, 27, 55, 88 và 120, tổng 12 quái đủ bốn loại. Giới hạn 9 quái sống; lượt còn lại được xếp chờ. Quái tìm đường vòng qua vật cản, điều tra tiếng súng và chỉ đánh cận chiến khi không có vật chắn.

Điểm: mỗi lõi 300, mỗi quái bị hạ 100; thắng thưởng 1.000 và 5 × máu còn lại làm tròn xuống.

## Bàn tay

Bật **Điều khiển bằng bàn tay** ở màn chọn bản đồ. Chờ sẵn sàng, mở tay rõ trong webcam rồi vào bản đồ. Vị trí tay lúc bắt đầu là tâm điều khiển.

- Mở tay, dịch trái/phải/lên/xuống để đi.
- Chụm để đứng lại, hướng tay từ tâm để ngắm; giữ chụm để bắn.
- Nắm tay để thay đạn.
- **C:** đặt lại tâm; **F1/F2:** ghi tay mở/tay chụm. Có nút hiệu chỉnh và thử lại ở màn chọn bản đồ.

Mất tay, mất kết nối hoặc dữ liệu cũ quá 250 ms sẽ hủy thao tác và tạm dừng. Phải chủ động tiếp tục khi thấy tay lại. Có thể đổi sang chuột/chạm trong tạm dừng. Webcam trong trang chỉ là ảnh xem trước từ Python. Cần thử thêm bằng tay thật theo ánh sáng và webcam thực tế.

## Android

APK: `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`. Phần chạm chạy bằng Flutter, nhận diện tay không chạy trực tiếp trong điện thoại. Với Android Emulator, mở Python trên laptop trước:

```powershell
.\.venv\Scripts\python.exe main.py --port 8765 --idle-timeout 0
cd flutter_app
flutter run -d <ma-gia-lap>
```

Giả lập kết nối `ws://10.0.2.2:8765`. Chơi bằng chạm không cần nhận diện.

## Mã nguồn và kiểm tra

- `flutter_app/lib/main.dart`: mở `ExplorationApp`.
- `flutter_app/lib/exploration/world.dart`: bốn bản đồ, vật cản, va chạm và A*.
- `flutter_app/lib/exploration/model.dart`: nhân vật, đạn, quái, kỹ năng, đợt, vật phẩm và cứu hộ.
- `flutter_app/lib/exploration/painter.dart`: thế giới 2D và cảm biến.
- `flutter_app/lib/exploration/app.dart`: giao diện, thao tác và âm thanh.
- `flutter_app/lib/exploration/hand_input.dart`: chuyển dữ liệu tay thành hành động.
- `flutter_app/lib/services/hand_bridge.dart`, `core/`, `hand_service/server.py`: kết nối và nhận diện hiện có.

```powershell
cd flutter_app
flutter analyze
flutter test --reporter expanded
```

Kiểm tra gồm đường tới vật phẩm, va chạm đi/lướt, đạn, boss, tìm đường, tạm dừng, tay, các đợt, cứu hộ và bố cục máy tính/chạm. Mã phòng trực và Sky Runner cũ được giữ để tham khảo và kiểm tra hồi quy.
