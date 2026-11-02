"""Fetch only the web/Windows entries from the official large template ZIP.

HTTP range requests avoid downloading templates for unrelated platforms.
Files stay within the project cache. Each extracted entry is CRC checked.
"""
import pathlib
import struct
import urllib.request
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
DEST = ROOT / '.cache' / 'godot' / 'templates'


def fetch(start, end):
    request = urllib.request.Request(URL, headers={'Range': f'bytes={start}-{end}'})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError('Official download host did not honor the byte range')
        payload = response.read(end - start + 1)
        return payload, response.headers['Content-Range']


def main():
    _, content_range = fetch(0, 0)
    length = int(content_range.rsplit('/', 1)[1])
    tail, _ = fetch(length - 131072, length - 1)
    offset = tail.rfind(b'PK\x05\x06')
    if offset < 0:
        raise RuntimeError('ZIP directory not found')
    eocd = struct.unpack_from('<4s4H2IH', tail, offset)
    directory, _ = fetch(eocd[6], eocd[6] + eocd[5] - 1)
    cursor = 0
    wanted = {'web_release.zip', 'windows_release_x86_64.exe'}
    DEST.mkdir(parents=True, exist_ok=True)
    while cursor < len(directory):
        values = struct.unpack_from('<4s6H3I5H2I', directory, cursor)
        if values[0] != b'PK\x01\x02':
            raise RuntimeError('Invalid ZIP directory entry')
        name_len, extra_len, comment_len = values[10:13]
        name = directory[cursor + 46:cursor + 46 + name_len].decode()
        basename = pathlib.PurePosixPath(name).name
        if basename in wanted:
            local_offset, compressed, expected_crc = values[16], values[8], values[7]
            header, _ = fetch(local_offset, local_offset + 29)
            local = struct.unpack('<4s5H3I2H', header)
            data_offset = local_offset + 30 + local[9] + local[10]
            packed, _ = fetch(data_offset, data_offset + compressed - 1)
            data = zlib.decompress(packed, -15) if values[4] == 8 else packed
            if len(data) != values[9] or zlib.crc32(data) != expected_crc:
                raise RuntimeError(f'Integrity check failed for {basename}')
            (DEST / basename).write_bytes(data)
            wanted.remove(basename)
            print(f'Template ready: {basename} ({len(data)} bytes)', flush=True)
        cursor += 46 + name_len + extra_len + comment_len
    if wanted:
        raise RuntimeError(f'Missing templates: {wanted}')


if __name__ == '__main__':
    main()
