# Trang bị, túi đồ, phòng tương tác và boss hai giai đoạn

Áp dụng bản Flutter một map ngày 03/11/2026. Giữ mục tiêu sống đủ 180 giây, 23 quái qua năm đợt và ba lõi tùy chọn. Người chơi chỉ gây sát thương bằng súng; quái vẫn có thể giết người chơi.

## Ba loại súng

Khởi đầu với súng trường 24/120 và một túi máu. Súng lục và shotgun nằm trong map; đi sát để tự nhặt, không bắt buộc đổi khẩu đang cầm. Phím 1/2/3 chọn lục/trường/shotgun, V chuyển qua các súng đã sở hữu. Mỗi khẩu giữ riêng băng và đạn dự trữ; đổi súng hủy nạp đang dở, không hoàn lại đạn đã bắn. Có thể chọn bằng ba ô HUD hoặc trong túi đồ.

| Súng | Băng / dự trữ tối đa | Sát thương | Khoảng cách giữa phát | Nạp | Tầm |
|---|---|---|---|---|---|
| Lục | 12 / 96 | 32 | 0,34 giây | 1,05 giây | 480 |
| Trường | 24 / 180 | 28 | 0,18 giây | 1,65 giây | 800 |
| Shotgun | 6 / 36 | 8 mảnh × 10, theo số mảnh trúng | 0,90 giây | 2,20 giây | 330 |

Shotgun tiêu tốn một viên mỗi phát, bắn quạt; độ chính xác thống kê theo phát, không cộng tám lần cho tám mảnh. Đạn đang bay giữ sát thương/tốc độ của khẩu đã bắn kể cả khi đổi súng. Hộp đạn bổ sung cho khẩu đang cầm: lục 24, trường 48, shotgun 8; không vượt sức chứa.

Điểm nhặt trong tọa độ map: súng lục (1190,1460), shotgun (1200,2070), chìa kho (1260,1670). Mở bản đồ M để thấy vật phẩm và hai phòng.

## Túi đồ và băng bó

I mở túi, tạm dừng thời gian và chiến đấu; I/Esc hoặc nút Trở lại để đóng. Túi có ba ô súng, tối đa ba túi máu và chìa kho. Đồ đầy vẫn nằm lại tại chỗ/hòm, có thể quay lại lấy. Chơi lại không giữ trang bị lượt trước.

H dùng túi máu: đứng yên 2,8 giây để hồi 40 HP, tối đa 100. Chỉ trừ một túi khi hoàn thành. Di chuyển, bắn, trúng đòn, đổi súng, nạp đạn, đổi tư thế hoặc lướt sẽ ngắt; chưa hoàn thành thì chưa mất túi. Tạm dừng đóng băng băng bó. Trúng đòn chí mạng ở khung hoàn thành vẫn thua. Nhặt túi máu không tự hồi ngay. Nút H, thanh tiến độ và động tác băng bó phản hồi trên HUD.

## Cửa, kho và đường vòng

Vẫn là thị trấn liên tục 4400×3600. Phòng trú nằm cạnh chợ đêm, kho nằm gần ngõ dẫn vườn hoang; các tuyến phố và đường vòng hiện có giữ vai trò cắt đuôi. Các phòng có tường, sàn, vật cản, cửa động và tiếp tế thật, không chuyển sang map khác.

- **Phòng trú:** vùng (420,1700)–(780,2000), cửa ban đầu mở, không cần chìa. Có góc ẩn và tủ thuốc: hai túi máu, 24 viên trường, 12 viên lục.
- **Kho tiếp tế:** vùng (2800,2080)–(3200,2440), cửa khóa. Nhặt chìa ở phố cổ rồi E trước cửa để mở; chìa dùng một lần, cửa đã mở khóa không cần chìa nữa. Hòm có hai túi máu, 48 viên trường, 24 viên lục, tám viên shotgun và shotgun.
- **E / nút Tương tác:** đóng/mở cửa hoặc lấy đồ hòm gần nhất có đường tiếp cận. Không tương tác xuyên tường; không đóng khi người/quái đứng trong lá cửa.
- Cửa đóng chặn di chuyển, tầm nhìn, đạn súng và cầu ma lực. Đóng/mở cập nhật ngay đường tìm đường của quái.
- Cửa có 120 độ bền. Quái có dấu người chơi ở phía đối diện tìm tới cửa và phá bằng sát thương riêng, mỗi 1,3 giây. Cửa vỡ mở vĩnh viễn trong lượt đó; phòng trú không bảo đảm an toàn vô hạn.
- Hòm chỉ lấy lượng mang được; đồ còn dư giữ lại. Trên bản đồ có tên phòng và trạng thái cửa mở/đóng.

## Boss giai đoạn hai

Boss có 300 HP và giáp giảm sát thương còn một phần ba khi chưa hở. Khi còn sống và HP ≤150, boss chuyển dạng một lần, báo trên đầu/thông điệp và khựng 1,2 giây.

Giai đoạn hai di chuyển nhanh hơn 18%, tụ ba cầu tím trong 1,05 giây, hồi phép cơ bản 4,8 giây. Boss luân phiên cầu ma lực, đòn nện và hai **vết nứt trên đất**: một tại vị trí lúc ra chiêu của người chơi, một cách 140 đơn vị theo hướng di chuyển gần nhất. Vùng không bám theo người. Vòng đỏ bán kính 90 báo trước 1,4 giây rồi gây 24 sát thương; hai vùng cùng đòn chỉ tính sát thương một lần. Có thể chạy ra ngoài, lướt hoặc dùng tường cắt đường sát thương.

Sau vụ nổ boss hở giáp ít nhất 1,5 giây; sau loạt cầu hở 2,4 giây. Đây là lúc phản công. Tối đa bốn vùng đang hiện; boss chết hủy vùng chưa nổ. Tạm dừng đóng băng vùng/đạn; chết đúng hạn 180 giây vẫn là thất bại. Đòn phép chỉ thuộc quái.

## Bàn tay và cảm ứng

Vòng bàn tay mở bằng nắm 0,8 giây có chín lựa chọn, ba hàng:

| Trái | Giữa | Phải |
|---|---|---|
| Nạp đạn | Ẩn / rời ẩn | Lướt |
| Đứng | Ngồi | Nằm |
| Băng bó | Đổi súng | Tương tác |

Hạ lòng bàn tay lần lượt để chọn hàng hai/ba, dịch trái/phải, chụm rồi thả xác nhận. Mở tay ổn định mới tiếp tục; đặt lại tâm để tránh tự bước/bắn. Cảm ứng dùng ba ô súng, nút H/I và nút E khi gần cửa/hòm. Phần nhận diện webcam và ngưỡng dữ liệu cũ giữ nguyên.

## Kiểm tra

`test/town_features_test.dart` kiểm tra đạn độc lập, shotgun, gián đoạn băng bó, cửa/đường đi, chìa, đồ còn dư, quái phá cửa, boss đổi dạng/vùng nổ/cùng mã đòn và hàng thứ ba điều khiển tay. `town_widget_test.dart` kiểm tra luồng thực cùng giao diện 1280×800, 844×390, 390×844. Các bài tay sử dụng dữ liệu giả lập qua đúng bộ nhận; chưa thay cho thử bàn tay thật trước webcam.

Toàn bộ **178 bài kiểm tra** đã qua; `flutter analyze` không báo lỗi. Ngày 04/11/2026 bổ sung luật cây/bụi đi xuyên được, nhà/tường vẫn chặn người và quái; kiểm tra di chuyển thực qua cây và dừng trước chân nhà. Ảnh thật từ bộ vẽ: [túi đồ](design_assets/town_inventory.png), [phòng trú](design_assets/town_refuge.png), [boss giai đoạn hai](design_assets/town_boss_phase_two.png), [vòng bàn tay](design_assets/town_hand_equipment.png).

Bản web release và Windows release đều dựng thành công. Đã mở web release trong trình duyệt để thử bắt đầu/chơi lại, đi nhặt súng lục, chọn bằng phím 1, mở túi I, trang bị súng trường từ túi và bắn. Đạn từng súng giữ riêng; nhật ký trình duyệt không có lỗi/cảnh báo. [Ảnh túi đồ trên web](design_assets/town_inventory_web.png). Dịch vụ và tab kiểm tra tạm đã đóng; chạy lại bằng `npm run web` như trước.

Lượt thử tải Windows profile riêng với chín AI, trong đó hai boss ở giai đoạn hai, ghi nhận 14,6 nhịp/giây trong 10 giây; p95 raster 41,65 ms, dựng 4,26 ms, 1265×682 ở tỷ lệ điểm ảnh 1,25. Đây là bài tải nặng, không phải số FPS web hoặc webcam; chưa thể bảo đảm 60 FPS. Số liệu đầy đủ trong `design_assets/town_equipment_benchmark.json`. Không dùng số 41,4 FPS của lượt trước để đại diện bản mới có hai boss giai đoạn hai.

Nguồn luật: `lib/survival/gear.dart`, `lib/exploration/model.dart`, `lib/exploration/world.dart`. Giao diện/vẽ: `lib/survival/app.dart`, `scene.dart`, `painter.dart`; ánh sáng dùng ảnh đã có, không thêm texture lớn.
