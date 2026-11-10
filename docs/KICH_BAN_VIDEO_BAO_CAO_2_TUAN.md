# Kịch bản video báo cáo tiến độ hai tuần — GesturePlay: DEAD SIGNAL

Thời lượng dự kiến: khoảng 6 phút. Người trình bày xưng “em”, dùng cho báo cáo với thầy/cô. Nội dung dựa trên mã nguồn, tài liệu và kết quả kiểm tra hiện có tại ngày 10/11/2026.

## 1. Nội dung có thể báo cáo

| Nhóm công việc | Kết quả hiện có | Mức độ cần nói rõ |
|---|---|---|
| Hướng phát triển | Chuyển hướng sang Flutter 2D, tập trung một thị trấn sinh tồn có nhân vật đi lại | Đây là bản hiện tại; các khu trong thị trấn thuộc cùng một map |
| Đồ họa, môi trường | Góc nhìn chéo, phố cổ, nhà, cây, xe, ánh đèn, mưa, sương, hoạt ảnh nhân vật/quái | Đã có trong bản game; chưa cam kết mức FPS cố định |
| Luật chơi và chiến đấu | Sống 180 giây, 5 đợt, 4 loại quái, người dùng súng, quái có ma lực, boss 2 giai đoạn | Có thắng/thua, sát thương, quái chết và chơi lại |
| Trang bị và tương tác | Súng lục/trường/shotgun, đạn riêng, túi đồ, băng bó, cửa, chìa kho, ẩn nấp, đứng/ngồi/nằm, né | Có thể demo trực tiếp bằng bàn phím/cảm ứng |
| Điều khiển tay | Python nhận diện webcam, truyền lệnh sang Flutter; một tay/hai tay, hiệu chỉnh, phân vai, tạm dừng khi mất tay | Có kiểm tra tự động/mô phỏng; cần tiếp tục kiểm thử trọn lượt bằng webcam thật |
| Giao diện ứng dụng | Đăng nhập/đăng ký, trải nghiệm, hồ sơ, kết nối tay, 11 bài thực hành | Đăng nhập thật chưa kết nối dịch vụ tài khoản |
| Kết quả và lịch sử | Kết quả cuối lượt, tài nguyên còn lại, chi tiết, lọc lịch sử và thống kê theo độ khó | Phiên trải nghiệm chỉ giữ kết quả trong phiên |
| Luồng lưu online | Mã lượt riêng, trạng thái lưu, chờ gửi và gửi lại, tách dữ liệu theo tài khoản | Đã kiểm tra với dịch vụ giả lập; chờ URL/key, adapter và database thật |
| Kiểm tra, bản chạy | Lần kiểm tra gần nhất: 233 bài Flutter đạt, 75 bài Python đạt; web/Windows dựng được, Android có APK và đã cài/khởi chạy trong giả lập | Android còn vấn đề cửa sổ/cảnh báo giả lập; Python chưa chạy trực tiếp trong APK |

Không có nhật ký công việc từng ngày đầy đủ, nên video báo cáo theo nhóm kết quả thay vì gán ngày hoàn thành cụ thể cho từng chức năng. Lịch sử Git có các mốc chuyển 3D sang 2D, thay hình ảnh vào 02/11 và chỉnh bàn tay vào 04/11; các thay đổi tiếp theo còn trong thư mục làm việc.

## 2. Chuẩn bị cảnh quay

Chạy bản web từ thư mục dự án:

```powershell
cd D:\GesturePlay
npm run web
```

Mở `http://127.0.0.1:8080`, chọn **Trải nghiệm giao diện**. Tải thử game một lần để các hình ảnh sẵn sàng. Dùng độ khó Dễ cho phần demo di chuyển và chiến đấu. Chọn vùng quay chỉ bao gồm cửa sổ ứng dụng, giữ chữ rõ và âm thanh game nhỏ hơn giọng đọc.

Quay thành các đoạn riêng rồi ghép theo bảng dưới. Với lượt sinh tồn, có thể ghi đủ một lượt và chọn các đoạn có hành động để đưa vào video. Giữ đúng kết quả thắng hoặc thua thực tế. Sau khi lượt kết thúc, quay lịch sử ngay trong cùng phiên trải nghiệm để có dữ liệu thật.

Phần bàn tay: thử webcam trước khi quay. Nếu nhận diện hoạt động ổn định, quay thêm 10–20 giây tay điều khiển thực tế. Nếu chưa ổn định, quay bảng kết nối/hiệu chỉnh và bài thực hành bằng bàn phím; giới thiệu đúng rằng luồng cử chỉ còn đang được kiểm thử.

Phần Android: có thể cho thấy file `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`; thêm đoạn ứng dụng trên giả lập khi cửa sổ đã thao tác được. Ghi rõ đây là bản Android đang kiểm thử.

## 3. Thứ tự quay và lời thuyết trình

### 00:00–00:25 — Giới thiệu

**Hình quay:** Trang chính DEAD SIGNAL, tên dự án và bối cảnh thị trấn.

**Lời đọc:**

“Em chào thầy/cô. Trong video này, em xin báo cáo tiến độ hai tuần gần đây của dự án GesturePlay, với trò chơi sinh tồn mang tên DEAD SIGNAL. Phần em tập trung là phát triển bản game Flutter 2D, mở rộng môi trường, bổ sung cơ chế chiến đấu, điều khiển bằng bàn tay và các giao diện quản lý người chơi.”

### 00:25–01:15 — Đồ họa, bản đồ và mục tiêu

**Hình quay:** Chọn Dễ, Bàn phím/Cảm ứng, bắt đầu. Di chuyển qua phố, ngõ và cây; bấm M xem toàn khu vực rồi đóng bản đồ.

**Lời đọc:**

“Ở bản hiện tại, em tập trung vào một bản đồ thị trấn liền mạch. Các khu phố cổ, chợ đêm, sân đền và vườn hoang là những khu vực trong cùng bản đồ. Nhân vật có thể đi lại, tìm đường vòng và sử dụng các vị trí ẩn nấp.

Về hình ảnh, em đã bổ sung nhà cửa, cây cối, xe, ánh đèn, mưa, sương và hoạt ảnh để tạo không khí ma mị. Nhà và vật chắn có va chạm; cây và bụi được dùng cho việc di chuyển, ngụy trang. Mục tiêu chính là sống sót trong 180 giây qua năm đợt tấn công. Thu thập lõi tín hiệu là mục tiêu phụ để tăng điểm.”

### 01:15–02:45 — Chiến đấu, trang bị và môi trường

**Hình quay:** Bắn quái; nạp R; đổi tư thế X/Z; né Space; mở túi I; nhặt/đổi súng nếu đã sở hữu; dùng H khi mất máu; tương tác cửa E khi ở gần. Chọn những thao tác làm được rõ nhất trong lượt quay.

**Lời đọc:**

“Phần chiến đấu đã có máu, sát thương và trạng thái chết cho cả người chơi lẫn quái. Người chơi chỉ dùng súng để gây sát thương, còn một số quái có thể sử dụng ma lực từ xa. Đòn phép có dấu hiệu báo trước để người chơi né hoặc dùng vật chắn.

Game có ba loại súng là súng lục, súng trường và shotgun. Mỗi loại có tốc độ bắn, tầm bắn và lượng đạn riêng. Em cũng đã bổ sung túi đồ và túi máu; băng bó cần thời gian nên người chơi phải chọn vị trí an toàn.

Nhân vật có ba tư thế đứng, ngồi xổm và nằm, với tốc độ và khả năng bị phát hiện khác nhau. Người chơi còn có thể lướt né, ẩn nấp, đóng mở cửa và tìm chìa khóa để tiếp cận kho tiếp tế. Boss có hai giai đoạn và thay đổi cách tấn công khi còn ít máu. Khi người chơi sắp hết máu, màn hình có cảnh báo đỏ và âm thanh để phản hồi tình trạng nguy hiểm.”

### 02:45–03:40 — Điều khiển tay và thực hành

**Hình quay:** Trang Kết nối tay; trạng thái webcam, vị trí tay, độ nhạy. Mở Thực hành và thực hiện vài bài. Chèn clip nhận diện tay thật nếu đã thử thành công.

**Lời đọc:**

“Điểm riêng của GesturePlay là luồng điều khiển bằng bàn tay. Python xử lý webcam và nhận diện cử chỉ, sau đó truyền lệnh sang Flutter. Chế độ hai tay phân vai: một tay di chuyển, tay còn lại ngắm và bắn. Các cử chỉ khác được dùng để thay đạn, đổi súng, đổi tư thế, băng bó và tương tác.

Em đã bổ sung màn kiểm tra kết nối, trạng thái phát hiện tay, hiệu chỉnh và độ nhạy. Phần thực hành có 11 bài để làm quen thao tác, không tính điểm hay tiêu hao tài nguyên của lượt sinh tồn thật. Luồng cử chỉ đã có kiểm tra tự động; em đang tiếp tục kiểm thử bằng webcam thật để đánh giá độ ổn định và độ trễ.”

### 03:40–04:45 — Giao diện, kết quả và lịch sử

**Hình quay:** Bảng kết quả từ lượt vừa chơi → Xem chi tiết → trang chính → Lịch sử → lọc độ khó → Hồ sơ. Lướt qua biểu mẫu đăng nhập/đăng ký bằng một đoạn quay riêng nếu cần.

**Lời đọc:**

“Về giao diện ứng dụng, em đã xây dựng các màn đăng nhập, đăng ký, hồ sơ và chế độ trải nghiệm. Các biểu mẫu có kiểm tra dữ liệu nhập. Phần đăng nhập thật hiện chưa kết nối database, nên bản demo này sử dụng chế độ trải nghiệm.

Sau mỗi lượt sinh tồn, ứng dụng hiển thị kết quả, độ khó, điểm, thời gian sống sót và tài nguyên còn lại. Người chơi có thể mở chi tiết, xem lịch sử, lọc kết quả và theo dõi tổng lượt, lượt thắng cùng điểm cao nhất theo từng độ khó.

Ở chế độ trải nghiệm, dữ liệu chỉ giữ trong phiên hiện tại. Em đã chuẩn bị luồng lưu và gửi lại theo mã lượt cố định để hạn chế trùng dữ liệu, đồng thời kiểm tra với dịch vụ giả lập. Phần lưu tài khoản online sẽ được hoàn thiện khi ghép database thật.”

### 04:45–05:25 — Kiểm tra và bản Android

**Hình quay:** Hiển thị ngắn kết quả test cuối trong nhật ký, sơ đồ bằng chữ Flutter ↔ Python, file APK hoặc giả lập đang chạy nếu ổn định.

**Lời đọc:**

“Về kiểm tra, lần chạy gần nhất ghi nhận 233 bài Flutter và 75 bài Python đạt. Các bài kiểm tra tập trung vào luật chiến đấu, chuyển trạng thái, điều khiển, kết quả và việc gửi lại dữ liệu.

Em đã dựng được bản web, Windows và tạo APK Android. Bản Android đã được cài và khởi chạy trong giả lập, tuy nhiên môi trường giả lập vẫn đang được xử lý thêm để thao tác ổn định. Phần Python nhận diện tay hiện chạy trên laptop; chưa được tích hợp để xử lý camera trực tiếp trong ứng dụng Android.”

### 05:25–06:00 — Công việc tiếp theo và kết thúc

**Hình quay:** Trở lại trang chính hoặc một cảnh game rõ, ít chuyển động. Có thể thêm ba dòng: Database — Kiểm thử tay thật — Tối ưu Android.

**Lời đọc:**

“Trong giai đoạn tiếp theo, em sẽ ưu tiên kết nối tài khoản và database, hoàn thiện việc lưu lịch sử online, kiểm thử cử chỉ trong điều kiện sử dụng thực tế và tối ưu trải nghiệm trên Android. Em cũng sẽ cho người dùng thử để đánh giá mức độ dễ điều khiển và nhịp chiến đấu.

Kết quả hiện tại là một bản game có vòng chơi sinh tồn, chiến đấu và các giao diện hỗ trợ. Phần cần hoàn thiện tiếp là dữ liệu online, độ ổn định của điều khiển tay và trải nghiệm di động. Em xin kết thúc phần báo cáo tại đây. Em cảm ơn thầy/cô đã theo dõi.”

## 4. Bằng chứng nên xuất hiện trong video

| Nội dung báo cáo | Cảnh hoặc tài liệu để đối chiếu |
|---|---|
| Gameplay, map, quái, trang bị | Quay trực tiếp một lượt trong game; `SINGLE_MAP.md`, `docs/SURVIVAL_SYSTEMS.md` |
| Cử chỉ và thực hành | Trang Kết nối tay/Thực hành; `docs/TWO_HAND_CONTROLS.md` |
| Kết quả và lịch sử | Kết quả từ chính lượt quay; `docs/RESULTS_HISTORY.md` |
| 233 bài Flutter đạt | `.cache/results-all-tests.log`, dòng cuối `All tests passed!` |
| 75 bài Python đạt | `.cache/portal-python-tests-full.log`, phần cuối `Ran 75 tests` và `OK` |
| Bản Android | File APK đã dựng; clip giả lập khi thao tác được |

Các nhật ký test là kết quả của lần kiểm tra đã lưu, không phải số liệu FPS hay số người dùng đã thử. Nếu test lại trước khi quay, dùng đúng kết quả mới nhất. Video không cần trình bày hết mọi tính năng; ưu tiên những thao tác nhìn rõ và chạy ổn định trong bản đang quay.
