"""Tải model chính thức, kiểm tra archive rồi mới đưa vào đường dẫn chạy."""

import argparse
import hashlib
from pathlib import Path
import tempfile
import urllib.request
import zipfile

from config import AppConfig, configure_console


MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
)


def validate_model(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError("File model rỗng hoặc không tồn tại.")
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if not any("hand_detector" in name and name.endswith(".tflite") for name in names):
            raise ValueError("Archive thiếu mô hình phát hiện bàn tay.")
        if not any("hand_landmark" in name and name.endswith(".tflite") for name in names):
            raise ValueError("Archive thiếu mô hình landmarks bàn tay.")
        if archive.testzip() is not None:
            raise ValueError("File model bị lỗi CRC.")


def download(destination: Path, force: bool = False) -> None:
    if destination.exists() and not force:
        validate_model(destination)
        print(f"Model đã tồn tại và hợp lệ: {destination}")
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".part", delete=False) as output:
            temporary = Path(output.name)
            with urllib.request.urlopen(MODEL_URL, timeout=60) as response:
                while chunk := response.read(1024 * 256):
                    output.write(chunk)
        validate_model(temporary)
        temporary.replace(destination)
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        print(f"Đã tải {destination.stat().st_size:,} bytes vào {destination}")
        print(f"SHA256: {digest}")
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def main() -> int:
    configure_console()
    parser = argparse.ArgumentParser(description="Tải mô hình Hand Landmarker từ Google.")
    parser.add_argument("--output", type=Path, default=AppConfig().model_path)
    parser.add_argument("--force", action="store_true", help="Tải lại và thay model hiện có")
    args = parser.parse_args()
    try:
        download(args.output.resolve(), args.force)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"Không tải được model: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
