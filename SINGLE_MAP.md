# DEAD SIGNAL Thị trấn bị phong tỏa

Bản Flutter 2D hiện tại có một map nhìn chéo từ trên xuống, áp dụng màn đầu trong `Thiet_ke_hoan_thien_GesturePlay123.docx`. Yêu cầu mới nhất chỉ làm một map được ưu tiên so với chiến dịch bốn màn trong Word. Giao diện dùng bối cảnh chơi thật làm nền trang chủ, không lấy ảnh chụp tham khảo làm bản đồ tĩnh.

## Chơi

Chạy `npm run web` từ thư mục dự án, mở http://127.0.0.1:8080. Chọn Bàn phím / Cảm ứng hoặc Bàn tay / Webcam rồi bấm Bắt đầu sinh tồn. Bản Windows dùng `npm run windows` hoặc `Chay_GesturePlay.bat`.

Sống đủ 180 giây qua năm đợt để thắng. Thu ba lõi tín hiệu là mục tiêu phụ, không cần quay về điểm xuất phát. Có bốn loại quái: nhanh 45 HP, bọc giáp 135 HP, gây nhiễu 70 HP, vật chủ 300 HP. Quái truy đuổi và tìm đường quanh vật cản. Quái thường có động tác chuẩn bị đánh; vật chủ nạp đòn 1,4 giây, giáp nhận một phần ba sát thương và lộ yếu 3,2 giây sau đòn mạnh. Nhiễu chỉ ảnh hưởng cảm biến.

Theo yêu cầu ngày 03/11/2026, chỉ quái có phép; người chơi dùng súng, né và ẩn nấp. Quái gây nhiễu tụ phép 0,95 giây rồi phóng cầu xanh gây 14 sát thương. Boss tụ phép 1,25 giây rồi phóng ba cầu tím hình quạt; cùng một loạt chỉ gây tối đa 20 sát thương lên một người chơi, sau đó boss hở giáp 2,4 giây. Đạn phép bay theo đường đã khóa, không tự bám người; nhà, xe và vật chắn chặn đạn. Có vòng tụ phép, dấu nhắm, cảnh báo và tiếng phép ở kênh riêng. Bắn trúng quái gây nhiễu khi đang tụ sẽ ngắt đòn; boss vẫn có giáp nên cần né rồi phản công. Có quái dùng phép ngay đợt đầu. Chi tiết tại `docs/COMBAT_MAGIC.md`.

## Thị trấn mở rộng và nhịp căng thẳng

Một map liên tục có kích thước 4.400 × 3.600, gấp bốn diện tích bản cũ 2.200 × 1.800. Phố cổ nối với chợ đêm, sân đền và vườn hoang bằng đường phố và ngõ vòng; không có bước tải hay chọn map khác giữa các khu. Camera, va chạm và tìm đường sử dụng toàn bộ diện tích mới. Bấm M hoặc nút bản đồ để xem đường, lõi, vật phẩm và chỗ ẩn; thời gian chơi tạm dừng khi xem bản đồ.

Nhà, tường, xe và vật chắn cứng chặn di chuyển; nhân vật và quái không đi xuyên phần chân nhà. Phòng trú/kho chỉ đi qua lối cửa khi cửa mở hoặc đã vỡ. Cây và bụi cây trong thị trấn đi xuyên được, vẫn dùng làm vùng ngụy trang; hình cây giữ nguyên, không đổi thành vật cản vô hình. Mái/cành vươn ra ngoài phần chân nên có thể che lối đi phía sau.

Máu còn 30 trở xuống làm viền màn hình đỏ theo nhịp, số máu đổi đỏ và hiện thông báo NGUY KỊCH. Có nhịp tim ở kênh âm thanh riêng; hồi máu vượt ngưỡng sẽ tắt cảnh báo. Chế độ giảm hiệu ứng giữ viền đỏ tĩnh thay vì nhịp sáng.

Quái tới gần trong khoảng 380 đơn vị phát tiếng hú kèm phụ đề cảnh báo. Tiếng hú có kênh riêng để tiếng súng không cắt mất, giảm âm khi có vật chắn và chỉ phát lại sau tối thiểu 9 giây. Quái đang choáng, đang xuất hiện hoặc đã chết không tạo cảnh báo áp sát. Tạm dừng, kết thúc hoặc tắt âm thanh sẽ dừng các kênh âm thanh căng thẳng.

Có bảy chỗ ẩn được đánh dấu bằng vòng xanh ở bụi cây, sau xe, các góc khuất và phòng trú. Đứng gần rồi bấm G hoặc nút trên màn hình. Trong chế độ bàn tay, giữ nắm mở vòng kỹ năng, giữ tay ở giữa hàng trên để chọn ẩn rồi chụm thả. Khi ẩn, nhân vật nín thở tối đa 10 giây; di chuyển, bắn hoặc lướt sẽ rời chỗ ẩn. Sau khi rời cần chờ 3 giây mới ẩn tiếp. Hết hơi làm lộ tiếng động.

Quái nhìn theo khoảng cách và đường nhìn không bị chắn. Mất dấu thì tới vị trí cuối đã thấy để điều tra, tìm quanh đó rồi tuần tra; không biết vị trí mới của người đang ẩn. Tiếng súng và chạy nhanh có thể dẫn chúng tới kiểm tra. Quái tới rất gần và nhìn thấy vẫn có thể phát hiện, tấn công người đang ẩn. Núp trước mặt quái đang đuổi không bảo đảm cắt đuôi được.

Năm đợt có tổng 23 quái, tối đa 9 con sống đồng thời. Điểm sinh ở quanh khu vực hiện tại của người chơi, có khoảng cách an toàn và 1,2 giây xuất hiện trước khi hoạt động. Hai lần mất điện vào khoảng giây 52 và 128, mỗi lần 14 giây, thu hẹp vùng sáng và tạo cơ hội trốn hoặc đổi vị trí. Vật phẩm được bổ sung ở các khu mới để khuyến khích khám phá.

Người chơi có 100 HP, không tự hồi; khởi đầu với súng trường 24/120 và một túi máu. Có thể nhặt thêm súng lục và shotgun, mỗi khẩu giữ đạn riêng. Hộp đạn bổ sung cho khẩu đang cầm. Túi chứa tối đa ba túi máu; H băng bó 2,8 giây hồi 40 HP, di chuyển/bắn/trúng đòn sẽ ngắt và chưa mất túi. I xem túi đồ. Điểm đạn/máu bổ sung mở ở giây 105. Người chơi không có phép, đèn chớp hoặc bẫy điện; E dùng để tương tác cửa/hòm. Tư thế, chạy, lướt và ẩn không gây sát thương. Chi tiết thông số súng tại [luật trang bị](docs/SURVIVAL_SYSTEMS.md).

Phòng trú và kho tiếp tế được đặt trong cùng thị trấn. E đóng/mở cửa hoặc lấy tiếp tế. Cửa chặn người/quái, tầm nhìn, súng và ma lực; có 120 độ bền và bị quái phá được. Kho cần chìa tìm ở phố cổ; đồ dư trong hòm được giữ lại. Bản đồ M có tên hai phòng và trạng thái cửa. Boss còn ≤150 HP chuyển giai đoạn hai, đi nhanh hơn, tụ cầu nhanh hơn và tạo hai vùng nổ báo trước 1,4 giây. Rời vòng đỏ rồi bắn khi boss hở giáp.

Máu quái về 0 thì chết, dừng AI và chỉ cộng điểm một lần; phép chưa tung sẽ hủy. Đạn phép đã phóng vẫn bay tới khi chạm người/vật chắn hoặc hết tầm. Máu người chơi về 0 thì dừng chiến đấu, phát hoạt ảnh ngã rồi hiển thị thất bại. Đòn trực tiếp có cửa sổ miễn đòn 0,45 giây; mỗi mã đòn chỉ gây sát thương một lần lên người chơi. Chết cùng lúc hết giờ vẫn là thua. Chơi lại tạo lại đầu map với 100 HP, 24/120 đạn, không có phép/đèn/bẫy, điểm và mục tiêu trở về 0. Không giữ điểm hoặc vật phẩm lượt thua.

## Ba tư thế chiến đấu

Cả đứng, ngồi xổm và nằm sấp đều ngắm, bắn và thay đạn được. X chuyển ngồi/đứng; Z chuyển nằm/đứng. Ba nút tư thế trên màn hình chọn trực tiếp, dùng được với chuột và cảm ứng. Đổi ngồi mất 0,22 giây; hạ xuống hoặc đứng dậy từ nằm mất 0,55 giây. Trong lúc đổi tư thế không bắn được; tạm dừng đóng băng thời gian chuyển.

| Tư thế | Di chuyển | Khả năng ẩn và dùng vật chắn |
|---|---|---|
| Đứng | Đi 190, chạy 280 đơn vị/giây | Dễ bị thấy hơn, tiếng bước chân lớn hơn; súng bắn qua vật chắn thấp nhưng không xuyên nhà, xe hoặc tường cao. |
| Ngồi xổm | Đi 105 đơn vị/giây, không chạy | Quái nhìn thấy ở khoảng cách ngắn hơn. Đặt vật chắn thấp giữa bạn và quái để che người; lúc bắn nhô lên và lộ vị trí trong khoảng 0,6 giây. |
| Nằm sấp | Bò 55 đơn vị/giây, không chạy | Khó bị thấy hơn, đặc biệt trong bụi rậm; tiếng bò nhỏ. Đạn ở tầm thấp nên bị tường thấp hoặc thùng chắn. Cần bò ra cạnh vật chắn để có đường bắn. |

Space từ tư thế ngồi có thể bật dậy lướt. Space khi nằm chỉ bắt đầu đứng dậy; sau khi đứng xong bấm tiếp để lướt. Động tác đứng dậy vẫn có thể nhận đòn. Mọi tư thế đều có thể bị quái phát hiện ở rất gần và bị giết; bắn súng tạo tiếng động thu hút quái. Tư thế nằm trong bụi là ngụy trang thụ động, tách biệt với thao tác G ẩn nấp nín thở tối đa 10 giây.

Trong chế độ một bàn tay, vòng chọn có ba hàng: hàng trên nạp đạn/ẩn/lướt; hàng giữa đứng/ngồi/nằm; hàng dưới băng bó/đổi súng/tương tác. Hạ lòng bàn tay để chọn hàng rồi dịch trái/giữa/phải. Chụm thả xác nhận rồi mở tay. Tâm di chuyển được đặt lại khi trở lại để không tự bước hoặc bắn.

`assets/town/stances.png` là atlas riêng cho ba hướng ngồi và ba hướng nằm, mỗi hướng có các khung ngắm, di chuyển/bò, bắn, thay đạn, trúng đòn và đổi tư thế. `stances.json` lưu vùng từng khung ảnh và được kiểm tra khi tải. Hình được tạo bằng image_gen tích hợp theo `docs/design_assets/stance_asset_prompt.txt`, giữ nhân vật áo tối khăn đỏ; tư thế nằm bắn không dùng ảnh chết.

## Điều khiển

Chế độ **Hai tay / Webcam** có cử chỉ trực tiếp và bảng 12 thao tác hoàn toàn bằng tay. Tay di chuyển nắm ngắn để đổi tư thế, chụm ngắn để cửa/ẩn, chụm giữ rồi thả để băng bó; tay ngắm nắm ngắn để nạp, nắm giữ rồi thả để đổi súng. Hai tay đi và bắn độc lập. Xem đầy đủ [TWO_HAND_CONTROLS.md](docs/TWO_HAND_CONTROLS.md). Bảng bên dưới là điều khiển bàn phím và chế độ một tay.

| Thao tác | Bàn phím và chuột | Bàn tay |
|---|---|---|
| Di chuyển | WASD hoặc mũi tên | Mở tay, dịch lòng bàn tay quanh tâm |
| Ngắm và bắn | Chuột, giữ chuột trái; F bắn dự phòng | Chụm ngón cái và ngón trỏ, dịch tay để ngắm |
| Thay đạn | R | Nắm ngắn rồi mở |
| Chọn súng | 1 lục / 2 trường / 3 shotgun; V đổi | Hàng dưới, giữa: đổi súng đã sở hữu |
| Băng bó | H hoặc nút túi máu | Hàng dưới, trái |
| Cửa / tiếp tế | E hoặc nút gần vật thể | Hàng dưới, phải |
| Túi đồ | I hoặc nút ba lô | Nút ba lô trên màn hình |
| Ngồi xổm / đứng | X hoặc nút Ngồi | Hạ tay ở vòng kỹ năng, chọn giữa |
| Nằm / đứng | Z hoặc nút Nằm | Hạ tay ở vòng kỹ năng, chọn phải |
| Vòng thao tác | Nút R, G, Space và các nút tư thế | Nắm 0,8 giây mở vòng chọn; tay trái chọn nạp đạn, giữa chọn ẩn, phải chọn lướt né; chụm thả rồi mở tay |
| Ẩn / rời chỗ ẩn | G hoặc nút trên màn hình | Chọn biểu tượng ẩn ở giữa vòng kỹ năng |
| Bản đồ toàn khu vực | M hoặc nút bản đồ | Dùng nút bản đồ trên màn hình |
| Lướt | Space; đang nằm thì đứng dậy trước | Nâng nhanh lòng bàn tay đang mở, rồi hạ về tâm để dùng lại; đang nằm thì đứng dậy trước |
| Chạy | Shift | Dùng tốc độ đi thường |
| Hiệu chỉnh | F1 tay mở, F2 chụm, C đặt lại tâm | Các nút hiệu chỉnh trên bàn phím |
| Tạm dừng | Esc hoặc P | Mất tay/dữ liệu trễ quá 250 ms tự tạm dừng |

Mất tay không tự tiếp tục khi có tín hiệu trở lại. Mở tay rõ rồi bấm Tiếp tục. Có thể đổi sang bàn phím trong màn tạm dừng. Webcam chỉ bật khi chọn chế độ bàn tay. Nhận diện trên Android vẫn dùng dịch vụ Python chạy trên laptop; bản cảm ứng không cần webcam.

Cảm ứng: cần trái đi lại, kéo cần phải ngắm/bắn, chạm giữa cần phải bắn quái gần nhất có đường bắn. Nút giữa lướt, nút R thay đạn nằm phía trên cần phải. Giao diện thích ứng màn hình ngang và dọc.

## Hình ảnh và cấu trúc

`assets/town/ground-v2.png` là nền đá ướt hạt nhỏ; `architecture-v2.png` chứa sáu kiểu công trình; `details-v2.png` chứa 12 nhóm cây, đồ ven đường và mặt nước. `environment-v2.json` xác định vùng ảnh được kiểm tra khi tải. `props.png` bổ sung xe tải, cổng và vật chắn. `actors.png` chứa bảy hàng, tám khung mỗi hàng, gồm ba hướng nhân vật và bốn loại quái. Hướng trái lật từ hướng phải. Hoạt ảnh theo di chuyển, bắn, nạp, bị thương, lướt, chết; quái có chuẩn bị đánh, đánh, choáng và chết.

Camera chiếu mặt đất theo góc chéo; nhà và nhân vật giữ thẳng đứng, sắp lớp theo độ sâu sau phép chiếu. Đường đi, va chạm và AI vẫn ở tọa độ map. Di chuyển bàn phím/cảm ứng/bàn tay và ngắm đều dùng phép đổi ngược để khớp hướng trên màn hình. Mái nhà và cây giảm đậm khi che người chơi; vùng va chạm tách khỏi phần hình mái/cành. Nhà phố được đưa về gần lề đường; một túi máu bổ sung chuyển tới (1250,1440) để không nằm trong nhà mới. Các chi tiết nhỏ trang trí không tạo thêm vật cản vô hình.

Hình tạo mới bằng công cụ tích hợp image_gen; prompt đầy đủ lưu ở `docs/design_assets/town_asset_prompts.txt`. Không dùng logo, watermark hoặc nhân vật từ ảnh tham khảo. Cài đặt có âm lượng và giảm mưa/sương. Chỉ vẽ hình trong vùng nhìn, số quái sống giới hạn 9, hiệu ứng có thời gian kết thúc.

Prompt bộ ảnh mới và lần làm sạch alpha lưu ở `docs/design_assets/town_v2_prompts.txt`. Chi tiết bộ vẽ và kiểm tra: `docs/GRAPHICS_V2.md`.

Tiếng hú và nhịp tim là âm tổng hợp tạo mới bằng `tools/make_tension_audio.py`, lưu thành PCM WAV trong `assets/audio/`. Có thể tái tạo bằng Python chuẩn mà không cần tải bản ghi hoặc thư viện ngoài.

`lib/survival/rules.dart` cấu hình thời gian và đợt cho map. `exploration/model.dart` là nguồn duy nhất tính máu, đạn, va chạm và thắng/thua. `survival/painter.dart` chỉ vẽ. Các tệp cũ trong `exploration/app.dart` và `exploration/painter.dart` giữ để tham khảo, không phải giao diện mặc định.

Tài khoản, database và lịch sử online vẫn chưa nằm trong phạm vi. Phiên bản này không có màn đi ngang, NPC hộ tống hoặc chuyển chiến dịch vì chỉ triển khai một map.
