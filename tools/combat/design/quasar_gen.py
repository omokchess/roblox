import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from twohand import *

# 1) 어깨 메기(란츠크네히트 츠바이핸더): 오른손이 배 앞에서 손잡이를 쥐고, 칼등(면)이 오른 어깨 위에 얹혀 뒤 위로
P = {"Root": (0, -0.28, 0, 0, -14, 0), "Torso": (-4, 0, 0), "Head": (4, 12, 0), "LArm": (4, 0, -12), "RLeg": (10, 0, 16), "LLeg": (-8, 0, -16)}
T = T_of(P)
S = (1.25, 1.18, 0.15)  # 오른 어깨 위(칼이 얹히는 점)
for arm in [(60, 24, 8)]:
    P["RArm"] = arm
    h = T.inv().pt(hand(P, "R"))
    d = norm(sub(S, h))
    P["W"] = aim(P, "W", frame(mv(T.R, d), mv(T.R, (0, 1, 0))), hand(P, "R"))
    tip = T.inv().pt(wpoint(P, "W", (0, 6.2, 0)))
    print("arm", arm, "hand", tuple(round(x, 2) for x in h), "tip", tuple(round(x, 2) for x in tip))
    show("REST", P); REST_W = P["W"]

# 2) 머리 앞 높이 두 손(폼 탁 — 날은 위 뒤로)
P = {"Root": (0, -0.22, 0.2, 0, -8, 0), "Torso": (8, 0, 0), "Head": (10, 6, 0), "RLeg": (12, 0, 16), "LLeg": (-10, 0, -16)}
print(two_hand(P, (0, 1.35, -0.8), (0.05, 0.8, 0.6), (0, 0, -1), left_y=-0.6, hintR=(150, 30, 0), hintL=(150, -30, 0)))
P["W"] = near(P["W"], REST_W); show("HIGH", P)

# 3) 내려친 끝: 숙이고 두 손이 배 앞 아래, 날은 앞 아래로 땅에
P = {"Root": (0, -0.9, -0.6, 0, -8, 0), "Torso": (-34, 0, 0), "Head": (22, 4, 0), "RLeg": (42, 0, 14), "LLeg": (-34, 0, -14)}
T = T_of(P)
print(two_hand(P, (0, -0.2, -1.2), mv(T.R.__class__ and tr(T.R), norm((0, -0.55, -1))) if False else (0, -0.25, -1), (0, 1, 0), left_y=-0.6, hintR=(60, 30, 0), hintL=(60, -30, 0)))
P["W"] = near(P["W"], REST_W); show("SLAM", P)

# 4) 중단(날 끝이 적 얼굴로 — 플루크)
P = {"Root": (0, -0.4, 0, 0, -8, 0), "Torso": (-8, 0, 0), "Head": (8, 6, 0), "RLeg": (22, 0, 14), "LLeg": (-20, 0, -14)}
print(two_hand(P, (0, 0.0, -1.2), (0, 0.45, -1), (0, 1, 0), left_y=-0.6, hintR=(70, 30, 0), hintL=(70, -30, 0)))
P["W"] = near(P["W"], REST_W); show("MID", P)

# 5) 방어 벽: 날을 몸 앞에 곧게 세우고(끝 위) 넓은 면이 적을 본다
P = {"Root": (0, -0.55, 0.15, 0, -2, 0), "Torso": (-4, 0, 0), "Head": (6, 4, 0), "RLeg": (24, 0, 16), "LLeg": (-20, 0, -16)}
print(two_hand(P, (0, 0.3, -1.15), (0, 1, -0.08), (0, 0, -1), left_y=-0.6, hintR=(80, 30, 0), hintL=(80, -30, 0)))
P["W"] = near(P["W"], REST_W); show("WALL", P)

# 6) 명상: 날을 앞 땅에 꽂고(곧게 아래) 두 손을 손잡이 끝에 얹는다
P = {"Root": (0, -0.3, 0, 0, -4, 0), "Torso": (-4, 0, 0), "Head": (-26, 0, 0), "RLeg": (4, 0, 12), "LLeg": (-4, 0, -12)}
print(two_hand(P, (0, -0.3, -1.2), (0, -1, -0.05), (0, 0, -1), left_y=0.6, hintR=(50, 30, 0), hintL=(50, -30, 0)))
P["W"] = near(P["W"], REST_W); show("KNEEL", P)

# 7) 가로베기 예비(날을 오른쪽 뒤로 수평) / 끝(왼쪽 앞으로 쓸어낸 뒤)
P = {"Root": (0, -0.5, 0.2, 0, 20, 0), "Torso": (-8, 30, 0), "Head": (6, -16, 0), "RLeg": (20, 0, 14), "LLeg": (-18, 0, -14)}
print(two_hand(P, (0.3, 0.2, -1.0), (1, 0.1, 0.6), (0, 0, -1), left_y=-0.6, hintR=(80, 60, 20), hintL=(90, 30, 0)))
P["W"] = near(P["W"], REST_W); show("SWEEP_A", P)
P = {"Root": (0, -0.62, -0.3, 0, -40, 0), "Torso": (-14, -40, 0), "Head": (10, 30, 0), "RLeg": (34, 0, 14), "LLeg": (-30, 0, -14)}
print(two_hand(P, (-0.3, 0.1, -1.0), (-1, 0.05, -0.5), (0, 0, 1), left_y=-0.6, hintR=(88, -40, 20), hintL=(88, -80, 0)))
P["W"] = near(P["W"], REST_W); show("SWEEP_B", P)

# 8) 하늘 가리키기(한 손, 날 위로)
P = {"Root": (0, -0.2, 0, 0, -20, 0), "Torso": (10, -8, 0), "Head": (20, 14, 0), "LArm": (40, 0, -40), "RLeg": (10, 0, 16), "LLeg": (-8, 0, -16)}
P["RArm"] = (178, 10, 10)
P["W"] = aim_axis(P, "W", mv(T_of(P).R, (0.05, 1, 0.1)))
P["W"] = near(P["W"], REST_W); show("SKY", P)

# 9) 명상(꽂기): 날을 곧게 아래로 꽂고 두 손을 손잡이 끝(폼멜 쪽)에 포갠다
P = {"Root": (0, -0.3, 0, 0, -4, 0), "Torso": (-4, 0, 0), "Head": (-26, 0, 0), "RLeg": (4, 0, 12), "LLeg": (-4, 0, -12)}
print(two_hand(P, (0, -0.5, -1.25), (0, -1, -0.04), (0, 0, -1), left_y=0.1, right_y=-0.6, hintR=(50, 30, 0), hintL=(50, -30, 0)))
P["W"] = near(P["W"], (0, 0, 0, 180, 0, 0)); show("PLANT", P)

# 10) 끌어당기기: 오른손 하나로 대검을 앞으로 겨누고 왼손을 뻗어 움켜쥔다
P = {"Root": (0, -0.5, 0.2, 0, -8, 0), "Torso": (-8, 0, 0), "Head": (14, 6, 0), "RLeg": (22, 0, 14), "LLeg": (-20, 0, -14), "LArm": (90, -10, 0)}
P["RArm"] = (96, 24, 8)
P["W"] = aim_axis(P, "W", mv(T_of(P).R, (0, 0.3, -1)))
P["W"] = near(P["W"], REST_W); show("PULL", P)

# 11) 특이점 명령: 하늘을 가리키던 칼을 앞 아래로 내려 긋는다(한 손)
P = {"Root": (0, -0.5, -0.2, 0, -6, 0), "Torso": (-22, 6, 0), "Head": (16, 6, 0), "LArm": (20, 0, -50), "RLeg": (30, 0, 16), "LLeg": (-24, 0, -16)}
P["RArm"] = (74, 20, 10)
P["W"] = aim_axis(P, "W", mv(T_of(P).R, (0, -0.2, -1)))
P["W"] = near(P["W"], REST_W); show("CMD", P)

# 12) 들림: 한 손에 늘어진 대검(끝이 아래)
P = {"Root": (0, 0, 0, 6, -12, 3), "Torso": (-10, 0, 0), "Head": (-22, 0, 0), "RArm": (-4, 0, 4), "LArm": (-2, 0, -6), "RLeg": (2, 0, 3), "LLeg": (-4, 0, -3)}
P["W"] = aim_axis(P, "W", (0.05, -1, 0.05))
show("HANG", P)
