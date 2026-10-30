"""청의 검사 모션 파일(src/shared/Combat/Motions/AzureBlade.luau)을 통째로 만든다(2026-10-25, 조건부 획득 직업).
자세 값 = azure_poses.py(posecalc — 꽂힌 자세는 키마다 칼을 검집 안에 넣고, 뽑은 자세는 오른손 하나로 쥔 날 방향).
키마다 칼(W)·검집(O) 회전을 앞 키에 가장 가까운 표기로 감아 적어(twohand.near) 키 사이가 늘 최단 호로 돈다.
덮어쓰는 것은 Root·Torso·Head·다리뿐 — 팔을 바꾸면 칼이 검집에서 빠지므로 팔은 늘 자세 표 그대로 쓴다.
쓰는 법: python tools/combat/design/azure_gen.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import azure_poses as A  # noqa: E402
from twohand import angles, f, near, to_angles  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "src", "shared", "Combat", "Motions", "AzureBlade.luau")
POSES, NOTES = A.POSES, A.NOTES

KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg", "W", "O"]
ORDER = ["STANCE", "THUMB", "CROUCH", "DRAW1", "DRAW2", "DRAW3", "OUT", "KESA", "RISE", "DRAWCUT", "CUTDOWN", "SWEEP", "ZAN", "CHIBURI", "NOTO",
         "PEEK", "FLICK", "LIFT", "STRIKE", "BLOCK", "RECOIL", "STEPBACK", "HANG", "LAND", "BOW", "SLASHR", "SKYRISE", "SIDEKESA", "BACKSWEEP", "FOOTLIFT", "FOOTDOWN", "SET", "RUNOFF", "RUNOFF2", "RAISE"]
# 이펙트가 쓰는 자세(잔상 — Fx/AzureBlade 의 Ghost)
GHOST_POSES = ["STANCE", "DRAW1", "DRAW2", "DRAWCUT", "RISE", "CUTDOWN", "KESA", "SWEEP", "OUT", "SLASHR", "NOTO", "ZAN", "SKYRISE", "SIDEKESA", "BACKSWEEP"]
ARMS = {"RArm", "LArm", "W", "O"}


# MotionMath.Ease 와 같은 곡선(중간 키의 진행도를 원래 키의 곡선으로 매긴다)
def _ease(name, x):
    c1 = 1.70158
    table = {
        None: lambda x: -(math.cos(math.pi * x) - 1) / 2,
        "linear": lambda x: x,
        "sineIn": lambda x: 1 - math.cos(x * math.pi / 2),
        "sineOut": lambda x: math.sin(x * math.pi / 2),
        "sineInOut": lambda x: -(math.cos(math.pi * x) - 1) / 2,
        "quadIn": lambda x: x * x,
        "quadOut": lambda x: 1 - (1 - x) ** 2,
        "cubicIn": lambda x: x ** 3,
        "cubicOut": lambda x: 1 - (1 - x) ** 3,
        "quartOut": lambda x: 1 - (1 - x) ** 4,
        "cubicInOut": lambda x: 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2,
        "expoOut": lambda x: 1.0 if x >= 1 else 1 - 2 ** (-10 * x),
        "expoIn": lambda x: 0.0 if x <= 0 else 2 ** (10 * x - 10),
        "backOut": lambda x: 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2,
    }
    return table[name](x)


def _quat(R):
    t = R[0][0] + R[1][1] + R[2][2]
    if t > 0:
        s4 = math.sqrt(t + 1) * 2
        return ((R[2][1] - R[1][2]) / s4, (R[0][2] - R[2][0]) / s4, (R[1][0] - R[0][1]) / s4, s4 / 4)
    i = max(range(3), key=lambda k: R[k][k])
    j, k = (i + 1) % 3, (i + 2) % 3
    s4 = math.sqrt(1 + R[i][i] - R[j][j] - R[k][k]) * 2
    q = [0.0, 0.0, 0.0, (R[k][j] - R[j][k]) / s4]
    q[i], q[j], q[k] = s4 / 4, (R[j][i] + R[i][j]) / s4, (R[k][i] + R[i][k]) / s4
    return tuple(q)


def _mat(q):
    x, y, z, w = q
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
            (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
            (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)))


def _slerp6(a, b, u):
    """무기 값 {x,y,z, 숙임,비틀기,기울기}: 자리는 직선, 회전은 최단 호(MotionMath.slerpWeapon 과 같은 뜻)"""
    qa, qb = _quat(angles(*a[3:]).R), _quat(angles(*b[3:]).R)
    d = sum(x * y for x, y in zip(qa, qb))
    if d < 0:
        qb, d = tuple(-x for x in qb), -d
    if d > 0.9995:
        q = tuple(x + (y - x) * u for x, y in zip(qa, qb))
    else:
        th = math.acos(d)
        q = tuple((math.sin((1 - u) * th) * x + math.sin(u * th) * y) / math.sin(th) for x, y in zip(qa, qb))
    n = math.sqrt(sum(x * x for x in q))
    q = tuple(x / n for x in q)
    return tuple(x + (y - x) * u for x, y in zip(a[:3], b[:3])) + tuple(to_angles(_mat(q)))


BODY = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg"]


def _full(name, over):
    P = {k: tuple(v) for k, v in POSES[name].items()}
    P.update({k: tuple(v) for k, v in (over or {}).items()})
    return P


# 칼끝이 검집 입을 막 빠져나온 뽑힘(이만큼 미끄러져야 칼이 검집에서 자유로워진다)
FULL = A.TIP_Y - A.SHEATH_Y + 0.12
# 발도(hilt → drawn)·납도(drawn → hilt)에서 칼이 검집 축을 따라 미끄러지는 몫(진행도) — 나머지 동안 칼이 휘둘러진다
SLIDE = 0.4


def saya_on_sword(P, depth):
    """오른손에 쥔 칼(W)에 검집을 depth 만큼 뽑힌 자리로 씌운다(azure_poses.place_sword 의 거꾸로)"""
    wc = A.weapon_cf(P, "W")
    r, o = A.sword_in_saya(depth)
    R = A.mm(wc.R, A.tr(r))
    A.set_back(P, R, A.sub(wc.p, A.mv(R, o)))


def _tween_mode(a, b):
    ma, mb = A.MODE[a], A.MODE[b]
    # 2026-10-30 사용자: "발도, 납도할 때 검날이 좀 부자연스럽게 들어가(검집을 뚫는다던가)" — 반쯤 뽑힌 자세와 뽑아 든 자세를
    # 곧장 이으면 칼이 검집 벽을 뚫고 휘둘러졌다 → 칼이 검집 축을 따라 끝까지 미끄러져 빠진 뒤(또는 입에 맞춘 뒤) 휘두른다
    if ma == "hilt" and mb == "drawn":
        return "draw"
    if ma == "drawn" and mb == "hilt":
        return "sheathe"
    if ma == "back" and mb == "back":
        return "back"
    if (ma == "carry" or a in A.ON_HILT) and (mb == "carry" or b in A.ON_HILT) and "carry" in (ma, mb):
        return "carry"
    # 뽑는 중(두 손이 칼자루·검집을 쥠) ↔ 뽑는 중 / 칼자루를 잡은 꽂힌 자세
    if "hilt" in (ma, mb) and (ma == "hilt" or a in A.ON_HILT) and (mb == "hilt" or b in A.ON_HILT):
        return "hilt"
    return None


def _between(Pa, Pb, u, mode, da, db, name_a="", name_b=""):
    """두 자세 사이 진행도 u 의 자세 — 몸은 직선으로 잇고 칼·검집은 상태대로 다시 맞춘다"""
    Q = {k: tuple(x + (y - x) * u for x, y in zip(Pa[k], Pb[k])) for k in BODY}
    if mode == "back":
        Q["O"] = tuple(x + (y - x) * u for x, y in zip(Pa["O"], Pb["O"]))
        A.place_sword(Q, da + (db - da) * u)
    elif mode == "hilt":
        # 검집(등 → 두 손 사이)과 뽑힌 길이를 잇고, 오른손은 칼자루에 · 왼손은 (끝 자세가 뽑는 중이면) 검집 입에 다시 맞춘다
        Q["O"] = _slerp6(Pa["O"], Pb["O"], u)
        depth = da + (db - da) * u
        A.place_sword(Q, depth)
        A.grip_hilt(Q, depth)
        if "hilt" in (A.MODE[name_a], A.MODE[name_b]):
            w = u if A.MODE[name_b] == "hilt" else 1 - u
            if w > 0.5:
                Q["LArm"], _ = A.reach(Q, "L", A.saya_point(Q, A.LGRIP_Y), hint=Q["LArm"])
    elif mode in ("draw", "sheathe"):
        # draw: 처음 SLIDE 동안 칼(손 공간 그대로)에서 검집이 축을 따라 FULL 까지 미끄러져 빠지고(왼손이 끌어냄) → 칼이 끝 자세로 휘둘러진다.
        # sheathe: 그 거꾸로 — 칼이 입에 맞춰 오고(검집도 그 자리로) → 마지막 SLIDE 동안 축을 따라 미끄러져 들어간다.
        hilt_p, drawn_p, d0 = (Pa, Pb, da) if mode == "draw" else (Pb, Pa, db)
        w = u if mode == "draw" else 1 - u  # 0 = 뽑는 중 자세 쪽, 1 = 뽑아 든 자세 쪽
        if w <= SLIDE:
            Q["W"] = hilt_p["W"]
            saya_on_sword(Q, d0 + (FULL - d0) * (w / SLIDE))
            Q["LArm"], _ = A.reach(Q, "L", A.saya_point(Q, A.LGRIP_Y), hint=Q["LArm"])
        else:
            # 칼이 빠진 순간(진행도 SLIDE)의 검집·왼팔에서 뽑아 든 자세 쪽으로
            u1 = SLIDE if mode == "draw" else 1 - SLIDE
            Q1 = {k: tuple(x + (y - x) * u1 for x, y in zip(Pa[k], Pb[k])) for k in BODY}
            Q1["W"] = hilt_p["W"]
            saya_on_sword(Q1, FULL)
            Q1["LArm"], _ = A.reach(Q1, "L", A.saya_point(Q1, A.LGRIP_Y), hint=Q1["LArm"])
            v = (w - SLIDE) / (1 - SLIDE)
            Q["W"] = _slerp6(hilt_p["W"], drawn_p["W"], v)
            Q["O"] = _slerp6(Q1["O"], drawn_p["O"], v)
            Q["LArm"] = tuple(x + (y - x) * v for x, y in zip(Q1["LArm"], drawn_p["LArm"]))
    else:
        Q["W"] = _slerp6(Pa["W"], Pb["W"], u)
        A.saya_with_sword(Q)
    return Q


# ── 칼·검집 겹침 검사(2026-10-30 사용자: "발도, 납도할 때 … 검집을 뚫는다", "스탠딩 모션에서도 가끔씩 검날이 검집을 통과") ──
# 키 사이를 재생과 같게(몸 = 직선, 칼·검집 = 자리 직선 + 회전 최단 호) 0.01초마다 짚어, 날 가운데 선 위 점마다 날 단면(반두께·반너비)이
# 검집 겉 상자에 닿았는데 그 안에 다 들어가 있지 않거나(= 날이 검집 겉으로 비어져 나옴) 검집 축과 6° 넘게 어긋나 있으면 센다.
SAYA_Y = (-0.35 * A.K, 3.81 * A.K)
OUTER = (0.075 * A.K, 0.17 * A.K)  # 검집 겉 반폭(두께 x · 너비 z)
BLADE = (0.0325 * A.K, 0.125 * A.K)  # 날 반두께 · 반너비(밑동 0.135 ~ 끝 0.11 의 가운데)
BLADE_Y = [0.6 + i * 0.12 for i in range(44)]
CLIPS = []
CURRENT = [""]


def _dsori(y):
    return 2 * 0.34 * max(0.0, y / A.K - 0.44) / (4.01 * 4.01)


def saya_clip(P):
    inv = A.back_cf(P).inv()
    wc = A.weapon_cf(P, "W")
    n = 0
    for y in BLADE_Y:
        q = inv.pt(wc.pt((0, y, A.sori(y))))
        if not (SAYA_Y[0] < q[1] < SAYA_Y[1]):
            continue
        ax, az = abs(q[0]), abs(q[2] - (A.sori(q[1] + A.SHEATH_Y) - A.sori(A.SHEATH_Y)))
        if ax >= OUTER[0] + BLADE[0] or az >= OUTER[1] + BLADE[1]:
            continue  # 닿지 않음
        d = A.norm(A.mv(inv.R, A.mv(wc.R, (0, 1, _dsori(y)))))
        t = A.norm((0, 1, _dsori(q[1] + A.SHEATH_Y)))
        inside = ax + BLADE[0] <= OUTER[0] and az + BLADE[1] <= OUTER[1]
        if not inside or sum(x * y for x, y in zip(d, t)) < math.cos(math.radians(6)):
            n += 1
    return n


def _blend(Pa, Pb, u):
    """재생과 같은 키 사이 자세: 몸 = 직선, 칼·검집 = 자리 직선 + 회전 최단 호"""
    Q = {k: tuple(x + (y - x) * u for x, y in zip(Pa[k], Pb[k])) for k in BODY}
    Q["W"], Q["O"] = _slerp6(Pa["W"], Pb["W"], u), _slerp6(Pa["O"], Pb["O"], u)
    return Q


def _check(out):
    """keys() 가 만든 키 줄(중간 키 포함)을 0.01초마다 짚어 겹침을 CLIPS 에 적는다"""
    full = [(t, name, _full(name, over)) for t, _, name, over in out]
    for (t0, a, Pa), (t1, b, Pb) in zip(full, full[1:]):
        steps = max(2, math.ceil((t1 - t0) / 0.01))
        worst = 0
        for j in range(steps + 1):
            worst = max(worst, saya_clip(_blend(Pa, Pb, j / steps)))
        if worst:
            CLIPS.append(f"{CURRENT[0]:14s} {t0:5.2f}~{t1:5.2f}  {a} -> {b}  겹친 점 {worst}")


def keys(spec):
    """키 줄들. 칼 상태가 이어지는 두 키 사이(등↔등, 칼자루를 잡은 채 등↔검집째 들기)는 0.05초마다 중간 키를 넣어
    키마다 칼·검집을 정확히 다시 맞춘다(키 사이 보간만으로는 칼이 검집에서 빠져 따로 날아간다)."""
    items = []
    for item in spec:
        t, e, name = item[0], item[1], item[2]
        over = dict(item[3]) if len(item) > 3 and item[3] else {}
        assert not (ARMS & set(over)), "팔·무기는 덮어쓰지 않는다(칼이 검집에서 빠진다): " + name
        items.append((t, e, name, over))
    out = []
    for i, (t, e, name, over) in enumerate(items):
        if i > 0:
            t0, _, prev_name, prev_over = items[i - 1]
            mode = _tween_mode(prev_name, name)
            if mode:
                Pa, Pb = _full(prev_name, prev_over), _full(name, over)
                n = max(8 if mode in ("draw", "sheathe") else 2, math.ceil((t - t0) / 0.05 - 1e-9))
                da, db = A.DEPTH.get(prev_name, 0.0), A.DEPTH.get(name, 0.0)

                def exact(tau, t0=t0, t=t, e=e, Pa=Pa, Pb=Pb, mode=mode, da=da, db=db, a=prev_name, b=name):
                    return _between(Pa, Pb, _ease(e, (tau - t0) / (t - t0)), mode, da, db, a, b)

                # 중간 키: 0.05초 간격 → 이웃 둘을 재생처럼 직선으로 이었을 때 칼이 검집 겉으로 비어져 나오면(saya_clip) 가운데에 키를 더 넣는다.
                # (칼은 오른손에 붙어 있어 손이 크게 움직이는 사이에선 0.05초 간격으로는 등에 꽂힌 칼이 검집 밖으로 흔들렸다 —
                #  2026-10-30 사용자: "스탠딩 모션에서도 가끔씩 검날이 검집을 통과")
                taus = [t0 + (t - t0) * j / n for j in range(n + 1)]
                poses = [Pa] + [exact(x) for x in taus[1:-1]] + [Pb]
                k = 0
                while k < len(taus) - 1:
                    if taus[k + 1] - taus[k] > 0.006 and any(saya_clip(_blend(poses[k], poses[k + 1], f)) for f in (0.17, 0.33, 0.5, 0.67, 0.83)):
                        m = (taus[k] + taus[k + 1]) / 2
                        taus.insert(k + 1, m)
                        poses.insert(k + 1, exact(m))
                    else:
                        k += 1
                for tau, Q in zip(taus[1:-1], poses[1:-1]):
                    out.append((round(tau, 3), "linear", name, Q))
                e = "linear"
        out.append((t, e, name, over))
    _check(out)
    lines, prev = [], {}
    for t, e, name, over in out:
        over = dict(over)
        for slot in ("W", "O"):
            v = tuple(over.get(slot, POSES[name][slot]))
            if slot in prev:
                v = near(v, prev[slot])
            prev[slot] = v
            if tuple(round(x, 1) for x in v) != tuple(round(x, 1) for x in POSES[name][slot]):
                over[slot] = v
            else:
                over.pop(slot, None)
        for k in list(over):
            if k not in ("W", "O") and tuple(round(x, 2) for x in over[k]) == tuple(round(x, 2) for x in POSES[name][k]):
                del over[k]
        es = "nil" if e is None else '"%s"' % e
        if over:
            body = ", ".join("%s = %s" % (k, f(v)) for k, v in over.items())
            lines.append("\t\t\t\tK(%s, %s, %s, { %s })," % (t, es, name, body))
        else:
            lines.append("\t\t\t\tK(%s, %s, %s)," % (t, es, name))
    return "\n".join(lines)


def keys_named(name, spec):
    CURRENT[0] = name
    return keys(spec)


def motion(name, comment, duration, spec, events, extra="", indent=2):
    CURRENT[0] = name
    tab = "\t" * indent
    body = keys(spec)
    if indent == 1:
        body = "\n".join(line[1:] for line in body.split("\n"))
    ev = "\n".join(tab + "\t\t" + e + "," for e in events)
    return (
        f"{tab}-- {comment}\n{tab}{name} = {{\n{tab}\tDuration = {duration},\n{extra}{tab}\tKeys = {{\n{body}\n{tab}\t}},\n"
        + (f"{tab}\tEvents = {{\n{ev}\n{tab}\t}},\n" if events else "")
        + f"{tab}}},\n"
    )


head = '''--!strict
--[[
	청의 검사 — 자기 키만 한 대태도를 등에 메고 다니는 방랑 검사. (2026-10-25, 조건부 획득 직업)

	성격: 말없고 느긋하다. 대태도를 등에 비스듬히 메고(칼자루가 오른 어깨 위) 무릎을 굽혀 적을 노려보다가 뽑아 벤다.
	2026-10-25 사용자 말 설명으로 다시 짰다:
	  · 박자 — "강중약중강, 강약중강약이 없어 부자연스럽다": 센 박(짧고 크게 · expoOut + 멈춤) · 중간 박 · 여린 박(느리고 작게,
	    sineInOut 으로 버티기)을 섞는다. 키 줄 옆 주석의 [강]/[중]/[약]이 그 박이다.
	  · 천천히 뽑기 — 오른손은 칼자루를, 왼손은 검집 입을 쥐고 두 팔을 벌려 검집을 등에서 끌어낸다(DRAW1~3).
	  · 진 발도술(2026-10-30 다시) — 등에서 뽑아 강하게 세로로 내리베어 검기를 날린다(선이 따라감) → 검기가 대상 열 전체를 1타 → 꽂을 때 선이 2타.
	  · 발도술의 절정 — 반쯤 뽑다 "챙" 멈춤(빛) → 줄 끝에 이미 벤 자세로 나타남(사용자 그림, ZAN) → 지나간 자리의 검로 →
	    줄 전체를 가르는 칼날이 반짝일 때마다 타격.
	  · 공간의 이해(2026-10-30 다시, 컷신) — 발 확대·내딛기 → 달리기 준비(칼자루) → 사라져 보이지 않게 블링크 17번(무작위 자리·잔상·검흔,
	    카메라는 오른쪽 위로 올라 적 진영을 점점 빠르게 돈다) → 제자리에 나타나 꽂으면 흑백 → 검흔 17개가 하나씩 터지는 17연타.
	  · 검집 타격 — 강중약중강: 칼자루를 낚아채고 · 검집째 치켜들고 · 꼭대기에서 머물다 · 내려오며 · 내리꽂는다.
	칼은 오른팔에 붙어 있어, 등에 꽂힌 자세에서는 키마다 칼을 검집 안에 넣어 두고(azure_poses.place_sword) 칼자루를 잡을 때는
	오른팔을 칼자루에 정확히 닿게 구한다(grip_hilt). 이펙트는 Fx/AzureBlade, 잔상 자세는 아래 Poses.
	무기 종류: Odachi (WeaponDefinitions.Odachi). 오른손 = 칼(W), 등 = 검집(O, 몸통 공간).
	수치: tools/combat/design/azure_poses.py · 이 파일은 tools/combat/design/azure_gen.py 가 만든다. 손으로 고치지 말 것.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

'''
lines = []
for name in ORDER:
    q = POSES[name]
    lines.append("-- %s\nlocal %s = { %s }" % (NOTES[name], name, ", ".join("%s = %s" % (k, f(q[k])) for k in KEYS)))
text = head + "\n".join(lines) + "\n\nreturn {\n\tStance = STANCE,\n"
text += "\t-- 잔상이 쓰는 자세(Fx/AzureBlade)\n\tPoses = { " + ", ".join("%s = %s" % (n, n) for n in GHOST_POSES) + " },\n\n"
text += '''	-- 대기: 낮고 고요한 숨(Kit.Breath, Smooth). 들숨에 어깨가 조금 오르고, 내쉬며 시선이 적 쪽으로 미끄러진다
	Idle = Kit.Breath(STANCE, {
		Duration = 4.4,
		Chest = 2.0,
		Rise = 0.025,
		Head = -1.0,
		Mid = { Head = { 3, -18, 0 } },
	}),

	-- 버릇(가끔) 강약중강약: 칼자루를 낚아채 한 치 들썩 · 천천히 고개를 돌려 날빛을 보고 · 되돌려 · 딸깍 · 숨을 놓는다
	Fidgets = {
		{
			Duration = 1.75,
			BlendIn = 0.2,
			BlendOut = 0.3,
			Keys = {
''' + "\n".join("\t" + line for line in keys_named("Fidget", [(0, None, "STANCE"), (0.16, "expoOut", "THUMB"), (0.85, "sineInOut", "THUMB", {"Head": (4, -30, 0)}), (1.15, "cubicInOut", "THUMB"), (1.22, "expoIn", "NOTO"), (1.75, "sineInOut", "STANCE")]).split("\n")) + '''
			},
			Events = {
				{ t = 0.16, k = "Fx", n = "Glint" },
				{ t = 1.22, k = "Fx", n = "Click" },
			},
		},
	},

'''
text += motion("Held", "들림: 칼을 꽂은 채 꼿꼿이 매달려 천천히 흔들린다(버둥대지 않음)", 3.2,
               [(0, None, "HANG"), (1.6, None, "HANG", {"Root": (0, 0.1, 0, -3, 16, -2), "Head": (6, -24, 0)})],
               [], "\t\tLoop = true,\n\t\tSmooth = true,\n", 1)
text += "\n" + motion("Drop", "내려놓임 강약중: 툭 내려서고 · 무릎으로 받아 · 이아이 자세로", 1.0,
                      [(0, None, "HANG"), (0.14, "quadIn", "LAND"), (0.55, "sineOut", "LAND", {"Root": (0, -0.5, 0, 0, 24, 0)}), (1.0, "cubicInOut", "STANCE")],
                      ['{ t = 0.14, k = "Fx", n = "Touchdown" }'], "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Hit", "피격 강약중: 확 젖혀지고 · 잠깐 휘청 · 자세를 되잡는다", 0.7,
                      [(0, None, "STANCE"), (0.06, "expoOut", "RECOIL"), (0.36, "sineOut", "RECOIL", {"Root": (0, -0.22, 0.5, 0, 22, 0)}), (0.7, "cubicInOut", "STANCE")],
                      [], "\t\tBlendIn = 0.02,\n", 1)
text += "\n" + motion("Guard", "방어 강약중강약: 검집째 확 들어 막고 · 버티고 · 등으로 되돌려 · 딸깍 · 숨", 1.1,
                      [(0, None, "STANCE"), (0.05, "quadOut", "CROUCH"), (0.13, "expoOut", "BLOCK"), (0.4, "sineOut", "BLOCK", {"Root": (0, -0.34, 0.3, 0, 0, 0)}),
                       (0.66, "cubicInOut", "CROUCH"), (0.72, "expoIn", "NOTO"), (1.1, "sineInOut", "STANCE")],
                      ['{ t = 0.12, k = "Fx", n = "Block" }', '{ t = 0.72, k = "Fx", n = "Click" }'], "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Dodge", "회피 강약중: 낮게 확 비켜서고(선 자리에 잔상) · 미끄러지다 · 돌아온다", 0.75,
                      [(0, None, "STANCE"), (0.1, "expoOut", "STEPBACK"), (0.42, "sineOut", "STEPBACK", {"Root": (1.3, -0.52, 1.0, 0, 24, -4)}), (0.75, "cubicInOut", "STANCE")],
                      ['{ t = 0.01, k = "Fx", n = "Afterimage" }'], "\t\tBlendIn = 0.02,\n", 1)

def _drift(name, dy=-0.04, dz=-0.02, dry=-2):
    """센 박 뒤 버티기: 그 자세에서 조금 더 가라앉고 비튼다"""
    r = list(POSES[name]["Root"])
    r[1] += dy
    r[2] += dz
    r[4] += dry
    return {"Root": tuple(round(v, 3) for v in r)}


S = []
S.append(motion("ScabbardStrike", "검집 타격 강중약중강: 칼자루를 낚아채고[강] · 검집째 치켜들고[중] · 꼭대기에서 머물다[약] · 내려오며[중] · 내리꽂는다[강] — 약중강약으로 거둔다", 1.95,
                [(0, None, "STANCE"), (0.12, "expoOut", "CROUCH"), (0.4, "cubicInOut", "LIFT"), (0.62, "sineInOut", "LIFT", {"Root": (0, -0.1, 0.22, 0, 14, 0), "Torso": (14, 0, 0)}),
                 (0.8, "expoIn", "STRIKE"), (1.15, "sineOut", "STRIKE", {"Root": (0, -0.44, -0.34, 0, -6, 0)}), (1.45, "cubicInOut", "CROUCH"), (1.52, "expoIn", "NOTO"), (1.95, "sineInOut", "STANCE")],
                ['{ t = 0.58, k = "Dash", to = "Target", gap = 6.5, d = 0.2 }', '{ t = 0.8, k = "Hit", i = 1, fx = "SheathHit" }', '{ t = 0.81, k = "Stop", d = 0.08 }',
                 '{ t = 0.82, k = "Shake", a = 0.35, d = 0.25 }', '{ t = 1.15, k = "Dash", to = "Home", d = 0.32 }', '{ t = 1.52, k = "Fx", n = "Click" }']))
# 2026-10-30 사용자: "'집중베기' 스킬 사용하고, 적한테 돌진 먼저 한 후에 베게 해줘. 지금은 베면서 돌진하는데, 그럼 이펙트가 도중에 나오다
# 말아버려" — 전엔 블링크(0.04초 돌진) 도중에 벤 자세가 되어 검흔이 지나간 길 위에 났다 → 뽑다 만 칼을 쥔 채 대상 앞까지 돌진해 멈춘 뒤
# 마저 뽑아(DRAW3) 벤다(DRAWCUT). 검흔(SmallCuts)은 다 온 뒤 대상 쪽에 난다.
S.append(motion("FocusCut", "집중 베기([집중력]) — 발도술 셋과 같은 결로 작게: 칼자루를 낚아채[강] 조금 뽑다 챙! 멈추고[강] 숨을 고르다[약] "
                "잔상을 남기고 뽑다 만 칼을 쥔 채 대상 앞까지 돌진해 멈추고[중] 마저 뽑아[약] 한 번에 베면[강] 대상 둘레에 작게 기운 검흔이 반짝이며 벤다 → "
                "버티고[약] 털고[중] 딸깍[강] → 잔상을 남기고 제자리로[약]", 2.4,
                [(0, None, "STANCE"), (0.12, "expoOut", "CROUCH"), (0.32, "sineInOut", "DRAW1"),
                 (0.36, "expoOut", "DRAW1", {"Root": (0, -0.34, 0.04, 0, 61, 0), "Torso": (-6, 14, 0)}), (0.5, "sineInOut", "DRAW1", {"Root": (0, -0.32, 0.02, 0, 60, 0)}),
                 # 돌진(0.5 → 0.62): 몸을 앞으로 숙인 채 미끄러져 가 멈춘다
                 (0.62, "quadOut", "DRAW1", {"Root": (0, -0.4, -0.12, 0, 58, 0), "Torso": (-14, 12, 0)}),
                 (0.7, "quadIn", "DRAW3"), (0.76, "expoOut", "DRAWCUT"), (1.05, "sineOut", "DRAWCUT", _drift("DRAWCUT")), (1.3, "cubicInOut", "CHIBURI"),
                 (1.42, "cubicIn", "OUT"), (1.52, "linear", "DRAW3"), (1.72, "cubicIn", "NOTO"), (1.78, "linear", "NOTO"), (2.4, "sineInOut", "STANCE")],
                ['{ t = 0.12, k = "Fx", n = "Glint" }', '{ t = 0.34, k = "Fx", n = "Ching" }', '{ t = 0.5, k = "Fx", n = "Slip", p = "DRAW1" }',
                 '{ t = 0.5, k = "Dash", to = "Target", gap = 3.2, d = 0.12, e = "quadOut" }', '{ t = 0.62, k = "Shake", a = 0.15, d = 0.1 }',
                 '{ t = 0.72, k = "Fx", n = "Release" }', '{ t = 0.75, k = "Fx", n = "SmallCuts" }',
                 '{ t = 0.79, k = "Hit", i = 1, fx = "CutHit" }', '{ t = 0.8, k = "Stop", d = 0.06 }', '{ t = 0.8, k = "Shake", a = 0.3, d = 0.2 }',
                 '{ t = 1.72, k = "Fx", n = "Click" }', '{ t = 1.8, k = "Fx", n = "Slip", p = "NOTO" }', '{ t = 1.8, k = "Dash", to = "Home", d = 0.04, e = "linear" }']))
S.append(motion("TrueIaido", "진 발도술(2026-10-30 다시): 칼자루를 낚아채[강] 등에서 뽑아[약중] 빠짐[강] → 머리 위로 치켜들어[중] 숨[약] → 강하게 세로로 내리베어[강] "
                "검기를 날린다(선이 따라감) → 검기가 대상 열 전체를 벤다(1타) → 털고[중] 딸깍 꽂는 순간 검기를 따라간 선이 다시 벤다(2타)[강]", 2.6,
                [(0, None, "STANCE"), (0.14, "expoOut", "CROUCH"), (0.36, "sineInOut", "DRAW1"), (0.56, "sineIn", "DRAW3"), (0.61, "expoOut", "OUT"),
                 (0.72, "cubicOut", "RAISE"), (0.86, "sineInOut", "RAISE", {"Root": (0, -0.04, 0.14, 0, 2, 0)}), (0.93, "expoOut", "CUTDOWN"),
                 (1.2, "sineOut", "CUTDOWN", _drift("CUTDOWN")), (1.45, "cubicInOut", "CHIBURI"), (1.57, "cubicIn", "OUT"), (1.65, "linear", "DRAW3"),
                 (1.92, "cubicIn", "NOTO"), (2.6, "sineInOut", "STANCE")],
                ['{ t = 0.14, k = "Fx", n = "Glint" }', '{ t = 0.38, k = "Fx", n = "DrawGlint" }', '{ t = 0.59, k = "Fx", n = "Release" }',
                 '{ t = 0.86, k = "Trail", on = true }', '{ t = 0.92, k = "Fx", n = "WaveLaunch" }', '{ t = 0.94, k = "Stop", d = 0.05 }',
                 '{ t = 0.94, k = "Shake", a = 0.3, d = 0.2 }', '{ t = 1.05, k = "Trail", on = false }', '{ t = 1.16, k = "Hit", i = 1, fx = "WaveHit" }',
                 '{ t = 1.92, k = "Fx", n = "Click" }', '{ t = 1.95, k = "Hit", i = 2, fx = "LineStrike" }', '{ t = 1.96, k = "Stop", d = 0.08 }',
                 '{ t = 1.97, k = "Shake", a = 0.45, d = 0.3 }']))
S.append(motion("IaidoPeak", "발도술의 절정: 칼자루를 쥐고[중] 천천히 뽑다[약약] 챙! 멈춰 날에 빛[강] · 숨을 멈추고[약] · 사라져 줄 끝에 이미 벤 자세로(ZAN) · 줄 전체를 가르는 칼날이 반짝일 때마다 타격[강중강] → 일어나 털고[중] 딸깍[강] 돌아온다[약]", 3.55,
                [(0, None, "STANCE"), (0.2, "cubicOut", "CROUCH"), (0.62, "sineInOut", "DRAW1"), (0.9, "sineInOut", "DRAW2"),
                 (0.95, "expoOut", "DRAW2", {"Root": (0, -0.34, 0.04, 0, 31, 0), "Torso": (-6, 10, 0)}), (1.3, "sineInOut", "DRAW2", {"Root": (0, -0.32, 0.02, 0, 30, 0)}),
                 (1.33, "linear", "ZAN"), (1.95, "sineOut", "ZAN", {"Root": (0, -0.98, -0.22, 0, -6, 0)}), (2.1, "sineInOut", "ZAN", {"Root": (0, -0.96, -0.2, 0, -6, 0)}),
                 (2.35, "cubicInOut", "CHIBURI"), (2.47, "cubicIn", "OUT"), (2.55, "linear", "DRAW3"), (2.82, "cubicIn", "NOTO"), (3.55, "sineInOut", "STANCE")],
                ['{ t = 0.2, k = "Fx", n = "Glint" }', '{ t = 0.55, k = "Fx", n = "DrawGlint" }', '{ t = 0.92, k = "Fx", n = "Ching" }', '{ t = 1.12, k = "Fx", n = "DrawGlint" }',
                 '{ t = 1.3, k = "Fx", n = "Vanish" }', '{ t = 1.3, k = "Dash", to = "Far", straight = true, past = 3, d = 0.04, e = "linear" }', '{ t = 1.37, k = "Fx", n = "PeakPath" }',
                 '{ t = 1.58, k = "Hit", i = 1, fx = "RowFlash" }', '{ t = 1.75, k = "Hit", i = 2, fx = "RowFlash" }', '{ t = 2.0, k = "Hit", i = 3, fx = "RowFlash" }',
                 '{ t = 2.01, k = "Stop", d = 0.1 }', '{ t = 2.02, k = "Shake", a = 0.5, d = 0.4 }', '{ t = 2.82, k = "Fx", n = "Click" }', '{ t = 2.9, k = "Dash", to = "Home", d = 0.45 }']))
# 공간의 이해(2026-10-30 다시 — 컷신): 발을 내딛고(발 확대) 달리기 준비(오른손 칼자루, 카메라 오른쪽 등 뒤) → 박차는 순간 사라진다 →
# 보이지 않는 채로 블링크 17번(간격이 점점 짧아짐 — 자리·잔상 자세·검흔은 Fx 가 무작위로) — 카메라는 오른쪽 위로 천천히 올라 적 진영을 비추고
# 점점 빠르게 한 바퀴 돌다 시전자가 제자리에 나타나는 순간 멈춘다 → 베며 나타나 꽂으면 흑백 → 검흔 17개가 하나씩 터지는 17연타
# 2026-10-30 사용자: "매 동작은 항상 베는 동작 … 검을 들고서 있는 동작은 없애" → 나타나는 자세도 칼을 치켜든 OUT 이 아니라 가로베기 끝(SLASHR)
PHANTOMS = 17
# 2026-10-30 사용자: "끌리는 게 못해도 2초는 돼야" — 어깨 너머 카메라가 2초 동안 끌며 멈추도록(Fx.CamShoulder SETTLE) 준비 자세를 H 초 더 버틴다
# (옛: 1.05 에 박차고 1.21 에 사라짐 → 2.35 · 2.51). 그 뒤 시각은 전부 H 만큼 밀린다.
H = 1.3
def h(t):
    return round(t + H, 3)
VANISH, RETURN = h(1.21), h(3.58)
blink_times = [round(h(1.25) + (RETURN - 0.1 - h(1.25)) * (k / PHANTOMS) ** 0.7, 3) for k in range(1, PHANTOMS + 1)]
SHEATHED = round(RETURN + 1.05, 3)  # 딸깍(칼이 다 들어간 순간) — 흑백 · 그 뒤 검흔이 하나씩 터진다
HITS_FROM, HIT_GAP = round(SHEATHED + 0.1, 3), 0.05
LAST_HIT = round(HITS_FROM + HIT_GAP * (PHANTOMS - 1), 3)
spec = [(0, None, "STANCE"), (0.3, "cubicInOut", "FOOTLIFT"), (0.42, "quadIn", "FOOTDOWN"), (0.75, "cubicOut", "SET"),
        # 카메라가 끌며 멈추는 동안 준비 자세로 숨을 고르며 버틴다(조금 가라앉았다가 · 박차기 직전 더 웅크린다)
        (1.6, "sineInOut", "SET", _drift("SET", dy=-0.03, dz=-0.01, dry=-1)), (h(1.05), "sineInOut", "SET", _drift("SET", dy=-0.07)),
        (h(1.13), "expoOut", "RUNOFF"),
        # 박찬 뒤에도 앞으로 달려 나간다(뿌리를 앞으로 밀며 둘째 걸음 → 다시 첫 걸음) — 둘째 걸음 도중(VANISH)에 사라진다
        (h(1.27), "linear", "RUNOFF2"), (h(1.4), "linear", "RUNOFF", {"Root": (0, -0.45, -7.0, 0, 8, 0)}),
        (RETURN - 0.03, "linear", "RUNOFF", {"Root": (0, -0.45, -7.0, 0, 8, 0)}),
        # 2026-10-30 사용자: "블링크 후 납도를 조금 더 천천히" — 벤 끝을 버티다(0.25) 칼을 검집 입에 천천히 맞춰(0.5) 밀어 넣는다(0.3, 딸깍)
        # (옛: 0.14 · 0.18 · 0.18)
        (RETURN, "linear", "SLASHR"), (round(RETURN + 0.25, 3), "sineOut", "SLASHR", _drift("SLASHR")), (round(RETURN + 0.75, 3), "sineInOut", "DRAW3"),
        (SHEATHED, "cubicIn", "NOTO"), (round(RETURN + 2.95, 3), "sineInOut", "STANCE")]
# 흔들림(2026-10-30 사용자: "카메라 셰이크를 추가해줘"): 내딛기 · 박차기 · 사라짐 · 블링크마다 작게 · 베며 나타남 · 딸깍 · (17연타는 감독이
# 타격마다 작게 흔든다) · 마지막 임팩트
events = ['{ t = 0, k = "Fx", n = "CamFoot" }', '{ t = 0.42, k = "Fx", n = "StepDust" }', '{ t = 0.42, k = "Shake", a = 0.18, d = 0.15 }',
          '{ t = %s, k = "Shake", a = 0.25, d = 0.2 }' % h(1.13), '{ t = %s, k = "Shake", a = 0.3, d = 0.25 }' % VANISH, '{ t = 0.45, k = "Fx", n = "CamShoulder", d = %s }' % round(VANISH - 0.45, 3),
          '{ t = 0.8, k = "Fx", n = "Glint" }', '{ t = %s, k = "Fx", n = "Disappear" }' % VANISH,
          '{ t = %s, k = "Fx", n = "CamOrbit", d = %s }' % (VANISH, round(RETURN - VANISH, 3))]
events += ['{ t = %s, k = "Fx", n = "Phantom" }' % t for t in blink_times]
events += ['{ t = %s, k = "Shake", a = 0.08, d = 0.06 }' % t for t in blink_times]
# 나타나는 순간부터 3초 동안 카메라가 맺음 자리로 끌리며 멈춘다(2026-10-30 사용자: "납도할 때 카메라도 3초 끌리게")
events += ['{ t = %s, k = "Fx", n = "Return" }' % RETURN, '{ t = %s, k = "Shake", a = 0.4, d = 0.25 }' % RETURN,
           '{ t = %s, k = "Fx", n = "CamSettle", d = 3 }' % RETURN,
           '{ t = %s, k = "Fx", n = "CutClick" }' % SHEATHED, '{ t = %s, k = "Shake", a = 0.2, d = 0.15 }' % SHEATHED]
events += ['{ t = %s, k = "Hit", i = %d, fx = "MarkHit" }' % (round(HITS_FROM + HIT_GAP * (k - 1), 3), k) for k in range(1, PHANTOMS + 1)]
# 카메라는 CamOrbit 의 맺음 자리에 머물다가 모션이 끝나면(감독이 Shot 을 놓으며) 전투 카메라로 돌아간다 — 2026-10-30 사용자 "공격이 완전히 종료된 후에"
events += ['{ t = %s, k = "Fx", n = "FinalBreak" }' % round(LAST_HIT + 0.04, 3), '{ t = %s, k = "Stop", d = 0.1 }' % round(LAST_HIT + 0.05, 3),
           '{ t = %s, k = "Shake", a = 0.7, d = 0.5 }' % round(LAST_HIT + 0.06, 3)]
S.append(motion("SpaceCut", "공간의 이해([집중력]) 컷신: 발을 들어[중] 내딛고(발 확대)[강] 달리기 준비로 칼자루를 쥐고[중] 버티다[약] 박차고[강] 달려 나가는 걸음 도중에 사라진다[중] → "
                "보이지 않게 블링크 17번(무작위 자리·잔상·검흔, 점점 빨라짐) → 제자리를 가로로 베며 나타나[강] 버티다[약] 천천히 칼을 검집에 맞춰[약] 밀어 넣으면[중] "
                "딸깍 흑백[강] → 검흔 17개가 하나씩 파바바박 터지는 17연타 (고정 피해)",
                round(RETURN + 3.05, 3), spec, events))
S.append(motion("Provoke", "도발 중약강약강약: 엄지로 칼을 한 자 밀어내고 · 턱을 들어 내려다보다 · 왼손 끝을 까딱 · 버티고 · 딸깍 · 숨([집중력])", 1.75,
                [(0, None, "STANCE"), (0.3, "cubicOut", "PEEK"), (0.72, "sineInOut", "PEEK", {"Head": (18, -20, 6)}), (0.8, "expoOut", "FLICK"),
                 (1.05, "sineOut", "FLICK", {"Head": (14, -24, 2)}), (1.12, "expoIn", "NOTO"), (1.75, "sineInOut", "STANCE")],
                ['{ t = 0.3, k = "Fx", n = "Glint" }', '{ t = 0.8, k = "Fx", n = "Taunt" }', '{ t = 1.12, k = "Fx", n = "Click" }']))
S.append(motion("Guard", "가드(스킬) 강약중강약: 검집째 확 들어 · 오래 버티고 · 등으로 되돌려 · 딸깍 · 숨", 1.3,
                [(0, None, "STANCE"), (0.08, "quadOut", "CROUCH"), (0.18, "backOut", "BLOCK"), (0.75, "sineInOut", "BLOCK", {"Root": (0, -0.32, 0.26, 0, 0, 0)}),
                 (0.98, "cubicInOut", "CROUCH"), (1.04, "expoIn", "NOTO"), (1.3, "sineInOut", "STANCE")],
                ['{ t = 0.16, k = "Fx", n = "Block" }', '{ t = 1.04, k = "Fx", n = "Click" }']))
S.append(motion("Meditate", "호흡 약중약: 칼을 꽂은 채 눈을 감고 고개를 숙여 크게 들이쉬고 길게 내쉰다", 2.6,
                [(0, None, "STANCE"), (0.5, "cubicInOut", "BOW"), (1.15, "sineInOut", "BOW", {"Root": (0, -0.24, 0, 0, 24, 0), "Torso": (-4, 0, 0), "Head": (-14, -22, 0)}),
                 (1.85, "sineInOut", "BOW", {"Root": (0, -0.34, 0, 0, 24, 0), "Torso": (-12, 0, 0), "Head": (-24, -22, 0)}), (2.6, "cubicInOut", "STANCE")],
                ['{ t = 0.5, k = "Fx", n = "Meditate" }']))
text += "\n\tSkills = {\n" + "\n".join(S) + "\t},\n}\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("썼다", os.path.normpath(OUT))
print("칼·검집 겹침:", "없음" if not CLIPS else "\n  " + "\n  ".join(CLIPS))
