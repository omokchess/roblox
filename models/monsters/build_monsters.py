# -*- coding: utf-8 -*-
"""
build_monsters.py — 보스 디버그(정십이면체 코어 + 위성 셋)의 블렌더 메시를 FBX 하나로 내보낸다. (2026-10-03)
  사용자(2026-10-03): "디버그를 정12각형 구체로 두고 … 돌아가거나, 움직이면서 투사체 같은 걸 발사하면서 공격" →
  코어 = 큰 정십이면체, 머리·삭제·패치 = 작은 정십이면체 위성(코어 앞을 돈다). "블렌더랑 로블록스 내 제작을 섞어서" →
  다면체·이음새 빛·코드 고리·더듬이·붕대 띠는 여기(블렌더), 기호(중단점·✕·+)·떠다니는 오류 조각은 DebugBoss.luau 의 Part.
  슬라임은 블록 그대로(메시 없음).

- 모델 공간: 원점 = 다면체 가운데, +Y 위, -Z 정면(아군 쪽). 면 하나가 정면(-Z)을 본다.
- 이름 "<모델>_<부품>": Spin… = 다면체와 함께 돈다(축은 DebugBoss.luau SPIN_AXIS), Ring… = 코드 고리(축 RING_N, 같은 값),
  Float… = 떠서 돈다, 그 밖(Mesh…)은 고정. 색은 이름의 낱말(Panel·Magenta·Red·Green·Cyan·Trim·Bandage, 없으면 몸 색).
- 원점 표지 MonstersOrigin_Marker(1×1×1) — tools/MonsterMeshes.luau 가 원점·배율을 되찾아 ReplicatedStorage.MonsterMeshes 로 정리.

돌리는 법: blender -b -P models/monsters/build_monsters.py → 스튜디오 Ctrl+M 로 Monsters.fbx → bash tools/job.sh tools/MonsterMeshes.luau
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

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


PHI = (1 + 5 ** 0.5) / 2
RING_N = Vector((0.35, 1.0, -0.2)).normalized()  # 코어 코드 고리의 축(DebugBoss.luau RING_AXIS 와 같게)


def dodeca(R):
    """둘레 반지름 R 정십이면체: 면마다 (꼭짓점 5개(반시계, 바깥에서 볼 때), 가운데, 바깥 법선). 면 하나가 -Z 를 본다."""
    vs = [Vector(v) for v in
          [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
          + [(0, y / PHI, z * PHI) for y in (-1, 1) for z in (-1, 1)]
          + [(x / PHI, y * PHI, 0) for x in (-1, 1) for y in (-1, 1)]
          + [(x * PHI, 0, z / PHI) for x in (-1, 1) for z in (-1, 1)]]
    ns = [Vector(n).normalized() for n in
          [(0, y * PHI, z) for y in (-1, 1) for z in (-1, 1)]
          + [(x, 0, z * PHI) for x in (-1, 1) for z in (-1, 1)]
          + [(x * PHI, y, 0) for x in (-1, 1) for y in (-1, 1)]]
    rot = ns[0].rotation_difference(Vector((0, 0, -1)))
    k = R / 3 ** 0.5
    vs = [rot @ v * k for v in vs]
    ns = [rot @ n for n in ns]
    faces = []
    for n in ns:
        best = max(v.dot(n) for v in vs)
        ring = [v for v in vs if v.dot(n) > best - 1e-6]
        c = sum(ring, Vector()) / 5
        u = (ring[0] - c).normalized()
        w = n.cross(u)
        ring.sort(key=lambda v: math.atan2((v - c).dot(w), (v - c).dot(u)))
        faces.append((ring, c, n))
    return faces


def shell(m, R, glow_name, glow_col, BODYC, PANELC):
    """판 12장(사이 틈으로 속 빛이 보인다) + 판 가운데 거꾸로 선 작은 오각 패널 + 속 빛 다면체 — 전부 같이 돈다"""
    plate, panel = m.g("SpinPlate", BODYC, 30), m.g("SpinPanel", PANELC, 30)
    t = 0.08 * R
    for ring, c, n in dodeca(R):
        def loop(shrink, lift, turn=0.0):
            out = []
            for v in ring:
                d = (v - c) * shrink
                if turn:
                    d = Matrix.Rotation(turn, 3, n) @ d
                out.append(tuple(c + d + n * lift))
            return out
        L.loft(plate, [loop(0.9, -t), loop(0.9, -0.35 * t), loop(0.84, 0)])
        L.loft(panel, [loop(0.46, -0.01, math.radians(36)), loop(0.46, 0.035 * R, math.radians(36)), loop(0.4, 0.05 * R, math.radians(36))])
    g = m.g("SpinGlow" + glow_name, glow_col, None)
    for ring, c, n in dodeca(R * 0.93):
        L.loft(g, [[tuple(v) for v in ring], [tuple(c)]], cap_start=True, cap_end=False)


def debug():
    out = []
    BODYC, PANELC, TRIMC = rgb(34, 30, 48), rgb(58, 52, 80), rgb(88, 80, 116)
    MAG, RED, GREEN, CYAN = rgb(255, 70, 200), rgb(255, 48, 60), rgb(60, 235, 100), rgb(50, 170, 210)

    # 코어: 반지름 6 정십이면체(마젠타 속 빛) + 기운 코드 고리(점선처럼 끊긴 띠, 고리 축으로 돈다) + 앞에 뜬 팔면체 결정
    c = Model("DebugCore")
    shell(c, 6.0, "Magenta", MAG, BODYC, PANELC)
    ring = c.g("RingCyan", CYAN, None)
    u = RING_N.cross(Vector((0, 0, 1))).normalized()
    w = RING_N.cross(u)
    dashes = [5, 2, 9, 3, 4, 1, 7, 2, 3, 6, 2, 8, 4, 2, 5, 3]  # 코드 줄처럼 길고 짧게(합 = 마디 수)
    seg, a0 = sum(dashes) * 3, 0
    for i, ln in enumerate(dashes):
        if i % 2 == 0:
            pts = []
            for j in range(ln * 3 + 1):
                ang = math.tau * (a0 * 3 + j) / seg
                pts.append(tuple((u * math.cos(ang) + w * math.sin(ang)) * 9.5))
            L.tube(ring, pts, 1.0, 4, section=[(0.28, 0.07), (-0.28, 0.07), (-0.28, -0.07), (0.28, -0.07)])
        a0 += ln
    L.lathe(c.g("FloatMagentaCrystal", MAG, None), [(0, -1.5), (1.0, 0), (0, 1.5)], 6, (0, 0, -7.8), "Y")
    out.append(c)

    # 위성 셋: 반지름 2.3. 머리 = 청록 속 빛 + 벌레 더듬이, 삭제 = 붉은 속 빛, 패치 = 초록 속 빛 + 비스듬히 감은 붕대 띠
    h = Model("DebugHead")
    shell(h, 2.3, "Cyan", CYAN, BODYC, PANELC)
    t = h.g("MeshTrim", TRIMC, 35)
    for sx in (-1, 1):
        path = [(sx * 0.6, 1.9, 0.5), (sx * 0.9, 2.6, 0.6), (sx * 1.3, 3.2, 0.2), (sx * 1.6, 3.5, -0.4), (sx * 1.7, 3.5, -0.9)]
        L.tube(t, path, [0.11, 0.09, 0.08, 0.07, 0.06], 8)
        L.ball(h.g("MeshTipMagenta", MAG, None), (sx * 1.72, 3.48, -0.98), 0.17, 12, 8)
    out.append(h)

    a = Model("DebugDeleteArm")
    shell(a, 2.3, "Red", RED, BODYC, PANELC)
    out.append(a)

    a = Model("DebugPatchArm")
    shell(a, 2.3, "Green", GREEN, BODYC, PANELC)
    bd = a.g("MeshBandage", rgb(206, 198, 172), 50)
    n = Vector((0.55, 0.8, 0.25)).normalized()
    u = n.cross(Vector((0, 0, 1))).normalized()
    w = n.cross(u)
    pts = [tuple((u * math.cos(math.tau * i / 40) + w * math.sin(math.tau * i / 40)) * 2.42) for i in range(41)]
    L.tube(bd, pts, 1.0, 4, cap=False, section=[(0.07, 0.3), (-0.07, 0.3), (-0.07, -0.3), (0.07, -0.3)])
    end = Vector(pts[30])
    L.tube(bd, [tuple(end), tuple(end + Vector((0.1, -0.5, -0.15))), tuple(end + Vector((0.05, -1.0, -0.35))), tuple(end + Vector((0.15, -1.4, -0.45)))],
           [0.25, 0.23, 0.2, 0.16], 4, section=[(1.0, 0.25), (-1.0, 0.25), (-1.0, -0.25), (1.0, -0.25)])
    out.append(a)
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
