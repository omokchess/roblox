# 작은 PNG 쓰개(PIL 없이). img: numpy uint8 [H, W, 3]
import struct
import zlib


def write_png(path, img):
    H, W = img.shape[:2]
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(H))

    def ch(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                           + ch(b"IDAT", zlib.compress(raw, 6)) + ch(b"IEND", b""))
