# GesturePlay — Flutter 2D và Python nhận diện

| Thành phần | Công nghệ |
| --- | --- |
| Trang chủ một map, HUD, tạm dừng, kết quả, chuột/bàn phím/chạm | Flutter widgets trong lib/survival/app.dart |
| Nhân vật, quái, đạn, kỹ năng, vật phẩm, thời gian và điểm | Dart trong lib/exploration/model.dart ở chế độ survival |
| Vẽ phố cổ, atlas PNG nhân vật/quái/đồ vật, hiệu ứng và sơ đồ | Flutter CustomPainter trong lib/survival/painter.dart |
| Tìm đường và va chạm | A* và hình học Dart; quái không đi xuyên vật cản |
| Webcam, MediaPipe, hiệu chỉnh và nhận diện cử chỉ | Python |
| Truyền trạng thái tay và preview | WebSocket nội bộ; web cổng 8766, Windows cổng 8765 |
| Mở ứng dụng và dịch vụ web | Node chỉ điều phối Flutter Web và Python |

Luồng: Webcam → Python nhận diện → HandBridge Dart → TownHandInput → ExplorationModel → TownPainter và Flutter widgets.

`flutter_app/lib/main.dart` mở `SurvivalApp`. Trang chủ chỉ có map Thị trấn bị phong tỏa. `npm run web`, `npm run windows` và các file .bat gọi Flutter. Godot không tham gia luồng chạy hiện tại. Flame còn là phụ thuộc cho các phần chơi trước đây; bản một map dùng CustomPainter để vẽ atlas ảnh. Một nguồn luật duy nhất xử lý máu và va chạm.

Python không tính điểm, xử lý đạn, chạy quái hoặc mở cửa sổ game. Mất tay, mất kết nối hoặc dữ liệu quá hạn khiến Dart dừng thao tác và tạm dừng; không tự tiếp tục khi có tay lại. Preview chỉ mở khi chọn bàn tay.

Hiện chưa có đăng nhập/database/lịch sử lượt chơi theo yêu cầu. Kết quả được hiển thị cuối ván. Cài đặt âm thanh và webcam dùng lưu trữ thiết bị.

Luật và hướng dẫn hiện tại: [SINGLE_MAP.md](SINGLE_MAP.md). Bản thử bốn map: [DEAD_SIGNAL.md](DEAD_SIGNAL.md). Kiến trúc Sky Runner trước đây được giữ trong docs/LEGACY_ARCHITECTURE.md.
