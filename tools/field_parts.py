# -*- coding: utf-8 -*-
"""
field_parts.py — 들판 배치표(tools/fields/*.py)를 **부품 목록**으로 바꾼다. (2026-09-29)

배치표가 정한 자리·모양 안을 고르게 채우는 규칙만 여기 있다(판 깔기, 오름 층, 돌담 돌, 밭 이랑, 길 토막, 계단, 바위 …).
결과는 한 줄에 부품 하나인 글(tools/swamp/field_parts.txt) — Studio 의 tools/Field_Build.luau 가 읽어 세운다.

한 줄 형식(공백 구분)
  G <묶음 번호> <묶음 경로>                         묶음(폴더) 이름표
  A <닻 번호> <x> <z> [<y 대신 쓸 값>]               닻: Studio 가 (x,z) 에서 아래로 쏜 광선이 맞은 땅 높이(없으면 y 대신 값)
  P <모양> <닻|-> <x> <y> <z> <sx> <sy> <sz> <ry> <rx> <rz> <재질> <r> <g> <b> <묶음> [<이름>]
      모양 B=네모 W=쐐기 C=원기둥(X 축) S=공. 닻이 있으면 y 는 닻 높이에서 더한 값. 각은 도(Y→X→Z 순서로 돈다)
  K <틀> <닻|-> <x> <y> <z> <yaw> <배율> <묶음>    복제할 틀(절화 틀·평원 나무). y 는 바닥 높이
"""
import math

from field_lib import hash01, line_dist, pip, oreum_profile, seg_dist


class Out:
    def __init__(self):
        self.lines = []
        self.groups = {}
        self.anchors = 0
        self.count = {"P": 0, "K": 0}

    def group(self, path):
        if path not in self.groups:
            self.groups[path] = len(self.groups) + 1
            self.lines.append("G %d %s" % (self.groups[path], path.replace(" ", "_")))
        return self.groups[path]

    def anchor(self, x, z, fallback=None):
        self.anchors += 1
        self.lines.append("A %d %.2f %.2f%s" % (self.anchors, x, z, "" if fallback is None else " %.2f" % fallback))
        return self.anchors

    def part(self, grp, x, y, z, sx, sy, sz, ry=0.0, rx=0.0, rz=0.0, mat="Rock", col=(128, 128, 128), shape="B",
             anchor=None, name=""):
        g = self.group(grp)
        self.count["P"] += 1
        self.lines.append("P %s %s %.2f %.2f %.2f %.2f %.2f %.2f %.1f %.1f %.1f %s %d %d %d %d%s" % (
            shape, anchor or "-", x, y, z, max(0.05, sx), max(0.05, sy), max(0.05, sz), ry, rx, rz, mat,
            int(col[0]), int(col[1]), int(col[2]), g, (" " + name) if name else ""))

    def kit(self, grp, kind, x, z, yaw, scale=1.0, anchor=None, y=0.0):
        g = self.group(grp)
        self.count["K"] += 1
        self.lines.append("K %s %s %.2f %.2f %.2f %.1f %.3f %d" % (kind, anchor or "-", x, y, z, yaw, scale, g))

    def text(self):
        return "\n".join(self.lines) + "\n"


def shade(col, k):
    return tuple(max(0, min(255, int(v * k))) for v in col)


# ------------------------------------------------------------------ 땅 판
def land(out, plates, grp):
    for i, p in enumerate(plates):
        y = p["y"]
        out.part(grp + "/판", p["x"], y - 2.35, p["z"], p["s"], 4.7, p["t"], ry=p["yaw"], mat=p["m"], col=p["c"],
                 name="Gs_F")
        if p["base"]:
            bottom = -27.0
            top = y - 4.7
            h = top - bottom
            if h > 1:
                out.part(grp + "/받침", p["x"], bottom + h / 2, p["z"], p["s"] * 0.94, h, p["t"] * 0.94, ry=p["yaw"],
                         mat="Rock", col=(101, 98, 90), name="Gb_F")


# ------------------------------------------------------------------ 오름(층층이 쌓은 기둥 판)
OREUM_TONE = {
    "억새": [(188, 176, 118), (176, 168, 108), (200, 186, 128), (166, 160, 100)],
    "풀": [(112, 150, 78), (120, 156, 84), (104, 142, 74), (126, 160, 90)],
}
LOW_TONE = [(116, 150, 82), (110, 146, 78)]


def oreum(out, o, g, coast, grp, cut_lines=(), sp=20.0, dh=3.5):
    """g: 땅 높이 함수 객체. cut_lines: (점들, 반폭) — 계단이 지나는 골(기둥을 비운다)."""
    y0 = g.y(o["x"], o["z"])
    R = max(o["rx"], o["rz"])
    tone = OREUM_TONE.get(o.get("tone", "풀"), OREUM_TONE["풀"])
    cols = {}
    n = int(R / sp) + 2
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            x = o["x"] + i * sp
            z = o["z"] + j * sp
            prof = oreum_profile(o, x, z)
            if prof < 1.2:
                continue
            if coast and not pip(x, z, coast):
                continue
            if any(line_dist(x, z, pts) < hw for pts, hw in cut_lines):
                continue
            q = max(1, round(prof / dh))
            cols[(i, j)] = (x, z, q, prof)
    for (i, j), (x, z, q, prof) in cols.items():
        lowest = q
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = cols.get((i + di, j + dj))
            lowest = min(lowest, nb[2] if nb else 0)
        top = y0 + q * dh
        bottom = y0 + lowest * dh - 1.0
        h = top - bottom
        jx = (hash01(x, z, 11) - 0.5) * sp * 0.25
        jz = (hash01(x, z, 12) - 0.5) * sp * 0.25
        size = sp * (1.28 + hash01(x, z, 13) * 0.25)
        frac = prof / o["h"]
        if o.get("tone") == "억새" and frac < 0.18:
            col = LOW_TONE[int(hash01(x, z, 14) * 2)]
        else:
            col = tone[int(hash01(x, z, 14) * len(tone))]
        out.part(grp, x + jx, bottom + h / 2, z + jz, size, h, size * (0.9 + hash01(x, z, 15) * 0.2),
                 ry=hash01(x, z, 16) * 90, mat="Grass", col=col, name="Or")
        # 바다에 잘린 가장자리: 벼랑 바위를 물 밑까지
        if coast and min(seg_dist(x, z, coast[k], coast[(k + 1) % len(coast)]) for k in range(len(coast))) < sp * 1.2:
            out.part(grp + "_벼랑", x + jx, (bottom - 27) / 2, z + jz, size * 0.96, bottom + 27, size * 0.96,
                     ry=hash01(x, z, 16) * 90, mat="Rock", col=(70, 66, 62), name="Cliff")
    return cols, y0


def oreum_top(o, g, x, z, dh=3.5):
    """오름 위 (x,z) 의 층 윗면 높이(기둥 규칙과 같다)."""
    y0 = g.y(o["x"], o["z"])
    prof = oreum_profile(o, x, z)
    if prof < 1.2:
        return None
    return y0 + max(1, round(prof / dh)) * dh


# ------------------------------------------------------------------ 돌담(현무암)
BASALT = [(46, 44, 46), (58, 56, 56), (38, 36, 40), (66, 62, 60), (52, 50, 54)]


def wall(out, pts, gates, grp, height=2.9):
    for k in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        L = math.hypot(bx - ax, bz - az)
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        n = max(1, int(L / 3.1))
        for i in range(n):
            t = (i + 0.5) / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            if any(math.hypot(x - gx, z - gz) < 5.5 for gx, gz in gates):
                continue
            a = out.anchor(x, z)
            h1 = 1.7 + hash01(x, z, 21) * 0.5
            w1 = L / n + 0.3
            col = BASALT[int(hash01(x, z, 22) * len(BASALT))]
            out.part(grp, x, h1 / 2 - 0.2, z, w1, h1, 1.9 + hash01(x, z, 23) * 0.4,
                     ry=yaw + (hash01(x, z, 24) - 0.5) * 8, rz=(hash01(x, z, 25) - 0.5) * 6, mat="Basalt", col=col,
                     anchor=a, name="Dam")
            if hash01(x, z, 26) < 0.72:
                h2 = 0.9 + hash01(x, z, 27) * 0.5
                out.part(grp, x + (hash01(x, z, 28) - 0.5), h1 - 0.2 + h2 / 2 - 0.1, z, w1 * (0.6 + hash01(x, z, 29) * 0.3),
                         h2, 1.4 + hash01(x, z, 30) * 0.3, ry=yaw + (hash01(x, z, 31) - 0.5) * 20,
                         rx=(hash01(x, z, 32) - 0.5) * 10, mat="Basalt", col=BASALT[int(hash01(x, z, 33) * 5)],
                         anchor=a, name="Dam")


# ------------------------------------------------------------------ 밭 이랑
CROPS = {
    "Canola": dict(soil=(104, 84, 60), row=(236, 212, 52), row2=(96, 140, 60), pitch=5.0, h=1.6),
    "Barley": dict(soil=(110, 92, 64), row=(150, 176, 80), row2=(186, 180, 96), pitch=4.0, h=1.4),
    "Radish": dict(soil=(96, 76, 54), row=(92, 150, 70), row2=(96, 76, 54), pitch=4.5, h=0.9),
    "Fallow": dict(soil=(128, 146, 84), row=(142, 156, 92), row2=(128, 146, 84), pitch=9.0, h=0.4),
}


def field(out, pts, crop, grp):
    c = CROPS[crop]
    # 이랑 방향: 가장 긴 변
    best = max(range(len(pts)), key=lambda i: math.hypot(pts[(i + 1) % len(pts)][0] - pts[i][0],
                                                         pts[(i + 1) % len(pts)][1] - pts[i][1]))
    (ax, az), (bx, bz) = pts[best], pts[(best + 1) % len(pts)]
    L = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / L, (bz - az) / L
    nx, nz = -uz, ux
    cx = sum(p[0] for p in pts) / len(pts)
    cz = sum(p[1] for p in pts) / len(pts)
    yaw = math.degrees(math.atan2(-uz, ux))
    ext = max(math.hypot(p[0] - cx, p[1] - cz) for p in pts) + 5
    k = -ext
    i = 0
    while k <= ext:
        # 이랑 한 줄: 다각형 안 구간
        xs = []
        t = -ext
        inside = False
        start = None
        while t <= ext + 1.5:
            x, z = cx + ux * t + nx * k, cz + uz * t + nz * k
            ins = pip(x, z, pts)
            if ins and not inside:
                start = t
            if not ins and inside:
                xs.append((start, t))
            inside = ins
            t += 1.5
        for s0, s1 in xs:
            s0 += 1.5
            s1 -= 1.5
            if s1 - s0 < 3:
                continue
            m = (s0 + s1) / 2
            x, z = cx + ux * m + nx * k, cz + uz * m + nz * k
            a = out.anchor(x, z)
            out.part(grp, x, 0.15, z, s1 - s0, 0.6, c["pitch"] * 0.98, ry=yaw, mat="Ground", col=c["soil"], anchor=a,
                     name="Soil")
            if crop != "Fallow":
                col = c["row"] if i % 2 == 0 or crop == "Radish" else c["row2"]
                out.part(grp, x, 0.45 + c["h"] / 2, z, s1 - s0 - 0.6, c["h"], c["pitch"] * 0.42, ry=yaw,
                         mat="Grass", col=col, anchor=a, name="Crop")
        k += c["pitch"]
        i += 1


# ------------------------------------------------------------------ 나무 울타리
def fence(out, pts, gates, grp):
    wood = (116, 86, 56)
    for k in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        L = math.hypot(bx - ax, bz - az)
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        n = max(1, int(L / 8))
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            x0, z0 = ax + (bx - ax) * t0, az + (bz - az) * t0
            x1, z1 = ax + (bx - ax) * t1, az + (bz - az) * t1
            mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
            if any(math.hypot(mx - gx, mz - gz) < 6 for gx, gz in gates):
                continue
            a = out.anchor(x0, z0)
            out.part(grp, x0, 2.0, z0, 0.7, 4.6, 0.7, mat="Wood", col=wood, anchor=a, name="Post")
            b = out.anchor(mx, mz)
            for hh in (2.0, 3.6):
                out.part(grp, mx, hh, mz, L / n, 0.4, 0.35, ry=yaw, mat="Wood", col=shade(wood, 1.1), anchor=b,
                         name="Rail")


# ------------------------------------------------------------------ 길(흙 토막)
def path(out, pts, w, grp):
    for k in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        L = math.hypot(bx - ax, bz - az)
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        n = max(1, int(L / 14))
        for i in range(n):
            t = (i + 0.5) / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            a = out.anchor(x, z)
            col = shade((132, 106, 74), 0.92 + hash01(x, z, 41) * 0.14)
            out.part(grp, x, -0.2, z, L / n + w * 0.6, 1.0, w * (0.9 + hash01(x, z, 42) * 0.15),
                     ry=yaw + (hash01(x, z, 43) - 0.5) * 4, mat="Ground", col=col, anchor=a, name="Path")


# ------------------------------------------------------------------ 오름 나무 계단(땅 윗면을 따라)
def stairs(out, pts, top_fn, ground_fn, grp, width=4.5):
    """top_fn(x, z) → 그 자리 오름 윗면(오름 밖이면 None). 오름 위 계단은 기둥을 비운 골에 놓이므로
    발판 밑을 땅(ground_fn)까지 흙으로 채워 붙인다. 발판은 2.4 마다, 6 칸마다 밧줄 기둥."""
    wood = (128, 96, 62)
    for k in range(len(pts) - 1):
        (ax, az), (bx, bz) = pts[k], pts[k + 1]
        L = math.hypot(bx - ax, bz - az)
        yaw = math.degrees(math.atan2(-(bz - az), bx - ax))
        n = max(1, int(L / 2.4))
        side = (math.cos(math.radians(yaw + 90)), -math.sin(math.radians(yaw + 90)))
        for i in range(n):
            t = (i + 0.5) / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            top = top_fn(x, z)
            if top is None:
                a = out.anchor(x, z)
                out.part(grp, x, 0.2, z, 2.6, 0.6, width, ry=yaw, mat="WoodPlanks", col=wood, anchor=a, name="Step")
                post_y, post_a = 1.8, a
            else:
                gy = ground_fn(x, z)
                fill = top - 0.4 - (gy - 1)
                if fill > 0.2:
                    out.part(grp, x, (gy - 1) + fill / 2, z, 2.7, fill, width + 1.6, ry=yaw, mat="Ground",
                             col=(118, 96, 68), name="StepFill")
                out.part(grp, x, top, z, 2.6, 0.8, width, ry=yaw, mat="WoodPlanks", col=wood, name="Step")
                post_y, post_a = top + 2.1, None
            if i % 6 == 0:
                for sgn in (-1, 1):
                    out.part(grp, x + side[0] * width * 0.6 * sgn, post_y, z + side[1] * width * 0.6 * sgn, 0.5, 3.4, 0.5,
                             mat="Wood", col=(96, 70, 44), anchor=post_a, name="RopePost")


# ------------------------------------------------------------------ 바위·바다 돌기둥
def rock(out, x, z, s, yaw, tilt, grp, mossy=False, sea_y=None):
    a = out.anchor(x, z, sea_y)
    col = BASALT[int(hash01(x, z, 51) * len(BASALT))]
    out.part(grp, x, s * 0.25, z, s, s * 0.72, s * 0.84, ry=yaw, rx=tilt, rz=tilt * 0.5, mat="Basalt", col=col, anchor=a,
             name="Rock")
    ox, oz = (hash01(x, z, 52) - 0.5) * s * 0.8, (hash01(x, z, 53) - 0.5) * s * 0.8
    out.part(grp, x + ox, s * 0.18, z + oz, s * 0.62, s * 0.5, s * 0.55, ry=yaw + 37, rx=-tilt, mat="Basalt",
             col=shade(col, 1.12), anchor=a, name="Rock")
    if mossy:
        out.part(grp, x, s * 0.6, z, s * 0.8, 0.5, s * 0.7, ry=yaw, rx=tilt, rz=tilt * 0.5, mat="Grass",
                 col=(84, 118, 60), anchor=a, name="Moss")


def stack(out, x, z, w, h, yaw, grp):
    bottom = -10.0
    y = bottom
    k = 0
    while y < h - 1:
        seg = min(h - y, 6 + hash01(x, z, 60 + k) * 4)
        ww = w * (1 - 0.12 * k)
        out.part(grp, x + (hash01(x, z, 70 + k) - 0.5) * 2, y + seg / 2, z + (hash01(x, z, 80 + k) - 0.5) * 2, ww, seg,
                 ww * 0.8, ry=yaw + k * 23, mat="Basalt", col=BASALT[k % 5], name="Stack")
        y += seg - 0.6
        k += 1


# ------------------------------------------------------------------ 억새 덤불
def silvergrass(out, x, z, grp, y_fn=None):
    top = y_fn(x, z) if y_fn else None
    a = out.anchor(x, z) if top is None else None
    for k in range(7):
        ang = k * 51.4 + hash01(x, z, 90 + k) * 30
        r = 0.6 + hash01(x, z, 100 + k) * 1.6
        bx, bz = x + math.cos(math.radians(ang)) * r, z + math.sin(math.radians(ang)) * r
        h = 4.5 + hash01(x, z, 110 + k) * 3.5
        tilt = (hash01(x, z, 120 + k) - 0.5) * 30
        yy = h / 2 if top is None else top + h / 2
        out.part(grp, bx, yy, bz, 0.35, h, 0.9, ry=ang, rz=tilt, mat="Grass", col=(214, 200, 150), anchor=a, name="Eulsae")
        out.part(grp, bx, yy + h / 2 + 0.6, bz, 0.6, 1.6, 1.2, ry=ang, rz=tilt, mat="Fabric", col=(240, 234, 214),
                 anchor=a, name="Plume")


# ------------------------------------------------------------------ 삼나무(블록)
def cedar(out, x, z, grp, scale=1.0, top=None):
    a = out.anchor(x, z) if top is None else None
    base = 0 if top is None else top
    h = (16 + hash01(x, z, 130) * 6) * scale
    out.part(grp, x, base + h * 0.35, z, 1.4 * scale, h * 0.7, 1.4 * scale, mat="Wood", col=(92, 64, 44), anchor=a,
             name="CedarTrunk")
    tiers = 4
    for k in range(tiers):
        f = k / tiers
        size = (7.5 - 5.5 * f) * scale
        yy = base + h * (0.32 + 0.17 * k)
        out.part(grp, x, yy, z, size, 3.4 * scale, size, ry=hash01(x, z, 140 + k) * 90 + k * 20, mat="Grass",
                 col=shade((48, 92, 60), 0.9 + 0.12 * k), anchor=a, name="CedarLeaf")
