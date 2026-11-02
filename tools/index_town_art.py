"""Index alpha bounds without changing any generated image pixels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'flutter_app/assets/town'
frames = {}
for name, columns, rows in [('architecture-v2', 3, 2), ('details-v2', 4, 3)]:
    image = Image.open(ASSETS / f'{name}.png')
    assert image.mode == 'RGBA'
    alpha = image.getchannel('A')
    rects = []
    for row in range(rows):
        for col in range(columns):
            cell = (round(col * image.width / columns), round(row * image.height / rows),
                    round((col + 1) * image.width / columns), round((row + 1) * image.height / rows))
            # Ignore very faint generated edge haze when finding the crop.
            bounds = alpha.crop(cell).point(lambda a: 255 if a > 40 else 0).getbbox()
            assert bounds
            x0, y0 = max(cell[0], cell[0] + bounds[0] - 2), max(cell[1], cell[1] + bounds[1] - 2)
            x1, y1 = min(cell[2], cell[0] + bounds[2] + 2), min(cell[3], cell[1] + bounds[3] + 2)
            rects.append([x0, y0, x1 - x0, y1 - y0])
    frames[name] = rects
(ASSETS / 'environment-v2.json').write_text(json.dumps(frames, indent=2) + '\n', encoding='utf-8')
print({key: len(value) for key, value in frames.items()})
