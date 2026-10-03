# -*- coding: utf-8 -*-
"""
build_monsters.py — 보스 디버그의 블렌더 장식 메시를 FBX 하나로 내보낸다. (2026-10-03)
  사용자(2026-10-03): "블렌더랑 로블록스 내 제작을 섞어서" · "슬라임은 원래 쓰던 슬라임으로".
  → 몸 덩어리·코드 줄·✕/+·떠다니는 조각은 로블록스 Part(src/client/Combat/DebugBoss.luau 부품 표) 그대로,
    블록으로는 못 만드는 것(휜 더듬이·유압 실린더·케이블·감은 붕대·베젤·볼트·발톱·팔면체 결정)만 여기서 메시로.
    슬라임은 블록 그대로(메시 없음).

- 모델 공간: 바닥 가운데(Pivot) 원점, +Y 위, -Z 정면(아군 쪽) — 부품 표와 같은 자리(치수는 그 표의 블록에 맞췄다).
- 이름 "<모델>_<부품>": DebugHead_MeshTrim, DebugPatchArm_MeshBandage, DebugCore_FloatMagentaCrystal …
  색은 이름의 낱말(Trim·Panel·Bandage·Magenta)로 DebugBoss.luau 가 입히고, Float… 은 떠서 돈다.
- 원점 표지 MonstersOrigin_Marker(1×1×1) — tools/MonsterMeshes.luau 가 원점·배율을 되찾아 ReplicatedStorage.MonsterMeshes 로 정리.

돌리는 법: blender -b -P models/monsters/build_monsters.py → 스튜디오 Ctrl+M 로 Monsters.fbx → bash tools/job.sh tools/MonsterMeshes.luau
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "weapons"))
import wlib as L  # noqa: E402

def rgb(r, g, b):
    return (r / 255) ** 2.2, (g / 255) ** 2.2, (b / 255) ** 2.2


class Model:
    def __init__(self, name):
        self.name = name
        self.groups = {}

    def g(self, piece, color, smooth=40.0, alpha=1.0):
        if piece not in self.groups:
            self.groups[piece] = L.Group("%s_%s" % (self.name, piece), color, smooth, alpha)
        return self.groups[piece]

    def finish(self):
        return [grp.finish() for grp in self.groups.values()]


# ── 보스 디버그 ─────────────────────────────────


def band(g, center, inner, depth, thick, rot=(0, 0, 0)):
    """상자 단면(inner = (w, h))을 두르는 띠(가운데가 빈 네모 고리) — 붕대·목 고리·테두리"""
    cx, cy, cz = center
    w, h = inner
    R = rot
    for dx, dy, sx, sy in ((0, (h + thick) / 2, w + 2 * thick, thick), (0, -(h + thick) / 2, w + 2 * thick, thick),
                           ((w + thick) / 2, 0, thick, h), (-(w + thick) / 2, 0, thick, h)):
        L.bbox(g, _rot(center, (dx, dy, 0), R), (sx, sy, depth), min(thick, depth) * 0.3, R)


def _rot(center, off, rot):
    rx, ry, rz = (math.radians(a) for a in rot)
    from mathutils import Matrix
    M = Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(rz, 4, "Z")
    v = M @ Vector(off)
    return (center[0] + v.x, center[1] + v.y, center[2] + v.z)


def bolts(g, pts, r=0.16):
    for q in pts:
        L.ball(g, q, r, 10, 6)


def piston(g, a, b, r0=0.36, r1=0.17):
    """유압 실린더: a 쪽 굵은 통 → b 쪽 가는 막대, 끝마다 고리"""
    a, b = Vector(a), Vector(b)
    mid = a.lerp(b, 0.55)
    L.tube(g, [tuple(a), tuple(a.lerp(mid, 0.5)), tuple(mid)], r0, 12)
    L.tube(g, [tuple(mid.lerp(a, 0.1)), tuple(mid.lerp(b, 0.5)), tuple(b)], r1, 10)
    L.ball(g, tuple(a), r0 * 1.15, 12, 8)
    L.ball(g, tuple(b), r0 * 0.9, 12, 8)


def debug():
    """블록(DebugBoss.luau 의 부품 표 — 로블록스 Part)으로는 못 만드는 것만 메시로: 휜 관·고리·볼트·발톱·결정"""
    out = []
    PANELC, TRIMC = rgb(58, 52, 80), rgb(88, 80, 116)
    MAG = rgb(255, 70, 200)

    # 머리: 얼굴 테(모니터 베젤)·모서리 볼트·목 마디 고리·옆 통풍 살·벌레 더듬이 둘
    h = Model("DebugHead")
    t, p = h.g("MeshTrim", TRIMC, 35), h.g("MeshPanel", PANELC, 35)
    band(t, (0, 5.6, -1.82), (3.9, 3.7), 0.36, 0.28)
    bolts(t, [(sx * 2.09, 5.6 + sy * 1.99, -2.02) for sx in (-1, 1) for sy in (-1, 1)], 0.14)
    for z in (3.8, 5.0, 6.2):
        band(t, (0, 3.2, z), (2.8, 3.0), 0.42, 0.16)
    for i in range(3):
        L.bbox(p, (2.36, 3.7 + i * 0.45, 0.8), (0.14, 0.2, 3.2), 0.05)
    for sx in (-1, 1):
        path = [(sx * 1.3, 8.3, 2.4), (sx * 1.7, 9.0, 2.6), (sx * 2.3, 9.7, 2.0), (sx * 2.8, 10.1, 1.0), (sx * 3.0, 10.1, 0.2)]
        L.tube(t, path, [0.17, 0.14, 0.12, 0.1, 0.09], 8)
        L.ball(h.g("MeshTipMagenta", MAG, None), (sx * 3.02, 10.08, 0.05), 0.24, 12, 8)
    out.append(h)

    # 삭제 팔: 주먹 손가락 마디 넷(블록 Knuckle 둘 대신)·어깨 볼트·윗팔 유압 실린더(카메라 쪽 -X)·손목 고리
    a = Model("DebugDeleteArm")
    t = a.g("MeshTrim", TRIMC, 35)
    for i in range(4):
        L.bbox(t, (-1.35 + i * 1.03, 4.05, -6.2), (0.86, 0.5, 1.0), 0.18, seg=2)
    bolts(t, [(-2.12, 4.6 + dy, 5.0 + dz) for dy in (-1.6, 1.6) for dz in (-1.4, 1.4)], 0.2)
    piston(t, (-2.0, 5.4, 3.6), (-1.75, 3.5, -0.9))
    band(t, (0.2, 2.4, -4.0), (3.2, 2.6), 0.4, 0.16)
    out.append(a)

    # 패치 팔: 비스듬히 감은 붕대 셋 + 늘어진 꼬리(블록 Wrap 셋 대신)·유압 실린더·손바닥 테·어깨 볼트
    a = Model("DebugPatchArm")
    t, bd = a.g("MeshTrim", TRIMC, 35), a.g("MeshBandage", rgb(206, 198, 172), 50)
    band(bd, (-0.2, 3.0, 2.8), (2.8, 2.6), 0.75, 0.13, (10, 0, 0))
    band(bd, (-0.2, 3.0, 0.7), (2.8, 2.6), 0.75, 0.13, (-8, 0, 0))
    band(bd, (-0.2, 2.0, -3.0), (3.0, 2.4), 0.8, 0.13, (6, 0, 0))
    L.tube(bd, [(-1.68, 2.2, -3.3), (-1.75, 1.6, -3.5), (-1.72, 1.0, -3.9), (-1.62, 0.6, -4.1)], [0.12, 0.11, 0.1, 0.08], 6,
           section=[(1.0, 0.25), (-1.0, 0.25), (-1.0, -0.25), (1.0, -0.25)])
    piston(t, (-2.25, 4.6, 3.6), (-2.0, 2.9, -0.9))
    band(t, (-0.2, 2.3, -5.42), (4.2, 3.2), 0.3, 0.14)
    bolts(t, [(-2.42, 3.9 + dy, 5.0 + dz) for dy in (-1.4, 1.4) for dz in (-1.4, 1.4)], 0.2)
    out.append(a)

    # 코어: 발톱(발마다 앞 셋)·윗판 볼트·+X 옆 통풍 살·등 케이블 둘·어깨 고리·결정(블록 Crystal 대신 길쭉한 팔면체, 떠서 돈다)
    c = Model("DebugCore")
    t, p = c.g("MeshTrim", TRIMC, 35), c.g("MeshPanel", PANELC, 35)
    for fx, fz in ((5.5, -6), (-5.5, -6), (5.5, 6), (-5.5, 6)):
        for k in (-1, 0, 1):
            L.bbox(t, (fx + k * 1.1, 0.45, fz - 2.1), (0.7, 0.9, 1.0), 0.2, (-12, 0, 0), seg=2)
    bolts(t, [(sx * 7.1, 10.95, z) for sx in (-1, 1) for z in (-10.6, -1, 8.6)], 0.24)
    for i in range(6):
        L.bbox(p, (7.08, 2.6 + i * 0.55, 6.6), (0.16, 0.24, 3.6), 0.06)
    for k, (x0, x1) in enumerate(((-2.6, -4.8), (2.6, 4.6))):
        path = [(x0, 12.0, 6.8), (x0 * 1.1, 11.6, 9.4), ((x0 + x1) / 2, 9.8, 10.2), (x1, 7.0, 9.8), (x1, 4.4, 9.1)]
        L.tube(t, path, 0.42 - 0.05 * k, 10)
    for x in (6.3, -6.3):
        band(t, (x, 5.4, -11.8), (4.2, 4.2), 0.5, 0.16, (90, 0, 0))
    L.lathe(c.g("FloatMagentaCrystal", MAG, None), [(0, -1.5), (1.0, 0), (0, 1.5)], 6, (0, 7.6, -12.1), "Y")
    out.append(c)
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    allobjs = []
    for m in debug():
        objs = m.finish()
        for ob in objs:
            assert L.tri_count(ob) <= 20000, ob.name
        print("  %-16s %d 조각, %d tri" % (m.name, len(objs), sum(L.tri_count(o) for o in objs)))
        allobjs += objs
    mk = L.Group("MonstersOrigin_Marker", (1, 0, 1), None)
    L.bbox(mk, (0, 0, 0), (1, 1, 1))
    marker = mk.finish()
    marker.hide_render = True
    bpy.ops.object.select_all(action="DESELECT")
    for ob in allobjs + [marker]:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = marker
    fbx = os.path.join(HERE, "Monsters.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                             axis_forward="-Z", axis_up="Y", object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
                             bake_space_transform=False)
    print("objects %d  FBX: %s" % (len(allobjs) + 1, fbx))


main()
