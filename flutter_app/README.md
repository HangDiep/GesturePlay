# GesturePlay — ứng dụng Flutter Windows

Flutter phụ trách toàn bộ giao diện; Flame/Dart phụ trách game Sky Runner, vật lý, va chạm và điểm. Python chỉ nhận diện tay qua webcam và gửi lệnh bằng WebSocket nội bộ.

Chạy từ thư mục này:

```powershell
flutter run -d windows
```

Chọn **Chơi bằng bàn tay** để ứng dụng tự mở dịch vụ Python, hoặc **Luyện bằng bàn phím** để chơi không cần webcam. Thả rồi chụm ngón cái–trỏ để nhảy; dùng F1/F2 ở màn chuẩn bị để hiệu chỉnh. Bàn phím dùng Space/↑.

Xem [README chính](../README.md) để cài môi trường, điều khiển, xử lý camera, kiểm tra và dựng bản Release. Kiến trúc tại [GesturePlay_Flutter_Python_Kien_truc.md](../GesturePlay_Flutter_Python_Kien_truc.md).
