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
         "PEEK", "FLICK", "LIFT", "STRIKE", "BLOCK", "RECOIL", "STEPBACK", "HANG", "LAND", "BOW", "SLASHR", "SKYRISE", "SIDEKESA", "BACKSWEEP"]
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


def _tween_mode(a, b):
    ma, mb = A.MODE[a], A.MODE[b]
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
    else:
        Q["W"] = _slerp6(Pa["W"], Pb["W"], u)
        A.saya_with_sword(Q)
    return Q


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
                n = max(2, math.ceil((t - t0) / 0.05 - 1e-9))
                da, db = A.DEPTH.get(prev_name, 0.0), A.DEPTH.get(name, 0.0)
                for j in range(1, n):
                    Q = _between(Pa, Pb, _ease(e, j / n), mode, da, db, prev_name, name)
                    out.append((round(t0 + (t - t0) * j / n, 3), "linear", name, Q))
                e = "linear"
        out.append((t, e, name, over))
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


def motion(name, comment, duration, spec, events, extra="", indent=2):
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
	  · 진 발도술 — 천천히 뽑아 왼쪽 아래로 사선베기 → 몹 앞에 다른 베기 자세의 잔상 셋 → 타격마다 하나씩 사라진다.
	  · 발도술의 절정 — 반쯤 뽑다 "챙" 멈춤(빛) → 줄 끝에 이미 벤 자세로 나타남(사용자 그림, ZAN) → 지나간 자리의 검로 →
	    줄 전체를 가르는 칼날이 반짝일 때마다 타격.
	  · 공간의 이해(2026-10-26 다시) — 뽑아 연속 블링크로 적진을 가로질러 줄 끝에 닿으면 칼을 꽂고 → 격자로 반듯하게 썰린 검흔이 반짝이며
	    필드 전체를 벤다. 블링크하는 동안 카메라는 등 뒤에서 따라가고, 꽂을 때 전투 카메라로 돌아와 필드 전체를 보인다.
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
''' + "\n".join("\t" + line for line in keys([(0, None, "STANCE"), (0.16, "expoOut", "THUMB"), (0.85, "sineInOut", "THUMB", {"Head": (4, -30, 0)}), (1.15, "cubicInOut", "THUMB"), (1.22, "expoIn", "NOTO"), (1.75, "sineInOut", "STANCE")]).split("\n")) + '''
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
S.append(motion("FocusCut", "집중 베기([집중력]) — 발도술 셋과 같은 결로 작게: 칼자루를 낚아채[강] 조금 뽑다 챙! 멈추고[강] 숨을 고르다[약] "
                "잔상을 남기고 앞 두 칸을 블링크로 지나 벤 자세로 나타나면 지나간 자리에 작게 기운 검흔이 반짝이며 벤다[강] → 버티고[약] 털고[중] "
                "딸깍[강] → 잔상을 남기고 제자리로[약]", 2.2,
                [(0, None, "STANCE"), (0.12, "expoOut", "CROUCH"), (0.32, "sineInOut", "DRAW1"),
                 (0.36, "expoOut", "DRAW1", {"Root": (0, -0.34, 0.04, 0, 61, 0), "Torso": (-6, 14, 0)}), (0.58, "sineInOut", "DRAW1", {"Root": (0, -0.32, 0.02, 0, 60, 0)}),
                 (0.62, "linear", "DRAWCUT"), (0.95, "sineOut", "DRAWCUT", _drift("DRAWCUT")), (1.2, "cubicInOut", "CHIBURI"), (1.32, "cubicIn", "OUT"),
                 (1.4, "linear", "DRAW3"), (1.6, "cubicIn", "NOTO"), (1.66, "linear", "NOTO"), (2.2, "sineInOut", "STANCE")],
                ['{ t = 0.12, k = "Fx", n = "Glint" }', '{ t = 0.34, k = "Fx", n = "Ching" }', '{ t = 0.59, k = "Fx", n = "Slip", p = "DRAW1" }',
                 '{ t = 0.59, k = "Dash", to = "Target", n = 2, gap = -2.4, d = 0.04, e = "linear" }', '{ t = 0.65, k = "Fx", n = "SmallCuts" }',
                 '{ t = 0.7, k = "Hit", i = 1, fx = "CutHit" }', '{ t = 0.71, k = "Stop", d = 0.06 }', '{ t = 0.71, k = "Shake", a = 0.25, d = 0.18 }',
                 '{ t = 1.6, k = "Fx", n = "Click" }', '{ t = 1.68, k = "Fx", n = "Slip", p = "NOTO" }', '{ t = 1.68, k = "Dash", to = "Home", d = 0.04, e = "linear" }']))
S.append(motion("TrueIaido", "진 발도술: 칼자루를 쥐고[중] 천천히 뽑아[약약약] 빠지는 순간[강] 숨을 고르다[약] 왼쪽 아래로 사선베기[강] → 몹 앞에 잔상 셋 → 타격마다 하나씩 사라진다[중중강] → 털고[중] 딸깍[강] 숨[약]", 3.75,
                [(0, None, "STANCE"), (0.2, "cubicOut", "CROUCH"), (0.6, "sineInOut", "DRAW1"), (0.95, "sineInOut", "DRAW2"), (1.25, "sineIn", "DRAW3"), (1.31, "expoOut", "OUT"),
                 (1.45, "sineOut", "OUT", {"Root": (0, -0.3, 0.05, 0, -18, 0)}), (1.52, "expoOut", "KESA"), (1.98, "sineOut", "KESA", {"Root": (0, -0.54, -0.27, 0, 16, 0)}),
                 (2.55, "sineInOut", "KESA", {"Root": (0, -0.52, -0.25, 0, 15, 0)}), (2.8, "cubicInOut", "CHIBURI"), (2.92, "cubicIn", "OUT"), (3.0, "linear", "DRAW3"),
                 (3.28, "cubicIn", "NOTO"), (3.75, "sineInOut", "STANCE")],
                ['{ t = 0.2, k = "Fx", n = "Glint" }', '{ t = 0.5, k = "Fx", n = "DrawGlint" }', '{ t = 0.9, k = "Fx", n = "DrawGlint" }', '{ t = 1.28, k = "Fx", n = "Release" }',
                 '{ t = 1.3, k = "Trail", on = true }', '{ t = 1.48, k = "Fx", n = "KesaArc" }', '{ t = 1.53, k = "Stop", d = 0.05 }', '{ t = 1.53, k = "Shake", a = 0.25, d = 0.2 }',
                 '{ t = 1.62, k = "Fx", n = "Ghosts", c = 3 }', '{ t = 1.66, k = "Trail", on = false }',
                 '{ t = 2.05, k = "Hit", i = 1, fx = "GhostCut" }', '{ t = 2.27, k = "Hit", i = 2, fx = "GhostCut" }', '{ t = 2.52, k = "Hit", i = 3, fx = "GhostCut" }',
                 '{ t = 2.53, k = "Stop", d = 0.08 }', '{ t = 2.54, k = "Shake", a = 0.35, d = 0.3 }', '{ t = 3.28, k = "Fx", n = "Click" }']))
S.append(motion("IaidoPeak", "발도술의 절정: 칼자루를 쥐고[중] 천천히 뽑다[약약] 챙! 멈춰 날에 빛[강] · 숨을 멈추고[약] · 사라져 줄 끝에 이미 벤 자세로(ZAN) · 줄 전체를 가르는 칼날이 반짝일 때마다 타격[강중강] → 일어나 털고[중] 딸깍[강] 돌아온다[약]", 3.55,
                [(0, None, "STANCE"), (0.2, "cubicOut", "CROUCH"), (0.62, "sineInOut", "DRAW1"), (0.9, "sineInOut", "DRAW2"),
                 (0.95, "expoOut", "DRAW2", {"Root": (0, -0.34, 0.04, 0, 31, 0), "Torso": (-6, 10, 0)}), (1.3, "sineInOut", "DRAW2", {"Root": (0, -0.32, 0.02, 0, 30, 0)}),
                 (1.33, "linear", "ZAN"), (1.95, "sineOut", "ZAN", {"Root": (0, -0.98, -0.22, 0, -6, 0)}), (2.1, "sineInOut", "ZAN", {"Root": (0, -0.96, -0.2, 0, -6, 0)}),
                 (2.35, "cubicInOut", "CHIBURI"), (2.47, "cubicIn", "OUT"), (2.55, "linear", "DRAW3"), (2.82, "cubicIn", "NOTO"), (3.55, "sineInOut", "STANCE")],
                ['{ t = 0.2, k = "Fx", n = "Glint" }', '{ t = 0.55, k = "Fx", n = "DrawGlint" }', '{ t = 0.92, k = "Fx", n = "Ching" }', '{ t = 1.12, k = "Fx", n = "DrawGlint" }',
                 '{ t = 1.3, k = "Fx", n = "Vanish" }', '{ t = 1.3, k = "Dash", to = "Far", straight = true, past = 3, d = 0.04, e = "linear" }', '{ t = 1.37, k = "Fx", n = "PeakPath" }',
                 '{ t = 1.58, k = "Hit", i = 1, fx = "RowFlash" }', '{ t = 1.75, k = "Hit", i = 2, fx = "RowFlash" }', '{ t = 2.0, k = "Hit", i = 3, fx = "RowFlash" }',
                 '{ t = 2.01, k = "Stop", d = 0.1 }', '{ t = 2.02, k = "Shake", a = 0.5, d = 0.4 }', '{ t = 2.82, k = "Fx", n = "Click" }', '{ t = 2.9, k = "Dash", to = "Home", d = 0.45 }']))
# 블링크 다섯: 남은 길의 1/5 · 1/4 · 1/3 · 1/2 · 전부 → 같은 걸음으로 줄 끝까지. 간격이 점점 짧아진다(가속).
# 자세는 앞 자세와 크게 다르게(2026-10-26 사용자): 서서 치켜듦 → 바닥까지 낮은 런지 → 공중 올려베기 → 오른쪽으로 틀어 낮은 사선 →
# 뒤돌아 휩쓸기 → 앞을 보고 강한 가로베기(줄 끝)
# 끝의 수 = 나타난 자세로 베어 들어온 초승달 검로의 크기(°, Fx Blink — 칼등 쪽에서 지금 칼 방향까지)
BLINKS = [(0.8, "OUT", "ZAN", 0.2, 120), (1.08, "ZAN", "SKYRISE", 0.25, 160), (1.32, "SKYRISE", "SIDEKESA", 0.333, 150),
          (1.52, "SIDEKESA", "BACKSWEEP", 0.5, 180), (1.69, "BACKSWEEP", "SLASHR", 1, 160)]
NEXT = [1.06, 1.3, 1.5, 1.67, 1.98]
spec = [(0, None, "STANCE"), (0.14, "expoOut", "CROUCH"), (0.36, "sineInOut", "DRAW1"), (0.56, "sineIn", "DRAW3"), (0.61, "expoOut", "OUT"),
        (0.78, "sineOut", "OUT", _drift("OUT"))]
events = ['{ t = 0, k = "Fx", n = "CamFollow" }', '{ t = 0.14, k = "Fx", n = "Glint" }', '{ t = 0.38, k = "Fx", n = "DrawGlint" }', '{ t = 0.59, k = "Fx", n = "Release" }']
for (t, before, after, frac, sweep), hold in zip(BLINKS, NEXT):
    # 블링크한 한순간 자세가 바뀐다(키 사이 0.03초) — 그 뒤엔 여린 박으로 버틴다
    spec.append((round(t + 0.03, 3), "linear", after))
    # 공중 자세는 버티는 동안 조금 떨어진다
    spec.append((hold, "sineOut", after, _drift(after, dy=-0.25) if after == "SKYRISE" else _drift(after)))
    events.append('{ t = %s, k = "Fx", n = "Blink", p = "%s", sweep = %d }' % (t, before, sweep))
    events.append('{ t = %s, k = "Dash", to = "Far", straight = true, frac = %s, past = 2, d = 0.03, e = "linear" }' % (t, frac))
spec += [(2.18, "cubicInOut", "OUT"), (2.26, "linear", "DRAW3"), (2.62, "sineIn", "DRAW1"), (2.72, "expoIn", "NOTO"), (4.3, "sineInOut", "STANCE")]
events += ['{ t = 1.73, k = "Stop", d = 0.05 }', '{ t = 1.73, k = "Shake", a = 0.3, d = 0.2 }', '{ t = 2.4, k = "Fx", n = "CamFree" }',
           '{ t = 2.72, k = "Fx", n = "CutClick" }', '{ t = 2.8, k = "Fx", n = "GridCut" }', '{ t = 3.25, k = "Fx", n = "GridFlash" }',
           '{ t = 3.27, k = "Hit", i = 1, fx = "GridHit" }', '{ t = 3.28, k = "Stop", d = 0.12 }', '{ t = 3.29, k = "Shake", a = 0.7, d = 0.5 }',
           '{ t = 3.6, k = "Dash", to = "Home", d = 0.5, e = "sineInOut" }']
S.append(motion("SpaceCut", "공간의 이해([집중력]): 칼자루를 낚아채[강] 뽑아[약중] 빠짐[강] → 블링크마다 높이·몸 방향·칼 방향이 크게 바뀌며 다섯 번으로 적진을 가로질러(간격이 점점 짧아짐) "
                "줄 끝에서 거의 가로로 멈춰 서고[강] → 천천히 꽂다[중약] 딸깍[강] → 격자로 반듯하게 썰린 검흔이 반짝이며 필드 전체를 벤다[강] (고정 피해)", 4.4, spec, events))
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
