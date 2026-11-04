# Quái dùng ma lực, người dùng súng

Áp dụng cho bản Flutter một map theo yêu cầu ngày 03/11/2026. Người chơi có ba loại súng, đạn và túi máu dùng có thời gian; không có phép, đèn chớp hay bẫy điện. E dùng để tương tác cửa/hòm. Đứng, ngồi, nằm, chạy, lướt và ẩn nấp được giữ. Vòng bàn tay có ba hàng: nạp đạn / ẩn / lướt, đứng / ngồi / nằm, băng bó / đổi súng / tương tác. Chi tiết trang bị, phòng và giai đoạn hai tại [SURVIVAL_SYSTEMS.md](SURVIVAL_SYSTEMS.md).

| Quái | Tấn công tầm xa | Thời gian tụ | Sát thương | Hồi phép cơ bản | Tầm bắt đầu |
|---|---|---|---|---|---|
| Kẻ gây nhiễu | Một cầu xanh, giữ khoảng cách với người chơi | 0,95 giây | 14 | 4,5 giây | 520 đơn vị |
| Vật chủ | Ba cầu tím hình quạt | 1,25 giây | Tối đa 20 cho cùng một loạt | 6,5 giây | 620 đơn vị |
| Vật chủ giai đoạn hai | Ba cầu tím + hai vùng nổ cố định | Cầu 1,05 giây; vùng 1,4 giây | Cầu tối đa 20/loạt; vùng 24/đòn | Cầu 4,8 giây; vùng 6 giây | 620 đơn vị |

Boss chuyển dạng một lần khi còn sống và HP ≤150/300. Hai vùng đỏ nằm tại vị trí người chơi lúc ra chiêu và cách 140 đơn vị theo hướng di chuyển gần nhất; không bám theo người. Rời bán kính 90 hoặc dùng vật chắn để né; sau nổ boss hở ít nhất 1,5 giây. Giết boss hủy vùng chưa nổ. Cửa đóng chặn cả súng và ma lực, nhưng quái có thể phá cửa.

Quái nhanh và bọc giáp giữ vai trò áp sát. Có một quái gây nhiễu từ đợt đầu, thay một quái nhanh; tổng số quái vẫn là 23, tối đa 9 con sống cùng lúc. Hồi phép có thêm khoảng lệch nhỏ theo quái để giảm việc bắn đồng loạt. Tối đa 2 quái tụ phép đồng thời, tối đa 18 cầu ma lực đang bay.

Phải nhìn thấy người chơi, có đường bắn không bị chắn và đủ khoảng cách thì mới bắt đầu tụ. Không bắt đầu phép mới chỉ dựa vào tiếng động hay vị trí cuối của người đang ẩn. Dấu nhắm khóa vào vị trí người chơi lúc bắt đầu; quái đứng lại khi tụ. Di chuyển ngang tránh được hướng đã khóa. Cầu bay hữu hạn, không bám theo người, chạm vật cản sẽ tan. Có thể bị đánh khi đang ngồi, nằm hoặc ẩn nếu cầu đã phóng có đường tới người; các tư thế không tạo miễn nhiễm ma lực.

Bắn trúng Kẻ gây nhiễu khi đang tụ sẽ ngắt phép và buộc chờ 2 giây. Giáp boss giữ phép đang tụ khi nhận đạn thường; sau khi tung phép boss lộ điểm yếu 2,4 giây để người chơi phản công. Đòn nện cận chiến cũ của boss vẫn có thời gian nạp 1,4 giây và yếu 3,2 giây. Giết quái hủy phép chưa phóng; cầu đã phóng tiếp tục bay. Lướt dùng cửa sổ né đòn hiện có. Một loạt boss có chung mã đòn, kể cả các cầu chạm ở thời điểm khác nhau cũng không cộng dồn ba lần sát thương.

Phép gây mất máu và chết thật; màn thua ghi nguyên nhân trúng ma lực. Nếu chết đúng lúc hết 180 giây vẫn thua. Tạm dừng đóng băng thời gian tụ, hồi phép và đường bay. Kết thúc dừng chiến đấu; chơi lại tạo model mới, không giữ cầu hoặc phép từ lượt trước.

`exploration/model.dart` tính AI, khóa hướng, đường bay, va chạm đoạn thẳng và sát thương; `survival/rules.dart` giữ các tham số. `survival/scene.dart` vẽ vòng tụ, đường nhắm đứt đoạn, cầu có đuôi, tia va chạm và thanh báo trạng thái bằng hình ánh sáng được dùng lại. Chế độ giảm hiệu ứng giữ cầu, dấu nhắm và cảnh báo; bỏ các hạt quay phụ. Không thêm ảnh nền lớn hoặc engine 3D.

Âm thanh được tổng hợp bằng `tools/make_magic_audio.py`, ra ba tệp `magic_charge.wav`, `magic_cast.wav`, `magic_hit.wav` trong `flutter_app/assets/audio/`. Phép dùng kênh riêng, không bị tiếng súng cắt mất; tuân theo âm lượng, tắt âm và dừng khi tạm dừng/kết thúc.

Kiểm tra gồm sát thương từ xa, dấu báo trước, khóa hướng và né, chặn bởi vật cản, ẩn nấp, ngắt phép, giáp/điểm yếu boss, cùng mã đòn, giới hạn số cầu, đóng băng khi dừng và chết tại hạn cứu hộ. Kiểm tra giao diện tại 1280×800, 844×390 và 390×844, điều khiển tay giả lập, cùng một lượt sống đủ 180 giây chỉ dùng súng, tài nguyên bình thường và di chuyển. Ảnh thực tế từ bộ vẽ trong `docs/design_assets/town_magic_charge.png` và `town_magic_volley.png`.

Lượt đo Windows profile với 9 quái có AI, ma lực, súng, mưa/sương và camera di chuyển: khoảng 41,4 nhịp khung hình/giây trong 10 giây, p95 dựng 6,71 ms, raster 39,27 ms, cửa sổ 1265×682, tỷ lệ điểm ảnh 1,25. Báo cáo tại `docs/design_assets/town_magic_benchmark.json`. Chưa bật webcam; số liệu không phải phép đo bản web hoặc bảo đảm 60 FPS. Dữ liệu 45,9 FPS trong tài liệu đồ họa trước là lượt đo trước khi thêm ma lực.
