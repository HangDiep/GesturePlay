# Điều khiển hoàn toàn bằng hai tay

Bản Flutter cập nhật ngày 04/11/2026. Chọn **Hai tay / Webcam** trên trang đầu. Sau bước chọn chế độ, có thể bắt đầu, chơi, tạm dừng, tiếp tục, xem túi/bản đồ và chơi lại bằng cử chỉ; các thao tác chiến đấu không cần bàn phím. Bản một tay và bàn phím/cảm ứng vẫn chọn riêng được.

Chạy `npm run web` từ `D:\GesturePlay`, mở `http://127.0.0.1:8080`. Nếu terminal đang chạy bản cũ, dừng bằng Ctrl+C rồi chạy lại để Python cũng nạp bộ nhận diện mới; Ctrl+F5 trong trình duyệt. Không cần cài thêm thư viện hoặc tải lại model.

## Cử chỉ trực tiếp

Mặc định tay trái là **tay di chuyển**, tay phải là **tay ngắm**. Có thể đảo hai vai trong Cài đặt → Đổi vai hai tay. Vai tay được ghi trên preview; cài đặt lưu trên máy.

| Chức năng | Cử chỉ |
|---|---|
| Đi lại | Mở và dịch tay di chuyển quanh tâm ban đầu; về tâm để dừng. |
| Ngắm | Dịch tay ngắm quanh tâm riêng; độc lập với hướng di chuyển. |
| Bắn | Chụm ngón cái–trỏ tay ngắm và giữ; mở ra để ngừng. Tay di chuyển vẫn đi được. |
| Đứng → ngồi → nằm → đứng | Nắm ngắn tay di chuyển rồi mở. Mỗi lần thả chuyển một tư thế. |
| Mở/đóng cửa, lấy tiếp tế | Đứng gần cửa/hòm, chụm ngắn ngón cái–trỏ tay di chuyển rồi thả. |
| Ẩn / rời ẩn | Gần chỗ ẩn, chụm ngắn tay di chuyển rồi thả. Nếu đồng thời có cửa/hòm gần, thao tác ưu tiên cửa/hòm; chọn Ẩn ở bảng thao tác để chỉ định rõ. |
| Băng bó | Chụm tay di chuyển ít nhất 0,8 giây rồi thả; giữ tay ngắm mở và tay di chuyển ở tâm trong lúc hồi. |
| Nạp đạn | Nắm ngắn tay ngắm rồi mở. |
| Đổi súng đã nhặt | Nắm tay ngắm ít nhất 0,8 giây rồi mở; chỉ đổi một lần khi thả. |
| Lướt né | Hất nhanh tay di chuyển đang mở lên; trở về tâm để dùng lại. Từ nằm phải đứng dậy trước. |
| Bảng thao tác | Nắm tay di chuyển ít nhất 0,8 giây; ván dừng và hiện bảng 12 ô. |
| Tạm dừng | Nắm cả hai tay ít nhất 0,8 giây. |

“Ngắn” là khoảng 0,2–0,5 giây, dưới ngưỡng 0,8 giây; dưới 0,12 giây bị bỏ qua. Cử chỉ giữ lâu được tách khỏi cử chỉ ngắn để không vừa đổi tư thế vừa mở bảng, hoặc vừa nạp vừa đổi súng. Tay nắm không được tính là bắn. Động tác băng bó/đổi súng/context chỉ thực hiện lúc thả, không lặp liên tục trong khi giữ.

## Bảng chọn cũng dùng tay

| Hàng | Trái | Giữa | Phải |
|---|---|---|---|
| 1 | Nạp đạn | Ẩn / rời ẩn | Lướt |
| 2 | Đứng | Ngồi | Nằm |
| 3 | Băng bó | Đổi súng | Tương tác |
| 4 | Túi đồ | Bản đồ | Tạm dừng |

Trong bảng, dịch **tay ngắm** trái/giữa/phải và hạ tay để chọn hàng tiếp theo; ô được chọn sáng vàng. Chụm rồi thả tay ngắm để xác nhận, sau đó mở cả hai tay để thực hiện. Chụm tay di chuyển để hủy chọn. Tâm hai tay đặt lại khi trở lại ván để tránh tự đi hoặc tự bắn. Bảng giúp chọn thẳng một tư thế, ngoài cách nắm ngắn để lần lượt đổi tư thế.

Ở **trang đầu**, nắm **tay phải** khoảng **0,5 giây** để bấm Bắt đầu sinh tồn. Chỉ cần nhận tay phải cho thao tác này, kể cả khi đã đổi vai hai tay. Thanh dưới preview hiển thị tiến độ nhận nắm tay; giữ nguyên nắm chỉ bấm một lần. Sau khi xác nhận, game hiện “ĐÃ NHẬN BẮT ĐẦU”, chờ thả tay phải và mở rõ cả hai tay rồi mới chạy. Trong lúc chờ thời gian bằng 0, không mất máu/đạn; nắm dùng để bắt đầu không bị tính thành nạp hoặc đổi súng.

Ở **màn Tạm dừng**, nắm **tay phải khoảng 0,5 giây** để bấm Tiếp tục. Có thanh tiến độ nắm tay, chỉ cần nhận tay phải để xác nhận. Game hiện “ĐÃ NHẬN TIẾP TỤC”; thả tay phải và mở rõ hai tay để ván chạy tiếp. Lượt chơi hiện tại được giữ nguyên, thời gian/máu/đạn không đổi trong lúc chờ; nắm dùng để tiếp tục không bị tính thành nạp hoặc đổi súng. Chỉ đưa tay trở lại camera mà chưa xác nhận thì game vẫn dừng. Nếu tay phải đang nắm từ lúc tạm dừng, cần mở tay rồi nắm lại; giữ nắm cũ không tự bấm Tiếp tục.

Ở màn kết quả, túi đồ hoặc bản đồ: **mở rõ hai tay → chụm tay ngắm một nhịp → thả** để chơi lại/đóng bảng đang xem.

## Nhận diện và ngăn thao tác nhầm

Python vẫn dùng một webcam, một model LIVE_STREAM; cấu hình `max_hands=2`. Mỗi tay có bộ lọc chụm/nắm và trạng thái sẵn sàng riêng. Giao thức thêm trường `hands.left/right` bên cạnh trường một tay cũ. Nhãn vật lý được sửa theo ảnh đã lật của CameraWorker; không suy vai tay từ thứ tự mảng phát hiện. Bộ ghép vị trí giữ vai khi mảng đổi thứ tự hoặc nhãn dao động; trường hợp hai tay chồng nhau không phân biệt được thì dừng điều khiển.

Mất một tay, tọa độ lỗi hoặc tín hiệu cũ hơn 250 ms sẽ ngừng đi/bắn và tạm dừng. Cử chỉ đang giữ bị hủy; không thực hiện khi tay xuất hiện lại. Cần hai tay rõ, sẵn sàng, rồi xác nhận tiếp tục. Đổi phiên dịch vụ cũng hủy thao tác đang giữ. Hai tay nên tách nhau trong khung hình.

Google mô tả cấu hình nhiều tay và việc ảnh phản chiếu làm đảo nhãn tại [Hand Landmarker Python](https://developers.google.com/edge/mediapipe/solutions/vision/hand_landmarker/python). Ảnh công khai dùng thử model lấy từ [notebook mẫu chính thức](https://github.com/google-ai-edge/mediapipe-samples/blob/main/examples/hand_landmarker/python/hand_landmarker.ipynb); chỉ nằm trong bộ nhớ đệm kiểm tra, không đóng gói vào game.

## Kiểm tra đã thực hiện

- 202 bài Flutter qua, gồm 21 bài bộ điều khiển hai tay và luồng giao diện 1280×800, 844×390, 390×844. Luồng bắt đầu kiểm tra chỉ có tay phải nắm, giữ không lặp, chờ hai tay mở mà không chạy đồng hồ/mất đạn, sau đó chơi đến chơi lại không gửi phím hoặc bấm nút trong ván.
- 42 bài Python đã qua các lượt kiểm tra: callback, thứ tự/nhãn tay, chồng tay, bộ lọc cử chỉ độc lập, mất tay, truyền hai vai qua WebSocket thật, vòng đời camera/model và pipeline với camera giả lập.
- `flutter analyze` không báo lỗi; bản web release và Windows release dựng thành công.
- Model LIVE_STREAM thật đã nhận hai tay từ ảnh mẫu công khai; vai đầu ra gồm `left` và `right`. Lệnh kiểm tra ảnh cục bộ: `.venv\Scripts\python.exe tools\check_two_hands.py .cache\mediapipe-two-hands.jpg`.
- Ảnh bảng hai tay: `design_assets/town_two_hands_wheel.png`; giao diện chơi dọc: `design_assets/town_two_hands_portrait.png`.
- Sửa thao tác Bắt đầu: `design_assets/town_right_fist_start.png`. Bản web đã dựng lại sau sửa đổi; phần nhận diện Python không cần thay đổi.
- Sửa màn Tạm dừng: `design_assets/town_right_fist_pause.png`, `town_right_fist_resume.png`. Đã kiểm tra 37 bài liên quan, gồm tiếp tục chỉ với tay phải nắm, giữ nắm cũ không tự tiếp tục, không đổi súng/nạp/bắn khi thả tay, giữ nguyên lượt chơi và tài nguyên trong lúc chờ hai tay; bố cục ở ba kích thước màn hình đều qua.

Chưa có lượt thử cử chỉ bằng hai tay thật trước webcam hoặc số FPS của game khi đồng thời nhận hai tay. Kiểm tra ảnh tĩnh và dữ liệu giả lập không thay thế lượt thử đó. Tốc độ thực tế còn phụ thuộc máy, ánh sáng và chất lượng webcam; chưa đưa ra mức FPS bảo đảm.

Nguồn chính: `core/hand_tracker.py`, `core/hand_roles.py`, `hand_service/server.py`, `flutter_app/lib/services/hand_bridge.dart`, `flutter_app/lib/survival/hand_input.dart`, `app.dart` và `hand_preview.dart`.
