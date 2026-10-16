# GesturePlay — Thiết kế backend, database và giao diện cho 3 game

> Cập nhật theo yêu cầu đã chốt: ứng dụng chạy **Windows bằng Flutter + Flame**; **Python chỉ nhận diện bàn tay** và gửi dữ liệu/lệnh qua WebSocket nội bộ. Phần lựa chọn Pygame/FastAPI bên dưới là phương án cũ, không phải kiến trúc triển khai hiện tại. Xem `GesturePlay_Flutter_Python_Kien_truc.md` và `README.md` để chạy bản mới.

## 1. Phạm vi đã chốt

Người dùng đăng ký/đăng nhập, vào sảnh có ba thẻ trò chơi, bấm thẻ nào thì mở đúng trò chơi đó. Cả ba dùng chung camera và bộ nhận diện bàn tay. Sau mỗi ván, ứng dụng lưu kết quả để xem lịch sử và xếp hạng.

Hai ảnh tham chiếu thể hiện một nhân vật vượt gai và thu xu, cùng một nhân vật nhảy giữa các nền qua vực. Tên dưới đây là tên mô tả đề xuất, không phải xác nhận tên hay toàn bộ luật của game gốc.

| Mã cố định | Tên hiển thị | Luật đề xuất | Điều khiển tay |
|---|---|---|---|
| `runner` | Chạy vượt chướng ngại vật | Nhân vật tự chạy, tránh gai/chướng ngại và thu xu; va chạm kết thúc ván | Chụm ngón cái–trỏ để nhảy; chỉ nhảy khi đang chạm đất |
| `platform_jump` | Nhảy vượt vực | Di chuyển trên nền, nhảy qua khoảng trống và gai để tới đích | Tay ở vùng trái/phải để di chuyển, vùng giữa đứng yên; chụm ngón để nhảy |
| `item_catch` | Hứng vật phẩm | Di chuyển giỏ hứng vật tốt, tránh vật xấu; hết thời gian hoặc hết lượt thì kết thúc | Vị trí ngang của bàn tay điều khiển vị trí giỏ |

Bản đồ nhảy vượt vực có điểm xuất phát và đích cố định, không sinh màn vô hạn ở bản đầu. Chụm ngón chỉ tạo lệnh khi chuyển từ thả sang chụm; phải thả ra mới nhảy lần tiếp theo. Tạm dừng bằng phím/nút trước, thêm nắm tay sau khi nhận diện ổn định.

Không đưa game đỡ bóng phá gạch từ tài liệu trước vào phạm vi mới. Danh sách hiện tại có đúng ba game ở bảng trên. Ảnh chỉ dùng tham khảo lối chơi; hình ảnh/âm thanh của sản phẩm cần tự tạo hoặc có quyền sử dụng.

## 2. Công nghệ và phân chia trách nhiệm

Đề xuất giữ Python 3.10 cho bản desktop hiện tại:

| Thành phần | Lựa chọn | Trách nhiệm |
|---|---|---|
| Giao diện và game | Pygame | Form tài khoản, sảnh game, các màn chơi, chuyển màn hình |
| Camera và nhận diện | OpenCV + MediaPipe Tasks | Nhận bàn tay tại laptop; chuyển thành hành động điều khiển |
| Backend | FastAPI, chạy một tiến trình riêng | Đăng nhập, kiểm tra quyền, quản lý game, lưu kết quả và truy vấn thống kê |
| Database máy chủ | SQLite | Lưu tài khoản, phiên đăng nhập, cấu hình và kết quả |
| Gọi API | HTTP client với timeout | Gửi yêu cầu qua worker, không chặn vòng lặp Pygame |

Bản demo có thể chạy backend tại `http://127.0.0.1:8000`, database ở `D:\GesturePlay\backend\data\gestureplay.db`. Đây là địa chỉ dự kiến, chưa có server nào được tạo hoặc chạy bởi tài liệu này. Bảng xếp hạng so sánh các tài khoản cùng sử dụng backend này, chưa phải dịch vụ online công khai.

Nếu triển khai nhiều máy, đưa backend lên máy chủ dùng HTTPS; client không sao chép và ghi trực tiếp database máy chủ. Nếu môn bắt buộc Flutter/mobile, cần đổi lớp giao diện/nhận diện tương ứng; phần API và database có thể giữ ý tưởng, còn Pygame không tự chuyển thành Flutter.

### Backend làm gì và không nên làm gì trong luồng game?

| Backend phụ trách | Máy người chơi phụ trách |
|---|---|
| Tạo tài khoản, kiểm tra mật khẩu, quản lý phiên | Hiển thị form và lưu token trong bộ nhớ phiên |
| Cấp danh mục và cấu hình độ khó | Chọn đúng lớp game theo mã cố định |
| Tạo bản ghi ván chơi | Mở camera, nhận diện tay và chạy vật lý/va chạm |
| Kiểm tra, lưu kết quả một lần | Tính sự kiện ván chơi và gửi báo cáo khi kết thúc |
| Tính điểm theo luật, lọc kết quả xếp hạng | Vẽ game, âm thanh, tạm dừng khi mất tay |
| Truy vấn lịch sử, bảng xếp hạng, thống kê | Hiển thị thông tin trả về |

Không truyền video hoặc 21 điểm bàn tay tới server mỗi frame. Không gọi API mỗi khi nhân vật di chuyển, nhảy, hứng đồ hoặc mất tay. Việc gửi mạng chỉ diễn ra ở màn tài khoản, chọn game, đầu/cuối ván, cài đặt và tra cứu.

## 3. Giao diện và luồng sử dụng

| Màn hình | Thành phần chính | Hành động |
|---|---|---|
| Đăng nhập | Username, mật khẩu, hiện/ẩn mật khẩu, nút Đăng nhập và Tạo tài khoản | Gửi đăng nhập, hiển thị lỗi; thành công vào sảnh |
| Đăng ký | Username, tên hiển thị, mật khẩu, nhập lại mật khẩu | Kiểm tra dữ liệu, tạo tài khoản, quay về đăng nhập |
| Sảnh 3 game | Tên người chơi, ba thẻ ảnh+tên+mô tả; Hồ sơ, Lịch sử, Xếp hạng, Cài đặt, Đăng xuất | Bấm thẻ để xem chi tiết đúng game |
| Chi tiết game | Hình minh họa, luật, hướng dẫn tay, dễ/vừa/khó, điểm cao nhất theo mức | Bấm Chơi để kiểm tra camera |
| Chuẩn bị camera | Preview nhỏ, trạng thái nhận tay, hướng dẫn vị trí, hiệu chỉnh, Bắt đầu, Quay lại | Chỉ bắt đầu khi camera và bàn tay sẵn sàng |
| Trong game | Điểm, lượt hoặc thời gian, trạng thái tay, nút tạm dừng, âm thanh | Dùng tay điều khiển; không hiển thị form backend |
| Tạm dừng | Tiếp tục, Chơi lại, Về sảnh; lý do nếu mất tay | Tiếp tục sau khi tay ổn định; chơi lại tạo ván mới |
| Kết thúc | Điểm, xu/vật phẩm, thời gian chơi, kết quả, trạng thái lưu | Chơi lại, Xem lịch sử, Về sảnh; gửi lại nếu lưu lỗi |
| Lịch sử | Bộ lọc game/độ khó, thời gian, điểm và trạng thái | Xem chi tiết từng ván; phân trang |
| Xếp hạng | Chọn game và độ khó; hạng, tên hiển thị, điểm tốt nhất | Không cộng điểm ba loại game vào một bảng |
| Hồ sơ | Tên hiển thị, ảnh đại diện có sẵn, đổi mật khẩu | Sửa thông tin của chính mình |
| Cài đặt | Camera, âm thanh, độ nhạy/làm mượt, tay thuận, vùng điều khiển | Lưu tùy chọn cá nhân; kiểm tra camera |

Không mở camera ngay tại màn đăng nhập. Sảnh chỉ hiển thị ảnh tĩnh của ba game, không chạy đồng thời ba game để làm thumbnail.

Luồng thành công: Đăng nhập → Sảnh → Chọn game → Chi tiết/độ khó → Chuẩn bị tay → Tạo ván trên backend → Đếm ngược → Chơi → Kết thúc và gửi kết quả → Hiển thị điểm đã lưu.

Khi nút gửi đang chờ phản hồi, vô hiệu hóa lần bấm trùng nhưng giao diện vẫn vẽ và nhận thao tác thoát. Lỗi kết nối phải có thông báo rõ và nút thử lại.

### Chuyển đúng game khi bấm

Client có bảng ánh xạ cố định: `runner` mở RunnerGame, `platform_jump` mở PlatformJumpGame, `item_catch` mở ItemCatchGame. Mã không nằm trong danh sách phải bị từ chối, không tải hoặc thực thi đường dẫn mã nguồn do API trả về.

Một SceneManager điều phối màn hình. Rời game phải dừng vòng cập nhật của game đó; chỉ duy trì một game hoạt động và một bộ nhận diện tay. Chơi lại cần reset điểm, nhân vật, va chạm và bộ đếm, đồng thời tạo game_session mới.

## 4. Danh sách chức năng để đăng ký đề tài

Ngoài đăng ký, đăng nhập, đăng xuất và sửa profile:

1. Sảnh lựa chọn ba trò chơi, xem luật và mức độ khó.
2. Nhận diện bàn tay và chuyển thành lệnh điều khiển.
3. Hiệu chỉnh vùng điều khiển, kiểm tra camera và luyện thao tác.
4. Chơi Chạy vượt chướng ngại vật.
5. Chơi Nhảy vượt vực.
6. Chơi Hứng vật phẩm.
7. Quản lý phiên chơi: tạm dừng, tiếp tục, chơi lại, xử lý mất tay.
8. Lưu và tra cứu lịch sử, thống kê thành tích.
9. Bảng xếp hạng theo từng game và độ khó.
10. Cài đặt điều khiển và âm thanh.

Đây là nhóm chức năng sản phẩm; giảng viên có thể gộp các game hoặc các thao tác khi đánh giá. Phần quản trị backend là hỗ trợ vận hành, chưa bắt buộc làm thêm một giao diện quản trị lớn.

## 5. Tài khoản và xác thực

### Đăng ký

- Nhận username, display_name, password và password_confirm. Username 3–30 ký tự, chữ ASCII/số/gạch dưới; chuẩn hóa thành chữ thường, kiểm tra trùng bằng UNIQUE trong database.
- Mật khẩu đề xuất tối thiểu 10 ký tự, tối đa 128; không tự trim hoặc thay đổi mật khẩu. So khớp password_confirm rồi bỏ trường này.
- Hash mật khẩu bằng thư viện hỗ trợ Argon2id; chỉ lưu password_hash. Không tự viết thuật toán hash hoặc lưu mật khẩu nguyên văn.
- Tạo user với role player và user_settings mặc định trong cùng transaction. Không cho request đăng ký tự đặt role admin.
- Bản đầu không cần email, xác minh email hay quên mật khẩu qua email. Không hiển thị nút quên mật khẩu nếu chưa có quy trình phục hồi thật.

### Đăng nhập và đăng xuất

Để dễ thu hồi phiên, bản đầu chọn opaque bearer token (chuỗi ngẫu nhiên đủ mạnh), không bắt buộc JWT. Backend trả token một lần; database chỉ lưu SHA-256 của token vì token là bí mật ngẫu nhiên độ entropy cao. Mật khẩu vẫn dùng Argon2id, không dùng SHA-256 đơn thuần.

Mỗi request cần đăng nhập gửi `Authorization: Bearer <token>`. Backend tra token_hash, kiểm tra thời hạn, revoked_at và users.is_active. Thời hạn đề xuất 8 giờ; hết hạn yêu cầu đăng nhập lại, chưa cần refresh token.

Token giữ trong RAM client ở bản đầu, đóng ứng dụng thì đăng nhập lại. Đăng xuất thu hồi phiên trên server rồi xóa token local. Nếu server không liên lạc được, xóa token local và thông báo phiên server chưa được thu hồi, sẽ hết hạn theo thời gian.

Đổi mật khẩu cần mật khẩu hiện tại, hash mật khẩu mới và thu hồi toàn bộ phiên cũ; yêu cầu đăng nhập lại. Giới hạn số lần đăng nhập sai theo IP/username, trả lỗi chung cho sai thông tin để không lộ tài khoản nào tồn tại.

## 6. Database: 7 bảng cốt lõi

SQLite phù hợp bản demo một backend nhỏ. Dùng truy vấn tham số/ORM, bật `PRAGMA foreign_keys=ON` trên mỗi kết nối. Không cho client mở trực tiếp file database server. Thời gian dùng UTC; khi hiển thị chuyển sang giờ địa phương.

### 6.1 users — tài khoản

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | INTEGER | PK |
| username | TEXT | NOT NULL, UNIQUE, chuẩn hóa chữ thường |
| password_hash | TEXT | NOT NULL; không trả ra API |
| display_name | TEXT | NOT NULL |
| avatar_key | TEXT | Mã ảnh đại diện từ bộ ảnh có sẵn, có thể NULL |
| role | TEXT | player/admin; mặc định player |
| is_active | INTEGER | 0/1, mặc định 1 |
| created_at, updated_at | TEXT | UTC ISO 8601 |

### 6.2 auth_sessions — phiên đăng nhập

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | TEXT | PK UUID |
| user_id | INTEGER | FK users.id, NOT NULL |
| token_hash | TEXT | UNIQUE, NOT NULL |
| created_at, expires_at | TEXT | NOT NULL, UTC |
| revoked_at | TEXT | NULL khi chưa thu hồi |

Một user có nhiều phiên đăng nhập. Token, password_hash không xuất hiện trong log hoặc response hồ sơ.

### 6.3 games — danh mục 3 game

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | INTEGER | PK |
| code | TEXT | UNIQUE; runner/platform_jump/item_catch |
| name, description, instructions | TEXT | Tên, mô tả, luật và hướng dẫn |
| thumbnail_key | TEXT | Mã ảnh trong assets client |
| sort_order | INTEGER | Thứ tự thẻ 1–3 |
| is_active | INTEGER | 0/1 |

Seed đúng ba dòng lúc khởi tạo. Tắt game chỉ ngăn tạo ván mới; không xóa lịch sử hoặc chặn hoàn tất ván đã bắt đầu.

### 6.4 game_modes — độ khó và phiên bản luật

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | INTEGER | PK |
| game_id | INTEGER | FK games.id |
| difficulty | TEXT | easy/normal/hard |
| rules_version | INTEGER | Số phiên bản luật, >=1 |
| config_json | TEXT | Tham số từng game: tốc độ, thời hạn, lượt, bản đồ, công thức điểm |
| is_active | INTEGER | Cho phép chọn để bắt đầu ván |

UNIQUE(game_id, difficulty, rules_version). Mỗi game/độ khó chỉ có một cấu hình đang active. Khởi tạo 9 mode: 3 game × 3 độ khó, version 1.

Khi thay đổi công thức điểm hoặc luật, tạo version mới và tắt version cũ, không sửa mode đã có kết quả. Client gửi lại đúng mã phiên bản đã nhận để tránh chơi sai luật. JSON phải được backend kiểm tra theo schema của từng game.

### 6.5 user_settings — cấu hình theo người chơi

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| user_id | INTEGER | PK đồng thời FK users.id; quan hệ 1–1 |
| sound_enabled | INTEGER | 0/1 |
| volume | REAL | Từ 0 đến 1 |
| handedness | TEXT | left/right |
| smoothing_alpha | REAL | Lớn hơn 0, không quá 1 |
| control_left, control_right | REAL | 0 <= left < right <= 1 |
| camera_index | INTEGER | >=0, mặc định 0 |
| show_preview | INTEGER | 0/1 |
| updated_at | TEXT | UTC |

Camera index và hiệu chỉnh phụ thuộc thiết bị: khi dùng máy khác phải kiểm tra camera và cho hiệu chỉnh lại, không coi thiết lập cũ chắc chắn hợp lệ.

### 6.6 game_sessions — mỗi lượt chơi

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | TEXT | PK UUID do server cấp |
| user_id | INTEGER | FK users.id |
| game_mode_id | INTEGER | FK game_modes.id |
| client_request_id | TEXT | UUID của yêu cầu bắt đầu, UNIQUE cùng user_id |
| status | TEXT | created/running/completed/abandoned/expired |
| created_at, started_at, ended_at | TEXT | UTC; started/ended có thể NULL |
| expires_at | TEXT | Hạn nhận kết quả; đề xuất 2 giờ từ lúc tạo |

Client không gửi user_id để quyết định chủ ván; backend lấy từ token. Chỉ chủ ván được xem/hoàn tất/hủy ván của mình. Mỗi lần chơi lại là một dòng mới.

### 6.7 game_results — kết quả ván

| Cột | Kiểu | Ràng buộc/ý nghĩa |
|---|---|---|
| id | INTEGER | PK |
| session_id | TEXT | FK game_sessions.id, UNIQUE: mỗi ván tối đa một kết quả |
| outcome | TEXT | won/lost/time_up |
| score | INTEGER | >=0; backend tính từ số liệu theo mode |
| active_duration_ms | INTEGER | Thời gian chơi thực, không tính tạm dừng; >=0 |
| metrics_json | TEXT | Dữ liệu riêng từng game, kiểm tra schema |
| validation_status | TEXT | accepted/flagged; chưa phải xác minh chống gian lận tuyệt đối |
| validation_reason | TEXT | Lý do khi flagged, có thể NULL |
| created_at | TEXT | UTC server nhận kết quả |

Không cần bảng điểm tốt nhất, bảng lịch sử hay bảng xếp hạng riêng ở bản đầu: truy vấn từ sessions và results để tránh dữ liệu lặp, lệch nhau.

### Quan hệ và index

- users 1–N auth_sessions; users 1–1 user_settings; users 1–N game_sessions.
- games 1–N game_modes; game_modes 1–N game_sessions; game_sessions 1–0..1 game_results.
- Index game_sessions(user_id, created_at) cho lịch sử; game_sessions(game_mode_id, status) cho xếp hạng.
- Index auth_sessions(user_id, expires_at); UNIQUE token_hash phục vụ xác thực.
- Unique game_results(session_id) chống ghi kết quả trùng; unique game_sessions(user_id, client_request_id) chống tạo ván trùng khi retry.
- Không xóa cứng game/mode/user đã có kết quả trong bản đầu; dùng is_active để giữ liên kết lịch sử.

## 7. Luật chơi và dữ liệu kết quả đề xuất

Luật dưới đây phục vụ bản tự xây dựng, không suy ra đầy đủ từ ảnh. Các mức số là cấu hình khởi đầu để điều chỉnh qua thử nghiệm.

| Game | metrics_json cần gửi | Công thức điểm version 1 | Điều kiện kết thúc |
|---|---|---|---|
| Runner | obstacles_passed, coins_collected, distance_units | 10 × chướng ngại vượt qua + 20 × xu | Va chạm: lost; đạt giới hạn 120 giây: time_up |
| Platform Jump | checkpoints_reached, coins_collected, reached_finish | 100 × checkpoint + 20 × xu + 500 nếu tới đích | Tới đích: won; rơi vực/chạm gai: lost; hết 120 giây: time_up |
| Item Catch | good_caught, bad_hits, good_missed, lives_remaining | max(0, 10 × vật tốt hứng được − 5 × vật xấu va phải) | Hết 3 lượt: lost; hết 60 giây: time_up |

Trong Catch, mỗi vật xấu va phải trừ một lượt; bỏ lỡ vật tốt chưa trừ lượt ở version 1. Không cho một vật tính điểm nhiều lần. Trong Platform, mỗi checkpoint chỉ tính một lần. Số deaths trong ảnh không bắt buộc đưa vào HUD; có thể tính số ván thua từ lịch sử.

Độ khó chỉ đổi tham số phù hợp từng game: tốc độ chạy và mật độ vật cản; khoảng nhảy/bố trí nền; tốc độ rơi và tỷ lệ vật xấu. Các khoảng nhảy phải kiểm tra có thể vượt bằng vận tốc và lực nhảy đã đặt.

Backend không nhận score do client tự quyết định. Backend nhận các metrics và tính lại điểm, kiểm tra số nguyên không âm, thời gian không vượt khoảng từ started_at tới hiện tại (có dung sai nhỏ), checkpoint không vượt số có trong map, số vật không vượt mức sinh hợp lý theo mode.

Tuy vậy, client có thể sửa các metrics trước khi gửi. Tính lại điểm chỉ giảm lỗi và gian lận đơn giản; muốn bảng xếp hạng cạnh tranh đáng tin cần replay hoặc server mô phỏng xác minh, ngoài phạm vi bản đầu. Bảng xếp hạng bài tập chỉ dùng kết quả accepted.

## 8. Danh sách API backend cần làm

Tất cả đường dẫn dùng tiền tố `/api/v1`. Nội dung JSON, trừ khi sau này thêm upload. API yêu cầu đăng nhập dùng bearer token. Không gửi password_hash, token_hash ra client.

| Method | Endpoint | Quyền | Nhiệm vụ |
|---|---|---|---|
| POST | /auth/register | Công khai | Tạo user và settings; 201 hoặc 409 khi username trùng |
| POST | /auth/login | Công khai | Xác minh mật khẩu; trả access_token, expires_at, user cơ bản |
| POST | /auth/logout | Người đăng nhập | Thu hồi phiên hiện tại |
| GET | /users/me | Người đăng nhập | Lấy hồ sơ của mình |
| PATCH | /users/me | Người đăng nhập | Sửa display_name/avatar_key trong danh sách cho phép |
| POST | /users/me/change-password | Người đăng nhập | Kiểm tra mật khẩu cũ, cập nhật hash và thu hồi phiên |
| GET | /games | Người đăng nhập | Danh sách ba game active và modes có thể chơi |
| GET | /games/{code} | Người đăng nhập | Luật, hướng dẫn, các mức độ khó và thumbnail_key |
| GET | /users/me/settings | Người đăng nhập | Lấy tùy chọn |
| PUT | /users/me/settings | Người đăng nhập | Kiểm tra và lưu tùy chọn |
| POST | /game-sessions | Người đăng nhập | Nhận game_mode_id, client_request_id; tạo hoặc trả ván đã tạo từ cùng request |
| POST | /game-sessions/{id}/start | Chủ ván | created → running; ghi started_at bằng giờ server |
| POST | /game-sessions/{id}/finish | Chủ ván | Nhận outcome, active_duration_ms, metrics; kiểm tra, tính điểm, lưu kết quả |
| POST | /game-sessions/{id}/abandon | Chủ ván | created/running → abandoned khi thoát/chơi lại |
| GET | /game-sessions/{id} | Chủ ván | Xem trạng thái để khôi phục khi phản hồi mạng bị mất |
| GET | /users/me/history | Người đăng nhập | Lọc game_code/difficulty/status, phân trang |
| GET | /users/me/statistics | Người đăng nhập | Số ván hoàn thành, điểm tốt nhất theo mode, tổng thời gian chơi |
| GET | /leaderboards | Người đăng nhập | Nhận game_code, difficulty, rules_version; trả xếp hạng phân trang |
| GET | /health | Công khai | Kiểm tra server hoạt động, không lộ cấu hình bí mật |

Mã lỗi chung: 401 thiếu/hết hạn phiên; 403 không có quyền; 404 không tồn tại; 409 xung đột trạng thái hoặc dữ liệu trùng; 422 dữ liệu không hợp lệ; 429 quá nhiều yêu cầu. Trả lỗi có code, message và field_errors khi phù hợp; không trả stack trace.

### Quản trị tối thiểu — có thể làm sau

Admin có thể xem thống kê tổng, bật/tắt game, tạo version cấu hình mới và xem kết quả flagged. Mỗi route admin phải kiểm tra role phía backend. Tạo admin bằng công cụ khởi tạo riêng, không qua đăng ký công khai. Cấu hình ban đầu có thể seed bằng script, chưa cần thêm dashboard quản trị để tránh tăng khối lượng.

## 9. Ví dụ luồng API một ván

1. Đăng nhập thành công, giữ token trong RAM.
2. GET /games → chọn `item_catch`, difficulty normal, lấy game_mode_id.
3. Camera sẵn sàng → POST /game-sessions với UUID client_request_id mới → nhận session_id.
4. Đếm ngược → POST /game-sessions/{id}/start. Nếu mất phản hồi, GET trạng thái hoặc gửi start lại; không tự tạo thêm ván.
5. Chơi tại máy. Bộ nhận diện chỉ phát move_x/jump/confirm; game tự xử lý va chạm và thời gian.
6. Kết thúc → dừng nhận input, tạo báo cáo. POST finish với ví dụ:

```json
{
  "outcome": "time_up",
  "active_duration_ms": 60000,
  "metrics": {
    "good_caught": 18,
    "bad_hits": 1,
    "good_missed": 4,
    "lives_remaining": 2
  }
}
```

7. Backend tính điểm 175, lưu transaction và trả kết quả chính thức. Không lấy score ở request.
8. Màn kết thúc hiện điểm và trạng thái Đã lưu. Chơi lại tạo session mới; về sảnh giữ đăng nhập nhưng đóng camera khi không cần.

## 10. Vòng đời ván, retry và mất mạng

- created → running qua start; running → completed qua finish. created/running → abandoned khi chủ ván thoát; created/running quá hạn → expired.
- start gọi lại với ván running trả cùng started_at. Ván đã kết thúc không được start lại.
- finish thực hiện kiểm tra trạng thái và insert result trong cùng transaction; cập nhật session thành completed chỉ khi insert thành công.
- finish gọi lại cùng payload cho ván completed trả kết quả đã lưu; payload khác trả 409. So sánh báo cáo đã chuẩn hóa từ các trường lưu, không tính lại bằng luật mới.
- Ván abandoned/expired không được ghi finish. Khi bị khóa tài khoản, request mới bị từ chối kể cả đang giữ token.
- Trong lúc đang chơi, mạng lỗi không làm dừng camera hoặc game. Kết quả cuối ván có thể lưu tạm cục bộ với session_id, user_id và payload để gửi lại trước expires_at.
- Khi đổi tài khoản, không gửi kết quả của tài khoản trước bằng token mới. Hàng chờ phải gắn user_id; file tạm không chứa token hoặc mật khẩu. Dữ liệu gửi lại quá hạn hiển thị Chưa được lưu chính thức, không vào bảng xếp hạng.
- Bản đầu yêu cầu backend hoạt động để tạo ván chính thức. Nếu muốn có chế độ luyện offline về sau, ghi rõ không tính xếp hạng, không tự dựng session_id server.

Tạm dừng chỉ tác động game local. Không cần gọi API theo mỗi lần pause. Client báo tổng active_duration_ms; server chỉ kiểm tra giới hạn hợp lý, chưa xác minh được toàn bộ thời gian hoạt động thực từ báo cáo này.

## 11. Lịch sử, thống kê và xếp hạng

- Lịch sử của user: join game_sessions → game_modes → games, LEFT JOIN game_results để thấy cả ván bỏ dở/chưa có điểm.
- Thống kê: chỉ tính completed có result accepted cho số ván hợp lệ và tổng thời gian; điểm tốt nhất tách theo game/difficulty/rules_version.
- Xếp hạng: lấy điểm tốt nhất của mỗi user trong cùng game, độ khó và version; điểm giảm dần. Đồng điểm ưu tiên lần đạt điểm đó sớm hơn, sau đó user_id để thứ tự ổn định.
- Không dùng thời gian ngắn hơn làm tiêu chí chung vì game sống sót và game về đích có mục tiêu khác nhau.
- Không đưa user bị vô hiệu hóa hay kết quả flagged vào xếp hạng. Hiển thị tên và avatar, không lộ username đăng nhập hoặc token.
- Giới hạn page_size tối đa 50. Bản đầu truy vấn trực tiếp, chưa cần Redis hoặc bảng tổng hợp.

## 12. Cấu trúc thư mục dự kiến

Các đường dẫn tính từ `D:\GesturePlay`:

| Đường dẫn | Nhiệm vụ |
|---|---|
| client/main.py | Chạy ứng dụng và SceneManager |
| client/screens/ | login, register, lobby, game_detail, calibration, pause, result, history, leaderboard, profile, settings |
| client/games/base_game.py | Giao diện chung start/update/render/pause/reset/get_result |
| client/games/runner.py | Chạy vượt chướng ngại |
| client/games/platform_jump.py | Nhảy vượt vực |
| client/games/item_catch.py | Hứng vật phẩm |
| client/core/camera.py | Đọc webcam, giữ ảnh mới nhất |
| client/core/hand_tracker.py | Một MediaPipe HandLandmarker dùng chung |
| client/core/gesture_controller.py | Ánh xạ landmarks thành move_x, jump_pressed, confirm_pressed |
| client/core/scene_manager.py | Chuyển màn hình, bảo đảm chỉ một game hoạt động |
| client/core/metrics.py | Đo FPS và độ cũ kết quả |
| client/services/api_client.py | Bearer token, timeout, gọi mạng ngoài vòng lặp vẽ |
| client/services/auth_state.py | User và token trong RAM |
| client/services/result_queue.py | Kết quả chưa gửi, gắn tài khoản; không lưu token |
| client/assets/ | Ảnh, font hỗ trợ tiếng Việt, âm thanh, bản đồ |
| client/models/hand_landmarker.task | Mô hình dùng local |
| backend/app/main.py | Khởi tạo FastAPI, đăng ký router |
| backend/app/config.py | Đọc cấu hình từ môi trường |
| backend/app/database.py | Kết nối DB, transaction, bật foreign keys |
| backend/app/models/ | Định nghĩa 7 bảng |
| backend/app/schemas/ | Validate request/response; tách model public khỏi dữ liệu hash |
| backend/app/routers/ | auth, users, games, sessions, statistics, leaderboards |
| backend/app/services/auth.py | Hash mật khẩu, token, thu hồi phiên, kiểm tra quyền |
| backend/app/services/scoring.py | Công thức điểm theo game và version |
| backend/app/services/sessions.py | Vòng đời ván, idempotency, timeout |
| backend/app/seed.py | Tạo ba game và chín mode ban đầu |
| backend/migrations/ | Thay đổi cấu trúc DB có phiên bản |
| backend/data/gestureplay.db | Database server, không đưa vào thư mục assets |
| tests/ | Kiểm tra backend và luật game quan trọng |
| requirements-client.txt | Phiên bản thư viện client đã thử thành công |
| requirements-backend.txt | Phiên bản thư viện backend đã thử thành công |

Đây là cấu trúc đề xuất, chưa có các module này được viết. Có thể giữ nguyên core đang làm rồi chuyển dần vào client/core, tránh viết lại chỉ để đổi thư mục.

## 13. Trình tự thực hiện vừa sức

| Giai đoạn | Cần hoàn thành | Điều kiện chuyển bước |
|---|---|---|
| 1 — Lõi tay | Camera, một bàn tay, thanh ngang, mất tín hiệu, đo độ trễ | Điều khiển ổn định trên laptop |
| 2 — Một game | Hứng vật phẩm đơn giản và màn kết quả local | Luật, va chạm, điểm, pause hoạt động |
| 3 — Backend nền | DB/migration/seed, đăng ký/đăng nhập/đăng xuất, hồ sơ, settings | Tài khoản tách biệt, hash/token đúng |
| 4 — Lưu ván | Tạo/start/finish/abandon, retry, lịch sử | Gửi lại không nhân đôi điểm |
| 5 — Ba game | Sảnh ba thẻ, Runner, Platform Jump, chung controller | Mỗi thẻ mở đúng game, rời game không còn vòng lặp cũ |
| 6 — Hoàn thiện | Xếp hạng, thống kê, âm thanh, lỗi mạng và kiểm tra hiệu năng | Chạy thử đủ ba game và luồng tài khoản |

Không cần xây toàn bộ backend trước khi biết nhận diện tay có đủ mượt. Phần lõi tay và game chạy local, backend không cần AI, GPU, WebSocket hoặc lưu video.

## 14. Kiểm tra bắt buộc khi triển khai

1. Username trùng bị chặn; mật khẩu không xuất hiện nguyên văn trong DB/log.
2. Phiên hết hạn/đăng xuất không dùng tiếp được; player không đổi role bằng request profile.
3. Tài khoản A không xem hoặc hoàn tất ván tài khoản B dù biết session_id.
4. Mỗi thẻ mở đúng game; đổi game không mở thêm camera hoặc mô hình.
5. Một lần chụm tạo một lần nhảy; giữ chụm không gây nhảy liên tục; ở trên không không nhảy lần nữa.
6. Mất tay dừng input và tạm dừng game; có tay lại phải xác nhận tiếp tục.
7. Finish gửi hai lần chỉ có một kết quả; gửi số âm/JSON sai/version không hợp lệ bị từ chối.
8. Bảng xếp hạng không trộn game, độ khó hoặc version; kết quả flagged bị loại.
9. Mất phản hồi start/finish có thể truy vấn hoặc retry mà không tạo ván/điểm trùng.
10. Chạy từng game 5 phút, ghi FPS nhận diện và độ cũ dữ liệu; mạng chậm không khóa giao diện.

## 15. Tài liệu tham khảo chính thức

- FastAPI security và hash mật khẩu: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
- SQLite foreign keys: https://www.sqlite.org/foreignkeys.html
- MediaPipe Hand Landmarker Python: https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/python

Tài liệu FastAPI minh họa JWT; thiết kế này chủ động chọn phiên opaque token để thu hồi dễ hơn. Các bảng, endpoint, công thức điểm và UI ở đây là đề xuất riêng cho GesturePlay. Đây là hồ sơ thiết kế để bắt đầu lập trình, chưa phải backend chạy được, database đã khởi tạo hoặc báo cáo đo hiệu năng.
