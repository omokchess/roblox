# -*- coding: utf-8 -*-
"""
field_pois.py — 들판의 특별한 자리(POI)를 부품으로 짓는다. (2026-09-29) field_parts.Out 에 부품을 넣는다.

방향: yaw 0 = 앞이 북(+Z), 90 = 동(+X). 앞 벡터 f = (sin yaw, cos yaw), 오른쪽 r = (cos yaw, -sin yaw).
원기둥(C)은 X 축이 길이라 세울 때 rz=90.
"""
import math

from field_lib import hash01
from field_parts import BASALT, shade

POROUS = (74, 70, 66)  # 구멍 숭숭 현무암(돌하르방·방사탑)


def frame(yaw):
    a = math.radians(yaw)
    return (math.sin(a), math.cos(a)), (math.cos(a), -math.sin(a))


def at(x, z, yaw, lx, lz):
    """제자리 앞(lz)·오른쪽(lx) 거리 → 세계 x, z"""
    (fx, fz), (rx, rz) = frame(yaw)
    return x + rx * lx + fx * lz, z + rz * lx + fz * lz


def ry_of(yaw):
    """모델 yaw(앞 = +Z 기준) → 부품 Y 회전(도). 부품 X 축이 오른쪽을 보게."""
    return -yaw


def beacon(out, x, z, yaw, grp, top):
    y = top
    out.part(grp, x, y + 1.5, z, 3.0, 13, 13, rz=90, mat="Basalt", col=BASALT[1], shape="C", name="BeaconBase")
    out.part(grp, x, y + 3.4, z, 0.8, 11.4, 11.4, rz=90, mat="Slate", col=(84, 80, 76), shape="C", name="BeaconTop")
    out.part(grp, x, y + 7.0, z, 6.5, 5.2, 5.2, rz=90, mat="Basalt", col=BASALT[3], shape="C", name="BeaconChimney")
    out.part(grp, x, y + 10.3, z, 0.6, 3.6, 3.6, rz=90, mat="Basalt", col=(30, 28, 28), shape="C", name="Soot")
    for k in range(3):
        lx, lz = 8.2, -2.0 - k * 2.2
        px, pz = at(x, z, yaw, 0, -7.0 - k * 2.2)
        out.part(grp, px, y + 2.6 - k * 1.0, pz, 5, 0.9, 2.2, ry=ry_of(yaw), mat="Basalt", col=BASALT[0], name="BeaconStep")


def shrine(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    out.kit(grp, "PlainsTree", x, z, yaw, 1.5, anchor=a)
    px, pz = at(x, z, yaw, 0, 9)
    b = out.anchor(px, pz)
    out.part(grp, px, 0.6, pz, 4, 1.2, 2.4, ry=ry_of(yaw), mat="Basalt", col=BASALT[2], anchor=b, name="Altar")
    out.part(grp, px, 1.45, pz, 2.4, 0.5, 1.4, ry=ry_of(yaw), mat="Slate", col=(90, 86, 80), anchor=b, name="AltarTop")
    # 반쯤 두른 돌담(뒤쪽 반원)
    for k in range(13):
        ang = math.radians(100 + k * 13.3 + yaw)
        sx, sz = x + math.sin(ang) * 13, z + math.cos(ang) * 13
        c = out.anchor(sx, sz)
        out.part(grp, sx, 0.9, sz, 3.2, 2.0, 1.8, ry=-(math.degrees(ang)), mat="Basalt", col=BASALT[k % 5], anchor=c,
                 name="ShrineWall")
    # 천 조각을 건 줄
    p1 = at(x, z, yaw, -6, 6)
    p2 = at(x, z, yaw, 6, 6)
    for (qx, qz) in (p1, p2):
        c = out.anchor(qx, qz)
        out.part(grp, qx, 3.0, qz, 0.5, 6.0, 0.5, mat="Wood", col=(90, 66, 42), anchor=c, name="ClothPost")
    c = out.anchor((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
    out.part(grp, (p1[0] + p2[0]) / 2, 5.6, (p1[1] + p2[1]) / 2, 12, 0.15, 0.15, ry=ry_of(yaw), mat="Fabric",
             col=(230, 222, 200), anchor=c, name="Rope")
    colors = [(240, 240, 236), (200, 40, 40), (40, 70, 170), (230, 190, 40), (240, 240, 236), (60, 140, 70)]
    for k, col in enumerate(colors):
        qx, qz = at(x, z, yaw, -4.5 + k * 1.8, 6)
        out.part(grp, qx, 4.4, qz, 0.8, 2.3, 0.1, ry=ry_of(yaw), mat="Fabric", col=col, anchor=c, name="Cloth")


def cave_arch(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    for s in (-1, 1):
        px, pz = at(x, z, yaw, s * 6.5, 0)
        out.part(grp, px, 4.5, pz, 4, 10, 5, ry=ry_of(yaw) + s * 6, mat="Basalt", col=BASALT[0], anchor=a, name="ArchSide")
    out.part(grp, x, 10.2, z, 17, 3.2, 6, ry=ry_of(yaw), rz=3, mat="Basalt", col=BASALT[2], anchor=a, name="ArchTop")
    out.part(grp, x, 12.8, z, 22, 3, 8, ry=ry_of(yaw) + 4, mat="Basalt", col=BASALT[3], anchor=a, name="ArchTop2")
    # 안쪽 어둠(들어가면 막힌 굴)
    px, pz = at(x, z, yaw, 0, -4)
    out.part(grp, px, 4.2, pz, 9, 8.5, 4, ry=ry_of(yaw), mat="SmoothPlastic", col=(8, 8, 10), anchor=a, name="CaveDark")
    for k in range(5):
        qx, qz = at(x, z, yaw, -6 + k * 3 + hash01(x, z, k) * 1.5, 4 + hash01(z, x, k) * 3)
        c = out.anchor(qx, qz)
        s = 1.4 + hash01(x, z, 10 + k) * 1.4
        out.part(grp, qx, s * 0.3, qz, s, s * 0.7, s * 0.9, ry=k * 41, rx=8, mat="Basalt", col=BASALT[k % 5], anchor=c,
                 name="Rubble")


def pier(out, x, z, yaw, grp, length=80):
    n = int(length / 8)
    for k in range(n):
        px, pz = at(x, z, yaw, 0, k * 8 + 4)
        out.part(grp, px, -5.4, pz, 10.5, 13.2, 8.6, ry=ry_of(yaw) + (hash01(px, pz, 1) - 0.5) * 3, mat="Basalt",
                 col=BASALT[k % 5], name="PierBlock")
        out.part(grp, px, 1.35, pz, 10, 0.5, 8.2, ry=ry_of(yaw), mat="Slate", col=(96, 92, 86), name="PierTop")
    px, pz = at(x, z, yaw, 3.5, length - 4)
    out.part(grp, px, 2.4, pz, 1.2, 2.2, 1.2, mat="Basalt", col=BASALT[3], name="Bollard")


def bulteok(out, x, z, yaw, grp):
    for k in range(16):
        if k in (0, 1):
            continue
        ang = math.radians(k * 22.5 + yaw)
        sx, sz = x + math.sin(ang) * 6, z + math.cos(ang) * 6
        c = out.anchor(sx, sz)
        h = 2.6 + hash01(sx, sz, 1) * 0.8
        out.part(grp, sx, h / 2 - 0.2, sz, 2.6, h, 1.8, ry=-(math.degrees(ang)), mat="Basalt", col=BASALT[k % 5],
                 anchor=c, name="Bulteok")
    c = out.anchor(x, z)
    out.part(grp, x, 0.2, z, 3, 0.4, 3, mat="Basalt", col=(30, 28, 28), anchor=c, name="FirePit")


def bangsatap(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    y = 0
    for k, r in enumerate((3.8, 3.2, 2.6, 2.0, 1.4)):
        out.part(grp, x, y + 0.8, z, 1.7, r * 2, r * 2, rz=90, mat="Basalt", col=shade(POROUS, 0.9 + 0.06 * k),
                 shape="C", anchor=a, name="Tap")
        y += 1.55
    out.part(grp, x, y + 1.0, z, 0.9, 2.0, 1.4, ry=ry_of(yaw), mat="Basalt", col=POROUS, anchor=a, name="TapBird")


def fish_rack(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    for s in (-1, 1):
        px, pz = at(x, z, yaw, s * 5, 0)
        out.part(grp, px, 2.6, pz, 0.5, 5.2, 0.5, mat="Wood", col=(96, 72, 46), anchor=a, name="RackPost")
    for hh in (3.4, 4.8):
        out.part(grp, x, hh, z, 10.5, 0.3, 0.3, ry=ry_of(yaw), mat="Wood", col=(110, 82, 52), anchor=a, name="RackBar")
        for k in range(6):
            px, pz = at(x, z, yaw, -4 + k * 1.6, 0)
            out.part(grp, px, hh - 0.9, pz, 0.3, 1.5, 0.7, ry=ry_of(yaw), mat="SmoothPlastic", col=(170, 176, 180),
                     anchor=a, name="Fish")


def boat(out, x, z, yaw, grp):
    y = -3.2
    wood = (116, 84, 54)
    out.part(grp, x, y, z, 3.4, 0.7, 11, ry=ry_of(yaw), mat="WoodPlanks", col=wood, name="BoatBottom")
    for s in (-1, 1):
        px, pz = at(x, z, yaw, s * 1.9, 0)
        out.part(grp, px, y + 1.0, pz, 0.4, 1.8, 10.4, ry=ry_of(yaw), rz=s * 14, mat="WoodPlanks", col=shade(wood, 1.1),
                 name="BoatSide")
    px, pz = at(x, z, yaw, 0, 6.2)
    out.part(grp, px, y + 0.8, pz, 3.6, 2.0, 2.4, ry=ry_of(yaw), mat="WoodPlanks", col=wood, shape="W", name="BoatBow")
    out.part(grp, x, y + 1.0, z, 3.2, 0.3, 1.0, ry=ry_of(yaw), mat="Wood", col=shade(wood, 0.9), name="BoatSeat")


def trough(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    out.part(grp, x, 0.8, z, 6, 1.6, 2.4, ry=ry_of(yaw), mat="Wood", col=(100, 74, 48), anchor=a, name="Trough")
    out.part(grp, x, 1.55, z, 5.2, 0.2, 1.7, ry=ry_of(yaw), mat="SmoothPlastic", col=(70, 120, 140), anchor=a,
             name="Water")


def sandam(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    out.part(grp, x, 0.2, z, 7, 3.2, 7, mat="Grass", col=(110, 146, 78), shape="S", anchor=a, name="Mound")
    hw, hd = 7.0, 8.0
    edges = [((-hw, -hd), (hw, -hd)), ((hw, -hd), (hw, hd)), ((hw, hd), (-hw, hd)), ((-hw, hd), (-hw, -hd))]
    for e, ((ax, az), (bx, bz)) in enumerate(edges):
        L = math.hypot(bx - ax, bz - az)
        n = int(L / 2.6)
        for k in range(n):
            t = (k + 0.5) / n
            lx, lz = ax + (bx - ax) * t, az + (bz - az) * t
            if e == 0 and abs(lx) < 1.8:
                continue  # 신문(앞 트인 곳)
            px, pz = at(x, z, yaw, lx, lz)
            c = out.anchor(px, pz)
            out.part(grp, px, 0.8, pz, 2.7, 1.8, 1.6, ry=ry_of(yaw) + (90 if e % 2 else 0), mat="Basalt",
                     col=BASALT[(k + e) % 5], anchor=c, name="Sandam")


def pond(out, x, z, yaw, grp, r=40):
    a = out.anchor(x, z)
    out.part(grp, x, 0.25, z, 0.5, r * 2, r * 1.6, rz=90, ry=ry_of(yaw), mat="SmoothPlastic", col=(64, 116, 132),
             shape="C", anchor=a, name="Water")
    for k in range(18):
        ang = math.radians(k * 20 + hash01(x, z, k) * 8)
        rr = r * (0.98 + hash01(x, z, 30 + k) * 0.1)
        px, pz = x + math.sin(ang) * rr, z + math.cos(ang) * rr * 0.8
        c = out.anchor(px, pz)
        if k % 3 == 0:
            for j in range(5):
                qx, qz = px + (hash01(px, pz, j) - 0.5) * 3, pz + (hash01(pz, px, j) - 0.5) * 3
                out.part(grp, qx, 2.2, qz, 0.3, 4.4 + j * 0.3, 0.3, rz=(hash01(qx, qz, 9) - 0.5) * 20, mat="Grass",
                         col=(96, 130, 64), anchor=c, name="Reed")
        else:
            s = 2.5 + hash01(px, pz, 5) * 2.5
            out.part(grp, px, s * 0.2, pz, s, s * 0.6, s * 0.8, ry=k * 33, mat="Basalt", col=BASALT[k % 5], anchor=c,
                     name="PondRock")


def dolhareubang(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    ry = ry_of(yaw + 180)  # 길을 바라본다(남쪽)
    out.part(grp, x, 0.5, z, 3.2, 1.0, 3.0, ry=ry, mat="Basalt", col=BASALT[0], anchor=a, name="HarubangBase")
    out.part(grp, x, 3.0, z, 2.6, 4.0, 2.2, ry=ry, mat="Basalt", col=POROUS, anchor=a, name="HarubangBody")
    out.part(grp, x, 6.2, z, 2.7, 2.6, 2.5, ry=ry, mat="Basalt", col=shade(POROUS, 1.05), anchor=a, name="HarubangHead")
    out.part(grp, x, 7.7, z, 0.5, 3.2, 3.2, rz=90, mat="Basalt", col=shade(POROUS, 0.95), shape="C", anchor=a,
             name="HarubangBrim")
    out.part(grp, x, 8.6, z, 1.4, 2.3, 2.3, rz=90, mat="Basalt", col=shade(POROUS, 0.95), shape="C", anchor=a,
             name="HarubangHat")
    fx, fz = frame(yaw + 180)[0]
    for s in (-1, 1):
        (rx, rz) = frame(yaw + 180)[1]
        ex, ez = x + fx * 1.25 + rx * 0.6 * s, z + fz * 1.25 + rz * 0.6 * s
        out.part(grp, ex, 6.6, ez, 0.8, 0.8, 0.5, ry=ry, mat="Basalt", col=(40, 38, 38), shape="S", anchor=a,
                 name="HarubangEye")
        hx, hz = x + fx * 1.15 + rx * 0.7 * s, z + fz * 1.15 + rz * 0.7 * s
        out.part(grp, hx, 2.6 + (0.6 if s > 0 else 0), hz, 1.1, 0.7, 0.4, ry=ry, mat="Basalt", col=shade(POROUS, 1.1),
                 anchor=a, name="HarubangHand")
    nx, nz = x + fx * 1.4, z + fz * 1.4
    out.part(grp, nx, 5.9, nz, 0.7, 1.0, 0.6, ry=ry, mat="Basalt", col=shade(POROUS, 1.1), anchor=a, name="HarubangNose")


def tor(out, x, z, yaw, grp):
    a = out.anchor(x, z)
    y = 0
    for k in range(5):
        s = 9 - k * 1.4
        h = 3.2 + hash01(x, z, 200 + k) * 1.4
        ox, oz = (hash01(x, z, 210 + k) - 0.5) * 2.4, (hash01(x, z, 220 + k) - 0.5) * 2.4
        out.part(grp, x + ox, y + h / 2 - 0.4, z + oz, s, h, s * 0.8, ry=yaw + k * 29, rx=(hash01(x, z, 230 + k) - 0.5) * 8,
                 mat="Basalt", col=BASALT[k % 5], anchor=a, name="Tor")
        y += h - 0.8
    for k in range(4):
        ang = math.radians(yaw + 40 + k * 85)
        px, pz = x + math.sin(ang) * 7, z + math.cos(ang) * 7
        c = out.anchor(px, pz)
        s = 2.4 + hash01(px, pz, 1) * 2
        out.part(grp, px, s * 0.3, pz, s, s * 0.7, s * 0.85, ry=k * 51, rx=10, mat="Basalt", col=BASALT[(k + 2) % 5],
                 anchor=c, name="TorRock")


BUILDERS = {
    "Shrine": shrine, "CaveArch": cave_arch, "Pier": pier, "Bulteok": bulteok, "Bangsatap": bangsatap,
    "FishRack": fish_rack, "Boat": boat, "Trough": trough, "Sandam": sandam, "Pond": pond,
    "Dolhareubang": dolhareubang, "Tor": tor,
}
