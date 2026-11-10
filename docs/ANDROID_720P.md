# Chạy Android giả lập ở 720p

Đã chỉnh máy ảo `Pixel_10_Pro_XL` ngày 10/11/2026 từ 1344 × 2992 xuống **720 × 1600**, mật độ **256 DPI**. Khi chơi ngang, màn hình tương ứng 1600 × 720. RAM vẫn 2048 MB, CPU 2 lõi, đồ họa `auto` hiện chọn NVIDIA RTX 3050.

Android đã xác nhận `Physical size: 720x1600` và `Physical density: 256`. Đây là độ phân giải thật của máy ảo, không chỉ thu nhỏ cửa sổ. Số điểm ảnh mỗi khung giảm khoảng 71%; mức tăng FPS và giảm RAM thực tế cần đo riêng.

## Mở game như bình thường

Chạy trong PowerShell:

```powershell
cd D:\GesturePlay
npm run android
```

Không cần chỉnh lại độ phân giải mỗi lần mở. Nếu cửa sổ lại bị khuất, đóng giả lập trước rồi dùng `npm run android -- --reset-window`.

## Tự chỉnh lại cấu hình

1. Đóng Android Emulator; chỉ sửa cấu hình khi máy ảo đã tắt.
2. Mở file `C:\Users\Admin\.android\avd\Pixel_10_Pro_XL.avd\config.ini` bằng trình soạn thảo.
3. Tìm và thay đúng các dòng sau; không thêm các dòng trùng khóa:

```ini
hw.lcd.width=720
hw.lcd.height=1600
hw.lcd.density=256
showDeviceFrame=no
skin.name=720x1600
skin.path=720x1600
```

`256 DPI` giữ kích thước chữ và nút gần giống cấu hình cũ. Skin `720x1600` dùng màn hình đơn giản phù hợp độ phân giải mới. Mật độ hiển thị và kích thước cửa sổ là hai thiết lập riêng.

4. Lưu file, mở lại bằng `npm run android`. Bộ khởi chạy dùng khởi động đầy đủ để tránh nạp snapshot cũ.

## Kiểm tra cấu hình đang chạy

Khi đúng máy ảo đang online với mã `emulator-5554`:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell wm size
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 shell wm density
```

Kết quả mong đợi: `Physical size: 720x1600` và `Physical density: 256`. Nếu mã máy ảo khác, xem bằng `adb devices` rồi thay mã trong hai lệnh.

## Khôi phục cấu hình gốc

Đóng giả lập, rồi chép bản sao cấu hình đã lưu trở lại:

```powershell
Copy-Item -LiteralPath 'D:\GesturePlay\.cache\Pixel_10_Pro_XL-before-720p-config.ini' -Destination 'C:\Users\Admin\.android\avd\Pixel_10_Pro_XL.avd\config.ini'
```

Sau đó mở lại bằng `npm run android`. Bản sao này chứa cấu hình 1344 × 2992, 480 DPI và khung Pixel cũ. Việc đổi hay khôi phục cấu hình giữ nguyên ứng dụng và dữ liệu trong máy ảo.
