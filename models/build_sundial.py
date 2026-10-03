# -*- coding: utf-8 -*-
"""
build_sundial.py — 2026-10-03. 절화 광장 해시계(앙부일구) Sundial.

사용자(2026-10-03): "절화 광장쪽 해시계를 표현한것 같은데, 블렌더로 해서 만들어줘."
레퍼런스: 조선 앙부일구(仰釜日晷, 보물) — 돌 대석 위 十자 받침, 네 다리가 받치는 청동 반구 솥,
솥 안쪽 시각선(세로 7)·절기선(가로 3), 북쪽 테에서 솥 가운데로 북극을 가리키는 영침(위도 37.5°).
치수는 스터드(배율 1). 원점 = 대석 밑 가운데, +z 위, +y 가 북쪽(로블록스로 가면 Jeolhwa_Sundial 이 돌려 앉힌다).

돌리는 법: blender --background --python build_sundial.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hanok_lib as L

PALETTE = {
    "Granite": "#8F8B80",   # 대석 아래 켜·기둥
    "Stone": "#BAB5A7",     # 대석 위 켜·머릿돌
    "Bronze": "#5E4A2A",    # 솥·받침·다리
    "Gilt": "#C9AE6E",      # 솥 안 시각선·절기선, 영침
    "Marker": "#ff00ff",
}

C = (0.0, 0.0, 5.2)   # 솥(반구) 가운데 = 테 높이
RO, RI = 1.35, 1.2    # 솥 바깥·안 반지름
LAT = math.radians(37.5)


def rod(grp, p0, p1, w):
    """p0 → p1 네모 막대(굵기 w)"""
    dx, dy, dz = (p1[i] - p0[i] for i in range(3))
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    mid = tuple((p0[i] + p1[i]) / 2 for i in range(3))
    rz = math.atan2(dy, dx)
    ry = -math.atan2(dz, math.hypot(dx, dy))
    grp.obox(mid[0], mid[1], mid[2], length, w, w, ry=ry, rz=rz)


def ring(grp, z0, z1, r_in, r_out, seg=48):
    """닫힌 고리(납작한 원통에서 가운데를 뺀 것)"""
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ca, sa = math.cos(a), math.sin(a)
        verts += [(r_in * ca, r_in * sa, z0), (r_out * ca, r_out * sa, z0),
                  (r_out * ca, r_out * sa, z1), (r_in * ca, r_in * sa, z1)]
    for i in range(seg):
        j = (i + 1) % seg
        a, b = 4 * i, 4 * j
        faces += [(a + 1, b + 1, b + 2, a + 2),   # 바깥
                  (a + 3, b + 3, b + 0, a + 0),   # 안
                  (a + 2, b + 2, b + 3, a + 3),   # 위
                  (a + 0, b + 0, b + 1, a + 1)]   # 아래
    grp.add_mesh([(x + C[0], y + C[1], z) for x, y, z in verts], faces)


def hemi_shell(grp, ro, ri, lat=12, lon=40):
    """테(z = C) 아래로 늘어진 반구 껍데기. 바깥·안 두 겹과 테 면"""
    def pt(r, t, p):
        # t: 0(테) → π/2(바닥), p: 경도
        return (C[0] + r * math.cos(t) * math.cos(p), C[1] + r * math.cos(t) * math.sin(p), C[2] - r * math.sin(t))
    verts, faces = [], []
    idx = {}
    for layer, r in enumerate((ro, ri)):
        for i in range(lat + 1):
            t = (math.pi / 2) * i / lat
            for j in range(lon):
                idx[(layer, i, j)] = len(verts)
                verts.append(pt(r, t, 2 * math.pi * j / lon))
    for layer in (0, 1):
        for i in range(lat):
            for j in range(lon):
                k = (j + 1) % lon
                a, b = idx[(layer, i, j)], idx[(layer, i, k)]
                c, d = idx[(layer, i + 1, k)], idx[(layer, i + 1, j)]
                faces.append((a, b, c, d) if layer == 0 else (a, d, c, b))
    for j in range(lon):   # 테 면
        k = (j + 1) % lon
        faces.append((idx[(1, 0, j)], idx[(1, 0, k)], idx[(0, 0, k)], idx[(0, 0, j)]))
    grp.add_mesh(verts, faces)


def arc_strip(grp, r, t0, t1, p0, p1, width, steps=16):
    """반구 안쪽 면(반지름 r)에 붙는 가는 띠. t·p 를 t0→t1, p0→p1 로 잇는다"""
    verts, faces = [], []
    for s in range(steps + 1):
        u = s / steps
        t, p = t0 + (t1 - t0) * u, p0 + (p1 - p0) * u
        # 띠의 옆 방향: 진행 방향과 지름 방향에 수직 — 작은 띠라 경도·위도 쪽으로만 벌린다
        if abs(p1 - p0) > 1e-6:      # 가로(절기선): 위아래로 벌림
            dt, dp = width / (2 * r), 0.0
        else:                         # 세로(시각선): 옆으로 벌림
            dt, dp = 0.0, width / (2 * r * max(0.2, math.cos(t)))
        for sgn in (-1, 1):
            tt, pp = t + sgn * dt, p + sgn * dp
            verts.append((C[0] + r * math.cos(tt) * math.cos(pp), C[1] + r * math.cos(tt) * math.sin(pp), C[2] - r * math.sin(tt)))
    for s in range(steps):
        a = 2 * s
        faces.append((a, a + 1, a + 3, a + 2))
        faces.append((a, a + 2, a + 3, a + 1))   # 뒷면도(얇은 판이라 양쪽에서 보이게)
    grp.add_mesh(verts, faces)


def sundial(g):
    # 대석: 두 켜 받침 → 네모 기둥(네 면에 액자 틀) → 머릿돌
    g["Granite"].box(0, 0, 0.225, 4.6, 4.6, 0.45)
    g["Stone"].box(0, 0, 0.65, 3.8, 3.8, 0.4)
    g["Granite"].box(0, 0, 0.85 + 1.2, 2.0, 2.0, 2.4)
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        # 면마다 액자 틀(위·아래·옆) — 기둥 면에서 0.05 도드라짐
        fx, fy = sx * 1.0, sy * 1.0
        along_x = sy != 0
        w = 1.5
        for dz in (-0.85, 0.85):
            if along_x:
                g["Stone"].box(0, fy + sy * 0.03, 2.05 + dz, w, 0.08, 0.12)
            else:
                g["Stone"].box(fx + sx * 0.03, 0, 2.05 + dz, 0.08, w, 0.12)
        for d in (-w / 2, w / 2):
            if along_x:
                g["Stone"].box(d, fy + sy * 0.03, 2.05, 0.12, 0.08, 1.82)
            else:
                g["Stone"].box(fx + sx * 0.03, d, 2.05, 0.08, 0.12, 1.82)
    g["Stone"].box(0, 0, 3.25 + 0.175, 2.7, 2.7, 0.35)
    g["Stone"].box(0, 0, 3.6 + 0.04, 2.45, 2.45, 0.08)

    # 十자 받침(청동) — 가운데에 물 고르는 홈(가는 금빛 줄)
    zb = 3.68
    g["Bronze"].box(0, 0, zb + 0.15, 3.2, 0.45, 0.3)
    g["Bronze"].box(0, 0, zb + 0.15, 0.45, 3.2, 0.3)
    g["Gilt"].box(0, 0, zb + 0.305, 3.0, 0.1, 0.02)
    g["Gilt"].box(0, 0, zb + 0.305, 0.1, 3.0, 0.02)
    # 받침 끝 발톱
    for a in range(4):
        ang = a * math.pi / 2
        ex, ey = 1.55 * math.cos(ang), 1.55 * math.sin(ang)
        g["Bronze"].box(ex, ey, zb + 0.2, 0.42, 0.42, 0.4)

    # 네 다리: 받침 끝에서 솥 테 바로 아래로 휘어 올라간다(두 토막)
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4 * 0  # 받침 끝과 같은 방향
        ca, sa = math.cos(ang), math.sin(ang)
        p0 = (1.5 * ca, 1.5 * sa, zb + 0.35)
        p1 = (1.58 * ca, 1.58 * sa, zb + 0.95)
        p2 = (RO * 0.98 * ca, RO * 0.98 * sa, C[2] - 0.25)
        rod(g["Bronze"], p0, p1, 0.2)
        rod(g["Bronze"], p1, p2, 0.18)

    # 솥: 반구 껍데기 + 굵은 테
    hemi_shell(g["Bronze"], RO, RI)
    ring(g["Bronze"], C[2] - 0.04, C[2] + 0.1, RI - 0.02, RO + 0.1)
    # 솥 안 시각선(세로 7: 묘시~유시) · 절기선(가로 3: 하지·춘추분·동지)
    r_line = RI - 0.012
    for h in range(7):
        p = math.radians(-180 + 22.5 * (h + 1)) + math.pi  # 남쪽 반 바퀴(동→서)
        arc_strip(g["Gilt"], r_line, 0.06, math.pi / 2 - 0.12, p, p, 0.035)
    for t in (math.radians(20), math.radians(40), math.radians(60)):
        arc_strip(g["Gilt"], r_line, t, t, math.radians(15), math.radians(165), 0.035, steps=24)

    # 영침: 북쪽 테에서 솥 가운데로, 북극(위도 37.5°)을 가리킨다
    top = (0.0, RI * math.cos(LAT), C[2] + RI * math.sin(LAT))
    rod(g["Gilt"], (0.0, 0.0, C[2]), top, 0.06)
    rod(g["Bronze"], (0.0, RI + 0.02, C[2] + 0.05), top, 0.09)

    g["Marker"].box(0, 0, 0.2, 0.4, 0.4, 0.4)


L.clear_scene()
g = L.new_groups("Sun", PALETTE)
sundial(g)
L.export_model("Sundial", g, 1.0, renders=[
    ("front", (7, -9, 6), (0, 0, 3.6)),
    ("top", (2, -4, 10), (0, 0, 4.6)),
], min_objs=4, palette=PALETTE)
