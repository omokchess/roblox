"""조율자 모션 파일(src/shared/Combat/Motions/Attuner.luau)을 통째로 만든다(2026-10-25, 조건부 획득 직업).

성격: 별을 지휘하는 천문가 — 땅에 서서 지휘자처럼 손짓하고, 옆에서 북두칠성 꼴로 천천히 도는 일곱 별(SevenStars, 손에 쥐지 않음)이
손짓을 따라 빛을 쏜다. 무기를 쥐지 않으므로 W/O 가 없다 — 가리키는 팔만 posecalc.point_arm 으로 구한다
(팔 축이 적 가슴·별을 향하게). 자세 값은 이 파일이 출처다(손으로 고치지 말고 여기서 고쳐 다시 뽑을 것).
쓰는 법: python tools/combat/design/attuner_gen.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import f, point_arm  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "src", "shared", "Combat", "Motions", "Attuner.luau")

ENEMY = (0, 0.4, -10)  # 적 가슴(캐릭터 앞 -Z)
ENEMY_LOW = (0, -1.5, -9)
KEYS = ["Root", "Torso", "Head", "RArm", "LArm", "RLeg", "LLeg"]


def P(**kw):
    base = {
        "Root": (0, 0, 0, 0, -18, 0),
        "Torso": (3, 0, 0),
        "Head": (6, 8, 0),
        "RArm": (62, 12, 18),
        "LArm": (30, -22, -12),
        "RLeg": (-3, 0, -3),
        "LLeg": (5, 0, 4),
    }
    base.update(kw)
    return base


def pointing(target, **kw):
    q = P(**kw)
    q["RArm"] = point_arm(q, "R", target)
    return q


# 떠 있는 높이(스터드) — pose() 가 LAND 말고 모든 자세 뿌리에 더한다(공격·피격 때도 떠 있다)
HOVER = 0.7
POSES = {}
NOTE = {}


def pose(name, note, q):
    # 떠 있는 직업(2026-10-30): 내려놓여 디딜 때(LAND) 말고는 뿌리를 HOVER 만큼 띄운다
    if name != "LAND":
        r = list(q["Root"])
        r[1] = round(r[1] + HOVER, 3)
        q = dict(q, Root=tuple(r))
    POSES[name] = q
    NOTE[name] = note


# 대기(2026-10-30 다시 — 사용자: "너가 생각했을 때 가장 예쁘다고 생각되는 모션으로 해봐. 공중에 뜬 상태에 별이 오른손 주위에 떠있어야
# 하는 건 고정이야. 대신 회전은 하면 안 돼") → 떠 있는 천문가:
#   · 발끝을 내린 채 HOVER 만큼 떠서 숨에 맞춰 천천히 오르내린다(대기 숨 Rise). 오른다리는 곧게 조금 뒤로, 왼다리는 조금 앞·안쪽으로(엇갈린 발끝).
#   · 오른손은 가슴 높이에서 앞 오른쪽으로 내밀어 손 위에 뜬 북두칠성(별은 오른손을 따라다닌다 — CombatWeapons)을 받쳐 들고,
#     고개를 숙여 그 별을 내려다본다. 왼팔은 힘을 빼 조금 뒤·바깥으로 흘려 오른팔과 균형을 맞춘다. 상체는 살짝 젖히고 별 쪽으로 튼다.
# 관절 부호(posecalc 로 잰 값): 팔·다리 x+ = 앞, 왼팔·왼다리 z− = 바깥, 오른다리 z+ = 바깥, 머리 x+ = 위 · y− = 오른쪽, 몸통 x+ = 젖힘.
STANCE_BODY = dict(Root=(0, 0, 0, 0, -18, 0), Torso=(6, -8, 0), Head=(-10, -26, 4), LArm=(-14, 0, -22), RLeg=(-6, 0, 3), LLeg=(10, 0, 6))
STANCE_HAND = (2.6, 0.6, -1.8)  # 오른손 끝이 향하는 곳(앞 오른쪽 가슴 높이 — 별을 받쳐 든다)
pose("STANCE", "대기 — 발끝을 내린 채 떠서, 앞 오른쪽으로 내민 오른손 위에 뜬 북두칠성을 고개 숙여 내려다본다. 왼팔은 힘을 빼 뒤로 흘린다",
     pointing(STANCE_HAND, **STANCE_BODY))
# 버릇: 별을 받친 손을 천천히 들어 올리면 별이 국자를 따라 차례로 반짝인다(돌지 않는다)
pose("OFFER", "버릇 — 별을 받친 오른손을 눈높이로 들어 올리고 고개를 들어 별을 본다(별이 손을 따라 오르며 차례로 반짝인다)",
     pointing((2.4, 1.7, -1.6), **dict(STANCE_BODY, Torso=(10, -10, 0), Head=(8, -24, 2))))

pose("READY", "가리키기 전 — 오른손을 귀 옆으로 끌어올려 겨눔을 모은다", P(Root=(0, 0, 0, 0, -26, 0), Torso=(6, -4, 0), Head=(4, 22, 0), RArm=(150, 18, 40), LArm=(40, -20, -20)))
pose("POINT", "메그레즈: 팔을 쭉 뻗어 적을 가리킨다(팔 축이 적 가슴 쪽), 왼팔은 뒤로 흘려 균형",
     pointing(ENEMY, Root=(0, -0.05, 0, 0, -30, 0), Torso=(-2, -8, 0), Head=(0, 26, 0), LArm=(-12, 0, -26), RLeg=(-10, 0, -4), LLeg=(12, 0, 4)))
pose("FLING_UP", "메라크 1 — 오른팔을 머리 뒤로 높이 젖혀 별을 집어 든다", P(Root=(0, 0.05, 0, 0, -22, 0), Torso=(12, 6, 0), Head=(18, 14, 0), RArm=(168, 0, 26), LArm=(60, -10, -24), RLeg=(4, 0, -3), LLeg=(-6, 0, 4)))
pose("FLING_DOWN", "메라크 2 — 내딛으며 별을 적의 줄 끝까지 던지듯 팔을 앞 아래로 뿌린다",
     pointing(ENEMY_LOW, Root=(0, -0.2, -0.2, 0, -30, 0), Torso=(-12, -10, 0), Head=(-6, 26, 0), LArm=(-20, 0, -30), RLeg=(-28, 0, -4), LLeg=(22, 0, 4)))
pose("RAISE", "알리오스 1 — 두 팔을 하늘로 V 자로 들어 별빛을 부른다", P(Root=(0, 0.08, 0, 0, -18, 0), Torso=(12, 0, 0), Head=(26, 8, 0), RArm=(166, 0, 24), LArm=(166, 0, -24), RLeg=(-2, 0, -4), LLeg=(2, 0, 4)))
pose("CAST", "알리오스 2 — 두 팔을 적 진영 위로 내리 뻗어 별비를 쏟는다", P(Root=(0, -0.12, -0.1, 0, -22, 0), Torso=(-8, -4, 0), Head=(-4, 20, 0), RArm=(96, 26, 22), LArm=(96, -26, -22), RLeg=(-16, 0, -4), LLeg=(14, 0, 4)))
pose("OPEN", "셉텐트리오네스 1 — 두 팔을 활짝 펴고 발끝으로 떠오르듯 선다(별 일곱이 적 위로 날아간다)", P(Root=(0, 0.18, 0, 0, -18, 0), Torso=(14, 0, 0), Head=(22, 10, 0), RArm=(112, -40, 72), LArm=(112, 40, -72), RLeg=(-6, 0, -6), LLeg=(-2, 0, 6)))
pose("CLOSE", "셉텐트리오네스 2 — 두 손을 앞으로 모아 움켜쥔다(별자리가 한 점으로 무너진다)", P(Root=(0, -0.08, -0.1, 0, -24, 0), Torso=(-10, -6, 0), Head=(-2, 22, 0), RArm=(92, 24, 4), LArm=(92, -24, -4), RLeg=(-18, 0, -4), LLeg=(16, 0, 4)))
pose("SHIELD", "방어 — 왼손바닥을 앞으로 내밀어 별 셋을 방패로, 오른손은 뒤로 감싼다", P(Root=(0, -0.06, 0.25, 0, -14, 0), Torso=(-4, 4, 0), Head=(-2, 14, 0), RArm=(30, 20, 30), LArm=(86, -14, 0), RLeg=(-8, 0, -3), LLeg=(10, 0, 3)))
pose("RECOIL", "피격 — 가슴을 맞아 상체가 뒤로 젖혀지고 두 팔이 흩어진다", P(Root=(0, -0.08, 0.55, 0, -18, 0), Torso=(18, 6, 0), Head=(22, 8, 0), RArm=(40, 0, 50), LArm=(40, 0, -50), RLeg=(10, 0, -4), LLeg=(-6, 0, 4)))
pose("SIDESTEP", "회피 — 별빛처럼 옆으로 미끄러져 비켜선다(몸을 낮추고 왼쪽으로)", P(Root=(-1.7, -0.25, 0.2, 0, -18, 6), Torso=(-6, 0, -8), Head=(0, 12, 6), RArm=(20, 0, 46), LArm=(40, 0, -34), RLeg=(-4, 0, 12), LLeg=(-10, 0, -4)))
pose("DANGLE", "들림 — 별을 올려다보며 느슨히 매달린다(버둥대지 않음)", P(Root=(0, 0.1, 0, 4, -18, 2), Torso=(6, 0, 0), Head=(24, 12, 0), RArm=(24, 0, 22), LArm=(24, 0, -22), RLeg=(-6, 0, 3), LLeg=(4, 0, -3)))
pose("LAND", "내려놓임 — 무릎을 살짝 굽혀 사뿐히 내려선다", P(Root=(0, -0.35, 0, 0, -18, 0), Torso=(-10, 0, 0), Head=(-6, 8, 0), RArm=(40, 10, 34), LArm=(40, -10, -34), RLeg=(22, 0, -4), LLeg=(-12, 0, 4)))
pose("PRAY", "호흡 — 두 손을 가슴 앞에 모으고 고개를 들어 별을 본다", P(Torso=(6, 0, 0), Head=(20, 6, 0), RArm=(56, 28, -14), LArm=(56, -28, 14)))


def K(t, e, name, over=None):
    es = "nil" if e is None else '"%s"' % e
    if over:
        body = ", ".join("%s = %s" % (k, f(v)) for k, v in over.items())
        return "\t\t\t\tK(%s, %s, %s, { %s })," % (t, es, name, body)
    return "\t\t\t\tK(%s, %s, %s)," % (t, es, name)


def motion(name, comment, duration, keys, events, extra="", indent=2):
    tab = "\t" * indent
    body = "\n".join(K(*k) for k in keys)
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
	조율자 — 북두의 일곱 별을 지휘하는 천문가. (2026-10-25, 조건부 획득 직업)

	성격: 고요하고 단정함. 땅에 서서 지휘자처럼 손짓하면, 옆(오른쪽 뒤)에서 북두칠성 꼴로 천천히 도는 일곱 별이 따라 움직인다(빛나는 구 — [칠성]을 준 스킬·패시브 이름의 별이 켜지고, 켜진 이웃 별끼리 선으로 이어진다).
	  메그레즈 = 적을 가리키면 그 별이 빛줄기를 쏜다(열 전체) · 메라크 = 별을 집어 적의 줄 끝까지 던진다(행 전체)
	  알리오스 = 두 팔을 하늘로 들었다 내리면 별비가 진형 전체에 쏟아진다
	  셉텐트리오네스 = 두 팔을 펴면 별 일곱이 적 위로 날아가 큰 별자리를 펼치고(Orbs Sky), 두 손을 모아 쥐면 한 점으로
	                   무너져 핵융합처럼 터진다.
	무기 종류: Stars (WeaponDefinitions.SevenStars, Hand = Float). 쥐는 것이 없다 — 켜진 별(칠성)은 CombatWeapons:SetLit.
	수치: tools/combat/design/attuner_gen.py 가 이 파일을 만든다(가리키는 팔은 posecalc.point_arm). 손으로 고치지 말 것.
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

'''
order = ["STANCE", "OFFER", "READY", "POINT", "FLING_UP", "FLING_DOWN", "RAISE", "CAST", "OPEN", "CLOSE", "SHIELD", "RECOIL", "SIDESTEP", "DANGLE", "LAND", "PRAY"]
lines = []
for name in order:
    q = POSES[name]
    lines.append("-- %s\nlocal %s = { %s }" % (NOTE[name], name, ", ".join("%s = %s" % (k, f(q[k])) for k in KEYS)))
text = head + "\n".join(lines) + "\n\nreturn {\n\tStance = STANCE,\n\n"
text += '''	-- 대기: 떠서 숨 쉰다(Kit.Breath, Smooth) — 들숨에 몸이 천천히 떠오르고(Rise 0.14) 별을 받친 손이 살짝 오르며, 내쉬며 고개가 별 쪽으로
	Idle = Kit.Breath(STANCE, {
		Duration = 4.4,
		Chest = 2.2,
		Rise = 0.14,
		Head = -1.2,
		In = { RArm = ''' + f(pointing((2.6, 0.78, -1.8), **STANCE_BODY)["RArm"]) + ''' },
		Mid = { Head = { -8, -22, 4 } },
	}),

	-- 버릇(가끔): 별을 받친 손을 천천히 눈높이로 들어 올리면[약중] 별이 국자를 따라 손잡이 끝부터 차례로 반짝이고(StarTwinkle) ·
	-- 잠깐 바라보다[약] · 손을 내려 받쳐 든다[중]. 별은 손을 따라 오르내릴 뿐 돌지 않는다
	Fidgets = {
		{
			Duration = 2.4,
			BlendIn = 0.3,
			BlendOut = 0.4,
			Keys = {
''' + "\n".join("\t" + K(*k) for k in [(0, None, "STANCE"), (0.7, "sineInOut", "OFFER"), (1.5, "sineInOut", "OFFER", {"Head": (12, -22, 2)}), (2.4, "cubicInOut", "STANCE")]) + '''
			},
			Events = {
				{ t = 0.75, k = "Fx", n = "StarTwinkle" },
			},
		},
	},

'''
text += motion("Held", "들림: 별을 올려다보며 느슨히 매달려 천천히 흔들린다. 별은 머리 위 작은 원으로", 3.0,
               [(0, None, "DANGLE"), (1.5, None, "DANGLE", {"Root": (0, 0.14, 0, -4, -14, -2), "Head": (20, 16, 0)})],
               ['{ t = 0, k = "Orbs", mode = "Crown" }'], "\t\tLoop = true,\n\t\tSmooth = true,\n", 1)
text += "\n" + motion("Drop", "내려놓임: 사뿐히 내려서면 발밑에 별빛 고리가 퍼지고 별이 제자리(별자리)로 돌아간다", 1.0,
                      [(0, None, "DANGLE"), (0.14, "quadIn", "LAND"), (0.55, "sineOut", "LAND", {"Root": (0, -0.2, 0, 0, -18, 0)}), (1.0, "sineInOut", "STANCE")],
                      ['{ t = 0.14, k = "Fx", n = "Touchdown" }', '{ t = 0.3, k = "Orbs", mode = "Orbit" }'], "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Hit", "피격: 가슴을 맞아 젖혀지고 별이 흩어졌다가 제자리로", 0.75,
                      [(0, None, "STANCE"), (0.06, "expoOut", "RECOIL"), (0.3, "sineOut", "RECOIL", {"Root": (0, -0.05, 0.5, 0, -18, 0), "Torso": (12, 4, 0)}), (0.75, "sineInOut", "STANCE")],
                      ['{ t = 0.02, k = "Orbs", mode = "Spread" }', '{ t = 0.5, k = "Orbs", mode = "Orbit" }'], "\t\tBlendIn = 0.02,\n", 1)
text += "\n" + motion("Guard", "방어: 왼손바닥을 내밀면 별이 앞에 세모 방패를 친다", 0.8,
                      [(0, None, "STANCE"), (0.08, "expoOut", "SHIELD"), (0.24, "sineOut", "SHIELD", {"Root": (0, -0.08, 0.35, 0, -14, 0)}), (0.8, "sineInOut", "STANCE")],
                      ['{ t = 0, k = "Orbs", mode = "Shield" }', '{ t = 0.1, k = "Fx", n = "StarShield" }', '{ t = 0.6, k = "Orbs", mode = "Orbit" }'], "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Dodge", "회피: 몸을 낮춰 별빛처럼 옆으로 미끄러지고 잔상이 남는다", 0.75,
                      [(0, None, "STANCE"), (0.1, "expoOut", "SIDESTEP"), (0.42, "sineOut", "SIDESTEP", {"Root": (-1.8, -0.2, 0.2, 0, -18, 4)}), (0.75, "sineInOut", "STANCE")],
                      ['{ t = 0.08, k = "Fx", n = "StarBlink" }'], "\t\tBlendIn = 0.02,\n", 1)

skills = []
skills.append(motion("Megrez", "메그레즈: 오른손을 귀 옆으로 끌어올렸다가 쭉 뻗어 적을 가리키면 — 메그레즈가 빛줄기를 쏘아 그 열을 위아래로 훑는다", 1.5,
                     [(0, None, "STANCE"), (0.28, "cubicOut", "READY"), (0.5, "expoOut", "POINT"), (0.95, "sineOut", "POINT", {"Root": (0, -0.08, 0.1, 0, -30, 0)}), (1.5, "cubicInOut", "STANCE")],
                     ['{ t = 0.3, k = "Fx", n = "MegrezCharge" }', '{ t = 0.52, k = "Fx", n = "MegrezBeam" }', '{ t = 0.62, k = "Hit", i = 1, fx = "StarHit" }',
                      '{ t = 0.63, k = "Stop", d = 0.06 }', '{ t = 0.64, k = "Shake", a = 0.25, d = 0.25 }']))
skills.append(motion("Merak", "메라크: 팔을 머리 뒤로 젖혀 별을 집어 들고 — 내딛으며 적의 줄 끝까지 뿌리면 메라크가 그 줄을 꿰뚫고 달린다", 1.6,
                     [(0, None, "STANCE"), (0.32, "cubicOut", "FLING_UP"), (0.52, "expoOut", "FLING_DOWN"), (1.0, "sineOut", "FLING_DOWN", {"Root": (0, -0.15, -0.1, 0, -30, 0)}), (1.6, "cubicInOut", "STANCE")],
                     ['{ t = 0.3, k = "Fx", n = "MerakSpark" }', '{ t = 0.52, k = "Fx", n = "MerakStreak" }', '{ t = 0.66, k = "Hit", i = 1, fx = "StarHit" }',
                      '{ t = 0.67, k = "Shake", a = 0.3, d = 0.3 }']))
skills.append(motion("Alioth", "알리오스: 두 팔을 하늘로 들어 알리오스를 부르고 — 적 진영 위로 내리 뻗으면 별비가 진형 전체에 쏟아진다", 2.0,
                     [(0, None, "STANCE"), (0.45, "cubicOut", "RAISE"), (0.8, "sineInOut", "RAISE", {"Root": (0, 0.12, 0, 0, -18, 0), "Head": (30, 8, 0)}), (0.95, "expoOut", "CAST"), (1.5, "sineOut", "CAST", {"Root": (0, -0.16, -0.1, 0, -22, 0)}), (2.0, "cubicInOut", "STANCE")],
                     ['{ t = 0.45, k = "Fx", n = "AliothCall" }', '{ t = 0.95, k = "Fx", n = "AliothRain" }', '{ t = 1.2, k = "Hit", i = 1, fx = "RainHit" }',
                      '{ t = 1.22, k = "Shake", a = 0.4, d = 0.4 }']))
skills.append(motion("Septentriones", "셉텐트리오네스: 두 팔을 활짝 펴면 별 일곱이 적 위로 날아가 큰 북두칠성을 펼치고 별끼리 빛줄이 이어진다 — 두 손을 모아 쥐면 별자리가 한 점으로 무너져 핵융합처럼 터진다", 3.0,
                     [(0, None, "STANCE"), (0.5, "cubicOut", "OPEN"), (1.35, "sineInOut", "OPEN", {"Root": (0, 0.24, 0, 0, -18, 0), "Head": (26, 10, 0)}), (1.6, "expoOut", "CLOSE"),
                      (2.3, "sineOut", "CLOSE", {"Root": (0, -0.14, -0.1, 0, -24, 0)}), (3.0, "cubicInOut", "STANCE")],
                     ['{ t = 0.45, k = "Orbs", mode = "Sky", at = "Enemies" }', '{ t = 0.5, k = "Fx", n = "SeptRise" }', '{ t = 1.05, k = "Fx", n = "SeptLines" }',
                      '{ t = 1.6, k = "Orbs", mode = "Gather", at = "Enemies" }', '{ t = 1.62, k = "Fx", n = "SeptCollapse" }', '{ t = 1.9, k = "Hit", i = 1, fx = "Fusion" }',
                      '{ t = 1.91, k = "Stop", d = 0.14 }', '{ t = 1.92, k = "Shake", a = 0.9, d = 0.6 }', '{ t = 2.4, k = "Orbs", mode = "Orbit" }']))
skills.append(motion("Guard", "가드(스킬): 별 방패를 오래 세운다", 1.1,
                     [(0, None, "STANCE"), (0.18, "backOut", "SHIELD"), (0.8, "sineInOut", "SHIELD", {"Root": (0, -0.08, 0.3, 0, -14, 0)}), (1.1, "sineInOut", "STANCE")],
                     ['{ t = 0, k = "Orbs", mode = "Shield" }', '{ t = 0.18, k = "Fx", n = "StarShield" }', '{ t = 0.9, k = "Orbs", mode = "Orbit" }']))
skills.append(motion("Meditate", "호흡: 두 손을 가슴 앞에 모으고 별을 올려다보며 크게 들이쉬고 길게 내쉰다 — 별은 머리 위 원으로 돈다", 2.6,
                     [(0, None, "STANCE"), (0.45, "cubicInOut", "PRAY"), (1.1, "sineInOut", "PRAY", {"Root": (0, 0.06, 0, 0, -18, 0), "Torso": (10, 0, 0), "Head": (26, 6, 0)}),
                      (1.8, "sineInOut", "PRAY", {"Root": (0, -0.06, 0, 0, -18, 0), "Torso": (0, 0, 0), "Head": (12, 6, 0)}), (2.6, "cubicInOut", "STANCE")],
                     ['{ t = 0.2, k = "Orbs", mode = "Crown" }', '{ t = 0.5, k = "Fx", n = "Meditate" }', '{ t = 2.3, k = "Orbs", mode = "Orbit" }']))
text += "\n\tSkills = {\n" + "\n".join(skills) + "\t},\n}\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("썼다", os.path.normpath(OUT))
for name in ("STANCE", "OFFER", "POINT", "FLING_DOWN"):
    print(name, "RArm", POSES[name]["RArm"])
