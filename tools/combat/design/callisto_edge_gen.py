# -*- coding: utf-8 -*-
"""
칼리스토 팔 검 "날로 베기" 계산·검사 (2026-11-01).
사용자: "칼날이 아니라 칼 면으로 때리는 것 같은데" — 1페이즈 무기 CallistoArms Main 은 팔 축에 고정(Fixed)이라
날 단면 = 두께 0.07(팔 로컬 X) × 폭 0.28(팔 로컬 Z). 날(양날)은 **팔 로컬 ±Z** 쪽을 향한다 → 칼끝이 팔 로컬 Z 로 움직여야 날이 앞장선다.
고치는 법 = 휘두르는 동안 오른팔을 팔 자신의 긴 축(팔 로컬 Y) 둘레로 θ 비튼다: 팔 회전 R' = R · Ry(θ).
 (칼끝은 팔 축 위의 점이라 비틀어도 거의 제자리지만, 어깨 축이 팔 중심축에서 0.5 비껴 있어 팔 전체가 최대 0.7 스터드 옆으로 쏠린다 —
  R6 상자 팔이라 눈에는 거의 안 띄고, 땅 여유는 검사가 따로 본다.)

팔 각은 YXZ 오일러라 팔을 수평 앞으로 든 근처(X≈90)에서는 비틀기 한 번에도 세 값이 다 튀고, 키 둘만 오일러 직선으로 이으면 칼끝이 엉뚱한 길로 간다.
그래서 ① 원래 모션의 칼끝이 가는 방향에서 표본마다 필요한 비틀기 θ*(t)를 구해 ② 키별 θ(PLAN — θ* 를 따르되 느린 구간에서 대기 자세 0° 로 풀어 낸다)를
정하고 ③ 같은 회전의 오일러 표기들 가운데 키 사이 직선 보간이 이상적인 길(원래 팔 · Ry(θ))에서 가장 덜 벗어나는 사슬을 고르고
④ 그래도 벗어나는 곳(칼끝이 이상적인 길에서 0.5 스터드 넘게, 휘두르는 순간 |cos| < 0.83)엔 원래 모션을 그 시각에 찍은 자세로 중간 키를 끼운다.

쓰는 법(저장소 루트에서, 먼저 lune run tools/combat/export_motions.luau):
  python tools/combat/design/callisto_edge_gen.py check [기술]     # 지금 모션(motions.json)을 촘촘히(480Hz) 찍어 날 방향 검사 — 가장 나쁜 |cos|, 칼끝 땅 여유.
                                                                   # 휘두르는 순간(날 둘레 칼끝 속도 v⊥ ≥ 25 스터드/초) |cos| ≥ 0.8 이 아니면 종료 코드 1
  python tools/combat/design/callisto_edge_gen.py gen [기술]       # PLAN 대로 비틀기 계산 → 키별 RArm · 곡선 · 끼울 키를 out/callisto_edge_plan.json 에 쓰고 보고
  python tools/combat/design/callisto_edge_gen.py selftest         # 닫힌 꼴 계산이 posecalc.solve(전신)와 같은지
  python tools/combat/design/callisto_edge_gen.py rebase           # 비틀기가 안 들어간 원래 모양일 때 지금 키를 새 원본(out/callisto_edge_base.json)으로
gen 은 늘 원본 키(비틀기 전)에서 시작하므로 몇 번을 돌려도 같다. 기술 5개: Slash · Trohia · Synthesis · Astro · Intro.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "out", "motions.json")
BASE = os.path.join(HERE, "..", "out", "callisto_edge_base.json")  # 비틀기 전 원본 키(칼 기술 5개) — 칼 자세를 새로 짜면 rebase

D = math.pi / 180
PI = math.pi
TIP_Y = -1.0 - 3.2  # 날끝(무기 (0,0,-3.2)) = 팔 로컬 (0, -4.2, 0)
GROUND = -3.0  # HRP 공간에서 땅(다리 2 + 몸통 반)

# 기술별 검사 구간(날이 나와 있는 동안 = 모션 전체. 컷신은 BladeOut ~ BladeIn)
WINDOW = {
    "CallistoSlash": (0.0, 1.4),
    "CallistoTrohia": (0.0, 1.3),
    "CallistoSynthesis": (0.0, 1.0),
    "CallistoAstro": (0.0, 2.35),
    "CallistoIntro": (1.75, 3.45),
}
# 날이 소매에서 미끄러져 나오는 처음 0.04초(날의 삼분의 일도 안 나옴 — Callisto.Blade 0.12초)는 날 방향 검사에서 뺀다
SKIP = {"CallistoSlash": 0.04, "CallistoTrohia": 0.04, "CallistoSynthesis": 0.04, "CallistoAstro": 0.04, "CallistoIntro": 0.0}
FAST = 17.0  # 한 프레임(60fps)에 날 폭(0.28)만큼 가로지르는 속도 — 이보다 느리면 면이 앞서도 눈에 안 띈다
SWING = 25.0  # 확실한 휘두름(합격 기준: 이 속도 이상이면 |cos| ≥ 0.8)

# ── 곡선(MotionMath.Ease 와 같다) ──────────────────────────
EASE = {
    "linear": lambda x: x,
    "sineIn": lambda x: 1 - math.cos(x * PI / 2), "sineOut": lambda x: math.sin(x * PI / 2),
    "sineInOut": lambda x: -(math.cos(PI * x) - 1) / 2,
    "quadIn": lambda x: x * x, "quadOut": lambda x: 1 - (1 - x) ** 2,
    "quadInOut": lambda x: 2 * x * x if x < 0.5 else 1 - (-2 * x + 2) ** 2 / 2,
    "cubicIn": lambda x: x ** 3, "cubicOut": lambda x: 1 - (1 - x) ** 3,
    "cubicInOut": lambda x: 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2,
    "quartOut": lambda x: 1 - (1 - x) ** 4, "quartIn": lambda x: x ** 4,
    "expoOut": lambda x: 1 if x >= 1 else 1 - 2 ** (-10 * x), "expoIn": lambda x: 0 if x <= 0 else 2 ** (10 * x - 10),
    "backOut": lambda x: 1 + 2.70158 * (x - 1) ** 3 + 1.70158 * (x - 1) ** 2,
    "backIn": lambda x: 2.70158 * x ** 3 - 1.70158 * x * x,
    "step": lambda x: 1 if x >= 1 else 0,
}


def ease(name, x):
    return EASE.get(name or "sineInOut", EASE["sineInOut"])(x)


# ── 모션 읽기(MotionMath.Compile 의 Root · Torso · RArm 만) ──────────────────────────
CH = {"Root": 6, "Torso": 3, "Head": 3, "RArm": 3, "LArm": 3, "RLeg": 3, "LLeg": 3}


def compile_keys(motion):
    keys = sorted(motion["Keys"], key=lambda k: k.get("t", 0))
    prev = {n: [0] * s for n, s in CH.items()}
    out = []
    for k in keys:
        pose = {}
        for n, s in CH.items():
            v = k.get(n)
            pose[n] = [(v[i] if i < len(v) else 0) for i in range(s)] if v else prev[n]
        prev = pose
        out.append((k.get("t", 0), k.get("e"), pose))
    return out


# ── 회전·자리(posecalc.solve 와 같은 값 — 팔 부품 하나만 닫힌 꼴로) ──────────────────────────
def om(x, y, z):
    """CFrame.fromOrientation(x,y,z)(도) = Ry·Rx·Rz 의 회전 행렬(행 3개 튜플)"""
    cx, sx = math.cos(x * D), math.sin(x * D)
    cy, sy = math.cos(y * D), math.sin(y * D)
    cz, sz = math.cos(z * D), math.sin(z * D)
    return ((cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx),
            (cx * sz, cx * cz, -sx),
            (-sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx))


def mm(a, b):
    return tuple(tuple(a[i][0] * b[0][j] + a[i][1] * b[1][j] + a[i][2] * b[2][j] for j in range(3)) for i in range(3))


def mv(a, v):
    return (a[0][0] * v[0] + a[0][1] * v[1] + a[0][2] * v[2],
            a[1][0] * v[0] + a[1][1] * v[1] + a[1][2] * v[2],
            a[2][0] * v[0] + a[2][1] * v[1] + a[2][2] * v[2])


def ryy(a):
    c, s = math.cos(a * D), math.sin(a * D)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def vadd(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vdot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def vmag(a):
    return math.sqrt(vdot(a, a))


def to_orient(R):
    """회전 행렬 → (x, y, z) 도 (orient(x,y,z) = Ry·Rx·Rz) — 주 표기(x -90~90)"""
    sx = max(-1.0, min(1.0, -R[1][2]))
    x = math.asin(sx)
    if abs(sx) > 0.9999999:  # 짐벌: z = 0 으로 두고 y 가 나머지를 가진다
        y = math.atan2(-R[2][0], R[0][0]) if sx > 0 else math.atan2(R[2][0], R[0][0])
        return (x / D, y / D, 0.0)
    return (x / D, math.atan2(R[0][2], R[2][2]) / D, math.atan2(R[1][0], R[1][1]) / D)


def wrap(a, ref):
    return a + 360 * round((ref - a) / 360)


def alt(e):
    """같은 회전의 다른 오일러 표기"""
    return (180 - e[0], e[1] + 180, e[2] + 180)


def reps(e, refs):
    """e 와 같은 회전의 표기들 — 주 표기·다른 표기 각각을 refs 에 가깝게 360 씩 감은 것(중복 없이)"""
    out = []
    for c in (tuple(e), alt(e)):
        for ref in refs:
            w = tuple(round(wrap(c[i], ref[i]), 4) for i in range(3))
            if w not in out:
                out.append(w)
    return out


def twist(arm, theta):
    """오른팔 각 arm 을 팔 자신의 긴 축 둘레로 theta 도 비튼 각(주 표기)"""
    return to_orient(mm(om(*arm), ryy(theta)))


# ── 표본 계산 ──────────────────────────
class Sim:
    """한 기술의 [t0, t1] 을 dt 간격으로 찍어 둔다. Root · Torso 는 비틀기와 상관없어 미리 풀어 두고, RArm 오일러만 바꿔 가며 다시 잰다."""

    def __init__(self, keys, t0, t1, dt):
        self.keys, self.dt = keys, dt
        n = int(round((t1 - t0) / dt))
        self.ts = [t0 + i * dt for i in range(n + 1)]
        self.seg = []
        self.RT, self.PT = [], []
        for t in self.ts:
            i, a = self._where(t)
            self.seg.append((i, a))
            ka, kb = keys[max(i - 1, 0)][2], keys[i][2]
            root = [ka["Root"][j] + (kb["Root"][j] - ka["Root"][j]) * a for j in range(6)]
            tor = [ka["Torso"][j] + (kb["Torso"][j] - ka["Torso"][j]) * a for j in range(3)]
            Rr, Rt = om(*root[3:6]), om(*tor)
            self.RT.append(mm(Rr, Rt))
            self.PT.append(vadd(tuple(root[:3]), mv(Rr, vadd((0, -1, 0), mv(Rt, (0, 1, 0))))))

    def _where(self, t):
        keys = self.keys
        if t <= keys[0][0]:
            return 0, 0.0
        for i in range(1, len(keys)):
            tb, eb, _ = keys[i]
            if t <= tb:
                ta = keys[i - 1][0]
                return i, ease(eb, (t - ta) / max(1e-4, tb - ta))
        return len(keys) - 1, 1.0

    def arm_at(self, eulers, j):
        i, a = self.seg[j]
        ea, eb = eulers[max(i - 1, 0)], eulers[i]
        return tuple(ea[c] + (eb[c] - ea[c]) * a for c in range(3))

    def run(self, eulers):
        """eulers[k] = 키 k 의 오른팔 오일러 → 표본별 (날끝 자리, 팔 축, 팔 로컬 Z 방향)"""
        tips, axes, zs, xs = [], [], [], []
        for j in range(len(self.ts)):
            RA = om(*self.arm_at(eulers, j))
            A = mm(self.RT[j], RA)
            pc = vadd(vadd(self.PT[j], mv(self.RT[j], (1, 0.5, 0))), mv(A, (0.5, -0.5, 0)))
            tips.append(vadd(pc, mv(A, (0, TIP_Y, 0))))
            axes.append((-A[0][1], -A[1][1], -A[2][1]))
            zs.append((A[0][2], A[1][2], A[2][2]))
            xs.append((A[0][0], A[1][0], A[2][0]))
        self.xs = xs
        return tips, axes, zs

    def metrics(self, eulers):
        """표본별 (v⊥ 크기, |cos|) 와 날끝 목록"""
        tips, axes, zs = self.run(eulers)
        out = [(0.0, 1.0)]
        for j in range(1, len(tips)):
            v = tuple((tips[j][c] - tips[j - 1][c]) / self.dt for c in range(3))
            a = axes[j]
            d = vdot(v, a)
            vp = (v[0] - d * a[0], v[1] - d * a[1], v[2] - d * a[2])
            m = vmag(vp)
            out.append((m, abs(vdot(vp, zs[j])) / m if m > 1e-9 else 1.0))
        return out, tips


# ── 보고 ──────────────────────────
def summary(name, met, tips, dt=1 / 480):
    skip = int(SKIP.get(name, 0.0) / dt)
    met = [(0.0, 1.0)] * skip + list(met[skip:])
    # 땅 여유는 날이 다 나온 뒤(처음 0.12초 이후)부터 본다 — 소매에서 나오는 동안은 칼끝이 팔 끝에 있다
    out_from = int(0.12 / dt)
    low = min(t[1] for t in tips[out_from:])
    lines = ["%-18s 칼끝 가장 낮은 y %.2f (땅 위 %.2f)%s" % (name, low, low - GROUND, "  ★땅에 박힘" if low - GROUND < 0.2 else "")]
    worst = {}
    for lim in (FAST, SWING):
        fast = [(c, m, j) for j, (m, c) in enumerate(met) if m >= lim]
        if fast:
            c, m, j = min(fast)
            low80 = sum(1 for f in fast if f[0] < 0.8)
            lines.append("   v⊥≥%g: %d 표본 중 가장 나쁜 |cos| = %.3f (v⊥ %.1f)  0.8 미만 %d 개" % (lim, len(fast), c, m, low80))
            worst[lim] = c
        else:
            lines.append("   v⊥≥%g: 순간 없음" % lim)
    return lines, worst, low


def load(base=False):
    """base=True: 비틀기 전 원본 키(out/callisto_edge_base.json) — gen 은 늘 이것에서 시작해 몇 번을 돌려도 같다. 아니면 지금 모션(motions.json)."""
    if base:
        return json.load(open(BASE, encoding="utf-8"))
    return json.load(open(OUT, encoding="utf-8"))["Callisto"]["Skills"]


def keys_of(name, base=False):
    return compile_keys(load(base)[name])


def cmd_check(names, dt=1 / 480):
    allw = {FAST: 1.0, SWING: 1.0}
    for name in names:
        keys = keys_of(name)
        t0, t1 = WINDOW[name]
        sim = Sim(keys, t0, t1, dt)
        met, tips = sim.metrics([k[2]["RArm"] for k in keys])
        lines, worst, _ = summary(name, met, tips)
        print("\n".join(lines))
        for lim, c in worst.items():
            allw[lim] = min(allw[lim], c)
    print("전체 가장 나쁜 |cos|: v⊥≥%g → %.3f   v⊥≥%g → %.3f" % (FAST, allw[FAST], SWING, allw[SWING]))
    return allw


# ── 비틀기 계획표 ──────────────────────────
# ov = {원래 키 번호: 비틀기 θ(도)}, extra = 강제로 끼울 중간 키 [(시각, θ)], pins = θ 를 0 으로 못 박을 원래 키 번호.
# θ 는 팔 로컬 Y 둘레 도(°)다. 칼은 양날이라 θ 와 θ±180 은 같은 날 방향이지만 어깨 축이 비껴 있어 팔이 쏠리는 쪽이 다르다 — 땅이 가까운 끝에선 위로 쏠리는 쪽을 쓴다.
# 구간별 값은 기술을 추정 곡선(원래 모션에서 칼이 가는 방향)과 맞춘 것: 휘두르기 직전 준비 키는 휘두름 첫 순간의 값을, 끝난 뒤 머무는 키는 휘두름 끝 값을 이어 가고,
# 느려진 뒤(v⊥ < SWING)에 풀어 대기 자세(θ=0)로 돌아온다.
PLAN = {
    # 비스듬히 내려벤다: 감아 올리는 동안 -35~-20, 벨 때 -25 -> -62, 머무는 동안 -70, 느린 머무름(0.6~0.95)에 풀어 낸다
    "CallistoSlash": dict(ov={1: -35, 2: -15, 3: -20, 4: -62, 5: -70, 6: 0}, extra=[(0.01, -35)], pins=(0, 6, 7)),
    # 등손 가로베기: 가슴 앞 감기부터 끝까지 팔이 수평으로 쓸려 가므로 줄곧 +85(면이 앞장서던 것을 날로), 마지막 0.08초에 풀어 낸다
    "CallistoTrohia": dict(ov={1: 85, 2: 85, 3: 85, 4: 85, 5: 85, 6: 85, 7: 85, 8: 85, 9: 85, 10: 85, 11: 85}, extra=[(0.01, 70)], pins=(0, 12)),
    # 찌르기: 당겨 겨눌 때 -70~-75, 꿰뚫을 때(몸이 도는 만큼 칼끝이 옆으로 쓸린다) -87. 꿰뚫은 자세는 팔이 수평 앞(X≈94, 짐벌 바로 곁)이라 거기서 풀면
    # 오일러 표기가 반 바퀴 튀므로, 대기로 돌아오며 팔이 내려가는 구간(0.66~1.0)에서 풀어 낸다
    "CallistoSynthesis": dict(ov={1: -70, 2: -75, 3: -87, 4: -87, 5: -87}, extra=[(0.01, -72)], pins=(0, 6)),
    # 칼춤: 웅크릴 때 팔이 옆으로 벌어지며 45°(웅크려 있는 동안 풀어 낸다), 도약(칼끝이 거의 위로 솟는다)·회전(팔 수평)은 원래부터 날이 앞장서서 0,
    # 회전에 들어서는 0.67~0.68초(팔이 수평으로 내려오며 몸이 돌기 시작)는 -35° 였다가 회전 직전에 0°, 착지·일어서는 구간(팔이 앞에서 옆으로 쓸려 돌아온다)은 65° 로 이어 가다 끝에서 푼다
    "CallistoAstro": dict(ov={1: 45, 2: 0, 3: 0, 4: 0, 5: -35, 13: 65}, extra=[(0.01, 55), (0.683, 0), (2.25, 65)], pins=(0,) + tuple(range(6, 13)) + (14,)),
    # 컷신: 날을 본 뒤(손목 비틀기) 허공을 두 번 긋는다 -87, 칼을 넣으러 가는 느린 구간에 풀어 낸다
    "CallistoIntro": dict(ov={1: 0, 2: 0, 3: -30, 4: -45, 5: -87, 6: -87, 7: -87, 8: 0}, pins=(0, 1, 2, 8, 9)),
}

# ── 비틀기 계획 ──────────────────────────
# (비틀면 어깨 축(팔 윗모서리 안쪽)이 팔 중심축에서 0.5 비껴 있어 팔 전체가 최대 0.7 스터드 옆으로 쏠린다 — 땅 여유는 결과로 따로 본다)
# 1) 원래 모션의 칼끝 길을 기준으로, 표본마다 "날이 앞장서려면 필요한 비틀기" θ*(t)를 구한다(칼끝이 가는 방향 v⊥ 에 팔 로컬 Z 를 맞춘다).
# 2) 키마다 비틀기 θ_k 를 최소제곱으로 구한다(키 사이는 그 구간의 가속 곡선을 따라 섞이므로 θ(t) = θ_{k-1}(1-α) + θ_k α).
#    빠른 순간일수록 무겁게, 처음·끝 키(대기 자세)는 θ=0 으로 못 박는다.
# 3) 오일러 직선 보간이 이상적인 회전 길(원래 길 · Ry(θ))에서 벗어나는 곳엔 중간 키를 끼운다(원래 모션을 그 시각에 찍은 자세 + 비튼 팔).
W_CAP = 80.0
LAMBDA = 0.02  # 이웃 키와 θ 가 다른 것에 매기는 벌(느린 구간에서 멋대로 돌지 않게)
TOL_DEG = 9.0  # 휘두름 중 팔이 이상적인 방향에서 벗어나도 되는 각
TOL_TIP = 0.2  # 칼끝이 원래 길에서 벗어나도 되는 거리(스터드)
INS_MIN = 0.002  # 중간 키 사이 최소 간격(초)


def unwrap_theta(met_dirs, weights):
    """표본별 θ*(도, 180° 마다 같은 날)를 이웃과 가까운 쪽으로 이어 붙인다 — 가장 무거운 표본에서 시작해 양쪽으로"""
    n = len(met_dirs)
    out = [0.0] * n
    start = max(range(n), key=lambda j: weights[j])
    out[start] = met_dirs[start]
    if out[start] > 90:
        out[start] -= 180
    elif out[start] <= -90:
        out[start] += 180
    for rng in (range(start + 1, n), range(start - 1, -1, -1)):
        prev = out[start]
        for j in rng:
            v = met_dirs[j]
            v += 180 * round((prev - v) / 180)
            out[j] = v
            prev = v
    return out


def solve_linear(A, b):
    n = len(b)
    M = [row[:] + [b[i]] for i, row in enumerate(A)]
    for c in range(n):
        piv = max(range(c, n), key=lambda r: abs(M[r][c]))
        M[c], M[piv] = M[piv], M[c]
        for r in range(n):
            if r != c and M[c][c] != 0:
                f = M[r][c] / M[c][c]
                for k in range(c, n + 1):
                    M[r][k] -= f * M[c][k]
    return [M[i][n] / M[i][i] if M[i][i] else 0.0 for i in range(n)]


def weight(m):
    """휘두름 무게: SWING 스터드/초 아래는 0, 위로 갈수록 커져 +48 에서 막는다"""
    return max(0.0, min((m - SWING) / 12.0, 4.0))


def profile(keys0, t0, t1, dt=1 / 480):
    """원래 모션에서 표본별 θ*·무게. 돌려주는 값: (sim0, θ* 목록, 무게 목록, 표본별 v⊥)"""
    sim0 = Sim(keys0, t0, t1, dt)
    base = [k[2]["RArm"] for k in keys0]
    tips, axes, zs = sim0.run(base)
    n = len(tips)
    ths, ws, vps = [0.0] * n, [0.0] * n, [0.0] * n
    for j in range(1, n):
        v = tuple((tips[j][c] - tips[j - 1][c]) / dt for c in range(3))
        a = axes[j]
        d = vdot(v, a)
        vp = (v[0] - d * a[0], v[1] - d * a[1], v[2] - d * a[2])
        m = vmag(vp)
        vps[j] = m
        ws[j] = weight(m)
        ths[j] = math.atan2(vdot(vp, sim0.xs[j]), vdot(vp, zs[j])) / D if m > 1e-9 else 0.0
    ths[0], ws[0], vps[0] = ths[1], 0.0, 0.0
    return sim0, unwrap_theta(ths, ws), ws, vps


def fit_theta(knots, sim, ths, ws, pin=()):
    """knots = [(t, e, pose)]. 표본마다 θ(t)가 θ* 에 가깝도록 키별 θ 를 최소제곱으로. pin = θ 를 0 으로 못 박을 키 번호."""
    n = len(knots)
    A = [[0.0] * n for _ in range(n)]
    b = [0.0] * n
    for j in range(len(sim.ts)):
        i, al = sim.seg[j]
        w = ws[j]
        if w <= 0:
            continue
        lo = max(i - 1, 0)
        if lo == i:
            A[i][i] += w
            b[i] += w * ths[j]
            continue
        c = {lo: 1 - al, i: al}
        for p, cp in c.items():
            b[p] += w * cp * ths[j]
            for q, cq in c.items():
                A[p][q] += w * cp * cq
    for k in range(1, n):
        for p, q, sgn in ((k - 1, k - 1, 1), (k, k, 1), (k - 1, k, -1), (k, k - 1, -1)):
            A[p][q] += LAMBDA * sgn
    for k in pin:
        A[k] = [0.0] * n
        A[k][k] = 1.0
        b[k] = 0.0
    return solve_linear(A, b)


def choose_reps(knots, ths, keys0):
    """키마다 비튼 팔의 오일러 표기. 같은 회전의 표기들(주·다른 표기 × 360 감기)을 후보로, 키 사이 오일러 직선 보간이 이상적인 길
    (원래 모션의 그 시각 팔 · Ry(θ))에서 벗어난 각의 제곱합이 가장 작은 사슬을 비터비로 고른다. 첫·마지막 키(대기 자세)는 원래 표기."""
    n = len(knots)
    base = [tuple(k[2]["RArm"]) for k in knots]
    cands = []
    for k in range(n):
        if abs(ths[k]) < 1e-9:
            cands.append([base[k]])
            continue
        e = twist(base[k], ths[k])
        refs = [base[k]] + (cands[k - 1] if k > 0 else [])
        opts = reps(e, refs)
        cands.append([tuple(round(v, 1) for v in c) for c in opts])
    F = (0.15, 0.3, 0.5, 0.7, 0.85)

    def edge(k, c1, c2):
        ta, tb, eb = knots[k - 1][0], knots[k][0], knots[k][1]
        tot = 0.0
        for f in F:
            al = ease(eb, f)
            ts = ta + (tb - ta) * f
            R1 = om(*[c1[i] + (c2[i] - c1[i]) * al for i in range(3)])
            th = ths[k - 1] + (ths[k] - ths[k - 1]) * al
            Rid = mm(orig_arm_R(keys0, ts), ryy(th))
            tot += ang(R1, Rid) ** 2
        return tot

    edge_raw = edge

    def edge(k, c1, c2):
        key = (id(keys0), knots[k - 1][0], knots[k][0], knots[k][1], c1, c2, round(ths[k - 1], 4), round(ths[k], 4))
        v = _EDGE.get(key)
        if v is None:
            v = _EDGE[key] = edge_raw(k, c1, c2)
        return v

    cost = [[0.0] * len(c) for c in cands]
    back = [[0] * len(c) for c in cands]
    for k in range(1, n):
        for i, c in enumerate(cands[k]):
            best = None
            for j, pc in enumerate(cands[k - 1]):
                d = cost[k - 1][j] + edge(k, pc, c)
                if best is None or d < best[0]:
                    best = (d, j)
            cost[k][i], back[k][i] = best
    i = min(range(len(cands[-1])), key=lambda x: cost[-1][x])
    out = [None] * n
    for k in range(n - 1, -1, -1):
        out[k] = cands[k][i]
        i = back[k][i]
    return out


def theta_at(sim, ths, j):
    i, al = sim.seg[j]
    lo = max(i - 1, 0)
    return ths[lo] + (ths[i] - ths[lo]) * al


def ang(Ra, Rb):
    """두 회전 사이의 각(도)"""
    tr_ = sum(Ra[i][0] * Rb[i][0] + Ra[i][1] * Rb[i][1] + Ra[i][2] * Rb[i][2] for i in range(3))
    return math.acos(max(-1.0, min(1.0, (tr_ - 1) / 2))) / D


FIT_EASES = ["linear", "sineIn", "sineOut", "sineInOut", "quadIn", "quadOut", "quadInOut", "cubicIn", "cubicOut", "expoOut", "expoIn", "quartOut"]


def orig_segment(keys0, t):
    """t 가 속한 원래 구간 (시작 시각, 끝 시각, 곡선 이름)"""
    for i in range(1, len(keys0)):
        if t <= keys0[i][0]:
            return keys0[i - 1][0], keys0[i][0], keys0[i][1]
    return keys0[-1][0], keys0[-1][0] + 1, None


def fit_ease(keys0, ta, tb):
    """원래 구간 안의 [ta, tb] 를 한 번에 잇는 가속 곡선 중 원래 모양에 가장 가까운 것"""
    sa, sb, e = orig_segment(keys0, (ta + tb) / 2)
    f = lambda t: ease(e, (t - sa) / max(1e-4, sb - sa))
    fa, fb = f(ta), f(tb)
    if abs(fb - fa) < 1e-9:
        return "linear"
    xs = [i / 16 for i in range(17)]
    target = [(f(ta + (tb - ta) * x) - fa) / (fb - fa) for x in xs]
    return min(FIT_EASES, key=lambda c: sum((ease(c, x) - y) ** 2 for x, y in zip(xs, target)))


_ORIG_ARM = {}
_EDGE = {}


def orig_arm_R(keys0, t):
    """원래 모션의 시각 t 오른팔 회전 행렬(캐시)"""
    key = (id(keys0), round(t, 6))
    if key not in _ORIG_ARM:
        _ORIG_ARM[key] = om(*sample_full(keys0, t)["RArm"])
    return _ORIG_ARM[key]


def sample_full(keys0, t):
    """원래 모션을 시각 t 에 찍은 자세(모든 관절)"""
    if t <= keys0[0][0]:
        return {c: list(v) for c, v in keys0[0][2].items()}
    for i in range(1, len(keys0)):
        tb, eb, pb = keys0[i]
        if t <= tb:
            ta, _, pa = keys0[i - 1]
            a = ease(eb, (t - ta) / max(1e-4, tb - ta))
            return {c: [pa[c][j] + (pb[c][j] - pa[c][j]) * a for j in range(len(pa[c]))] for c in pa}
    return {c: list(v) for c, v in keys0[-1][2].items()}


def build(knots, ths, keys0):
    """knots = [(t, e, 원래 자세)] + 키별 θ → (오일러를 고른 키 목록, 키별 오른팔 오일러)"""
    arms = choose_reps(knots, ths, keys0)
    keys = []
    for k, (t, e, pose) in enumerate(knots):
        q = {c: list(v) for c, v in pose.items()}
        q["RArm"] = list(arms[k])
        keys.append((t, e, q))
    return keys, arms


def runs(mask, gap=3):
    """참인 표본 번호들을 이어진 덩어리(gap 이하로 끊기면 같은 덩어리)로"""
    out = []
    for j in mask:
        if out and j - out[-1][-1] <= gap:
            out[-1].append(j)
        else:
            out.append([j])
    return out


def plan(name, ov=None, extra=(), pins=None, max_ins=40, verbose=True, dt=1 / 480, target=0.83, swing=None, wobble=0.5, slow_wobble=0.25):
    """키별 비틀기 θ(ov: {키 번호: 도 또는 "prev"} — 안 적은 키는 최소제곱 추천값)와 강제로 끼울 중간 키 extra=[(t, θ)] 로 시작해,
    ① 휘두름(v⊥ ≥ swing) 표본 중 |cos| < target ② 오일러 직선 보간 때문에 칼끝이 이상적인 길(원래 팔 · Ry(θ))에서 wobble 스터드 넘게
    벗어난 표본이 남아 있으면, 그 덩어리 가운데에 중간 키(원래 모션을 그 시각에 찍은 자세 + 그 순간의 비틀기)를 끼운다.
    pins = θ=0 으로 못 박을 키(기본: 마지막)."""
    swing = swing or SWING
    keys0 = keys_of(name, base=True)
    t0, t1 = WINDOW[name]
    sim0, star, ws, vps = profile(keys0, t0, t1, dt)
    n0 = len(keys0)
    pins = tuple(pins) if pins is not None else (n0 - 1,)
    ths = fit_theta(keys0, sim0, star, ws, pin=pins)
    for k, v in (ov or {}).items():
        ths[k] = ths[k - 1] if v == "prev" else float(v)
    knots = [(k[0], k[1], {c: list(v) for c, v in k[2].items()}) for k in keys0]
    inserted = []
    base_arms0 = [tuple(k[2]["RArm"]) for k in keys0]
    orig_R = [om(*sim0.arm_at(base_arms0, j)) for j in range(len(sim0.ts))]

    def insert(tm, theta_m, why=""):
        nonlocal knots, ths
        ts_ = [k[0] for k in knots]
        if any(abs(tm - x) < INS_MIN for x in ts_):
            return False
        i = next(i for i, x in enumerate(ts_) if x > tm)
        e_m = fit_ease(keys0, ts_[i - 1], tm)
        e_next = fit_ease(keys0, tm, ts_[i])
        knots[i] = (knots[i][0], e_next, knots[i][2])
        knots.insert(i, (tm, e_m, sample_full(keys0, tm)))
        ths = ths[:i] + [theta_m] + ths[i:]
        inserted.append(tm)
        if verbose:
            print("   중간 키 t=%.3f 끼움 (%s θ=%.1f, 곡선 %s/%s)" % (tm, why, theta_m, e_m, e_next))
        return True

    for tm, theta_m in extra:
        insert(round(tm, 3), float(theta_m), "지정")
    for it in range(max_ins + 1):
        keys, arms = build(knots, ths, keys0)
        sim1 = Sim(keys, t0, t1, dt)
        eul = [k[2]["RArm"] for k in keys]
        met, tips = sim1.metrics(eul)
        wob = [0.0] * len(tips)
        for j in range(len(tips)):
            A = mm(sim1.RT[j], mm(orig_R[j], ryy(theta_at(sim1, ths, j))))
            pc = vadd(vadd(sim1.PT[j], mv(sim1.RT[j], (1, 0.5, 0))), mv(A, (0.5, -0.5, 0)))
            wob[j] = vmag(vsub(tips[j], vadd(pc, mv(A, (0, TIP_Y, 0)))))
        sk = int(SKIP.get(name, 0.0) / dt)
        bad_cos = [j for j in range(max(1, sk), len(tips)) if met[j][0] >= swing and met[j][1] < target]
        bad_wob = [j for j in range(1, len(tips)) if wob[j] > (wobble if vps[j] >= swing else slow_wobble)]
        groups = [(max(1.0 - met[j][1] for j in g_) + 1.0, g_, "|cos| %.2f" % min(met[j][1] for j in g_)) for g_ in runs(bad_cos)]
        groups += [(max(wob[j] for j in g_) / slow_wobble, g_, "칼끝 벗어남 %.2f" % max(wob[j] for j in g_)) for g_ in runs(bad_wob)]
        if not groups or it == max_ins:
            break
        done = False
        for _, g_, why in sorted(groups, reverse=True):
            for frac in (0.5, 0.33, 0.67):
                j = g_[int(len(g_) * frac)]
                if insert(round(sim1.ts[j], 3), theta_at(sim1, ths, j), why + " (%d 표본)" % len(g_)):
                    done = True
                    break
            if done:
                break
        if not done:
            if verbose:
                print("   (더 못 끼움: 남은 나쁜 덩어리 %d 개)" % len(groups))
            break
    return knots, ths, arms, keys, sim1, inserted


def cmd_gen(names):
    """계획표대로 비틀기를 구해 보고하고, 키 목록(원래 키의 새 RArm · 곡선, 끼운 중간 키의 전체 자세)을 out/callisto_edge_plan.json 에 쓴다"""
    dump = {}
    for name in names:
        pl = PLAN[name]
        print("[%s]" % name)
        knots, ths, arms, keys, sim1, ins = plan(name, ov=pl["ov"], extra=pl.get("extra", ()), pins=pl["pins"])
        fine = Sim(keys, *WINDOW[name], 1 / 480)
        met, tips = fine.metrics([k[2]["RArm"] for k in keys])
        lines, worst, _ = summary(name, met, tips)
        print(chr(10).join(lines))
        print("-- %s 키별 RArm (비틀기 θ)  * = 끼운 중간 키" % name)
        rows = []
        for k, (t, e, pose) in enumerate(knots):
            mid = t in ins
            print("  %st=%-6g %-9s θ=%6.1f  RArm = { %s }   (원래 { %s })" % ("*" if mid else " ", t, e or "-", ths[k], ", ".join("%g" % v for v in arms[k]), ", ".join("%g" % round(v, 1) for v in pose["RArm"])))
            row = {"t": t, "e": e, "theta": round(ths[k], 1), "RArm": list(arms[k]), "mid": mid}
            if mid:
                row["pose"] = {c: [round(x, 2 if c == "Root" and i < 3 else 1) for i, x in enumerate(v)] for c, v in pose.items() if c != "RArm"}
            rows.append(row)
        dump[name] = {"keys": rows, "worst": {str(k): round(v, 3) for k, v in worst.items()}}
    with open(os.path.join(HERE, "..", "out", "callisto_edge_plan.json"), "w", encoding="utf-8", newline=chr(10)) as f:
        json.dump(dump, f, ensure_ascii=False, indent=1)


def cmd_rebase():
    """지금 motions.json 의 칼 기술 5개 키를 새 원본(비틀기 전)으로 저장한다 — Callisto.luau 에서 칼 자세(READY_HI 같은 것)를 새로 짰고
    RArm 에 비틀기가 안 들어간(원래 모양) 상태일 때만. 이미 비튼 키로 하면 이중으로 비튼다."""
    sk = load()
    names = list(WINDOW)
    with open(BASE, "w", encoding="utf-8", newline=chr(10)) as f:
        json.dump({n: {"Duration": sk[n]["Duration"], "Keys": sk[n]["Keys"]} for n in names}, f, ensure_ascii=False, indent=1)
    print("원본 키를 저장:", BASE)


def cmd_selftest():
    """닫힌 꼴 계산(Sim)이 posecalc.solve(전신 계산)와 같은 칼끝·팔 방향을 내는지, 비틀기가 오일러로 정확히 왕복하는지"""
    sys.path.insert(0, os.path.join(HERE, ".."))
    import posecalc as pc

    keys = keys_of("CallistoSlash", base=True)
    sim = Sim(keys, 0.0, 1.4, 1 / 60)
    arms = [k[2]["RArm"] for k in keys]
    tips, axes, zs = sim.run(arms)
    worst = 0.0
    for j in range(0, len(sim.ts), 5):
        i, a = sim.seg[j]
        ka, kb = keys[max(i - 1, 0)][2], keys[i][2]
        pose = {n: [ka[n][c] + (kb[n][c] - ka[n][c]) * a for c in range(len(ka[n]))] for n in ka}
        w = pc.solve(pose)["RArm"]
        worst = max(worst, vmag(vsub(w.pt((0, TIP_Y, 0)), tips[j])), vmag(vsub(tuple(w.R[r][2] for r in range(3)), zs[j])))
    assert worst < 1e-6, worst
    for base in [(165, 0, 35), (88, 0, -92), (30, 0, 78), (76, 0, -50)]:
        for th in (-87, -35, 0, 55, 85):
            R0, R1 = mm(om(*base), ryy(th)), om(*twist(base, th))
            assert max(abs(R0[i][j] - R1[i][j]) for i in range(3) for j in range(3)) < 1e-9
    print("selftest ok (닫힌 꼴 = posecalc.solve, 최대 차이 %.1e)" % worst)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    names = list(WINDOW)
    if len(sys.argv) > 2:
        names = ["Callisto" + sys.argv[2].replace("Callisto", "")]
    if cmd == "check":
        w = cmd_check(names)
        sys.exit(0 if w[SWING] >= 0.8 else 1)
    elif cmd == "gen":
        cmd_gen(names)
    elif cmd == "rebase":
        cmd_rebase()
    elif cmd == "selftest":
        cmd_selftest()
