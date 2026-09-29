"""
extract_part_names.py — .rbxl(바이너리 Roblox 플레이스)에서 파트 이름 색인을 뽑는다.

왜 필요한가
    추가&수정.md `# 수동 수정을 위해` 는 "검색해서 찾기 편하도록 각 브릭들과
    스크립트들의 위치와 역할을 써놓을 것"을 요구한다.
    Studio 커맨드 바로 뽑으면 출력창 한계 때문에 폴더당 상위 몇 종만 담기게 된다.
    저장된 .rbxl을 직접 파싱하면 **모든 파트 이름을 빠짐없이** 얻을 수 있다.

바이너리 포맷 (rbx-dom 문서 기준)
    헤더 32바이트:
        b"<roblox!" + b"\x89\xff\r\n\x1a\n" + uint16(0)
        + int32 numTypes + int32 numInstances + 8바이트 예약
    이후 청크 반복:
        char[4] 이름 + uint32 압축크기 + uint32 원본크기 + 4바이트 예약 + 데이터
        압축크기 == 0 이면 데이터가 비압축.
        압축은 LZ4 또는 Zstd(매직 28 b5 2f fd).

    INST 청크: int32 typeId, string typeName, bool isService, int32 count, ...
    PROP 청크: int32 typeId, string propName, uint8 typeCode, 값 배열
               typeCode 0x01 = String → 이름 목록이 여기 들어 있다.

사용법
    python tools/extract_part_names.py backup/pre-union-2026-07-20.rbxl
"""

from __future__ import annotations

import struct
import sys
from collections import Counter
from pathlib import Path

try:
    from compression import zstd  # Python 3.14+
except ImportError:  # pragma: no cover
    zstd = None  # type: ignore

HEADER_MAGIC = b"<roblox!\x89\xff\r\n\x1a\n"
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"


def decompress(blob: bytes, expected: int) -> bytes | None:
    """청크 데이터를 푼다. Zstd만 지원하며, 실패하면 None."""
    if blob[:4] == ZSTD_MAGIC:
        if zstd is None:
            return None
        try:
            return zstd.decompress(blob)
        except Exception:
            return None
    # LZ4 블록은 외부 의존이 필요해 여기서는 건너뛴다.
    return None


def read_chunks(data: bytes):
    """헤더를 지나 청크를 차례로 내놓는다."""
    if not data.startswith(HEADER_MAGIC):
        raise SystemExit("rbxl 헤더가 아닙니다.")

    offset = 16
    num_types, num_instances = struct.unpack_from("<ii", data, offset)
    offset += 8 + 8  # 카운트 8바이트 + 예약 8바이트

    while offset + 16 <= len(data):
        name = data[offset : offset + 4]
        comp_len, raw_len = struct.unpack_from("<II", data, offset + 4)
        offset += 16

        payload_len = comp_len if comp_len else raw_len
        payload = data[offset : offset + payload_len]
        offset += payload_len

        if comp_len:
            payload = decompress(payload, raw_len)
            if payload is None:
                continue

        yield name, payload

        if name == b"END\x00":
            break

    _ = (num_types, num_instances)


def read_string(buf: bytes, pos: int) -> tuple[str, int]:
    (length,) = struct.unpack_from("<I", buf, pos)
    pos += 4
    raw = buf[pos : pos + length]
    return raw.decode("utf-8", "replace"), pos + length


def parse(path: Path) -> tuple[Counter, Counter]:
    """(클래스 카운터, Name 프로퍼티 카운터)를 돌려준다."""
    data = path.read_bytes()

    classes: Counter = Counter()
    names: Counter = Counter()
    type_counts: dict[int, int] = {}

    for chunk_name, payload in read_chunks(data):
        if chunk_name == b"INST":
            try:
                (type_id,) = struct.unpack_from("<i", payload, 0)
                class_name, pos = read_string(payload, 4)
                pos += 1  # isService
                (count,) = struct.unpack_from("<i", payload, pos)
                classes[class_name] += count
                type_counts[type_id] = count
            except Exception:
                continue

        elif chunk_name == b"PROP":
            try:
                (type_id,) = struct.unpack_from("<i", payload, 0)
                prop_name, pos = read_string(payload, 4)
                if prop_name != "Name":
                    continue
                (type_code,) = struct.unpack_from("<B", payload, pos)
                pos += 1
                if type_code != 0x01:  # String
                    continue
                count = type_counts.get(type_id, 0)
                for _ in range(count):
                    if pos + 4 > len(payload):
                        break
                    value, pos = read_string(payload, pos)
                    names[value] += 1
            except Exception:
                continue

    return classes, names


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("사용법: python extract_part_names.py <파일.rbxl>")

    path = Path(sys.argv[1])
    classes, names = parse(path)

    print(f"# {path.name}")
    print(f"# 클래스 {len(classes)}종 / 이름 {len(names)}종\n")

    print("## 클래스별 개수")
    for class_name, count in classes.most_common(30):
        print(f"{class_name}\t{count}")

    print("\n## 이름별 개수 (전체, 개수 내림차순)")
    for name, count in names.most_common():
        print(f"{name}\t{count}")


if __name__ == "__main__":
    main()
