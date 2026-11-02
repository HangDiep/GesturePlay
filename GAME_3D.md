# DEAD SIGNAL 3D — bản thử đã ngừng dùng làm mặc định

Theo yêu cầu mới, ứng dụng chính đã trở về Flutter 2D. Dùng `npm run web` hoặc `npm run windows` để mở bản Flutter. Tài liệu này chỉ lưu lại thông tin của bản Godot thử nghiệm; các lệnh npm 3D bên dưới không còn là lệnh đang sử dụng.

Bản hiện tại chuyển sang nhân vật điều khiển được, góc nhìn sau lưng, chạy/nhảy và khám phá bốn bản đồ 3D bằng Godot 4.7.2. Đây là bản chơi một người với đồ họa hình khối. Bản Flutter phòng trực cũ vẫn nằm trong `flutter_app`, mở bằng `npm run web:classic` hoặc `npm run windows:classic`.

## Chạy

```powershell
cd D:\GesturePlay
npm run web
```

Mở http://127.0.0.1:8080. Dừng lần chạy cũ bằng Ctrl+C trước khi chạy. Lệnh này nhập tài nguyên, xuất bản Web mới, mở dịch vụ nhận diện tay và trình duyệt. Webcam chỉ bật khi chọn Bàn tay. Ctrl+C dừng các tiến trình do lệnh mở.

```powershell
npm run windows
```

Bản Windows nằm tại `godot_game/build/windows/DeadSignal3D.exe`. Chạy qua lệnh trên để có sẵn dịch vụ tay. Game 3D không còn biên dịch bằng Flutter. Chưa tạo bản Android 3D; APK Flutter trước đó vẫn là trò chơi phòng trực cũ.

Godot portable và hai bộ xuất cần thiết đã được chuẩn bị trong `.cache/godot`. Khi chuyển sang máy khác, tạo môi trường Python theo README rồi chạy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup-godot.ps1
```

Script tải bản chính thức, kiểm SHA512 của engine và tải riêng template Web/Windows. Không cài Godot vào hệ thống. Có thể đặt `GODOT_EXE` nếu đã có bản Godot phù hợp. Muốn chỉnh cảnh bằng editor, mở `godot_game/project.godot`.

## Bốn bản đồ

| Bản đồ | Môi trường và cách chơi |
| --- | --- |
| 01 – Rừng thông | Đường mòn, cây, đá và trạm gác. Có thể rời đường chính, dùng cây/đá làm vật chắn. |
| 02 – Thị trấn bỏ hoang | Những dãy nhà, đường chính, đường ngang và quảng trường. Di chuyển qua các phố và vòng qua nhà để cắt đường truy đuổi. |
| 03 – Bến cảng | Bãi container xếp chồng, cần cẩu, mặt nước trang trí và cầu tàu. Các lối giữa container tạo nhiều góc khuất. |
| 04 – Nhà máy phản ứng | Bồn chứa lớn, đường ống, thiết bị và các vùng nhiễm. Đứng trong vòng nhiễm sẽ mất máu theo thời gian. |

Mỗi bản đồ có bố cục va chạm riêng và ba lõi tín hiệu. Đi gần lõi để nhặt, sau đó trở về vòng cứu hộ màu xanh ở điểm xuất phát để thắng. Có vật phẩm hồi máu và đạn. Các đợt quái xuất hiện ở giây 3, 27, 55, 88 và 120. Có bốn loại quái với máu, tốc độ, đòn đánh và gây nhiễu khác nhau; boss nạp đòn và để lộ lõi yếu sau đòn mạnh.

Các nhà dân hiện là vật cản bên ngoài; chưa có nội thất. Bản đồ là khu chơi giới hạn, chưa có nhiều người chơi, xe hoặc hệ thống battle royale. Không có tài khoản/database/lịch sử theo phạm vi người dùng đã chọn.

## Điều khiển

- WASD hoặc các phím mũi tên: đi theo hướng camera; Shift chạy nhanh; Space nhảy.
- Chuột: xoay camera; chuột trái bắn; chuột phải ngắm. Nếu môi trường trình duyệt không giữ được chuột, giữ chuột phải và kéo để xoay nhìn, hoặc dùng I/J/K/L xoay camera.
- R thay đạn. Súng có 24 viên/băng, 120 viên dự trữ ban đầu. Vật cản chặn cả đường đi và đường đạn.
- Q dùng đèn chớp; E đặt bẫy điện. Mỗi loại có 3 lượt và thời gian hồi riêng.
- Esc: tạm dừng, tiếp tục hoặc về chọn bản đồ.

Bàn tay: bật Bàn tay trong màn chọn bản đồ, chờ nhận diện sẵn sàng, giữ tay mở ở vị trí thoải mái rồi vào game. Vị trí đó là tâm điều khiển. Mở tay và dịch trái/phải/lên/xuống để đi; chụm và dịch tay để ngắm, giữ chụm để bắn; nắm tay để thay đạn. Tín hiệu cũ hơn 250 ms hoặc mất tay sẽ dừng thao tác và tạm dừng ván. Không tự tiếp tục sau khi có tay lại. Trong tạm dừng có thể đổi về bàn phím/chuột.

## Kiểm tra và xuất bản

```powershell
.\.cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path godot_game --fixed-fps 60 --script res://tests/smoke.gd
npm run build:3d
npm run build:3d:windows
```

Bộ kiểm tra xác minh đường tới cả ba mục tiêu trong mỗi bản đồ bằng va chạm thật; di chuyển, tạm dừng, súng, đạn, boss, quái chết, nhặt vật phẩm, cứu hộ, các đợt và dữ liệu tay đến trễ. Nhận diện tay cần được thử thêm bằng tay thật theo ánh sáng và webcam thực tế.

Thử máy chủ mà không chiếm cổng của lần chạy cũ:

```powershell
npm run web -- --port=8081 --no-open --no-hand
```

`--no-hand` chỉ mở phần chơi bằng chuột/bàn phím. Máy chủ chỉ phục vụ trên loopback; game Web dùng WebGL 2.0 và WebAssembly.
