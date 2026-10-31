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

# ── 2026-10-31 스킬 넷(사용자 말): 염동력 — 손짓으로 별을 부린다 ──
def gesture(target, **kw):
    return pointing(target, **dict(STANCE_BODY, **kw))


pose("MEG_L", "메그레즈 1 — 꺼낸 별을 손끝에 띄운 채 오른팔을 몸 앞으로 감아 왼쪽으로 가져간다(몸도 왼쪽으로 틂)",
     gesture((-2.4, 0.9, -1.8), Root=(0, 0, 0, 0, -6, 0), Torso=(4, 26, 0), Head=(2, 16, 0)))
pose("MEG_R", "메그레즈 2 — 오른쪽으로 확 뿌려 별을 대상 열로 날린다(팔이 앞 오른쪽으로 쭉, 고개는 적 쪽)",
     gesture((3.6, 0.8, -2.6), Root=(0, 0, -0.1, 0, -24, 0), Torso=(0, -14, 0), Head=(-2, 18, 0)))
pose("MER_LOW", "메라크 1 — 꺼낸 별을 왼쪽 아래로 끌어내린다(오른손이 왼 무릎 앞, 몸을 왼쪽으로 숙여 튼다)",
     gesture((-1.6, -1.2, -1.4), Torso=(-8, 20, 0), Head=(-12, 18, 0)))
pose("MER_UP", "메라크 2 — 팔을 오른쪽 위로 휘둘러 별을 내 행으로 돌진시킨다(몸을 펴 젖히고 오른쪽으로 튼다)",
     gesture((3.0, 3.2, -2.0), Root=(0, 0.06, 0, 0, -24, 0), Torso=(10, -14, 0), Head=(12, 4, 0)))
pose("AL_READY", "알리오스 0 — 꺼낸 별을 손끝에 띄워 적 진영 쪽으로 들어 올린다", gesture((2.4, 1.6, -2.4), Torso=(4, -6, 0), Head=(0, 16, 0)))
pose("AL_A", "알리오스 손짓 A — 왼 위로 크게 그어 올린다", gesture((-1.2, 3.0, -2.2), Torso=(6, 16, 0), Head=(10, 18, 0)))
pose("AL_B", "알리오스 손짓 B — 오른 아래로 내리긋는다", gesture((3.0, -1.0, -1.6), Torso=(-6, -14, 0), Head=(-8, 10, 0)))
pose("AL_C", "알리오스 손짓 C — 앞 위로 찌르듯 뻗는다", gesture((0.8, 2.4, -3.2), Torso=(6, 0, 0), Head=(8, 16, 0)))
pose("AL_D", "알리오스 손짓 D — 오른쪽으로 가로 휘두른다", gesture((3.6, 0.8, -0.6), Torso=(2, -16, 0), Head=(0, 8, 0)))
pose("SEPT_LOW", "셉텐트리오네스 1 — 오른손을 왼 허리로 끌어 모은다(별자리가 손을 따라 허리춤으로, 몸을 왼쪽으로 숙여 튼다)",
     gesture((-1.0, -0.6, -0.6), Torso=(-6, 22, 0), Head=(-14, 14, 0)))
pose("SEPT_UP", "셉텐트리오네스 2 — 오른팔을 하늘 높이 치켜든다(별 일곱이 하늘로 — 몸을 젖히고 올려다본다)",
     gesture((1.4, 5.0, -2.4), Root=(0, 0.1, 0, 0, -18, 0), Torso=(12, -4, 0), Head=(30, 4, 0)))
pose("SEPT_DOWN", "셉텐트리오네스 3 — 치켜든 팔을 적 진영으로 내리친다(별자리가 진형을 강타)",
     gesture((2.4, -1.2, -3.4), Root=(0, -0.08, -0.1, 0, -22, 0), Torso=(-10, -8, 0), Head=(-10, 14, 0)))
pose("SHIELD", "방어 — 왼손바닥을 앞으로 내밀어 별 셋을 방패로, 오른손은 뒤로 감싼다", P(Root=(0, -0.06, 0.25, 0, -14, 0), Torso=(-4, 4, 0), Head=(-2, 14, 0), RArm=(30, 20, 30), LArm=(86, -14, 0), RLeg=(-8, 0, -3), LLeg=(10, 0, 3)))
pose("RECOIL", "피격 — 가슴을 맞아 상체가 뒤로 젖혀지고 두 팔이 흩어진다", P(Root=(0, -0.08, 0.55, 0, -18, 0), Torso=(18, 6, 0), Head=(22, 8, 0), RArm=(40, 0, 50), LArm=(40, 0, -50), RLeg=(10, 0, -4), LLeg=(-6, 0, 4)))
pose("SIDESTEP", "회피 — 별빛처럼 옆으로 미끄러져 비켜선다(몸을 낮추고 왼쪽으로)", P(Root=(-1.7, -0.25, 0.2, 0, -18, 6), Torso=(-6, 0, -8), Head=(0, 12, 6), RArm=(20, 0, 46), LArm=(40, 0, -34), RLeg=(-4, 0, 12), LLeg=(-10, 0, -4)))
pose("DANGLE", "들림 — 별을 올려다보며 느슨히 매달린다(버둥대지 않음)", P(Root=(0, 0.1, 0, 4, -18, 2), Torso=(6, 0, 0), Head=(24, 12, 0), RArm=(24, 0, 22), LArm=(24, 0, -22), RLeg=(-6, 0, 3), LLeg=(4, 0, -3)))
pose("LAND", "내려놓임 — 무릎을 살짝 굽혀 사뿐히 내려선다", P(Root=(0, -0.35, 0, 0, -18, 0), Torso=(-10, 0, 0), Head=(-6, 8, 0), RArm=(40, 10, 34), LArm=(40, -10, -34), RLeg=(22, 0, -4), LLeg=(-12, 0, 4)))
pose("PRAY", "호흡 — 두 손을 가슴 앞에 모으고 고개를 들어 별을 본다", P(Torso=(6, 0, 0), Head=(20, 6, 0), RArm=(56, 28, -14), LArm=(56, -28, 14)))


def K(t, e, name, over=None):
    if over and "Root" in over and name != "LAND":
        r = list(over["Root"])
        r[1] = round(r[1] + HOVER, 3)
        over = dict(over, Root=tuple(r))
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
order = ["STANCE", "OFFER", "MEG_L", "MEG_R", "MER_LOW", "MER_UP", "AL_READY", "AL_A", "AL_B", "AL_C", "AL_D", "SEPT_LOW", "SEPT_UP", "SEPT_DOWN", "SHIELD", "RECOIL", "SIDESTEP", "DANGLE", "LAND", "PRAY"]
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
# 2026-10-31 사용자: "전체적인 느낌은 염동력으로 움직인다는 느낌. 별을 하나 꺼낸 후에 다른 별들은 비활성화 되면서 오른쪽 아래(허리춤 쯤)로 빠지도록."
# 별 꺼내기 = Orbs Pick(star) · 그 별을 날리는 것 = Fx(ctx.Weapons:Drive) · 끝나면 Orbs Orbit 으로 별자리가 손 위로 돌아온다.
skills.append(motion("Megrez", "메그레즈: 손 위 별무리에서 메그레즈를 꺼내(나머지는 허리춤으로)[약] 팔을 왼쪽으로 가져갔다가[중] 오른쪽으로 확 뿌리면[강] "
                     "별이 대상 열로 날아가 열을 가로질러 훑고 손끝으로 돌아온다", 1.95,
                     [(0, None, "STANCE"), (0.4, "cubicInOut", "MEG_L"), (0.52, "sineInOut", "MEG_L", {"Head": (0, 20, 0)}), (0.62, "expoOut", "MEG_R"),
                      (1.0, "sineOut", "MEG_R", {"Root": (0, -0.04, -0.14, 0, -26, 0)}), (1.85, "cubicInOut", "STANCE")],
                     ['{ t = 0.08, k = "Orbs", mode = "Pick", star = 1 }', '{ t = 0.1, k = "Fx", n = "TeleGrab", star = 1 }', '{ t = 0.6, k = "Fx", n = "MegrezFling" }',
                      '{ t = 0.78, k = "Hit", i = 1, fx = "StarHit" }', '{ t = 0.79, k = "Stop", d = 0.05 }', '{ t = 0.8, k = "Shake", a = 0.3, d = 0.25 }',
                      '{ t = 1.45, k = "Orbs", mode = "Orbit" }']))
skills.append(motion("Merak", "메라크: 메라크를 꺼내[약] 왼쪽 아래로 끌어내렸다가[중] 팔을 오른쪽 위로 휘두르면[강] 별이 내 행을 꿰뚫고 달리며 흰 선을 남기고(1타), "
                     "그 선이 네 번 부분부분 터지고 다섯 번째에 통째로 터진다(10 · 2 · 2 · 2 · 2 · 4)", 2.4,
                     [(0, None, "STANCE"), (0.42, "cubicInOut", "MER_LOW"), (0.6, "sineInOut", "MER_LOW", {"Head": (-14, 22, 0)}), (0.72, "expoOut", "MER_UP"),
                      (1.3, "sineOut", "MER_UP", {"Root": (0, 0.1, 0, 0, -26, 0)}), (2.3, "cubicInOut", "STANCE")],
                     ['{ t = 0.08, k = "Orbs", mode = "Pick", star = 2 }', '{ t = 0.1, k = "Fx", n = "TeleGrab", star = 2 }', '{ t = 0.7, k = "Fx", n = "MerakDash" }',
                      '{ t = 0.85, k = "Hit", i = 1, fx = "MerakPass" }', '{ t = 0.86, k = "Shake", a = 0.3, d = 0.25 }']
                     + ['{ t = %s, k = "Hit", i = %d, fx = "MerakBurst" }' % (t, i) for i, t in ((2, 1.2), (3, 1.36), (4, 1.52), (5, 1.68), (6, 1.95))]
                     + ['{ t = 1.96, k = "Shake", a = 0.5, d = 0.35 }', '{ t = 2.05, k = "Orbs", mode = "Orbit" }']))

# 알리오스: "한 대 - 1초 쉼 - 한 대 - 0.9초 쉼 - 한 대 - 0.4초 쉼 - 한 대 - 0.3초 쉼 - (그 후 0.3초씩 반복)" — 10타
# 2026-10-31 사용자: "알리오스 속도를 전체적으로 두 배 올리자" — 모든 시각을 AL 배(0.5)로(간격 0.5 · 0.45 · 0.2 · 0.15 …, 6초 → 3초)
AL = 0.5
GAPS = [1.0, 0.9, 0.4] + [0.3] * 6
ALIOTH_HITS = [round(0.75 * AL, 3)]
for g in GAPS:
    ALIOTH_HITS.append(round(ALIOTH_HITS[-1] + g * AL, 3))
SWIPES = ["AL_A", "AL_B", "AL_C", "AL_D"]
al_keys = [(0, None, "STANCE"), (round(0.3 * AL, 3), "cubicOut", "AL_READY")]
prev = "AL_READY"
for k, th in enumerate(ALIOTH_HITS):
    # 손짓은 타격 바로 앞 0.12 × AL 초에 휙 — 그 전까지는 앞 손짓에 머문다
    if th - 0.12 * AL > al_keys[-1][0] + 0.01:
        al_keys.append((round(th - 0.12 * AL, 3), "sineInOut", prev))
    prev = SWIPES[k % 4]
    al_keys.append((th, "expoOut", prev))
al_keys += [(round(ALIOTH_HITS[-1] + 0.4 * AL, 3), "sineOut", prev), (round(5.9 * AL, 3), "cubicInOut", "STANCE")]
al_events = ['{ t = 0.06, k = "Orbs", mode = "Pick", star = 3 }', '{ t = 0.07, k = "Fx", n = "TeleGrab", star = 3 }', '{ t = %s, k = "Fx", n = "AliothLaunch" }' % round(0.35 * AL, 3)]
al_events += ['{ t = %s, k = "Hit", i = %d, fx = "AliothStrike" }' % (th, k + 1) for k, th in enumerate(ALIOTH_HITS)]
al_events += ['{ t = %s, k = "Shake", a = 0.15, d = 0.1 }' % th for th in ALIOTH_HITS]
al_events += ['{ t = %s, k = "Fx", n = "AliothReturn" }' % round(5.0 * AL, 3), '{ t = %s, k = "Orbs", mode = "Orbit" }' % round(5.4 * AL, 3)]
skills.append(motion("Alioth", "알리오스: 알리오스를 꺼내 적 진영 위로 띄우고[약] 허공에 팔을 자유자재로 휘두를 때마다[강] 별이 진형을 곧게 가로지른다 — "
                     "10타가 0.5 · 0.45 · 0.2 · 0.15 … 초 간격으로 점점 빨라진다(사용자 원안의 두 배 빠르기) → 별이 손끝으로 돌아온다", round(6.0 * AL, 3), al_keys, al_events))

# 셉텐트리오네스(컷신): 왼 허리로 손을 모았다 치켜들면 별 일곱이 하늘 높이(Orbs Sky) → 별이 하나씩 레이저(국자를 따라 알카이드부터) →
# 북두칠성 꼴로 진형 전체를 강타. 카메라는 Fx 가 잡는다(SeptRise → SeptLaser ×7 → SeptSlam), 모션이 끝나면 감독이 놓는다.
TRACE = [4, 5, 3, 1, 6, 2, 7]
LASERS = [round(2.1 + 0.95 * k, 2) for k in range(7)]
sept_events = ['{ t = 0.95, k = "Orbs", mode = "Sky", at = "Enemies" }', '{ t = 0.95, k = "Fx", n = "SeptRise", d = 1.1, total = 9.5 }']
for k, t in enumerate(LASERS):
    sept_events += ['{ t = %s, k = "Fx", n = "SeptLaser", star = %d, nth = %d }' % (t, TRACE[k], k + 1),
                    '{ t = %s, k = "Hit", i = %d, fx = "SeptLaserHit" }' % (round(t + 0.47, 2), k + 1),
                    '{ t = %s, k = "Shake", a = 0.8, d = 0.4 }' % round(t + 0.47, 2)]  # 2026-10-31 사용자: "레이저 떨굴 때마다 진동도 강하게"
sept_events += ['{ t = 8.62, k = "Fx", n = "SeptGather" }', '{ t = 9.05, k = "Hit", i = 8, fx = "SeptSlam" }', '{ t = 9.06, k = "Stop", d = 0.12 }', '{ t = 9.07, k = "Shake", a = 1.4, d = 0.9 }',
                '{ t = 9.9, k = "Orbs", mode = "Orbit" }']
skills.append(motion("Septentriones", "셉텐트리오네스(컷신): 오른손을 왼 허리로 모았다가[중] 하늘로 치켜들면[강] 별 일곱이 하늘 높이 오르고 → 별이 하나씩 적 진영으로 레이저"
                     "(별 이름 · 화면 색 · 카메라가 별 → 레이저를 따라 아래로) → 팔을 내리치면[강] 북두칠성 꼴로 진형 전체를 강타하고 선 자국이 남는다", 10.8,
                     [(0, None, "STANCE"), (0.3, "cubicOut", "SEPT_LOW"), (0.75, "sineInOut", "SEPT_LOW", {"Head": (-16, 16, 0)}), (0.95, "expoOut", "SEPT_UP"),
                      (4.5, "sineInOut", "SEPT_UP", {"Root": (0, 0.16, 0, 0, -18, 0), "Head": (26, 6, 0)}), (8.6, "sineInOut", "SEPT_UP", {"Root": (0, 0.2, 0, 0, -20, 0)}),
                      (8.95, "expoOut", "SEPT_DOWN"), (9.6, "sineOut", "SEPT_DOWN", {"Root": (0, -0.12, -0.12, 0, -24, 0)}), (10.6, "cubicInOut", "STANCE")],
                     sept_events))
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
for name in ("STANCE", "OFFER", "MEG_R", "MER_UP", "SEPT_UP"):
    print(name, "RArm", POSES[name]["RArm"])
