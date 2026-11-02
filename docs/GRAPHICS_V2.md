# Đồ họa phố cổ GesturePlay

Bản nâng cấp vẫn dùng Flutter 2D trên một thị trấn 4.400 × 3.600. Phố cổ, chợ đêm, sân đền và vườn hoang là các khu trong cùng một map. Nhà nhiều tầng, mái ngói, quầy chợ, miếu, cây lớn và đồ ven đường được tạo riêng để thay đổi cảnh thực tế. Đứng, ngồi, nằm, chiến đấu hai chiều, ẩn nấp và điều khiển tay tiếp tục dùng luật hiện có.

## Hình và ánh sáng

- `flutter_app/assets/town/architecture-v2.png`: ba kiểu nhà, quầy chợ, miếu và chòi vườn; chọn theo vị trí thay vì lặp một mẫu.
- `flutter_app/assets/town/details-v2.png`: bụi rậm, dây leo, chuối, cây lớn, xe kéo, xe đạp, chum, tượng, đèn, lan can, nước và sen.
- `flutter_app/assets/town/ground-v2.png`: nền đá nhỏ, lặp bằng shader dùng lại, đặt theo mặt đất chiếu chéo.
- `environment-v2.json`: 6 vùng công trình và 12 vùng chi tiết, kiểm tra số lượng và giới hạn ảnh khi tải. `tools/index_town_art.py` chỉ phân tích alpha và tạo tọa độ cắt; không chỉnh pixel PNG.

Ảnh được tạo bằng image_gen tích hợp, alpha gốc được giữ; prompt và lần chỉnh alpha tại `docs/design_assets/town_v2_prompts.txt`. Bộ ảnh là tài nguyên mới cho game, không cắt hai ảnh minh họa làm nền chơi.

Đèn vàng có vùng sáng và vệt phản chiếu, nước phản chiếu xanh, bóng tiếp đất, lớp sương xa, mưa, vệt khí lạnh quanh quái. Chế độ giảm hiệu ứng tắt mưa/sương chuyển động. `lighting.dart` tạo các hình ánh sáng nhỏ một lần rồi dùng lại, gồm cả viền nguy kịch và vùng tối mất điện; không tính phản xạ hay bóng 3D theo thời gian thực.

## Camera và điều khiển

`survival/view.dart` là phép chiếu duy nhất: mặt đất `(x,y)` thành `(x + 0.45y, 0.62y - 0.26x)`. Bộ vẽ đặt hình nhà/nhân vật thẳng đứng tại điểm chân đã chiếu. Độ sâu được sắp lại theo chân sau phép chiếu. Mái/cây che nhân vật sẽ mờ bớt, gồm cả khi đứng, ngồi hoặc nằm.

WASD, cần cảm ứng và lòng bàn tay đổi từ hướng màn hình sang hướng map. Độ mạnh của cần/tay và tốc độ của ba tư thế được giữ. Chuột dùng phép chiếu ngược kèm cao độ súng của từng tư thế để tâm ngắm khớp con trỏ. Chụm ngón vẫn dừng di chuyển và bắn; mất tay vẫn tạm dừng.

`scene.dart` vẽ; `scenery.dart` lưu sẵn bố trí chi tiết trang trí theo map bằng bộ nhớ đệm yếu; `painter.dart` xuất bộ vẽ và vẽ cảm biến. Vùng nhìn quyết định vật cần vẽ, gồm lề để mái/cây cao không bị cắt đột ngột. Sáu ảnh đang nạp tương đương khoảng 36 MiB điểm ảnh RGBA, các hình ánh sáng thêm khoảng 1,3 MiB, chưa tính bản sao GPU, âm thanh, Flutter hay webcam; tổng PNG khoảng 14,6 MiB. Đây là ước lượng tài nguyên ảnh, không phải mức RAM của cả game.

## Kiểm tra

Các kiểm tra bao gồm phép chiếu qua lại và biên camera ở ba tỷ lệ màn hình, hướng đi/ngắm bằng tay, ngắm chuột ở ba tư thế, đường tới vật phẩm/chỗ ẩn, giao diện và chơi lại. Bản đồ lớn, luật chiến đấu và các kiểm tra dự án trước được giữ.

`flutter_app/tool/town_benchmark.dart` là công cụ đo riêng cho Windows, chạy 3 giây làm nóng rồi 10 giây với 9 quái có AI, camera di chuyển và hiệu ứng. Công cụ đóng khi xong, ghi JSON; không dùng làm điểm vào của game. Chạy bằng `flutter run -d windows --profile -t tool/town_benchmark.dart`. Không đo đồng thời lúc chạy kiểm tra ảnh hoặc biên dịch. Kết quả native không đại diện cho bản web hoặc khi bật nhận dạng webcam.

Lượt đo profile ngày 02/11/2026 sau khi dùng lại hình ánh sáng: 45,9 lượt vẽ/giây theo ticker trong 10 giây, 454 mẫu thời gian khung hình, p95 build 3,75 ms và raster 40,43 ms; cửa sổ 1265 × 682, tỷ lệ điểm ảnh 1,25, 9 quái đang sống, chưa bật webcam. Đây là một lượt đo ngắn tại môi trường kiểm tra, không bảo đảm 60 FPS hay kết quả giống nhau trên mọi trình duyệt. Báo cáo lưu tại `docs/design_assets/town_v2_benchmark.json`.

Chạy game bình thường từ gốc dự án: `npm run web`. Dừng lần chạy cũ, chạy lại và dùng Ctrl+F5 để nạp tài nguyên mới.
