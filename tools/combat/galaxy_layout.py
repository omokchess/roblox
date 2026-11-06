"""galaxy_plan.json(lune run tools/combat/galaxy_plan.luau)을 위에서 본 평면도로 -> out/galaxy_layout.png
라이브러리 없이(zlib 만) 더하기 합성으로 그린다: 입자 수(Rate × 수명)만큼 이미터 상자 안에 점을 흩뿌려 밀도·색을 본다.
어두운 먼지는 빼기로, 성운·글로우는 크고 옅게. 회색 실선 = 팔 곡선, 흰 점 = 유성 이미터 자리."""
import json, math, random, struct, zlib

N, HALF = 900, 150.0
img = [[[2.0, 3.0, 8.0] for _ in range(N)] for _ in range(N)]
rng = random.Random(3)
def px(x, y): return int((x + HALF) / (2 * HALF) * N), int((HALF - y) / (2 * HALF) * N)
def blob(x, y, rad, c, a):
    cx, cy = px(x, y); rr = max(1, int(rad / (2 * HALF) * N))
    for j in range(max(0, cy - rr), min(N, cy + rr + 1)):
        for i in range(max(0, cx - rr), min(N, cx + rr + 1)):
            d = math.hypot(i - cx, j - cy) / rr
            if d <= 1:
                w = a * (1 - d) ** 2
                p = img[j][i]
                for k in range(3): p[k] = max(0.0, p[k] + c[k] * w)
data = json.load(open("tools/combat/out/galaxy_plan.json"))
plan, beams = data["emitters"], data["beams"]
def col(s, f=0.0):
    ks = s["Color"]; c = ks[0][1] if f < 0.5 else ks[-1][1]; return c
order = {"Disc": 0, "Nebula": 1, "Dust": 2, "ArmStars": 3, "Bulge": 4, "Meteor": 5}
for s in sorted(plan, key=lambda s: order[s["Layer"]]):
    x0, _, z0 = s["Pos"]; sx, _, sz = s["Size"]
    n = int(s["Rate"] * sum(s["Life"]) / 2)
    big = s["Scale"][-1][1]
    if s["Layer"] == "Meteor":
        blob(x0, -z0, 3, (255, 255, 255), 1); continue
    for _ in range(n):
        c = col(s, rng.random())
        if s["Layer"] == "Disc":                      # 납작한 타원체: 투영하면 가운데가 촘촘
            while True:
                u, v = rng.uniform(-1, 1), rng.uniform(-1, 1)
                if u * u + v * v <= 1: break
            x, y = u * sx / 2, v * sz / 2
        elif s["Layer"] == "Bulge":
            x, y = rng.gauss(0, sx / 4), rng.gauss(0, sx / 4)
        else:
            u, v = rng.uniform(-sx / 2, sx / 2), rng.uniform(-sz / 2, sz / 2)
            lx, lz = s["Look"]                         # 상자: v 가 접선, u 가 옆
            x, y = x0 + lx * v - lz * u, -(z0 + lz * v + lx * u)
            x, y = x, y
        if s["Layer"] == "Dust":
            blob(x, y, big * 0.5, (-50, -40, -30), 0.5)
        elif s["Layer"] in ("Nebula",) or big > 8:
            blob(x, y, big * 0.5, [v * 0.55 for v in c], 0.16)
        else:
            blob(x, y, max(1.2, big * 0.5), c, 0.9)
def bez_pts(b, n=70):                                   # Beam 곡선(문서: 제어점 = P0+D0*C0, P1-D1*C1 — 로블록스 z 는 위로 뒤집어 그린다)
    p0, p3 = (b["P0"][0], b["P0"][2]), (b["P1"][0], b["P1"][2])
    p1 = (p0[0] + b["D0"][0] * b["C0"], p0[1] + b["D0"][1] * b["C0"])
    p2 = (p3[0] - b["D1"][0] * b["C1"], p3[1] - b["D1"][1] * b["C1"])
    for i in range(n + 1):
        t = i / n; u = 1 - t
        yield tuple(u**3 * p0[k] + 3 * u * u * t * p1[k] + 3 * u * t * t * p2[k] + t**3 * p3[k] for k in range(2))
for b in beams:
    wide = b["Layer"] == "BandWide"
    c = b["Color"][0][1] if b["Layer"] != "BandCore" else (255, 240, 220)
    for x, z in bez_pts(b):
        w = b["W0"] / 2 if wide else max(1.0, b["W0"] / 2)
        if wide: blob(x, -z, w, [v * 0.5 for v in c], 0.03)
        elif b["Layer"] == "BandCore": blob(x, -z, w, c, 0.06)
        else: blob(x, -z, 0.8, (255, 255, 255), 0.4)
for arm in range(0):
    for k in range(240):
        t = 1.0 + k * 0.04; r = 14 * math.exp(0.21 * t)
        if r > 135: break
        a = arm * math.pi / 2 + t
        i, j = px(math.cos(a) * r, math.sin(a) * r)   # 로블록스 z=-sin 을 위로 뒤집어 그린다
        if 0 <= i < N and 0 <= j < N: img[j][i][0] += 25; img[j][i][1] += 25; img[j][i][2] += 35
raw = b"".join(b"\x00" + bytes(min(255, int(255 * (1 - math.exp(-v / 110.0)))) for p in row for v in p) for row in img)
def chunk(t, d): c = struct.pack(">I", len(d)) + t + d; return c + struct.pack(">I", zlib.crc32(t + d))
open("tools/combat/out/galaxy_layout.png", "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))

# 별자리 실 교차 검사: 같은 줄(끝점을 나누는 이웃 포함)을 뺀 모든 쌍(팔 안·팔 사이)이 만나지 않아야 한다
def ccw(a, b, c): return (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
def cross(a, b, c, d): return ccw(a, c, d) * ccw(b, c, d) < 0 and ccw(a, b, c) * ccw(a, b, d) < 0
lines = [((b["P0"][0], b["P0"][2]), (b["P1"][0], b["P1"][2]), b["Name"]) for b in beams if b["Layer"] == "Constellation"]
bad = [(l1[2], l2[2]) for i, l1 in enumerate(lines) for l2 in lines[i + 1:] if cross(l1[0], l1[1], l2[0], l2[1])]
print("별자리 실 %d줄, 교차 %d쌍 %s" % (len(lines), len(bad), bad))
