# -*- coding: utf-8 -*-
"""
posecalc.py — 전투 자세 손계산 도우미(블렌더 없이 파이썬만). (2026-09-30)

게임·미리보기와 같은 규칙(CombatRig / preview_motion.solve)으로 R6 자세의 손·무기 자리를 구하고,
양손 무기에서 **왼손이 자루의 한 점을 쥐도록** 팔 각도를 찾아 준다(팔이 곧은 R6 라 계산 없이 맞추기 어렵다).

  from posecalc import *
  pose = {...}                      # 모션 파일의 키와 같은 모양(Root 6, 관절 3, W/O 6)
  hand(pose, "L")                   # 왼손 끝(캐릭터 공간, x 오른쪽 · y 위 · z 뒤)
  wpoint(pose, "W", (0, -0.7, 0))   # 오른손 무기 공간의 점 → 캐릭터 공간
  reach(pose, "L", target)          # 왼손이 target 에 닿는 LArm (x, y, z)
  aim(pose, "O", R_world, origin)   # 무기를 원하는 월드 회전·원점에 두는 O 값
"""
import math

D = math.pi / 180


def rx(a):
    c, s = math.cos(a * D), math.sin(a * D)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def ry(a):
    c, s = math.cos(a * D), math.sin(a * D)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rz(a):
    c, s = math.cos(a * D), math.sin(a * D)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def mm(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mv(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def tr(a):
    return tuple(tuple(a[j][i] for j in range(3)) for i in range(3))


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def scale(a, k):
    return tuple(x * k for x in a)


def norm(a):
    n = math.sqrt(sum(x * x for x in a))
    return tuple(x / n for x in a)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


I3 = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


class CF:
    def __init__(self, R=I3, p=(0, 0, 0)):
        self.R, self.p = R, tuple(p)

    def __mul__(self, o):
        return CF(mm(self.R, o.R), add(mv(self.R, o.p), self.p))

    def inv(self):
        Rt = tr(self.R)
        return CF(Rt, scale(mv(Rt, self.p), -1))

    def pt(self, v):
        return add(mv(self.R, v), self.p)


def cfp(x, y, z):
    return CF(I3, (x, y, z))


def orient(x, y, z):  # CFrame.fromOrientation = Ry·Rx·Rz
    return CF(mm(mm(ry(y), rx(x)), rz(z)))


def angles(x, y, z):  # CFrame.Angles = Rx·Ry·Rz
    return CF(mm(mm(rx(x), ry(y)), rz(z)))


def to_angles(R):
    """CFrame.Angles(x,y,z) 로 되돌리기(도)"""
    b = math.asin(max(-1, min(1, R[0][2])))
    a = math.atan2(-R[1][2], R[2][2])
    c = math.atan2(-R[0][1], R[0][0])
    return (a / D, b / D, c / D)


RJ = ((-1, 0, 0), (0, 0, 1), (0, 1, 0))
RS = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))
LS = ((0, 0, -1), (0, 1, 0), (1, 0, 0))
JOINTS = {
    "Torso": ("HRP", CF(RJ), CF(RJ)),
    "Head": ("Torso", CF(RJ, (0, 1, 0)), CF(RJ, (0, -0.5, 0))),
    "RArm": ("Torso", CF(RS, (1, 0.5, 0)), CF(RS, (-0.5, 0.5, 0))),
    "LArm": ("Torso", CF(LS, (-1, 0.5, 0)), CF(LS, (0.5, 0.5, 0))),
    "RLeg": ("Torso", CF(RS, (1, -1, 0)), CF(RS, (0.5, 1, 0))),
    "LLeg": ("Torso", CF(LS, (-1, -1, 0)), CF(LS, (-0.5, 1, 0))),
}
ORDER = ["Torso", "Head", "RArm", "LArm", "RLeg", "LLeg"]


def solve(pose):
    """preview_motion.solve 와 같다(부품 월드 CFrame, HRP 기준)"""
    world = {"HRP": CF()}
    rt = orient(*pose.get("Torso", (0, 0, 0)))
    r = pose.get("Root", (0,) * 6)
    rootcf = cfp(r[0], r[1], r[2]) * orient(r[3], r[4], r[5])
    for name in ORDER:
        parent, C0, C1 = JOINTS[name]
        v = pose.get(name, (0, 0, 0))
        if name == "Torso":
            R = rootcf * cfp(0, -1, 0) * rt * cfp(0, 1, 0)
        elif name in ("RLeg", "LLeg"):
            R = rt.inv() * orient(*v)
        else:
            R = orient(*v)
        conj = CF(C0.R)
        T = conj.inv() * R * conj
        world[name] = world[parent] * C0 * T * C1.inv()
    return world


GRIP = cfp(0, -1, 0) * angles(-90, 0, 0)


def grip_cf(pose, slot):
    w = solve(pose)
    return w["RArm" if slot == "W" else "LArm"] * GRIP


def weapon_cf(pose, slot):
    v = pose.get(slot, (0,) * 6)
    return grip_cf(pose, slot) * angles(v[3], v[4], v[5]) * cfp(v[0], v[1], v[2])


def wpoint(pose, slot, local):
    return weapon_cf(pose, slot).pt(local)


def hand(pose, side):
    return solve(pose)["RArm" if side == "R" else "LArm"].pt((0, -1, 0))


def reach(pose, side, target, hint=None, lam=1e-5):
    """side 팔 끝이 target 에 닿는 팔 각도(x, y, z). hint 가까이(비슷한 답 중 덜 비튼 것)."""
    key = "RArm" if side == "R" else "LArm"
    best = list(hint or pose.get(key, (0, 0, 0)))
    ref = tuple(best)

    def cost(v):
        p = dict(pose)
        p[key] = tuple(v)
        return dist(hand(p, side), target) ** 2 + lam * sum((a - b) ** 2 for a, b in zip(v, ref))

    c0 = cost(best)
    step = 24.0
    while step > 0.05:
        moved = False
        for i in range(3):
            for s in (step, -step):
                t = list(best)
                t[i] += s
                if abs(t[i] - ref[i]) > 90:
                    continue
                c = cost(t)
                if c < c0:
                    best, c0, moved = t, c, True
        if not moved:
            step /= 2
    p = dict(pose)
    p[key] = tuple(best)
    return tuple(round(a, 1) for a in best), dist(hand(p, side), target)


ARM = math.sqrt(0.5 ** 2 + 1.5 ** 2)  # 어깨 축에서 손끝까지(팔이 곧아 손은 이 반지름의 구 위에만 간다)


def pivot(pose, side):
    """어깨 돌림 축(팔 부품의 안쪽 위 모서리 가운데)"""
    return solve(pose)["RArm" if side == "R" else "LArm"].pt((-0.5, 0.5, 0) if side == "R" else (0.5, 0.5, 0))


def reach_line(pose, side, slot, y0, y1, n=200):
    """무기 slot 의 자루(무기 공간 y0~y1) 위에서 팔이 닿는 점을 골라 그 점을 쥔다 → (팔 각도, 쥔 y, 어긋남)"""
    pv = pivot(pose, side)
    best = None
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        e = abs(dist(wpoint(pose, slot, (0, y, 0)), pv) - ARM)
        if best is None or e < best[0]:
            best = (e, y)
    v, err = reach(pose, side, wpoint(pose, slot, (0, best[1], 0)))
    return v, round(best[1], 2), err


def point_arm(pose, side, target, z=0.0):
    """팔 길이 축(어깨→손)이 target 을 향하는 팔 각도(x, y, z 고정). 팔 가운데에서 본 방향으로 맞춘다."""
    key = "RArm" if side == "R" else "LArm"
    best = None
    x0, y0 = pose.get(key, (60, 0, 0))[:2]
    for step in (8.0, 2.0, 0.5, 0.1):
        cx, cy = (x0, y0) if best is None else best[1][:2]
        for i in range(-12, 13):
            for j in range(-12, 13):
                v = (cx + i * step, cy + j * step, z)
                q = dict(pose)
                q[key] = v
                w = solve(q)[key]
                d = norm(sub(w.pt((0, -1, 0)), w.pt((0, 1, 0))))
                e = dist(d, norm(sub(target, w.pt((0, 0, 0)))))
                if best is None or e < best[0]:
                    best = (e, v)
    return tuple(round(a, 1) for a in best[1])


def frame(y_axis, z_hint):
    """무기 축: +Y = y_axis(날·머리 쪽), -Z 는 z_hint 쪽(날이 향하는 쪽)에 가깝게"""
    y = norm(y_axis)
    x = norm(cross(z_hint, y))
    z = cross(x, y)
    return tuple(tuple(v[i] for v in (x, y, z)) for i in range(3))


def aim(pose, slot, R_world, origin=None):
    """무기를 월드 회전 R_world(열 = 무기 x,y,z 축)로, 원점을 origin 에 두는 {x,y,z,숙임,비틀기,기울기}"""
    g = grip_cf(pose, slot)
    Rl = mm(tr(g.R), R_world)
    a = to_angles(Rl)
    if origin is None:
        off = (0, 0, 0)
    else:
        # 무기 원점 = 손 + R_world · (x,y,z)
        off = mv(tr(R_world), sub(origin, g.p))
    return tuple(round(v, 2) for v in off) + tuple(round(v, 1) for v in a)


def aim_axis(pose, slot, world_dir, origin=None):
    """날 길이 축(+Y)만 world_dir 로 — 비틀기 0(숙임·기울기만)이라 손에 자연스럽게 쥔 채로 방향만 바꾼다"""
    g = grip_cf(pose, slot)
    d = mv(tr(g.R), norm(world_dir))
    tilt = -math.asin(max(-1, min(1, d[0])))
    pitch = math.atan2(d[2], d[1])
    out = (0, 0, 0)
    if origin is not None:
        R = mm(g.R, angles(pitch / D, 0, tilt / D).R)
        out = tuple(round(v, 2) for v in mv(tr(R), sub(origin, g.p)))
    return out + (round(pitch / D, 1), 0, round(tilt / D, 1))


def show(pose, slot, pts):
    for name, loc in pts.items():
        print(f"  {slot}.{name}: " + ", ".join(f"{v:.2f}" for v in wpoint(pose, slot, loc)))


def lua(name, v):
    return f"{name} = {{ " + ", ".join(f"{x:g}" for x in v) + " }"


if __name__ == "__main__":
    # 스스로 점검: 가만히 선 오른손 끝 = (1.5, -1, 0), 무기 숙임 0 → 무기 +Y 가 앞(-Z)
    p = {}
    assert dist(hand(p, "R"), (1.5, -1, 0)) < 1e-9
    assert dist(wpoint(p, "W", (0, 1, 0)), (1.5, -1, -1)) < 1e-9
    # 팔 수평 앞 + 숙임 -90 → 무기가 팔 연장선(앞)
    p = {"RArm": (90, 0, 0), "W": (0, 0, 0, -90, 0, 0)}
    tip = wpoint(p, "W", (0, 1, 0))
    assert abs(tip[1] - hand(p, "R")[1]) < 1e-9 and tip[2] < hand(p, "R")[2]
    # aim 이 되돌려 놓는지
    R = frame((0.3, 0.8, -0.5), (0, 0, -1))
    o = aim(p, "W", R, (1, 2, -1))
    q = dict(p)
    q["W"] = o
    assert dist(wpoint(q, "W", (0, 0, 0)), (1, 2, -1)) < 0.02
    assert dist(sub(wpoint(q, "W", (0, 1, 0)), wpoint(q, "W", (0, 0, 0))), norm((0.3, 0.8, -0.5))) < 0.01
    # aim_axis: 팔 수평 앞, 날을 위로 → 숙임 0
    q = {"RArm": (90, 0, 0)}
    a = aim_axis(q, "W", (0, 1, 0))
    assert abs(a[3]) < 0.1 and abs(a[5]) < 0.1, a
    q["W"] = aim_axis(q, "W", (0.5, 0.5, -0.7))
    assert dist(norm(sub(wpoint(q, "W", (0, 1, 0)), wpoint(q, "W", (0, 0, 0)))), norm((0.5, 0.5, -0.7))) < 1e-2
    # frame: -Z 가 z_hint 쪽
    Fr = frame((0, 1, 0), (0, 0, -1))
    assert dist(tuple(Fr[i][2] for i in range(3)), (0, 0, 1)) < 1e-9 and dist(tuple(Fr[i][0] for i in range(3)), (1, 0, 0)) < 1e-9
    # reach
    t = add(pivot({}, "L"), scale(norm((-0.4, 0.2, -1)), ARM))
    v, err = reach({}, "L", t, hint=(90, 0, 0))
    assert err < 0.02, err
    print("posecalc ok", v)
