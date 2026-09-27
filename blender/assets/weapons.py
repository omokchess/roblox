"""무기 메시.

규칙: 손잡이 그립 = 원점, 날/머리 방향 = +Z (Roblox +Y), 날의 앞(베는 면) = +Y (Roblox -Z).
마커: Grip(원점), Tip(끝), TrailA/TrailB (휘두르기 궤적 Trail 부착점).
"""

import math

from mathutils import Vector

from swamplib.asset import Asset
from swamplib import geom, shapes as S


def _wrap(a, z0, z1, r, key="leather", turns=None):
    turns = turns or int((z1 - z0) / 0.18)
    with a.no_parts():
        pts = [Vector((math.cos(t * 1.1) * r, math.sin(t * 1.1) * r, z0 + (z1 - z0) * i / (turns * 6))) for i, t in enumerate([k * 2 * math.pi / 6 for k in range(turns * 6 + 1)])]
        a.tube(pts, 0.05, key, sides=4, caps=False, part=False)


def _blade(a, z0, length, w0, w1, thick, key="steel", curve=0.0, notch=None, spine_key=None):
    """외날 칼날: 앞쪽 날 가장자리가 얇아지는 단면."""
    n = 10
    verts, faces, uvs = [], [], []
    rows = []
    for i in range(n + 1):
        t = i / n
        z = z0 + length * t
        w = w0 + (w1 - w0) * t
        if i == n:
            w = 0.05
        yb = -w * 0.45 + curve * t * t      # 등(뒤)
        ye = w * 0.55 + curve * t * t        # 날(앞)
        if notch and notch[0] < t < notch[1]:
            yb += w * 0.25
        ids = [len(verts), len(verts) + 1, len(verts) + 2, len(verts) + 3]
        verts += [Vector((thick / 2, yb, z)), Vector((thick * 0.1, ye, z + 0.06 * (i == n))), Vector((-thick * 0.1, ye, z)), Vector((-thick / 2, yb, z))]
        rows.append(ids)
    for i in range(n):
        A, B = rows[i], rows[i + 1]
        for k in range(4):
            q = (A[k], A[(k + 1) % 4], B[(k + 1) % 4], B[k])
            faces.append(q)
            uvs.append(tuple((verts[j].y, verts[j].z) for j in q))
    faces.append(tuple(reversed(rows[0])))
    uvs.append(tuple((verts[j].x, verts[j].y) for j in reversed(rows[0])))
    faces.append(tuple(rows[-1]))
    uvs.append(tuple((verts[j].x, verts[j].y) for j in rows[-1]))
    # 방향 교정
    fixed_f, fixed_uv = [], []
    for f, uv in zip(faces, uvs):
        c = sum((verts[j] for j in f), Vector()) / len(f)
        axis_c = Vector((0, 0, c.z))
        nrm = (verts[f[1]] - verts[f[0]]).cross(verts[f[2]] - verts[f[0]])
        out = c - axis_c
        if len(f) == 4 and f in faces[-2:]:
            out = Vector((0, 0, 1)) if f == faces[-1] else Vector((0, 0, -1))
        if nrm.dot(out) < 0:
            f = tuple(reversed(f)); uv = tuple(reversed(uv))
        fixed_f.append(f); fixed_uv.append(uv)
    a.mesh((verts, fixed_f, fixed_uv, [False] * len(fixed_f)), key,
           part_boxes=[((0, (w0 + w1) * 0.05 + curve * 0.3, z0 + length / 2), (thick, (w0 + w1) / 2, length), None)])


def bogcleaver():
    a = Asset("W_Bogcleaver", "Weapon", description="늪지기 식칼 — 균형형 한손검")
    a.cyl((0, 0, -1.1), (0, 0, 0.9), 0.2, "wood_dark", sides=8)
    _wrap(a, -1.0, 0.8, 0.22)
    a.sphere((0, 0, -1.25), 0.3, "brass", seg=8, rings=6)
    a.box((0, 0.05, 1.05), (0.35, 1.5, 0.3), "iron", bevel=0.06)
    for sy in (-1, 1):
        a.sphere((0, sy * 0.78, 1.05), 0.2, "iron", seg=6, rings=4)
    _blade(a, 1.2, 3.6, 0.95, 1.25, 0.18, "steel", curve=0.25, notch=(0.55, 0.7))
    with a.no_parts():
        a.box((0.1, -0.15, 2.2), (0.04, 0.12, 2.0), "iron", bevel=0.0)
    a.marker("Grip", (0, 0, 0))
    a.marker("Tip", (0, 0.3, 4.8))
    a.marker("TrailA", (0, 0.2, 1.4))
    a.marker("TrailB", (0, 0.4, 4.6))
    return a


def harpoon():
    a = Asset("W_Harpoon", "Weapon", description="작살창 — 긴 사거리 찌르기, 투척")
    a.cyl((0, 0, -3.2), (0, 0, 5.4), 0.2, "wood_c", sides=8, bevel=0.03)
    _wrap(a, -0.8, 0.8, 0.22, "rope")
    _wrap(a, 4.6, 5.3, 0.22, "rope")
    a.cyl((0, 0, 5.2), (0, 0, 6.0), 0.28, "iron", r1=0.22, sides=8)
    # 창날 + 미늘
    prof = [(6.0, 0.3), (6.6, 0.42), (7.6, 0.2), (8.2, 0.02)]
    a.tube([Vector((0, 0, z)) for z, _ in prof], [r for _, r in prof], "steel", sides=4, part_step=3)
    for sy in (-1, 1):
        a.box_between((0, sy * 0.25, 6.3), (0, sy * 0.75, 5.6), 0.1, "steel", width=0.14)
    a.cyl((0, 0, -3.4), (0, 0, -3.1), 0.28, "iron", sides=8)
    with a.no_parts():
        for k in range(3):
            a.box((0.1 * (k - 1), 0.25, 4.4 - k * 0.2), (0.1, 0.06, 0.8), ("cloth_red", "cloth_green", "wood_dark")[k], rot=(15, 0, 0), bevel=0.0)
    a.marker("Grip", (0, 0, 0))
    a.marker("Tip", (0, 0, 8.2))
    a.marker("TrailA", (0, 0, 5.6))
    a.marker("TrailB", (0, 0, 8.0))
    return a


def mossmaul():
    a = Asset("W_Mossmaul", "Weapon", description="이끼 망치 — 느리고 강력한 양손 둔기")
    a.cyl((0, 0, -1.6), (0, 0, 5.4), 0.26, "wood_dark", sides=8, bevel=0.03)
    _wrap(a, -1.4, 0.9, 0.28)
    a.cyl((0, 0, -1.9), (0, 0, -1.5), 0.36, "iron", sides=8)
    # 돌 머리
    a.blob((0, 0, 5.4), 1.5, "stone", seg=10, rings=7, amp=0.12, scale=(1.0, 1.6, 0.9), part=False)
    a._prim_box_only((0, 0, 5.4), (2.2, 4.2, 2.2), "stone")
    for y in (-1.1, 1.1):
        a.cyl((0, y - 0.2, 5.4), (0, y + 0.2, 5.4), 1.45, "iron", sides=12)
    with a.no_parts():
        for k in range(4):
            ang = k * math.pi / 2
            a.cyl((0, 0, 4.4), (math.cos(ang) * 1.3, math.sin(ang) * 0.4, 5.6), 0.07, "rope", sides=3)
        a.blob((0.2, 0.3, 6.5), 0.9, "moss", seg=7, rings=5, amp=0.3, scale=(1.3, 1.6, 0.4))
    a.marker("Grip", (0, 0, 0))
    a.marker("Tip", (0, 0, 6.8))
    a.marker("TrailA", (0, -2.4, 5.4))
    a.marker("TrailB", (0, 2.4, 5.4))
    return a


def witch_staff():
    a = Asset("W_WitchStaff", "Weapon", description="늪 마녀의 지팡이 (발광 구슬)")
    pts = [Vector((0.1 * math.sin(i), 0.1 * math.cos(i * 1.3), -3.0 + i * 1.1)) for i in range(9)]
    a.tube(pts, [0.18, 0.2, 0.19, 0.2, 0.22, 0.24, 0.28, 0.34, 0.4], "bark", sides=7, noise_amp=0.15, part_step=2)
    top = pts[-1]
    for k in range(4):
        ang = k * math.pi / 2
        a.tube([top, top + Vector((math.cos(ang) * 0.7, math.sin(ang) * 0.7, 0.8)), top + Vector((math.cos(ang) * 0.4, math.sin(ang) * 0.4, 1.8))], [0.15, 0.1, 0.04], "bark", sides=5, part_step=2)
    a.sphere(top + Vector((0, 0, 1.0)), 0.55, "glow_potion", seg=10, rings=7)
    a.light(top + Vector((0, 0, 1.0)), color=(180, 110, 255), range_=10, brightness=1.2)
    with a.no_parts():
        a.cyl(top - Vector((0, 0, 0.3)), top - Vector((0.2, 0, 1.6)), 0.03, "rope_dk", sides=3)
        a.box(top - Vector((0.2, 0, 1.8)), (0.1, 0.1, 0.5), "bone", bevel=0.02)
    a.marker("Grip", (0, 0, 0))
    a.marker("Tip", tuple(top + Vector((0, 0, 1.0))))
    return a


def brute_club():
    a = Asset("W_BruteClub", "Weapon", description="진흙 거인의 통나무 곤봉")
    pts = [Vector((0, 0, -1.5 + i * 1.6)) for i in range(7)]
    a.tube(pts, [0.45, 0.5, 0.6, 0.8, 1.0, 1.2, 1.25], "bark_dead", sides=9, noise_amp=0.18, part_step=2)
    for k in range(6):
        ang = k * 2.1
        z = 4.5 + (k % 3) * 1.4
        r = 0.9 + (z - 4.5) * 0.15
        a.cyl((math.cos(ang) * r * 0.8, math.sin(ang) * r * 0.8, z), (math.cos(ang) * (r + 1.0), math.sin(ang) * (r + 1.0), z + 0.3), 0.18, "bone", r1=0.04, sides=5)
    with a.no_parts():
        a.blob((0.5, 0, 7.5), 0.9, "moss", seg=7, rings=5, amp=0.3, scale=(1.3, 1.3, 0.5))
    a.marker("Grip", (0, 0, 0))
    a.marker("Tip", (0, 0, 8.0))
    a.marker("TrailA", (0, 0, 4.0))
    a.marker("TrailB", (0, 0, 8.0))
    return a


ASSETS = [bogcleaver, harpoon, mossmaul, witch_staff, brute_club]
for _f in ASSETS:
    _f.preview = {"env": "mud", "azim": 70, "elev": 12, "pad": 1.3}
