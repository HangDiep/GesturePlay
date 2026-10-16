# GesturePlay — Cấu trúc phần lõi điều khiển bằng tay

Môi trường dự kiến: Windows, Python 3.10 64-bit, laptop RAM 16 GB.
Thư mục trên máy người dùng: `D:\GesturePlay`.
Đây là bản thiết kế và hướng dẫn triển khai, chưa phải mã nguồn chạy được. Chưa có đo hiệu năng trên laptop của bạn; không thể cam kết hết lag hoặc cấu hình này là tối ưu tuyệt đối.

## 1. Mục tiêu bản đầu

Chỉ mở webcam, nhận diện một bàn tay và điều khiển thanh ngang trong một cửa sổ Pygame. Chưa làm bóng, điểm, đăng nhập, cơ sở dữ liệu hay nhiều trò chơi.

Tiêu chí: tay dịch trái/phải thì thanh đi theo; mất tay thì dừng; giao diện vẫn phản hồi khi camera hoặc nhận diện chậm; nhấn Esc đóng sạch camera và chương trình.

Đây là bản thử desktop. Nếu môn bắt buộc Flutter/mobile thì cần xác nhận lại nền tảng trước khi phát triển toàn bộ; mã Python/Pygame không tự trở thành ứng dụng Flutter.

## 2. Cấu trúc dự kiến

Các đường dẫn sau tính từ `D:\GesturePlay`. Những file .py dưới đây sẽ viết ở bước tiếp theo, hiện chỉ định nghĩa trách nhiệm.

| Đường dẫn | Nhiệm vụ |
|---|---|
| `main.py` | Khởi tạo, chạy vòng lặp Pygame trên luồng chính, đóng tài nguyên |
| `config.py` | Độ phân giải, giới hạn FPS, ngưỡng nhận diện, hệ số làm mượt |
| `core/__init__.py` | Đánh dấu gói Python |
| `core/camera.py` | Luồng đọc camera liên tục; chỉ giữ một khung hình mới nhất cùng mã khung và thời điểm đọc |
| `core/hand_tracker.py` | Tạo một HandLandmarker, gửi ảnh mới theo nhịp giới hạn, nhận callback |
| `core/shared_state.py` | Chia sẻ ảnh/kết quả mới nhất có khóa ngắn; không giữ khóa trong lúc suy luận |
| `core/controller.py` | Chuyển tọa độ bàn tay thành tọa độ thanh, làm mượt, xử lý mất tay |
| `core/metrics.py` | Đo FPS giao diện, FPS kết quả nhận diện, độ cũ của dữ liệu |
| `ui/__init__.py` | Đánh dấu gói Python |
| `ui/control_demo.py` | Vẽ thanh, chấm chỉ vị trí tay, thông số hiệu năng; preview camera tùy chọn |
| `models/hand_landmarker.task` | Mô hình Hand Landmarker tải từ nguồn chính thức, không phải file Python |
| `requirements-lock.txt` | Phiên bản thư viện đã cài và kiểm tra thành công trên máy |
| `logs/` | Bản đo tổng hợp khi cần; không ghi từng khung hình |
| `.venv/` | Môi trường riêng đã tạo; không chia sẻ thư mục này khi gửi dự án |

## 3. Kiến trúc giảm độ trễ

1. Luồng camera liên tục đọc hình, thay thế ô chứa ảnh mới nhất. Không dùng hàng đợi ảnh không giới hạn.
2. Luồng gửi nhận diện chỉ lấy khung mới chưa gửi, tối đa khoảng 20 lần/giây lúc đầu. Chuyển BGR sang RGB, tạo ảnh MediaPipe và gọi `detect_async`.
3. MediaPipe ở chế độ `LIVE_STREAM` trả kết quả bằng callback. Callback chỉ cập nhật trạng thái ngắn gọn; không vẽ, không ghi file, không gọi Pygame.
4. Luồng chính Pygame đọc kết quả mới nhất, tính vị trí thanh và vẽ độc lập với camera. Không chờ nhận diện xong để xử lý nút đóng cửa sổ.

Dùng một đối tượng nhận diện suốt phiên. Không tạo mô hình lại mỗi frame, không chạy nhiều mô hình song song. Tách luồng giúp tránh chặn giao diện nhưng không bảo đảm tăng tốc tính toán; phải đo thực tế.

Hand Landmarker dùng tracking trong chế độ video/live stream để giảm số lần phát hiện lòng bàn tay. Khi đang bận, lời gọi live stream mới có thể bị bỏ qua. Đây là hành vi phù hợp cho điều khiển thời gian thực: ưu tiên dữ liệu mới thay vì xử lý lần lượt dữ liệu cũ.

Timestamp gửi vào MediaPipe phải tăng nghiêm ngặt, dùng đồng hồ monotonic; không dùng giờ hệ thống có thể bị đổi. Gắn thời điểm đọc ảnh với kết quả để tính độ cũ. Đối tượng ảnh đã gửi không được sửa nội dung trong lúc bộ nhận diện có thể đang sử dụng.

## 4. Cấu hình khởi đầu để đo

| Thông số | Giá trị thử ban đầu | Ghi chú |
|---|---|---|
| Camera | 640 × 480, yêu cầu 30 FPS | Camera/driver có thể không đáp ứng; đọc lại kích thước và đo thực tế |
| Số bàn tay | 1 | `num_hands=1` |
| Chế độ | LIVE_STREAM | MediaPipe Tasks HandLandmarker, không trộn API cũ `mp.solutions` |
| Tần suất gửi nhận diện | Tối đa 20 FPS | Nhịp gửi không đồng nghĩa FPS kết quả |
| Giao diện | Giới hạn 60 FPS | Hạ 30 FPS nếu phần vẽ chiếm nhiều CPU |
| Các ngưỡng confidence | 0.5 | Giữ mặc định trước; tăng quá cao có thể gây mất tracking |
| Làm mượt EMA | alpha = 0.6 | Chỉ áp dụng khi có kết quả mới; đây là tham số cần thử |
| Hết hạn kết quả tay | 250 ms | Sau mốc này giữ thanh đứng yên, hiện mất tín hiệu |
| Preview camera | Tắt mặc định | Bật lúc chỉnh vị trí camera; nếu bật giới hạn khoảng 10–15 FPS |

Không cài TensorFlow, PyTorch hoặc mô hình nhận dạng cử chỉ riêng cho bản đầu. Chỉ dùng landmarks và phép tính hình học. Chưa cấu hình GPU; không mặc định coi máy có GPU là MediaPipe sẽ sử dụng được GPU trong môi trường này.

## 5. Cách ánh xạ bàn tay sang điều khiển

Lấy trung bình tọa độ x của cổ tay và gốc bốn ngón (landmark 0, 5, 9, 13, 17) làm tâm điều khiển. Trung bình này giúp giảm phụ thuộc chuyển động một đầu ngón.

Lật ảnh theo chiều ngang một lần trước khi nhận diện để chuyển động giống gương; không đảo tọa độ lần thứ hai. Chọn vùng điều khiển x từ 0.15 đến 0.85 của ảnh để tay không cần vươn ra sát mép.

- Chuẩn hóa: `u = clamp((x - 0.15) / 0.70, 0, 1)`.
- Vị trí trái thanh mục tiêu: `target_x = u * (window_width - paddle_width)`.
- Làm mượt mỗi kết quả mới: `smooth_x = 0.6 * target_x + 0.4 * previous_x`.
- Lần nhận đầu hoặc sau khi mất tay: khởi tạo trực tiếp theo vị trí hiện tại để tránh kéo từ vị trí cũ.
- Alpha nhỏ làm thanh êm hơn nhưng tăng trễ; không tăng làm mượt để che lỗi nhận diện.
- Kết quả xác nhận không có tay: ngừng cập nhật vị trí ngay. Không có callback mới quá 250 ms: vô hiệu hóa điều khiển.

Bản đầu chỉ cần chuyển động trái/phải. Sau khi mượt mới thêm chụm ngón để xác nhận hoặc nắm tay để tạm dừng; dùng ngưỡng tương đối theo kích thước bàn tay, hysteresis và chỉ phát sự kiện khi đổi trạng thái. Không tự động huấn luyện AI chỉ để thêm nút bấm.

## 6. Thứ tự triển khai và tiêu chí kiểm tra

| Bước | Việc làm | Kết quả cần thấy |
|---|---|---|
| 1 | Kiểm tra môi trường, thư viện và file mô hình | Import thành công; model tồn tại, có kích thước lớn hơn 0 |
| 2 | Chỉ camera | Ảnh ổn định, không trễ dồn khi chạy vài phút |
| 3 | Camera + một bàn tay | Theo dõi vị trí, đo FPS kết quả và thời gian xử lý |
| 4 | Thêm Pygame và thanh ngang | Thanh theo tay, vẫn đóng/mở thao tác được khi mất tay |
| 5 | Thêm làm mượt và hết hạn dữ liệu | Không rung quá mức, không chạy theo kết quả cũ |
| 6 | Đo liên tục 5 phút | Không tăng RAM kéo dài, không tăng trễ theo thời gian |
| 7 | Chỉ sau khi đạt mới thêm bóng và va chạm | Không làm suy giảm phản hồi tay quá mức |

Mục tiêu tham khảo: giao diện tối thiểu 30 FPS, kết quả tay khoảng 15–20 FPS, độ cũ phần mềm phần lớn dưới 150 ms. Đây là mục tiêu thử nghiệm, không phải hiệu năng đã được xác nhận. Độ cũ phần mềm tính từ lúc đọc ảnh tới lúc sử dụng kết quả; không bao gồm toàn bộ độ trễ cảm biến/driver và màn hình. Muốn đo cảm giác đầu-cuối chính xác hơn, quay đồng thời tay và màn hình bằng camera ngoài.

Ghi số liệu mỗi giây: FPS camera, FPS nhận diện hoàn thành, FPS vẽ, độ cũ kết quả, CPU và RAM quan sát trong Task Manager. Không chỉ nhìn FPS vẽ 60 rồi kết luận điều khiển mượt.

## 7. Nếu vẫn lag, xử lý theo số đo

| Dấu hiệu | Thử xử lý |
|---|---|
| Camera riêng đã trễ | Đóng ứng dụng đang dùng webcam, kiểm tra ánh sáng; thử backend DSHOW và MSMF riêng rẽ |
| Trễ tăng dần | Kiểm tra hàng đợi; chỉ giữ ảnh/kết quả mới nhất, tránh tích lũy callback hoặc ghi đĩa |
| Camera mượt, AI chậm | Hạ ảnh đầu vào xuống 480 × 360 hoặc 320 × 240 cùng tỷ lệ; kiểm tra lại độ chính xác |
| CPU cao, kết quả không kịp | Thử giới hạn gửi 15 FPS; so độ trễ thực tế, không mặc định giảm FPS luôn tốt hơn |
| Nhận diện mượt, game giật | Tắt preview/vẽ khớp, tránh chuyển ảnh thành surface mỗi vòng lặp; giới hạn vẽ 30 FPS |
| Nhận diện hay mất tay | Cải thiện ánh sáng, để tay đủ lớn trong ảnh; không tiếp tục giảm độ phân giải |
| Thanh chậm dù AI nhanh | Giảm mức làm mượt (tăng alpha), kiểm tra tọa độ và thời điểm dữ liệu |
| RAM gần đầy và máy dùng bộ nhớ ảo | Đóng giả lập/trình duyệt nặng; kiểm tra lưu ảnh vô hạn trước khi cân nhắc nâng RAM |

Mỗi lần chỉ đổi một tham số và so cùng điều kiện. Không coi `CAP_PROP_BUFFERSIZE=1` là bảo đảm hết trễ: hiệu lực phụ thuộc backend/driver. Vòng đọc camera liên tục vẫn cần thiết. Hạ kích thước ảnh không bảo đảm giảm tương ứng chi phí suy luận vì mô hình có kích thước đầu vào nội bộ.

## 8. Chuẩn bị thư mục trên ổ D


```

Nếu tất cả kiểm tra thành công, lưu phiên bản đang dùng để lần sau tái tạo môi trường:

```powershell
.\.venv\Scripts\python.exe -m pip freeze | Out-File -Encoding utf8 requirements-lock.txt
```

Không đổi phiên bản thư viện giữa lúc thử hiệu năng. Dùng duy nhất một bản OpenCV có giao diện (đã chọn opencv-contrib-python), tránh cài đồng thời opencv-python/headless. Nếu báo lỗi phụ thuộc, xử lý lỗi trước khi viết nhận diện.

Tải mô hình Hand Landmarker bằng liên kết trong mục Models của trang Overview chính thức dưới đây. Lưu đúng tên `models\hand_landmarker.task`; đây là mô hình Hand Landmarker, không phải Gesture Recognizer. Gói pip không thay thế bước tải mô hình này.

## 9. Tài liệu chính thức

- Hướng dẫn Hand Landmarker Python: https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/python
- Tổng quan và tải model: https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
- Pygame: https://www.pygame.org/wiki/GettingStarted

Các lựa chọn luồng, giới hạn FPS, EMA và ngưỡng thời gian trong tài liệu là đề xuất thiết kế để thử trên máy bạn; không phải cấu hình tối ưu do nhà cung cấp bảo đảm.
