# Giao diện ứng dụng GesturePlay — DEAD SIGNAL

Đã triển khai giao diện trước theo yêu cầu ngày 07/11/2026. Chưa kết nối dịch vụ tài khoản/database; URL và public key sẽ được cung cấp sau.

## Cách mở

Tại thư mục dự án chạy `npm run web`, mở `http://127.0.0.1:8080`. Chọn **TRẢI NGHIỆM GIAO DIỆN** ở màn đăng nhập để vào trang chính và chơi game hiện có. Dùng `npm run windows` cho cửa sổ Windows.

Biểu mẫu đăng nhập/đăng ký kiểm tra dữ liệu và thông báo chưa kết nối khi gửi. Không tạo tài khoản giả, không lưu mật khẩu và không báo đăng ký thành công khi chưa có dịch vụ.

## 3.1. Tài khoản và dữ liệu cá nhân

- **Đăng ký:** tên hiển thị, email, mật khẩu từ 8 ký tự, xác nhận mật khẩu, hiện/ẩn mật khẩu, trạng thái chờ và lỗi.
- **Đăng nhập:** email/mật khẩu và chuyển sang biểu mẫu đăng ký.
- **Hồ sơ:** xem email, đổi tên hiển thị, số lượt chơi, lượt sống sót và điểm cao nhất.
- **Lịch sử:** các lượt sinh tồn đã kết thúc, thời gian, điểm, quái hạ được, lõi tín hiệu, độ chính xác, độ khó, phương thức điều khiển, nguyên nhân thất bại. Lọc tất cả/sống sót/thất bại.
- **Thoát trải nghiệm/đăng xuất:** trở lại biểu mẫu đăng nhập, dừng camera.

Phần kết quả và lịch sử đã được mở rộng với màn chi tiết, tài nguyên cuối lượt, thống kê theo độ khó, trạng thái lưu và gửi lại theo mã lượt cố định. Xem [mục 3.11](RESULTS_HISTORY.md).

Ở bản hiện tại, người dùng vào bằng chế độ trải nghiệm được ghi rõ **chưa đăng nhập**. Tên và kết quả chỉ tồn tại trong bộ nhớ của phiên hiện tại, mất khi thoát trải nghiệm hoặc tải lại ứng dụng. Lịch sử ban đầu để trống; chỉ hiển thị kết quả từ lượt chơi thực tế. Mỗi lượt kết thúc được ghi một lần; hủy giữa lượt và luyện tập không ghi kết quả.

Thiết lập được lưu trên thiết bị bằng vùng riêng cho ID người chơi. Phiên trải nghiệm dùng vùng `player.preview.signal`. Chưa đồng bộ thiết lập, hồ sơ hoặc lịch sử lên mạng.

## 3.2. Kết nối và hiệu chỉnh tay

Trang **Kết nối tay** sử dụng bộ nhận diện Python có sẵn:

- Xem webcam, trạng thái kết nối, trạng thái camera/bộ nhận diện, tay trái/phải và tốc độ nhận diện.
- Chọn một tay/hai tay, chỉ số webcam 0–20 và cách mở camera.
- Kết nối, thử lại hoặc ngắt camera.
- Quan sát vị trí tay trên bảng kiểm tra con trỏ; đặt lại tâm của bảng kiểm tra.
- Ghi tư thế tay mở và tay chụm, có phản hồi độc lập cho từng tay.
- Điều chỉnh độ nhạy con trỏ/ngắm và di chuyển; đổi vai hai tay.

Độ nhạy di chuyển thay đổi mức dịch tay cần thiết để đạt tốc độ tối đa. Độ nhạy ngắm thay đổi khoảng cách tâm ngắm theo chuyển động tay. Nút đặt lại tâm trong trang kết nối dùng cho bảng kiểm tra; game tự nhận tâm khi tay sẵn sàng. Camera vẫn do một HandBridge dùng chung quản lý; mở trang hồ sơ/kết nối không làm game tự bắt đầu bằng nắm tay.

## 3.3. Hướng dẫn và thực hành

Hướng dẫn được sửa theo game đi lại trong **một thị trấn**, thay cho thao tác kéo điện/camera của bản phòng trực cũ. Mục Cách sống sót có luật, bàn phím, cảm ứng, một tay và hai tay.

Trang **Thực hành** có 11 bài theo thứ tự: di chuyển, bắn trúng bia, ngồi xổm, nằm, đứng dậy, nạp đạn, đổi súng, tương tác cửa, ẩn nấp, băng bó và lướt né. Có mục tiêu đánh dấu, lời nhắc và phản hồi đúng rồi chuyển bài. Sử dụng đúng thao tác của game; có thể chọn bàn phím/cảm ứng/webcam để thử.

Đây là một lượt luyện riêng trên cùng bản đồ: không mất máu do quái, không sinh đợt quái, không hết giờ cứu hộ, đủ trang bị để thử, không tính điểm hoặc ghi lịch sử. Bia quái đứng yên để tập ngắm. Hoàn thành hoặc quay về sẽ không làm thay đổi tài nguyên của lượt sinh tồn.

## 3.4. Chuẩn bị lượt sinh tồn

- Mục tiêu giữ mạng sống 180 giây, 5 đợt tấn công; 3 lõi là mục tiêu phụ.
- Chọn **Dễ**: quái di chuyển chậm hơn 22%, sát thương thấp hơn 30%; **Thường** giữ tốc độ/sát thương tiêu chuẩn.
- Chọn bàn phím/cảm ứng, một tay hoặc hai tay, đọc hướng dẫn trước khi vào.
- Bắt đầu khởi tạo lượt mới với vật phẩm, máu, đạn và trạng thái bản đồ ban đầu.
- Giữ cách xác nhận hai tay đã có: nắm tay phải khoảng 0,5 giây để Bắt đầu/Tiếp tục; mở cả hai tay để ván chạy.
- Bảng kết quả và nút chơi lại tiếp tục sử dụng cùng bản đồ; kết quả có độ khó để phân biệt.

## Điểm ghép dịch vụ tài khoản sau này

`flutter_app/lib/account/models.dart` định nghĩa `AccountGateway`: đăng nhập, đăng ký, đăng xuất, đổi tên, lấy lịch sử, lưu kết quả. `GesturePlayApp` nhận triển khai này qua tham số `gateway`. Bản mặc định là `PendingAccountGateway`, luôn trả lời rõ rằng chưa kết nối.

Khi có URL/public key và cấu trúc database, triển khai adapter thật cùng phiên đăng nhập, xác nhận email và quyền truy cập dữ liệu của từng người chơi. Hiện không gọi Supabase và không cần key để xem hoặc chơi bản giao diện.

## Kiểm tra

Các kiểm tra mới bao gồm biểu mẫu sai/đúng, trạng thái chưa kết nối, đổi tên, lịch sử trống/kết quả thật, thoát rồi vào lại, kết nối/hiệu chỉnh giả lập, thiết lập tách theo người chơi, độ khó và hoàn thành đủ 11 bài bằng thao tác game. Bố cục được kiểm tra ở 1280×800, 844×390 và 390×844. Chưa coi kết nối giả lập là kiểm chứng nhận diện cử chỉ bằng webcam thật.

Ảnh giao diện được lưu trong `docs/design_assets/portal/`.

Kết quả kiểm tra sau khi bổ sung mục 3.11: **233 kiểm tra Flutter đạt**, `flutter analyze` không báo lỗi. Phần Python trước đó đạt **75 kiểm tra** và không thay đổi trong lần bổ sung kết quả/lịch sử. Đã thử trực tiếp trên web việc vào chế độ trải nghiệm, đổi tên hồ sơ và mở bài luyện; không thấy lỗi console trong luồng đó. Bộ khởi chạy cũng tìm được Flutter còn hoạt động tại `D:/android` khi các đường dẫn trong Downloads đã thiếu SDK.

Ảnh tham khảo: [Đăng nhập](design_assets/portal/login.png), [Trang chính](design_assets/portal/home.png), [Hồ sơ](design_assets/portal/profile.png), [Hiệu chỉnh tay](design_assets/portal/connection.png), [Thực hành](design_assets/portal/practice.png), [Điện thoại](design_assets/portal/mobile-login.png). Ảnh đăng ký có dữ liệu minh họa phục vụ kiểm tra biểu mẫu; không phải tài khoản đã được tạo.
