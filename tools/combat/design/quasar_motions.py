"""퀘이사 모션 파일(src/shared/Combat/Motions/Quasar.luau)을 통째로 만든다(2026-10-02 리메이크).
자세 값 = quasar2_gen.py 출력(quasar2_out.txt). 키마다 무기 W 회전을 앞 키에 가장 가까운 표기로 감아 적어
(성분마다 ±360) 키 사이가 늘 쿼터니언 최단 호로 돈다(뜻하지 않은 오일러 돌기 없음 — check_wrap.py 로 확인).
쓰는 법: python quasar_motions.py"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "src", "shared", "Combat", "Motions", "Quasar.luau")
SRC = open(os.path.join(HERE, "quasar2_out.txt"), encoding="utf-8").read()

POSES = {}
for name, body in re.findall(r"^local (\w+) = \{ (.*) \}$", SRC, re.M):
    pose = {}
    for k, v in re.findall(r"(\w+) = \{ ([^}]*) \}", body):
        pose[k] = [float(x) for x in v.split(",")]
    POSES[name] = pose
ORDER = ["STANCE", "SALUTE", "RECOIL", "RGUARD", "BARRIER", "TAG", "NEBEN", "LOW", "OCHS_L", "VIGIL", "LANG", "SKY", "CMD", "FLOURISH"]
NOTE = {
    "STANCE": "대기 — 바흐셀·알버: 몸을 오른쪽으로 틀어 왼발을 앞에, 두 손은 오른 허리 앞, 칼끝은 앞 아래 땅 가까이, 앞날은 아래",
    "SALUTE": "경례(들림·버릇): 두 손을 명치 앞에 모으고 날을 얼굴 앞에 곧게",
    "RECOIL": "피격: 두 손은 그대로 몸만 뒤로 젖혀 밀림",
    "RGUARD": "회피 — 역수 허리 막기: 왼쪽으로 비켜서며 오른손 역수, 날이 팔뚝을 따라 오른 허리 바깥으로 뒤 아래 — 골반·옆구리를 덮고 왼손은 폼멜",
    "BARRIER": "방어 — 역수 가로막이: 오른손 역수로 가슴 앞, 날이 허리 앞을 왼쪽 아래로 가로질러 면이 적을 막고 왼손은 날 가운데(하프소드)",
    "TAG": "폼 탁(오른 어깨 위): 날은 위로, 앞날은 적 쪽",
    "NEBEN": "네벤훗: 오른 허리 뒤로 칼끝을 뒤 아래로(감기)",
    "LOW": "내려친 끝: 오른발 내딛고 깊게, 칼끝이 앞 땅에 닿는다",
    "OCHS_L": "왼쪽 옥스(올려벤 끝): 손이 왼 어깨 앞, 칼끝은 적 쪽, 앞날 위",
    "VIGIL": "무릎 꿇은 기도(명상): 두 손을 가슴 앞에 모으고 날을 곧게 땅에 꽂는다",
    "LANG": "한 손 랑고르트(끌어당기기): 팔·칼이 한 줄로 적을 겨누고 왼손을 뻗어 움켜쥔다",
    "SKY": "하늘 가리키기(한 손, 날 위로 곧게)",
    "CMD": "한 손으로 적을 내려 가리킴(명령)",
    "FLOURISH": "내려놓임 한가운데: 한 손으로 날을 오른쪽 아래로 크게 휘둘러 내림, 왼팔은 옆으로 펴 균형",
}


def fmt(v):
    return "{ " + ", ".join(("%g" % round(x, 2)) for x in v) + " }"


def wrap_to(w, prev):
    return w[:3] + [w[i] + 360 * round((prev[i] - w[i]) / 360) for i in (3, 4, 5)]


def keys(spec):
    """spec = [(t, e, 자세 이름, {덮을 것})] → Luau 키 줄. W 는 앞 키에 맞춰 감는다"""
    lines, prev = [], None
    for t, e, pose, over in spec:
        over = dict(over or {})
        w = list(over.get("W", POSES[pose]["W"]))
        if prev is not None:
            w = wrap_to(w, prev)
        if w != POSES[pose]["W"]:
            over["W"] = w
        prev = w
        es = "nil" if e is None else '"%s"' % e
        if over:
            body = ", ".join("%s = %s" % (k, fmt(v)) for k, v in over.items())
            lines.append("\t\t\t\tK(%s, %s, %s, { %s })," % (t, es, pose, body))
        else:
            lines.append("\t\t\t\tK(%s, %s, %s)," % (t, es, pose))
    return "\n".join(lines)


def tremble(t, dx, lift):
    return (t, "sineInOut", "TAG", {"Root": [dx, -0.25 - lift, 0.15 + lift, 0, -30, 0], "Torso": [6 + lift * 40, 8, 0]})


def motion(name, comment, duration, spec, events, extra="", indent=2):
    tab = "\t" * indent
    ev = "\n".join(tab + "\t\t" + e + "," for e in events)
    body = keys(spec)
    if indent == 1:
        body = "\n".join(l[1:] for l in body.split("\n"))
    return (
        f"{tab}-- {comment}\n{tab}{name} = {{\n{tab}\tDuration = {duration},\n{extra}{tab}\tKeys = {{\n{body}\n{tab}\t}},\n"
        + (f"{tab}\tEvents = {{\n{ev}\n{tab}\t}},\n" if events else "")
        + f"{tab}}},\n"
    )


head = '''--!strict
--[[
	퀘이사 — 별이 흐르는 검은 대검(츠바이핸더)을 쓰는 중력의 검사. (2026-09-28, 다시 2026-10-02)

	2026-10-02 리메이크(사용자: "우아한 대검술 쓰는 느낌 — 회피할 때나 그럴 때 대검을 순간 역수로 잡아서 골반 쪽을 방어", 레퍼런스 찾아서):
	  - 레퍼런스: 요아힘 마이어 「검술의 철저한 기술」(1570)의 츠바이핸더·롱소드 자세 — 바흐셀(낮은 옆 겨눔, 칼끝이 다리 옆 아래),
	    알버(낮게 늘어뜨림), 슈랑크훗(낮은 가로막이, 칼끝이 땅 — 아래를 막음), 네벤훗(오른 허리 뒤, 칼끝 뒤 아래), 폼 탁, 랑고르트,
	    왼쪽 옥스. "자세는 멈춰 서는 곳이 아니라 흐름 속의 한 순간"(hema101 마이어 롱소드 101) → 네벤훗 → 폼 탁 → 내려치기처럼
	    원을 그리며 잇는다(감아 올림 — 칼이 몸 옆으로 한 바퀴).
	  - 퀘이사만의 수: 막고 피할 때 대검을 **역수**로 고쳐 쥔다 — 날이 팔뚝을 따라 허리 바깥으로 지나가 골반·옆구리를 덮거나(회피),
	    허리 앞을 가로질러 면으로 막고 왼손이 날을 받친다(방어 — 슈랑크훗을 거꾸로 쥔 꼴).
	  - 쥐는 법 바로잡음: 날이 90° 꺾여 면이 손가락 마디 쪽을 보던 것을(사용자: "검을 90도 꺾어서 잡고 있어") 무기 Turn = 90 으로
	    앞날(-Z)이 마디 쪽이 되게 했다. 자세 값은 그 기준으로 다시 구했다.
	성격: 느긋하고 우아함. 꼿꼿이 서서 칼끝을 땅 가까이 늘어뜨리고 깊게 숨 쉰다. 공격은 원을 그리는 감기 → 한순간의 내려침.
	무기 종류: Great2H (WeaponDefinitions.Greatsword). 오른손 = 손잡이 윗쪽(날밑 밑, 무기 y 0), 왼손 = 폼멜 쪽 y -0.6.
	수치: tools/combat/design/quasar2_gen.py(posecalc — 두 손이 손잡이를 함께 쥐고, 땅에 닿을 칼끝은 땅 바로 위),
	      이 파일은 tools/combat/design/quasar_motions.py 가 만든다(키마다 W 를 앞 키에 맞춰 감아 최단 호로 돌게).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K

'''
poses = []
for name in ORDER:
    p = POSES[name]
    body = ", ".join("%s = %s" % (k, fmt(v)) for k, v in p.items())
    poses.append("-- %s\nlocal %s = { %s }" % (NOTE[name], name, body))
text = head + "\n".join(poses) + "\n\nreturn {\n\tStance = STANCE,\n\n"
text += '''	-- 대기: 깊고 느린 숨(Kit.Breath, Smooth). 칼끝을 땅 가까이 늘어뜨린 채 가슴이 오르내리고, 내쉬며 고개가 조금 돈다
	Idle = Kit.Breath(STANCE, {
		Duration = 4.0,
		Chest = 2.2,
		Rise = 0.03,
		Head = -1.2,
		Mid = { Head = { 1, 27, 0 } },
	}),

'''
text += "\t-- 버릇(가끔): 적에게 경례하듯 날을 얼굴 앞에 세워 칼날을 비춰 보고 다시 늘어뜨린다\n\tFidgets = {\n\t\t{\n\t\t\tDuration = 2.6,\n\t\t\tBlendIn = 0.3,\n\t\t\tBlendOut = 0.4,\n\t\t\tKeys = {\n"
text += keys([(0, None, "STANCE", None), (0.7, "cubicInOut", "SALUTE", {"Head": [10, 20, 0]}), (1.7, "sineInOut", "SALUTE", {"Head": [6, 22, 0]}), (2.6, "cubicInOut", "STANCE", None)]).replace("\t\t\t\tK(", "\t\t\t\tK(")
text += "\n\t\t\t},\n\t\t},\n\t},\n\n"
text += motion("Held", "들림: 경례 자세로 꼿꼿이 매달려 천천히 흔들린다(버둥대지 않음)", 3.2,
               [(0, None, "SALUTE", None), (1.6, None, "SALUTE", {"Root": [0, 0.04, 0, 2, -20, 2], "Head": [-6, 22, 2], "RLeg": [-2, 0, 3], "LLeg": [2, 0, -3]})],
               [], "\t\tLoop = true,\n\t\tSmooth = true,\n", 1)
text += "\n" + motion("Drop", "내려놓임: 경례 자세로 사뿐히 내려서 무릎을 굽히고 — 한 손으로 날을 오른쪽 아래로 크게 휘둘러(원) 낮은 겨눔으로", 1.3,
                      [(0, None, "SALUTE", {"Root": [0, 0.3, 0, 0, -20, 0]}), (0.12, "quadIn", "SALUTE", {"Root": [0, -0.5, 0, 0, -20, 0], "Torso": [-8, 0, 0], "RLeg": [26, 0, 6], "LLeg": [-14, 0, -6]}),
                       (0.42, "cubicOut", "FLOURISH", None), (0.8, "sineInOut", "STANCE", {"Root": [0, -0.3, 0, 0, -28, 0]}), (1.3, "sineInOut", "STANCE", None)],
                      ['{ t = 0.12, k = "Fx", n = "HeavyLand" }', '{ t = 0.13, k = "Shake", a = 0.2, d = 0.25 }', '{ t = 0.25, k = "Trail", on = true }', '{ t = 0.6, k = "Trail", on = false }'],
                      "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Hit", "피격: 거의 안 밀린다 — 몸만 뒤로 젖혀 받고 곧 낮은 겨눔으로", 0.6,
                      [(0, None, "STANCE", None), (0.06, "expoOut", "RECOIL", None), (0.3, "sineOut", "RECOIL", {"Root": [0, -0.3, 0.3, 0, -24, 0], "Torso": [6, 4, 0]}), (0.6, "sineInOut", "STANCE", None)],
                      ['{ t = 0.05, k = "Fx", n = "MassAbsorb" }'], "\t\tBlendIn = 0.02,\n", 1)
text += "\n" + motion("Guard", "방어: 순간 역수로 고쳐 쥐어 날이 허리 앞을 가로지르는 가로막이 — 면으로 받고 왼손이 날을 받친다", 0.75,
                      [(0, None, "STANCE", None), (0.1, "expoOut", "BARRIER", None), (0.25, "sineOut", "BARRIER", {"Root": [0, -0.55, 0.32, 0, -20, 0], "Torso": [-6, 4, 0]}), (0.75, "cubicInOut", "STANCE", None)],
                      ['{ t = 0.1, k = "Fx", n = "GravityWall" }'], "\t\tBlendIn = 0.03,\n", 1)
text += "\n" + motion("Dodge", "회피(성공): 왼쪽으로 비켜서며 대검을 순간 역수로 — 날이 팔뚝을 따라 오른 허리 바깥을 덮어 공격을 흘리고, 다시 낮은 겨눔으로 돌려 쥔다", 0.85,
                      [(0, None, "STANCE", None), (0.15, "expoOut", "RGUARD", None), (0.45, "sineOut", "RGUARD", {"Root": [-0.75, -0.48, 0.22, 0, -56, 0]}), (0.85, "cubicInOut", "STANCE", None)],
                      ['{ t = 0.06, k = "Trail", on = true }', '{ t = 0.14, k = "Fx", n = "Deflect" }', '{ t = 0.45, k = "Trail", on = false }'], "\t\tBlendIn = 0.02,\n", 1)

skills = []
skills.append(motion("Collapse", "붕괴: 네벤훗으로 감았다가 원을 그려 폼 탁으로 — 대검 위에 중력이 뭉쳐 떨리고 → 한 걸음 내딛으며 내려쳐 칼끝이 땅에", 2.2,
                     [(0, None, "STANCE", None), (0.18, "cubicOut", "NEBEN", None), (0.42, "cubicInOut", "TAG", None),
                      tremble(0.6, 0.04, 0.06), tremble(0.72, -0.04, 0.08), tremble(0.84, 0.04, 0.1), tremble(0.96, -0.03, 0.12), tremble(1.08, 0, 0.14),
                      (1.18, "expoOut", "LOW", None), (1.6, "linear", "LOW", {"Root": [0, -0.82, -0.6, 0, -20, 0]}), (1.95, "cubicInOut", "STANCE", {"Root": [0, -0.3, 0, 0, -28, 0]}), (2.2, "sineInOut", "STANCE", None)],
                     ['{ t = 0.3, k = "Fx", n = "Implode" }', '{ t = 0.9, k = "Dash", to = "Target", gap = 4.5, d = 0.18, e = "quadIn" }', '{ t = 1.05, k = "Trail", on = true }',
                      '{ t = 1.18, k = "Hit", i = 1, fx = "CollapseSlam" }', '{ t = 1.19, k = "Stop", d = 0.14 }', '{ t = 1.2, k = "Shake", a = 0.8, d = 0.5 }', '{ t = 1.4, k = "Trail", on = false }',
                      '{ t = 1.75, k = "Dash", to = "Home", d = 0.35 }']))
skills.append(motion("CollapseCharge", "붕괴 차징(첫 사용 = 피해 없음): 감아 올려 폼 탁에 중력을 모으고 → 한 손 랑고르트로 겨눈 채 왼손으로 적을 움켜 끌어당긴다", 1.7,
                     [(0, None, "STANCE", None), (0.18, "cubicOut", "NEBEN", None), (0.42, "cubicInOut", "TAG", None), tremble(0.6, 0.04, 0.06), tremble(0.75, -0.04, 0.07), tremble(0.9, 0.04, 0.08),
                      (1.1, "expoOut", "LANG", None), (1.35, "sineOut", "LANG", {"Root": [0, -0.44, 0.35, 0, 40, 0], "LArm": [70, 10, 0]}), (1.7, "sineInOut", "STANCE", None)],
                     ['{ t = 0.3, k = "Fx", n = "Implode" }', '{ t = 1.1, k = "Fx", n = "Pull" }', '{ t = 1.12, k = "Shake", a = 0.25, d = 0.3 }']))
skills.append(motion("Singularity", "특이점: 한 손으로 날을 머리 위 곧게 들어 하늘을 가리키면 대상 위에 거대한 에너지 검 — 내려 가리키는 손짓에 떨어져 꽂힌다", 2.2,
                     [(0, None, "STANCE", None), (0.4, "cubicOut", "SKY", None), (0.95, "sineInOut", "SKY", {"Root": [0, -0.13, 0, 0, -20, 0], "Torso": [14, -6, 0], "RArm": [180, 8, 8]}),
                      (1.1, "expoOut", "CMD", None), (1.6, "sineOut", "CMD", {"Root": [0, -0.42, -0.2, 0, 30, 0], "Torso": [-14, -4, 0]}), (2.2, "sineInOut", "STANCE", None)],
                     ['{ t = 0.4, k = "Fx", n = "PointSky" }', '{ t = 0.5, k = "Fx", n = "SummonSword" }', '{ t = 1.1, k = "Trail", on = true }', '{ t = 1.1, k = "Fx", n = "DropSword" }',
                      '{ t = 1.35, k = "Hit", i = 1, fx = "SingularityHit" }', '{ t = 1.36, k = "Stop", d = 0.12 }', '{ t = 1.37, k = "Shake", a = 0.7, d = 0.5 }', '{ t = 1.4, k = "Trail", on = false }']))
skills.append(motion("Infall", "낙하: 네벤훗(오른 허리 뒤)에서 왼쪽 위 앞으로 올려베어 왼쪽 옥스로 — 가볍고 빠른 한 수", 1.3,
                     [(0, None, "STANCE", None), (0.2, "cubicOut", "NEBEN", None), (0.34, "expoOut", "OCHS_L", None), (0.7, "sineOut", "OCHS_L", {"Root": [0, -0.38, -0.32, 0, 22, 0]}), (1.3, "cubicInOut", "STANCE", None)],
                     ['{ t = 0.08, k = "Dash", to = "Target", gap = 4, d = 0.16 }', '{ t = 0.24, k = "Trail", on = true }', '{ t = 0.33, k = "Hit", i = 1, fx = "InfallCut" }',
                      '{ t = 0.34, k = "Stop", d = 0.08 }', '{ t = 0.35, k = "Shake", a = 0.35, d = 0.25 }', '{ t = 0.5, k = "Trail", on = false }', '{ t = 0.85, k = "Dash", to = "Home", d = 0.28 }']))
skills.append(motion("Guard", "가드(스킬): 역수 가로막이로 오래 버틴다", 1.1,
                     [(0, None, "STANCE", None), (0.2, "backOut", "BARRIER", None), (0.8, "sineInOut", "BARRIER", {"Root": [0, -0.52, 0.2, 0, -20, 0], "Torso": [-5, 4, 0]}), (1.1, "sineInOut", "STANCE", None)],
                     ['{ t = 0.2, k = "Fx", n = "GravityWall" }']))
skills.append(motion("Meditate", "명상: 무릎 꿇고 대검을 앞 땅에 곧게 꽂아 두 손을 모으고 고개를 숙인다(기사의 기도)", 2.0,
                     [(0, None, "STANCE", None), (0.45, "cubicInOut", "VIGIL", None), (1.5, "sineInOut", "VIGIL", {"Root": [0, -1.12, 0.2, 0, -14, 0], "Head": [-24, 0, 0]}), (2.0, "sineInOut", "STANCE", None)],
                     ['{ t = 0.5, k = "Fx", n = "Meditate" }']))
text += "\n\tSkills = {\n" + "\n".join(skills) + "\t},\n}\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("썼다", os.path.normpath(OUT))
