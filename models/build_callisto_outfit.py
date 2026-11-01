# -*- coding: utf-8 -*-
"""
build_callisto_outfit.py — 2026-11-01. 히든 보스 칼리스토 복장(블렌더). 사용자: "전체적으로 갈색 톤에 재킷을 걸치고 있고, 재킷 안에는
와이셔츠, 바지는 검정색 바지를 입고 있는 거야. 거기에 의수 끼고 있고" (머리카락은 카탈로그 Carmen — ReplicatedStorage.CallistoAssets.Hair).

R6 관절 부품마다 따로 메시를 만든다(모션을 따라가게). 리그 공간(블렌더) — 몸통 가운데가 원점, 앞 = -y, 위 = +z:
  몸통 x -1..1 · y -0.5..0.5 · z -1..1 / 머리 (0, 0, 1.5) / 오른팔(로블록스 +X) 블렌더 x -1.5 / 왼팔 x +1.5 / 오른다리 (-0.5, 0, -2) / 왼다리 (0.5, 0, -2)
  (블렌더 (x, y, z) → 로블록스 (-x, z, y) — FBX -Z 앞 · Y 위)
메시 이름 = 앞머리_재질: CalT(몸통) · CalRA(오른팔 — 의수, 검을 쥔다) · CalLA(왼팔 — 손목 카메라) · CalRL(오른다리) · CalLL(왼다리). 원점 표지 CalOrigin_Marker.
2026-11-01 2판(사용자: "재킷은 단추를 잠그지 않은 채 열려 있어야 하고, 의수 팔은 검을 끼고 있어야 해"): 앞판을 벌려 셔츠가 끝까지 보이고
허리띠·버클이 드러난다(단추는 오른 앞판에 달린 채 풀림, 왼 앞판엔 단춧구멍). 의수는 오른팔 — 무기 CallistoArms 의 Main(검)이 이 손에 쥐어진다.
Studio: tools/Callisto_Outfit.luau 가 가져온 CallistoOutfit 을 ReplicatedStorage.CallistoAssets.Outfit 으로(부품마다 속성 Host · Offset).

레퍼런스: 갈색 트위드 재킷(노치 라펠 · 덮개 주머니 · 팔꿈치 스웨이드 덧댐 · 뒤트임) · 흰 와이셔츠(뾰족 깃 · 진주 단추) · 검은 정장 바지(주름선) ·
갈색 가죽 구두 · 스팀펑크 의수(놋쇠 팔꿈치 마디 · 겹친 팔뚝 판 · 구리 피스톤 · 마디 손가락) — 천문학자라 별 브로치 · 회중시계 줄 · 의수 마디의 푸른 별빛.
돌리기: blender -b -P models/build_callisto_outfit.py [-- render]  →  models/CallistoOutfit.fbx (+ models/snowtown_render/CallistoOutfit_*.png)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hanok_lib as L  # noqa: E402
import zfight_scan as Z  # noqa: E402

PAL = {
    "Jacket": "#6E4A30", "JacketDark": "#4A2F1F", "Suede": "#5C3B27", "Shirt": "#ECE7DC", "Trouser": "#1C1C20",
    "TrouserLine": "#34343C", "Leather": "#3E2618", "Shoe": "#4A2C1A", "Sole": "#1A1412", "Brass": "#B8913F",
    "Iron": "#3A3C42", "Copper": "#B06A3F", "Pearl": "#F4F1EA", "StarGlow": "#9CC8FF", "Skin": "#F6E4DA",
}
HOSTS = {"CalT": (0, 0, 0), "CalRA": (-1.5, 0, 0), "CalLA": (1.5, 0, 0), "CalRL": (-0.5, 0, -2), "CalLL": (0.5, 0, -2)}
# 2026-11-01 3판(사용자: "옷 재질 손봐서 체형만 맞으면 현실적으로 — 너무 각지면 보기 그러니 약간 부드럽게"):
# 모든 조각을 둥근 모서리(베벨)로 — 천은 크게(두께의 35%, 최대 0.14, 3단) · 금속은 작게(20%, 최대 0.05, 2단) · 단추·별은 1단.
# 내보낼 때 각도 35° 로 매끈 음영(모서리는 살림), FBX 는 법선 그대로(mesh_smooth_type OFF).
FABRIC = {"Jacket", "JacketDark", "Suede", "Shirt", "Trouser", "TrouserLine", "Leather", "Shoe", "Sole"}
METAL = {"Brass", "Iron", "Copper"}


def _merge(group, bm):
    bm.verts.index_update()
    group.add_mesh([tuple(v.co) for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])


def _bevel(bm, r, seg):
    if r > 1e-4 and seg > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, offset_type="OFFSET", segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


class Soft:
    """재질 하나(L.Group)에 둥근 조각을 넣는 대리자. box/obox = 둥근 상자(taper = 아래 면 x·y 배율), add_mesh = 모서리 둥근 판."""

    def __init__(self, group, mat):
        self.g = group
        if mat in ("Sole", "Shoe"):        # 구두·밑창은 덜 둥글게(부풀어 보이지 않게)
            self.ratio, self.cap, self.seg = 0.25, 0.06 if mat == "Shoe" else 0.025, 2
        elif mat in FABRIC:
            self.ratio, self.cap, self.seg = 0.35, 0.14, 3
        elif mat in METAL:
            self.ratio, self.cap, self.seg = 0.2, 0.05, 2
        else:
            self.ratio, self.cap, self.seg = 0.25, 0.02, 1

    def _r(self, *dims):
        return min(min(dims) * self.ratio, self.cap)

    def obox(self, cx, cy, cz, sx, sy, sz, rx=0.0, rz=0.0, ry=0.0, taper=None):
        if sx <= 0 or sy <= 0 or sz <= 0:
            return
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((sx, sy, sz, 1.0)))
        if taper:
            for v in bm.verts:
                if v.co.z < 0:
                    v.co.x *= taper[0]
                    v.co.y *= taper[1]
        _bevel(bm, self._r(sx, sy, sz), self.seg)
        m = (Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X"))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        _merge(self.g, bm)
        bm.free()

    def box(self, cx, cy, cz, sx, sy, sz, taper=None):
        self.obox(cx, cy, cz, sx, sy, sz, taper=taper)

    def add_mesh(self, verts, faces):
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in verts]
        for f in faces:
            try:
                bm.faces.new([vs[i] for i in f])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        thin = min(abs(verts[0][1] - verts[len(verts) // 2][1]), 0.2)
        _bevel(bm, min(thin * 0.4, self.cap), max(1, self.seg - 1))
        _merge(self.g, bm)
        bm.free()

    def cyl(self, *a, seg=12, **k):
        self.g.cyl(*a, seg=max(seg, 16), **k)

    def hcyl(self, *a, seg=12, **k):
        self.g.hcyl(*a, seg=max(seg, 16), **k)



def prism(g, mat, pts, y0, y1):
    """x-z 평면 다각형(pts) 을 y0 ~ y1 로 민 판(재킷 앞판·라펠·깃)."""
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [list(range(n)), list(range(n, 2 * n))[::-1]] + [[i, n + i, n + (i + 1) % n, (i + 1) % n] for i in range(n)]
    g[mat].add_mesh(verts, faces)


def torso(g):
    F = -0.5          # 몸통 앞면
    # 셔츠 앞판(열린 재킷 사이로 목에서 허리띠까지) · 진주 단추 다섯 · 뾰족 깃 · 허리띠(놋쇠 버클)
    g["Shirt"].box(0, F - 0.025, 0.02, 0.9, 0.05, 1.96)
    for z in (0.8, 0.5, 0.2, -0.1, -0.4, -0.7):
        g["Pearl"].cyl(0, F - 0.055, z - 0.02, 0.045, 0.045, 0.04, seg=8)
    g["Shirt"].box(0, F - 0.052, 0.05, 0.05, 0.01, 1.7)                     # 단추 덧단
    for s in (-1, 1):
        prism(g, "Shirt", [(0, 0.99), (s * 0.36, 1.02), (s * 0.18, 0.74)], F - 0.1, F - 0.05)
    for x in (-0.22, 0.2):                                                   # 허리띠 위로 넣어 입은 셔츠 주름
        g["Shirt"].obox(x, F - 0.05, -0.7, 0.07, 0.04, 0.34, ry=x * 0.4)
    g["Leather"].box(0, F - 0.03, -0.9, 0.96, 0.08, 0.16)                   # 허리띠(열린 앞판 사이)
    g["Brass"].box(0, F - 0.085, -0.9, 0.22, 0.03, 0.18)
    g["Leather"].box(0, F - 0.1, -0.9, 0.1, 0.02, 0.06)
    # 재킷 앞판 둘 — 단추를 풀어 벌어짐(아래까지 셔츠가 보이게, 앞 끝이 살짝 바깥으로 젖힘)
    for s in (-1, 1):
        pts = [(s * 0.36, -1.32), (s * 1.07, -1.32), (s * 1.07, 0.98), (s * 0.44, 1.0), (s * 0.3, 0.2), (s * 0.34, -0.6)]
        if s < 0:
            pts = pts[::-1]
        prism(g, "Jacket", pts, F - 0.1, F - 0.03)
        g["JacketDark"].obox(s * 0.355, F - 0.075, -0.56, 0.05, 0.06, 1.5, ry=s * 0.02)   # 앞 끝 접힌 단
    # 노치 라펠(짙은 갈색, 앞판 위에 접혀 누움)
    for s in (-1, 1):
        lap = [(s * 0.3, 0.2), (s * 0.44, 1.0), (s * 0.62, 0.86), (s * 0.52, 0.74), (s * 0.64, 0.66), (s * 0.47, 0.26)]   # 꺾임점(앞판 끝)에서 어깨로
        if s < 0:
            lap = lap[::-1]
        prism(g, "JacketDark", lap, F - 0.135, F - 0.1)
    # 서는 깃(목 뒤) · 어깨 판(목 구멍 비움) · 등판 · 옆판(얇게 — 팔이 덮음) · 뒤 가운데 솔기 · 뒤트임
    g["JacketDark"].box(0, 0.38, 1.12, 1.02, 0.22, 0.26)
    for s in (-1, 1):
        g["JacketDark"].obox(s * 0.52, 0.0, 1.1, 0.16, 0.8, 0.22, rz=s * 0.25)
        g["Jacket"].box(s * 0.76, 0.0, 1.03, 0.64, 1.16, 0.08)
    g["Jacket"].box(0, 0.54, -0.16, 2.14, 0.08, 2.32)
    for s in (-1, 1):
        g["Jacket"].box(s * 1.015, 0.0, -0.16, 0.03, 1.16, 2.32)
    g["JacketDark"].box(0, 0.585, -0.2, 0.04, 0.02, 2.2)
    g["JacketDark"].box(0, 0.59, -1.18, 0.05, 0.03, 0.28)
    # 단추 둘(놋쇠 — 오른 앞판(블렌더 -x)에 달린 채 풀림) · 단춧구멍(왼 앞판) · 덮개 주머니 셋 · 별 브로치 · 회중시계 줄
    for z in (-0.12, -0.52):
        g["Brass"].hcyl(-0.48, F - 0.13, z, 0.06, 0.05, axis="y", seg=10)
        g["JacketDark"].box(0.5, F - 0.105, z, 0.14, 0.02, 0.03)
    for x, z, w in ((0.66, -1.08, 0.46), (-0.66, -1.08, 0.46), (0.68, 0.5, 0.32)):   # 허리띠 아래로(띠처럼 이어 보이지 않게)
        g["JacketDark"].obox(x, F - 0.12, z, w, 0.04, 0.13, ry=-0.03 * (1 if x > 0 else -1))
    g["Brass"].obox(0.36, F - 0.15, 0.7, 0.16, 0.03, 0.05, ry=0.0)
    g["Brass"].obox(0.36, F - 0.15, 0.7, 0.05, 0.03, 0.16, ry=0.0)
    g["Brass"].obox(0.36, F - 0.152, 0.7, 0.11, 0.03, 0.11, ry=math.radians(45))
    g["StarGlow"].box(0.36, F - 0.17, 0.7, 0.045, 0.02, 0.045)
    for k in range(9):                                     # 줄: 가슴 주머니에서 앞판 끝 단춧구멍 쪽으로 처짐(촘촘한 고리)
        t = k / 8
        g["Brass"].box(0.66 - t * 0.2, F - 0.112, 0.44 - math.sin(t * math.pi) * 0.14 - t * 0.3, 0.05, 0.015, 0.02)


def sleeve(g, side, short=False):
    """재킷 소매(오른팔은 손목까지 + 셔츠 소맷부리 + 장갑 / 왼팔은 짧게 걷어 의수가 보이게)."""
    x = side * 1.5
    if not short:
        g["Jacket"].box(x, 0, 0.26, 1.14, 1.14, 1.6, taper=(0.94, 0.94))
        for dz, rot in ((0.1, 0.14), (-0.06, -0.12)):                          # 팔꿈치 안쪽 천 주름(얕은 둔덕)
            g["Jacket"].obox(x, -0.565, dz, 0.4, 0.03, 0.05, ry=rot)
        g["JacketDark"].box(x, 0, -0.5, 1.16, 1.16, 0.14)                  # 소매 끝
        g["Shirt"].box(x, 0, -0.62, 1.04, 1.04, 0.14)                      # 셔츠 소맷부리
        g["Brass"].box(x + side * 0.535, 0.0, -0.62, 0.03, 0.12, 0.08)      # 커프스 단추(바깥)
        g["Suede"].box(x, 0.57, 0.04, 0.5, 0.03, 0.42)                     # 팔꿈치 덧댐(뒤)
        g["Leather"].box(x, 0, -0.86, 1.06, 1.06, 0.36)                    # 장갑
        for k in range(3):
            g["JacketDark"].box(x - 0.3 + k * 0.3, -0.535, -0.92, 0.025, 0.02, 0.22)
        g["Leather"].obox(x - side * 0.28, -0.6, -0.8, 0.22, 0.2, 0.32, rx=0.3)   # 엄지 불룩
    else:
        g["Jacket"].box(x, 0, 0.62, 1.12, 1.12, 0.88)
        g["JacketDark"].box(x, 0, 0.16, 1.18, 1.18, 0.18)                  # 걷어 올린 소매 끝(두툼)
        g["Shirt"].box(x, 0, 0.04, 1.08, 1.08, 0.1)


def prosthetic(g, side):
    """왼팔 의수(스팀펑크 + 별빛) — 팔 부피(1×2×1)를 채운다: 굵은 팔꿈치 마디 · 비늘처럼 겹친 놋쇠·구리 판(앞뒤) · 옆 구리 피스톤 ·
    손목 고리 · 손바닥(손등 판) · 마디 손가락 넷 + 엄지. 리벳은 판 가장자리 줄(점 둘이 얼굴처럼 보이지 않게)."""
    x = side * 1.5
    o = side                                                                  # 바깥 쪽
    g["Iron"].cyl(x, 0, -0.02, 0.52, 0.52, 0.08, seg=18)                      # 소매 밑 이음 고리
    g["Brass"].hcyl(x, 0, -0.18, 0.46, 0.98, axis="x", seg=18)                # 팔꿈치 마디(옆으로 누운 통)
    for s_ in (-1, 1):
        g["Iron"].hcyl(x + s_ * 0.5, 0, -0.18, 0.36, 0.06, axis="x", seg=16)
        g["Iron"].hcyl(x + s_ * 0.54, 0, -0.18, 0.12, 0.05, axis="x", seg=10)
    g["StarGlow"].obox(x, -0.47, -0.18, 0.12, 0.03, 0.12, ry=math.radians(45))   # 마디 앞 별빛
    for r in (0.0, math.pi / 2):
        g["Brass"].obox(x, -0.47, -0.18, 0.28, 0.02, 0.05, ry=r)
    g["Iron"].box(x, 0, -0.5, 0.74, 0.74, 0.56)                               # 팔뚝 속
    for face in (-1, 1):                                                      # 앞뒤 겹친 판 셋(위가 넓고 아래로 좁아짐)
        for k in range(3):
            w = 0.86 - k * 0.05
            z = -0.34 - k * 0.16
            yy = face * (0.4 + 0.012 * (2 - k))
            g["Brass" if (k + (face > 0)) % 2 == 0 else "Copper"].obox(x, yy, z, w, 0.06, 0.2, rx=face * 0.1)
            for dx in (-1, 1):                                                # 리벳: 판 양 끝 줄
                g["Iron"].box(x + dx * (w / 2 - 0.05), yy + face * 0.035, z, 0.04, 0.02, 0.12)
    for s_ in (-1, 1):                                                        # 옆판(안·바깥)
        g["Iron"].obox(x + s_ * 0.4, 0, -0.5, 0.06, 0.7, 0.5, ry=s_ * 0.04)
    for dy in (-0.16, 0.16):                                                  # 바깥 옆 구리 피스톤 둘(통 + 막대)
        g["Copper"].cyl(x + o * 0.47, dy, -0.7, 0.07, 0.07, 0.3, seg=10)
        g["Iron"].cyl(x + o * 0.47, dy, -0.42, 0.03, 0.03, 0.2, seg=8)
        g["Brass"].cyl(x + o * 0.47, dy, -0.73, 0.09, 0.09, 0.04, seg=10)
    g["Iron"].cyl(x, 0, -0.84, 0.42, 0.42, 0.1, seg=18)                       # 손목 고리
    g["Brass"].cyl(x, 0, -0.8, 0.44, 0.44, 0.04, seg=18)
    g["Iron"].box(x, -0.02, -0.98, 0.78, 0.5, 0.26)                           # 손바닥
    g["Brass"].box(x, -0.28, -0.98, 0.6, 0.03, 0.2)                           # 손등 판
    g["Iron"].box(x - 0.24, -0.3, -0.98, 0.03, 0.02, 0.14)
    g["Iron"].box(x + 0.24, -0.3, -0.98, 0.03, 0.02, 0.14)
    for k in range(4):                                                        # 손가락: 놋쇠 마디 + 쇠 마디 둘(살짝 굽음)
        fx = x - 0.28 + k * 0.19
        g["Brass"].hcyl(fx, -0.06, -1.14, 0.065, 0.14, axis="x", seg=8)
        g["Iron"].obox(fx, -0.08, -1.23, 0.12, 0.13, 0.17, rx=-0.22)
        g["Iron"].obox(fx, -0.13, -1.36, 0.11, 0.12, 0.13, rx=-0.5)
    g["Brass"].hcyl(x - o * 0.42, -0.2, -0.96, 0.07, 0.14, axis="y", seg=8)    # 엄지 마디
    g["Iron"].obox(x - o * 0.46, -0.3, -1.06, 0.12, 0.13, 0.2, rx=-0.45, ry=-o * 0.35)


def leg(g, side):
    """검은 정장 바지(주름선 · 밑단) + 갈색 가죽 구두(밑창 · 굽 · 끈 · 앞코 솔기)."""
    x = side * 0.5
    inner = side * 0.01
    outer = side * 1.05
    cx, w = (inner + outer) / 2, abs(outer - inner)
    g["Trouser"].box(cx, 0, -1.85, w, 1.1, 1.8, taper=(0.93, 0.93))
    for dz, rot in ((-1.62, 0.18), (-1.76, -0.14)):                           # 무릎 뒤 천 주름
        g["Trouser"].obox(x, 0.54, dz, 0.6, 0.06, 0.08, ry=rot)
    g["TrouserLine"].box(x, -0.555, -1.85, 0.03, 0.02, 1.7)                   # 앞 주름선
    g["TrouserLine"].box(x, 0.555, -1.85, 0.03, 0.02, 1.7)
    g["Trouser"].obox(cx, -0.03, -2.72, w - 0.04, 1.06, 0.09, rx=0.08)          # 밑단 꺾임(구두 위에서 한 번 접힘)
    g["Shoe"].box(x, -0.08, -2.88, 1.02, 1.2, 0.26)                           # 구두(앞코가 나옴)
    g["Shoe"].obox(x, -0.62, -2.9, 0.98, 0.3, 0.2, rx=0.35)                   # 둥근 앞코
    g["Sole"].box(x, -0.1, -3.03, 1.04, 1.32, 0.06)
    g["Sole"].box(x, 0.38, -2.98, 0.9, 0.34, 0.12)                            # 굽
    g["JacketDark"].box(x, -0.36, -2.75, 0.5, 0.36, 0.03)                     # 끈 판
    for k in range(3):
        g["Pearl"].obox(x, -0.3 - k * 0.1, -2.735, 0.42, 0.025, 0.02, rz=0.0)
    g["JacketDark"].obox(x, -0.6, -2.82, 0.9, 0.02, 0.025, rx=0.35)           # 앞코 솔기


def build():
    groups, soft = {}, {}
    for pre in HOSTS:
        groups[pre] = L.new_groups(pre, PAL)
        soft[pre] = {k: Soft(v, k) for k, v in groups[pre].items()}
    real, groups = groups, soft
    torso(groups["CalT"])
    sleeve(groups["CalLA"], 1)                    # 왼팔: 소매 + 장갑(손목 카메라 = 무기 Off)
    sleeve(groups["CalRA"], -1, short=True)       # 오른팔: 걷어 올린 소매 + 의수(검을 쥔다 = 무기 Main)
    prosthetic(groups["CalRA"], -1)
    leg(groups["CalRL"], -1)
    leg(groups["CalLL"], 1)
    return real


if __name__ == "__main__":
    RENDER = "render" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    L.clear_scene()
    groups = build()
    objs, total = [], 0
    for pre, g in groups.items():
        zm, zl = Z.fix(g, pre)
        for k in PAL:
            ob = g[k].finish()
            if len(ob.data.polygons) == 0:
                bpy.data.objects.remove(ob, do_unlink=True)
                continue
            tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            assert tris <= 10000, (ob.name, tris)
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
            total += tris
            objs.append(ob)
        print("  %-6s 반짝임 민 면 %d 남음 %d" % (pre, zm, zl))
    print("CallistoOutfit %d tri · 오브젝트 %d" % (total, len(objs)))
    m = L.Group("CalOrigin_Marker", L.material("Iron", PAL))
    m.box(0, 0, 0, 0.2, 0.2, 0.2)
    marker = m.finish()
    if RENDER:
        from mathutils import Vector
        # 미리보기용 몸(관절 상자) — 내보내지 않는다
        body = L.new_groups("Body", PAL)
        body["Skin"].box(0, 0, 1.5, 1.2, 1.2, 1.2)
        body["Jacket"].box(0, 0, 0, 2, 1, 2)
        body["Jacket"].box(1.5, 0, 0, 1, 1, 2)
        body["Trouser"].box(-0.5, 0, -2, 1, 1, 2)
        body["Trouser"].box(0.5, 0, -2, 1, 1, 2)
        preview = [ob for ob in (body[k].finish() for k in PAL) if len(ob.data.polygons)]
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        sh = scene.display.shading
        sh.light, sh.color_type = "STUDIO", "MATERIAL"
        sh.show_cavity = True
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.62, 0.68, 0.76)
        scene.render.resolution_x, scene.render.resolution_y = 800, 1000
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        scene.collection.objects.link(cam)
        scene.camera = cam
        cam.data.lens = 60
        marker.hide_render = True
        out = os.path.join(HERE, "snowtown_render")
        for tag, d in (("front", Vector((0.25, -1.0, 0.12))), ("back", Vector((-0.4, 1.0, 0.15))), ("arm", Vector((1.0, -0.6, 0.0)))):
            mid = Vector((0, 0, -0.5))
            d = d.normalized()
            cam.location = mid + d * 13
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, "CallistoOutfit_%s.png" % tag)
            bpy.ops.render.render(write_still=True)
        for ob in preview:
            bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(HERE, "CallistoOutfit.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="OFF", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("FBX:", fbx)
