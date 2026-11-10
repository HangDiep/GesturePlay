# 3.11. Kết quả và lịch sử cá nhân

Áp dụng cho bản DEAD SIGNAL một thị trấn. Game hiện không sử dụng điện năng của bản phòng trực cũ; tài nguyên cuối lượt là **máu, đạn trong súng, đạn dự trữ của khẩu đang dùng và túi máu**.

## Chức năng đã bổ sung

1. **Kết quả vừa chơi:** thắng/thua, độ khó, điểm, thời gian sống sót, quái đã hạ, lõi, độ chính xác và tài nguyên cuối lượt. Số liệu được chốt một lần khi kết thúc. Có nút mở chi tiết ngay tại bảng kết quả.
2. **Lưu kết quả:** mỗi lượt được đưa vào sổ kết quả của người chơi. Khi có dịch vụ tài khoản thật, ứng dụng ghi bản chờ trên thiết bị trước khi gửi; gửi thành công mới chuyển sang Đã lưu tài khoản.
3. **Lịch sử:** mới nhất trước, kèm ngày giờ, độ khó, điểm và kết quả. Lọc theo thắng/thua và Dễ/Thường. Có tải lại lịch sử tài khoản khi kết nối hoạt động trở lại.
4. **Chi tiết:** chọn Xem chi tiết ở một lượt để đọc toàn bộ thông tin, ngày bắt đầu/kết thúc, nguyên nhân thua, trang bị, tài nguyên, mã lượt và trạng thái lưu. Kết quả cũ không có trường tài nguyên sẽ hiện Chưa ghi nhận.
5. **Thống kê:** tổng lượt hoàn thành, số lượt thắng và điểm cao nhất; bảng riêng cho Dễ và Thường. Tính từ các lượt duy nhất, bao gồm lượt thua; không tính thực hành hoặc lượt bỏ giữa chừng. Khi chưa tải được đầy đủ lịch sử tài khoản, ứng dụng thông báo rõ thống kê chỉ dựa trên dữ liệu đang có.
6. **Trạng thái lưu:** chỉ trong phiên, chờ gửi, đang lưu, đã lưu và lưu lỗi. Có Thử lưu lại cho từng lượt và gửi lại toàn bộ lượt chờ. Phân biệt lỗi lưu tài khoản với lỗi bản sao trên thiết bị; yêu cầu mạng bị treo có thời hạn 12 giây.
7. **Chống trùng:** UUID được cấp khi bắt đầu mỗi lượt, kể cả chơi lại cùng map/cùng seed. Một lượt kết thúc chỉ được ghi một lần; gửi lại giữ nguyên UUID và nội dung. Gộp yêu cầu đồng thời cho cùng một lượt, đối chiếu lịch sử máy chủ để nhận ra kết quả đã được lưu.

## Trạng thái trong bản hiện tại

Theo yêu cầu làm giao diện trước, **chưa cấu hình đăng nhập/database online**. Vào bằng Trải nghiệm giao diện: kết quả, chi tiết và thống kê dùng dữ liệu từ lượt chơi thật trong phiên, không lưu lên tài khoản và không tồn tại sau khi thoát trải nghiệm/tải lại trang. Không có nút giả lập lưu thành công trong sản phẩm.

Các trạng thái lưu online, hàng chờ khôi phục khi mở lại và gửi lại khi mạng hoạt động đã được triển khai trong `ResultJournal`, kiểm tra bằng dịch vụ tài khoản giả lập trong bộ test. Chúng sẽ dùng dịch vụ thật khi triển khai `AccountGateway` sau khi có URL/key và cấu trúc database.

## Ràng buộc khi ghép database

- `AccountGateway.saveResult(result, playerId: ...)` phải xác thực tài khoản hiện tại và ghi theo khóa duy nhất **(user_id, round_id)** ở phía máy chủ. Gửi cùng mã phải thành công với bản ghi đã có; không tạo ID mới khi gửi lại. Chỉ kiểm tra trùng trong Flutter không đủ để bảo đảm qua nhiều thiết bị.
- Phản hồi thành công chỉ trả sau khi máy chủ đã xác nhận ghi. Nếu máy chủ đã nhận nhưng phản hồi bị mất, gửi lại vẫn sử dụng mã cũ.
- Lịch sử phải được giới hạn theo chủ tài khoản. Bản sao/hàng chờ trên thiết bị cũng nằm ở vùng riêng theo ID tài khoản; kết quả trả về muộn sau đăng xuất không đi vào tài khoản kế tiếp.
- Ngày giờ lưu dạng UTC và hiển thị theo giờ của thiết bị.
- Khi không đọc được bộ nhớ lịch sử, giữ nguyên dữ liệu cũ và thông báo; không âm thầm ghi đè lên phần không đọc được.

## Kiểm tra

Đã có kiểm tra UUID, lưu/khôi phục số liệu, thống kê theo độ khó, thứ tự/lọc lịch sử, xem chi tiết, chốt tài nguyên từ lượt game thật, mỗi lần chơi lại có ID mới, gửi đồng thời, mất mạng, mất phản hồi sau khi máy chủ đã nhận, thời hạn yêu cầu mạng, gửi lại, tách tài khoản và lỗi bộ nhớ thiết bị. Bố cục kiểm tra ở 1280×800, 844×390 và 390×844.

Mã chính: `survival/round_result.dart`, `account/result_journal.dart`, `account/history_page.dart`, `account/result_widgets.dart`.

Kết quả: `flutter analyze` không báo lỗi; toàn bộ **233 kiểm tra Flutter đạt**, trong đó có 17 kiểm tra mới dành cho kết quả/lịch sử. Các trường hợp lưu online dùng dịch vụ giả lập, chưa phải xác nhận kết nối database thật.

Ảnh: [Bảng kết quả từ lượt thử trong game](design_assets/portal/result-summary.png), [Thống kê và lịch sử](design_assets/portal/history-statistics.png), [Chi tiết trên điện thoại](design_assets/portal/result-detail-mobile.png). Hai ảnh sau dùng dữ liệu mẫu của bộ kiểm tra, không phải lịch sử tài khoản thật.
