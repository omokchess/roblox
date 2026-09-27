"""파이프라인 전역 설정.

좌표계 규칙
-----------
* Blender 는 Z-up, 1 BU(Blender Unit) = 1 stud 로 모델링한다.
* Roblox 는 Y-up 이다. 변환은  (x, y, z)_blender -> (x, z, -y)_roblox  (회전 행렬 C).
  - Roblox 파트의 로컬 축:  X_r = C·X_b,  Y_r = C·Z_b,  Z_r = C·(-Y_b)
  - 따라서 파트 크기 매핑은  (sx, sy, sz)_blender -> (sx, sz, sy)_roblox.
* 모든 에셋의 원점(0,0,0)은 "지면/수면 접지점" 이다. 수면은 Roblox Y=0.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # 레포 루트
BLENDER_DIR = ROOT / "blender"
OUT_DIR = ROOT / "assets"
FBX_DIR = OUT_DIR / "fbx"
PARTS_DIR = OUT_DIR / "parts"          # Part 기반(임포트 불필요) 버전 JSON -> Lune 이 .rbxm 으로 변환
PREVIEW_DIR = OUT_DIR / "previews"
MANIFEST_PATH = OUT_DIR / "manifest.json"
BLEND_DIR = OUT_DIR / "blend"

# Roblox 머티리얼 텍스처가 메시 UV 1.0 당 몇 stud 를 덮을지 (월드 스케일 UV)
UV_STUDS_PER_TILE = 8.0

# Roblox MeshPart 한 개당 삼각형 상한 (Roblox 한도 20k, 여유 있게 10k)
MAX_TRIS_PER_PART = 10000

# Part 버전에서 너무 작은 조각은 그림자 비활성 (성능)
PART_NO_SHADOW_MAX_DIM = 0.6

# 미리보기 렌더
PREVIEW_RES = (1600, 900)
PREVIEW_SAMPLES = 96
