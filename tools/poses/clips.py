"""절차적 애니메이션 클립 정의 (tools/poses/gen_luau.py 가 PoseLibrary.luau 로 변환).

키 형식: k(시간, {관절: 회전, "RootPos": (x,y,z)}, 이징)
회전은 (rx, ry, rz) 도(= CFrame.Angles, 부모 공간) 또는 헬퍼가 만든 3x3 행렬.
  어깨 +X = 팔을 앞으로 들기, 오른팔 +Z = 바깥으로 벌리기, Y = 비틀기
  팔꿈치 +X = 굽히기, 손목 +X = 칼끝 들기 (-90 이면 칼날이 팔의 연장선)
  허리/루트 +Y = 왼쪽으로 회전, -X = 앞으로 숙이기
  고관절 +X = 다리 앞으로, 무릎 -X = 굽히기
빈 키 {} = 중립 (기본 애니메이션/들기 자세로 복귀).
layer: "Upper"(상체만, 걸으며 공격) | "Full"(전신) — 캐릭터 이동 애니메이션 위에 덮어쓸 범위.
"""

import math

import numpy as np

from fk import rx, ry, rz

WEAPON_LEN = {"cleaver": 4.8, "spear": 8.4, "maul": 6.8, "staff": 6.0, "club": 8.0, None: 0}


def D(v):
    return math.radians(v)


def arm(yaw, pitch, twist=0.0):
    """어깨 회전: 팔이 가리킬 방향. yaw 0=정면, +=왼쪽, -=오른쪽 / pitch 0=수평, +=위, -90=아래."""
    return ry(D(yaw)) @ rx(D(90 + pitch)) @ ry(D(twist))


def yaw(deg):
    return (0, deg, 0)


def k(t, pose=None, ease="Smooth"):
    return (t, pose or {}, ease)


def merge(*poses):
    out = {}
    for p in poses:
        out.update(p)
    return out


# ─────────────────────────────────────────────────────────────
# 무기 들기 자세 (상시 오버레이)
# ─────────────────────────────────────────────────────────────
HOLD = {
    "cleaver": {"RightShoulder": arm(-12, -72), "RightElbow": (38, 0, 0), "RightWrist": (-14, 0, 0)},
    "spear": {"RightShoulder": arm(-18, -62, 10), "RightElbow": (58, 0, 0), "RightWrist": (-78, 18, 0),
              "LeftShoulder": arm(22, -38), "LeftElbow": (48, 0, 0)},
    "maul": {"RightShoulder": arm(-25, -40, 20), "RightElbow": (105, 0, 0), "RightWrist": (-10, 0, 25),
             "LeftShoulder": arm(35, -45), "LeftElbow": (95, 0, 0)},
}

CLIPS = {}


def clip(name, dur, keys, weapon=None, layer="Upper", loop=False, hold=None):
    CLIPS[name] = {"dur": dur, "keys": keys, "weapon": weapon, "layer": layer, "loop": loop, "hold": hold}


def stance(hold_name):
    return HOLD[hold_name]


# ─────────────────────────────────────────────────────────────
# 늪지기 식칼 (한손검)
# ─────────────────────────────────────────────────────────────
H = HOLD["cleaver"]
clip("Hold_Cleaver", 1.0, [k(0, H), k(1, H)], weapon="cleaver", loop=True)

clip("Cleaver_L1", 0.52, [   # 오른쪽 → 왼쪽 수평 베기
    k(0.00, H),
    k(0.15, {"Waist": yaw(-38), "Neck": yaw(28), "RightShoulder": arm(-105, 10, 90), "RightElbow": (40, 0, 0), "RightWrist": (-78, 0, 0),
             "LeftShoulder": arm(30, -40), "LeftElbow": (40, 0, 0)}, "Out"),
    k(0.27, {"Waist": yaw(32), "Neck": yaw(-22), "RightShoulder": arm(55, -4, 90), "RightElbow": (22, 0, 0), "RightWrist": (-80, 0, 0),
             "LeftShoulder": arm(-10, -70), "LeftElbow": (20, 0, 0)}, "Out"),
    k(0.52, H),
], weapon="cleaver")

clip("Cleaver_L2", 0.52, [   # 왼쪽 아래 → 오른쪽 위 올려베기
    k(0.00, H),
    k(0.15, {"Waist": yaw(34), "Neck": yaw(-24), "RightShoulder": arm(60, -30, -90), "RightElbow": (45, 0, 0), "RightWrist": (-75, 0, 0)}, "Out"),
    k(0.27, {"Waist": yaw(-34), "Neck": yaw(24), "RightShoulder": arm(-95, 35, -90), "RightElbow": (12, 0, 0), "RightWrist": (-80, 0, 0)}, "Out"),
    k(0.52, H),
], weapon="cleaver")

clip("Cleaver_L3", 0.62, [   # 머리 위 내려찍기
    k(0.00, H),
    k(0.22, {"Waist": (12, -10, 0), "RightShoulder": arm(-10, 145), "RightElbow": (55, 0, 0), "RightWrist": (-60, 0, 0),
             "LeftShoulder": arm(20, 20), "LeftElbow": (30, 0, 0)}, "Out"),
    k(0.34, {"Waist": (-28, 5, 0), "Neck": (18, 0, 0), "RightShoulder": arm(-8, -30), "RightElbow": (8, 0, 0), "RightWrist": (-75, 0, 0),
             "LeftShoulder": arm(10, -80), "RootPos": (0, -0.45, -0.3), "RightHip": (25, 0, 0), "RightKnee": (-25, 0, 0),
             "LeftHip": (-18, 0, 0)}, "Out"),
    k(0.62, H),
], weapon="cleaver", layer="Full")

clip("Cleaver_L4", 0.78, [   # 회전 베기 마무리
    k(0.00, H),
    k(0.12, {"Root": yaw(40), "RightShoulder": arm(-80, 5), "RightElbow": (15, 0, 0), "RightWrist": (-85, 0, 0), "RootPos": (0, -0.3, 0)}, "Out"),
    k(0.26, {"Root": yaw(-80), "RightShoulder": arm(-92, 0), "RightElbow": (5, 0, 0), "RightWrist": (-88, 0, 0), "RootPos": (0, -0.35, 0)}, "Linear"),
    k(0.40, {"Root": yaw(-200), "RightShoulder": arm(-92, 0), "RightElbow": (5, 0, 0), "RightWrist": (-88, 0, 0), "RootPos": (0, -0.35, 0)}, "Linear"),
    k(0.52, {"Root": yaw(-320), "RightShoulder": arm(-85, -5), "RightElbow": (10, 0, 0), "RightWrist": (-85, 0, 0), "RootPos": (0, -0.3, 0)}, "Out"),
    k(0.78, H),
], weapon="cleaver", layer="Full")

clip("Cleaver_HeavyCharge", 0.45, [
    k(0.00, H),
    k(0.45, {"Waist": (10, -30, 0), "Neck": (0, 25, 0), "RightShoulder": arm(-30, 150), "RightElbow": (70, 0, 0), "RightWrist": (-50, 0, 0),
             "LeftShoulder": arm(40, 10), "LeftElbow": (40, 0, 0), "RootPos": (0, -0.6, 0.2), "RightHip": (-15, 0, 0), "LeftHip": (30, 0, 0),
             "LeftKnee": (-40, 0, 0), "RightKnee": (-30, 0, 0)}, "Out"),
], weapon="cleaver", layer="Full", hold=True)

clip("Cleaver_Heavy", 0.72, [
    k(0.00, {"Waist": (10, -30, 0), "Neck": (0, 25, 0), "RightShoulder": arm(-30, 150), "RightElbow": (70, 0, 0), "RightWrist": (-50, 0, 0),
             "LeftShoulder": arm(40, 10), "LeftElbow": (40, 0, 0), "RootPos": (0, -0.6, 0.2), "RightHip": (-15, 0, 0), "LeftHip": (30, 0, 0),
             "LeftKnee": (-40, 0, 0), "RightKnee": (-30, 0, 0)}),
    k(0.14, {"Waist": (-35, 10, 0), "Neck": (25, -8, 0), "RightShoulder": arm(0, -35), "RightElbow": (5, 0, 0), "RightWrist": (-80, 0, 0),
             "LeftShoulder": arm(15, -60), "RootPos": (0, -0.8, -1.2), "RightHip": (40, 0, 0), "RightKnee": (-45, 0, 0), "LeftHip": (-30, 0, 0),
             "LeftKnee": (-20, 0, 0)}, "Out"),
    k(0.40, {"Waist": (-30, 10, 0), "Neck": (22, -8, 0), "RightShoulder": arm(0, -40), "RightElbow": (5, 0, 0), "RightWrist": (-80, 0, 0),
             "RootPos": (0, -0.75, -1.2), "RightHip": (40, 0, 0), "RightKnee": (-45, 0, 0), "LeftHip": (-30, 0, 0)}),
    k(0.72, H),
], weapon="cleaver", layer="Full")

clip("Cleaver_VenomRend", 0.62, [   # X 자 이연격
    k(0.00, H),
    k(0.10, {"Waist": yaw(-25), "RightShoulder": arm(-70, 70, -30), "RightElbow": (35, 0, 0), "RightWrist": (-70, 0, 0)}, "Out"),
    k(0.20, {"Waist": yaw(25), "RightShoulder": arm(45, -35, -30), "RightElbow": (10, 0, 0), "RightWrist": (-80, 0, 0)}, "Out"),
    k(0.30, {"Waist": yaw(20), "RightShoulder": arm(40, 70, 150), "RightElbow": (35, 0, 0), "RightWrist": (-70, 0, 0)}, "Out"),
    k(0.40, {"Waist": yaw(-28), "RightShoulder": arm(-75, -35, 150), "RightElbow": (10, 0, 0), "RightWrist": (-80, 0, 0)}, "Out"),
    k(0.62, H),
], weapon="cleaver")

clip("Cleaver_Whirl", 0.95, [   # 2회전 소용돌이
    k(0.00, H),
    k(0.10, {"Root": yaw(30), "RightShoulder": arm(-90, 0), "RightWrist": (-88, 0, 0), "LeftShoulder": arm(90, 0), "RootPos": (0, -0.4, 0)}, "Out"),
    k(0.25, {"Root": yaw(-90), "RightShoulder": arm(-90, 0), "RightWrist": (-88, 0, 0), "LeftShoulder": arm(90, 0), "RootPos": (0, -0.4, 0)}, "Linear"),
    k(0.40, {"Root": yaw(-210), "RightShoulder": arm(-90, 0), "RightWrist": (-88, 0, 0), "LeftShoulder": arm(90, 0), "RootPos": (0, -0.4, 0)}, "Linear"),
    k(0.55, {"Root": yaw(-330), "RightShoulder": arm(-90, 0), "RightWrist": (-88, 0, 0), "LeftShoulder": arm(90, 0), "RootPos": (0, -0.4, 0)}, "Linear"),
    k(0.70, {"Root": yaw(-450), "RightShoulder": arm(-90, 0), "RightWrist": (-88, 0, 0), "LeftShoulder": arm(90, 0), "RootPos": (0, -0.4, 0)}, "Linear"),
    k(0.80, {"Root": yaw(-560), "RightShoulder": arm(-80, -10), "RightWrist": (-80, 0, 0), "RootPos": (0, -0.3, 0)}, "Out"),
    k(0.95, H),
], weapon="cleaver", layer="Full")

# ─────────────────────────────────────────────────────────────
# 작살창 (양손 창)
# ─────────────────────────────────────────────────────────────
HS = HOLD["spear"]
clip("Hold_Spear", 1.0, [k(0, HS), k(1, HS)], weapon="spear", loop=True)
THRUST = {"Waist": yaw(10), "Neck": yaw(-8), "RightShoulder": arm(24, -8, 10), "RightElbow": (6, 0, 0), "RightWrist": (-86, -36, 0),
          "LeftShoulder": arm(8, 0), "LeftElbow": (12, 0, 0), "RootPos": (0, -0.3, -0.9), "RightHip": (-20, 0, 0), "LeftHip": (28, 0, 0), "LeftKnee": (-25, 0, 0)}
PULL = {"Waist": yaw(-22), "Neck": yaw(18), "RightShoulder": arm(-30, -72, 10), "RightElbow": (70, 0, 0), "RightWrist": (-72, 12, 0),
        "LeftShoulder": arm(25, -25), "LeftElbow": (45, 0, 0), "RootPos": (0, -0.25, 0.3)}
clip("Spear_L1", 0.5, [k(0.0, HS), k(0.14, PULL, "Out"), k(0.24, THRUST, "Out"), k(0.5, HS)], weapon="spear", layer="Full")
clip("Spear_L2", 0.56, [   # 수평 휘두르기
    k(0.00, HS),
    k(0.16, {"Waist": yaw(-40), "RightShoulder": arm(-110, -10, 10), "RightElbow": (30, 0, 0), "RightWrist": (-86, 0, 0), "LeftShoulder": arm(-40, -20)}, "Out"),
    k(0.30, {"Waist": yaw(40), "RightShoulder": arm(60, -5, 10), "RightElbow": (10, 0, 0), "RightWrist": (-86, 0, 0), "LeftShoulder": arm(80, -30)}, "Out"),
    k(0.56, HS),
], weapon="spear")
clip("Spear_L3", 0.66, [   # 연속 두 번 찌르기
    k(0.00, HS), k(0.10, PULL, "Out"), k(0.18, THRUST, "Out"), k(0.28, PULL, "Out"), k(0.38, merge(THRUST, {"RootPos": (0, -0.35, -1.3)}), "Out"), k(0.66, HS),
], weapon="spear", layer="Full")
clip("Spear_HeavyCharge", 0.4, [k(0.0, HS), k(0.4, merge(PULL, {"RootPos": (0, -0.7, 0.6), "RightKnee": (-35, 0, 0), "LeftKnee": (-35, 0, 0), "LeftHip": (25, 0, 0)}), "Out")],
     weapon="spear", layer="Full", hold=True)
clip("Spear_Heavy", 0.7, [
    k(0.00, merge(PULL, {"RootPos": (0, -0.7, 0.6), "RightKnee": (-35, 0, 0), "LeftKnee": (-35, 0, 0), "LeftHip": (25, 0, 0)})),
    k(0.16, merge(THRUST, {"RootPos": (0, -0.5, -2.0), "Waist": (-15, 20, 0), "LeftHip": (45, 0, 0), "LeftKnee": (-45, 0, 0), "RightHip": (-35, 0, 0)}), "Out"),
    k(0.42, merge(THRUST, {"RootPos": (0, -0.45, -1.8), "Waist": (-12, 18, 0)})),
    k(0.70, HS),
], weapon="spear", layer="Full")
clip("Spear_Throw", 0.62, [
    k(0.00, HS),
    k(0.20, {"Waist": (10, -35, 0), "Neck": yaw(30), "RightShoulder": arm(-60, 110, 90), "RightElbow": (80, 0, 0), "RightWrist": (-20, 0, 0),
             "LeftShoulder": arm(10, 20), "LeftElbow": (10, 0, 0), "RootPos": (0, -0.2, 0.4), "LeftHip": (25, 0, 0)}, "Out"),
    k(0.30, {"Waist": (-18, 25, 0), "Neck": yaw(-20), "RightShoulder": arm(-5, 5, 90), "RightElbow": (5, 0, 0), "RightWrist": (-40, 0, 0),
             "LeftShoulder": arm(40, -60), "RootPos": (0, -0.3, -0.7), "RightHip": (-25, 0, 0), "LeftHip": (30, 0, 0)}, "Out"),
    k(0.62, {}),
], weapon="spear", layer="Full")
clip("Spear_Leap", 0.9, [   # 도약 찌르기
    k(0.00, HS),
    k(0.15, merge(PULL, {"RootPos": (0, -1.0, 0.3), "RightKnee": (-60, 0, 0), "LeftKnee": (-60, 0, 0), "RightHip": (40, 0, 0), "LeftHip": (40, 0, 0)}), "Out"),
    k(0.40, {"RootPos": (0, 3.0, -2.0), "Waist": (-10, 0, 0), "RightShoulder": arm(-10, 70, 10), "RightElbow": (60, 0, 0), "RightWrist": (-40, 0, 0),
             "LeftShoulder": arm(20, 40), "RightHip": (60, 0, 0), "RightKnee": (-80, 0, 0), "LeftHip": (30, 0, 0), "LeftKnee": (-60, 0, 0)}, "Out"),
    k(0.55, merge(THRUST, {"Waist": (-40, 10, 0), "RightShoulder": arm(-5, -45, 10), "RootPos": (0, -0.8, -2.5), "RightKnee": (-50, 0, 0), "LeftKnee": (-60, 0, 0),
                           "RightHip": (30, 0, 0), "LeftHip": (-20, 0, 0)}), "In"),
    k(0.9, HS),
], weapon="spear", layer="Full")

# ─────────────────────────────────────────────────────────────
# 이끼 망치 (양손 둔기)
# ─────────────────────────────────────────────────────────────
HM = HOLD["maul"]
clip("Hold_Maul", 1.0, [k(0, HM), k(1, HM)], weapon="maul", loop=True)
MAUL_BACK_R = {"Waist": yaw(-45), "Neck": yaw(35), "RightShoulder": arm(-120, 20, 60), "RightElbow": (60, 0, 0), "RightWrist": (-60, 0, 0),
               "LeftShoulder": arm(-60, 0), "LeftElbow": (70, 0, 0), "RootPos": (0, -0.5, 0.2), "LeftKnee": (-30, 0, 0), "RightKnee": (-20, 0, 0)}
MAUL_FRONT_L = {"Waist": yaw(40), "Neck": yaw(-30), "RightShoulder": arm(45, -15, 60), "RightElbow": (15, 0, 0), "RightWrist": (-80, 0, 0),
                "LeftShoulder": arm(70, -30), "LeftElbow": (40, 0, 0), "RootPos": (0, -0.6, -0.4), "LeftHip": (20, 0, 0), "RightHip": (-15, 0, 0)}
clip("Maul_L1", 0.78, [k(0.0, HM), k(0.30, MAUL_BACK_R, "Out"), k(0.44, MAUL_FRONT_L, "Out"), k(0.78, HM)], weapon="maul", layer="Full")
clip("Maul_L2", 0.8, [k(0.0, MAUL_FRONT_L), k(0.28, merge(MAUL_FRONT_L, {"Waist": yaw(55)}), "Out"),
                      k(0.44, merge(MAUL_BACK_R, {"Waist": yaw(-35), "RightShoulder": arm(-100, -10, 60)}), "Out"), k(0.8, HM)], weapon="maul", layer="Full")
SLAM_UP = {"Waist": (15, 0, 0), "Neck": (-10, 0, 0), "RightShoulder": arm(-15, 160, 0), "RightElbow": (40, 0, 0), "RightWrist": (-30, 0, 0),
           "LeftShoulder": arm(15, 160), "LeftElbow": (40, 0, 0), "RootPos": (0, -0.2, 0.3)}
SLAM_DOWN = {"Waist": (-45, 0, 0), "Neck": (30, 0, 0), "RightShoulder": arm(-5, -20, 0), "RightElbow": (5, 0, 0), "RightWrist": (-80, 0, 0),
             "LeftShoulder": arm(10, -25), "LeftElbow": (10, 0, 0), "RootPos": (0, -1.0, -0.6), "RightHip": (40, 0, 0), "RightKnee": (-50, 0, 0),
             "LeftHip": (-25, 0, 0), "LeftKnee": (-30, 0, 0)}
clip("Maul_L3", 0.95, [k(0.0, HM), k(0.38, SLAM_UP, "Out"), k(0.50, SLAM_DOWN, "In"), k(0.95, HM)], weapon="maul", layer="Full")
clip("Maul_HeavyCharge", 0.5, [k(0.0, HM), k(0.5, merge(SLAM_UP, {"RootPos": (0, -0.6, 0.3), "RightKnee": (-40, 0, 0), "LeftKnee": (-40, 0, 0)}), "Out")],
     weapon="maul", layer="Full", hold=True)
clip("Maul_Heavy", 0.85, [k(0.0, merge(SLAM_UP, {"RootPos": (0, -0.6, 0.3)})), k(0.20, merge(SLAM_UP, {"RootPos": (0, 2.2, -1.0)}), "Out"),
                          k(0.34, SLAM_DOWN, "In"), k(0.6, SLAM_DOWN), k(0.85, HM)], weapon="maul", layer="Full")
clip("Maul_GroundSlam", 1.0, [k(0.0, HM), k(0.25, merge(SLAM_UP, {"RootPos": (0, 3.0, 0)}), "Out"), k(0.45, SLAM_DOWN, "In"), k(0.75, SLAM_DOWN), k(1.0, HM)],
     weapon="maul", layer="Full")
CHARGE_RUN = {"Waist": (-30, 0, 0), "Neck": (25, 0, 0), "RightShoulder": arm(-30, -50, 60), "RightElbow": (80, 0, 0), "LeftShoulder": arm(50, -10),
              "LeftElbow": (90, 0, 0), "RootPos": (0, -0.5, 0)}
clip("Maul_Charge", 1.1, [k(0.0, HM), k(0.15, CHARGE_RUN, "Out"),
                          k(0.35, merge(CHARGE_RUN, {"RightHip": (45, 0, 0), "LeftHip": (-40, 0, 0), "RightKnee": (-30, 0, 0)})),
                          k(0.55, merge(CHARGE_RUN, {"RightHip": (-40, 0, 0), "LeftHip": (45, 0, 0), "LeftKnee": (-30, 0, 0)})),
                          k(0.75, merge(CHARGE_RUN, {"RightHip": (45, 0, 0), "LeftHip": (-40, 0, 0), "RightKnee": (-30, 0, 0)})),
                          k(0.85, merge(MAUL_FRONT_L, {"Waist": yaw(30)}), "Out"), k(1.1, HM)], weapon="maul", layer="Full")

# ─────────────────────────────────────────────────────────────
# 공통: 회피/방어/피격/기절/사망
# ─────────────────────────────────────────────────────────────
TUCK = {"RightHip": (100, 0, 0), "LeftHip": (100, 0, 0), "RightKnee": (-120, 0, 0), "LeftKnee": (-120, 0, 0),
        "RightShoulder": arm(-10, -20), "LeftShoulder": arm(10, -20), "RightElbow": (100, 0, 0), "LeftElbow": (100, 0, 0), "Neck": (-40, 0, 0)}
clip("Roll", 0.44, [
    k(0.00, {}),
    k(0.06, merge(TUCK, {"Root": (-40, 0, 0), "RootPos": (0, -1.2, 0)}), "Out"),
    k(0.16, merge(TUCK, {"Root": (-150, 0, 0), "RootPos": (0, -1.5, 0)}), "Linear"),
    k(0.27, merge(TUCK, {"Root": (-260, 0, 0), "RootPos": (0, -1.4, 0)}), "Linear"),
    k(0.36, merge(TUCK, {"Root": (-345, 0, 0), "RootPos": (0, -0.9, 0)}), "Out"),
    k(0.44, {}),
], layer="Full")
clip("Backstep", 0.36, [k(0.0, {}), k(0.1, {"Waist": (15, 0, 0), "RootPos": (0, -0.4, 0.4), "RightHip": (-20, 0, 0), "LeftHip": (30, 0, 0), "LeftKnee": (-30, 0, 0)}, "Out"),
                        k(0.36, {})], layer="Full")
clip("Block_Cleaver", 0.14, [k(0.0, H), k(0.14, {"Waist": yaw(10), "RightShoulder": arm(20, 25, -80), "RightElbow": (70, 0, 0), "RightWrist": (-10, 0, 0),
                                                "LeftShoulder": arm(-10, 10), "LeftElbow": (100, 0, 0), "RootPos": (0, -0.3, 0)}, "Out")],
     weapon="cleaver", hold=True)
clip("Block_Spear", 0.14, [k(0.0, HS), k(0.14, {"RightShoulder": arm(-40, 10, 90), "RightElbow": (80, 0, 0), "RightWrist": (-10, 0, -60),
                                               "LeftShoulder": arm(40, 10), "LeftElbow": (80, 0, 0), "RootPos": (0, -0.3, 0)}, "Out")],
     weapon="spear", hold=True)
clip("Block_Maul", 0.16, [k(0.0, HM), k(0.16, {"RightShoulder": arm(-35, 15, 90), "RightElbow": (85, 0, 0), "RightWrist": (0, 0, -70),
                                              "LeftShoulder": arm(35, 15), "LeftElbow": (85, 0, 0), "RootPos": (0, -0.4, 0)}, "Out")],
     weapon="maul", hold=True)
clip("Parry", 0.36, [k(0.0, {}), k(0.07, {"Waist": yaw(-25), "RightShoulder": arm(-60, 50, -40), "RightElbow": (40, 0, 0), "RightWrist": (-60, 0, 0)}, "Out"),
                     k(0.36, {})])
clip("HitReact", 0.3, [k(0.0, {}), k(0.06, {"Waist": (18, 8, 4), "Neck": (15, 0, 0), "RootPos": (0, 0, 0.3)}, "Out"), k(0.3, {})], layer="Full")
clip("Stagger", 0.9, [k(0.0, {}), k(0.12, {"Waist": (30, -10, 8), "Neck": (25, 0, 0), "RightShoulder": arm(-60, 20), "LeftShoulder": arm(70, 10),
                                           "RootPos": (0, -0.4, 0.8), "RightKnee": (-30, 0, 0), "LeftKnee": (-20, 0, 0)}, "Out"),
                      k(0.6, {"Waist": (20, 5, -5), "Neck": (10, 0, 0), "RootPos": (0, -0.3, 0.5)}), k(0.9, {})], layer="Full")
clip("Stun", 1.2, [k(0.0, {}), k(0.3, {"Waist": (-15, 20, 10), "Neck": (20, -25, 0), "RightShoulder": arm(-20, -80), "LeftShoulder": arm(20, -80), "RootPos": (0, -0.3, 0)}),
                   k(0.6, {"Waist": (-15, -20, -10), "Neck": (20, 25, 0), "RightShoulder": arm(-20, -80), "LeftShoulder": arm(20, -80), "RootPos": (0, -0.3, 0)}),
                   k(0.9, {"Waist": (-15, 20, 10), "Neck": (20, -25, 0), "RootPos": (0, -0.3, 0)}), k(1.2, {})], layer="Full", loop=True)
clip("Death", 1.2, [k(0.0, {}), k(0.3, {"Waist": (25, 0, 0), "Neck": (30, 0, 0), "RightKnee": (-60, 0, 0), "LeftKnee": (-60, 0, 0), "RootPos": (0, -1.0, 0.3)}),
                    k(0.8, {"Root": (80, 0, 0), "RootPos": (0, -2.3, 1.2), "RightShoulder": arm(-60, 20), "LeftShoulder": arm(60, 20)}, "In"),
                    k(1.2, {"Root": (88, 0, 0), "RootPos": (0, -2.4, 1.4), "RightShoulder": arm(-70, 10), "LeftShoulder": arm(70, 10)})], layer="Full", hold=True)
clip("Equip", 0.35, [k(0.0, {"RightShoulder": arm(-30, -70), "RightElbow": (20, 0, 0)}), k(0.12, {"RightShoulder": arm(-60, -30, 0), "RightElbow": (90, 0, 0), "Waist": yaw(-15)}, "Out"),
                     k(0.35, {})])

# ─────────────────────────────────────────────────────────────
# 적 (크리처 리그도 R15 관절 이름을 사용)
# ─────────────────────────────────────────────────────────────
clip("Crawler_Bite", 0.6, [k(0.0, {}), k(0.22, {"Waist": (20, 0, 0), "Neck": (25, 0, 0), "RightShoulder": arm(-50, -40), "LeftShoulder": arm(50, -40), "RootPos": (0, -0.4, 0.5)}, "Out"),
                           k(0.32, {"Waist": (-35, 0, 0), "Neck": (-20, 0, 0), "RightShoulder": arm(-20, 10), "LeftShoulder": arm(20, 10), "RootPos": (0, -0.3, -1.4)}, "Out"),
                           k(0.6, {})], layer="Full")
clip("Crawler_Swipe", 0.62, [k(0.0, {}), k(0.24, {"Waist": yaw(-40), "RightShoulder": arm(-110, 40, 0), "RightElbow": (30, 0, 0)}, "Out"),
                             k(0.34, {"Waist": yaw(35), "RightShoulder": arm(50, -20, 0), "RightElbow": (10, 0, 0)}, "Out"), k(0.62, {})])
clip("Crawler_Pounce", 0.95, [k(0.0, {}), k(0.3, {"Waist": (-20, 0, 0), "RightHip": (60, 0, 0), "LeftHip": (60, 0, 0), "RightKnee": (-90, 0, 0), "LeftKnee": (-90, 0, 0),
                                                  "RightShoulder": arm(-30, -60), "LeftShoulder": arm(30, -60), "RootPos": (0, -1.0, 0.3)}, "Out"),
                              k(0.5, {"Waist": (-30, 0, 0), "RightShoulder": arm(-20, 30), "LeftShoulder": arm(20, 30), "RightHip": (-20, 0, 0), "LeftHip": (-20, 0, 0),
                                      "RootPos": (0, 1.5, -2.0)}, "Out"),
                              k(0.62, {"Waist": (-40, 0, 0), "RightShoulder": arm(-15, -30), "LeftShoulder": arm(15, -30), "RootPos": (0, -0.6, -1.0),
                                       "RightKnee": (-50, 0, 0), "LeftKnee": (-50, 0, 0)}, "In"), k(0.95, {})], layer="Full")
BRUTE_UP = {"Waist": (15, -20, 0), "RightShoulder": arm(-20, 150), "RightElbow": (60, 0, 0), "LeftShoulder": arm(40, 30), "RootPos": (0, -0.3, 0.4)}
BRUTE_DOWN = {"Waist": (-35, 5, 0), "Neck": (20, 0, 0), "RightShoulder": arm(-5, -25), "RightElbow": (10, 0, 0), "LeftShoulder": arm(20, -60), "RootPos": (0, -0.9, -0.8),
              "RightHip": (35, 0, 0), "RightKnee": (-40, 0, 0), "LeftHip": (-20, 0, 0)}
clip("Brute_Smash", 1.35, [k(0.0, {}), k(0.7, BRUTE_UP, "Out"), k(0.84, BRUTE_DOWN, "In"), k(1.1, BRUTE_DOWN), k(1.35, {})], weapon="club", layer="Full")
clip("Brute_Sweep", 1.2, [k(0.0, {}), k(0.55, {"Waist": yaw(-55), "RightShoulder": arm(-130, 10), "RightElbow": (30, 0, 0), "RootPos": (0, -0.4, 0.2)}, "Out"),
                          k(0.72, {"Waist": yaw(50), "RightShoulder": arm(60, -10), "RightElbow": (10, 0, 0), "RootPos": (0, -0.5, -0.4)}, "Out"), k(1.2, {})],
     weapon="club", layer="Full")
clip("Brute_Stomp", 1.3, [k(0.0, {}), k(0.6, {"Waist": (10, 0, 5), "RightHip": (70, 0, 0), "RightKnee": (-70, 0, 0), "RightShoulder": arm(-60, 20), "LeftShoulder": arm(60, 20),
                                              "RootPos": (0, 0.4, 0)}, "Out"),
                          k(0.72, {"Waist": (-20, 0, 0), "RightHip": (-5, 0, 0), "RightKnee": (-10, 0, 0), "RightShoulder": arm(-40, -30), "LeftShoulder": arm(40, -30),
                                   "RootPos": (0, -0.6, 0)}, "In"), k(1.0, {"RootPos": (0, -0.4, 0)}), k(1.3, {})], layer="Full")
clip("Witch_Cast", 0.9, [k(0.0, {}), k(0.4, {"Waist": (10, -15, 0), "RightShoulder": arm(-30, 120), "RightElbow": (30, 0, 0), "LeftShoulder": arm(40, 20), "LeftElbow": (40, 0, 0)}, "Out"),
                         k(0.52, {"Waist": (-15, 10, 0), "RightShoulder": arm(-5, 20), "RightElbow": (10, 0, 0), "LeftShoulder": arm(10, 5)}, "Out"), k(0.9, {})], weapon="staff")
clip("Witch_Hex", 1.3, [k(0.0, {}), k(0.6, {"Waist": (15, 0, 0), "Neck": (-25, 0, 0), "RightShoulder": arm(-40, 150), "LeftShoulder": arm(40, 150), "RightElbow": (20, 0, 0), "LeftElbow": (20, 0, 0)}, "Out"),
                        k(0.9, {"Waist": (-20, 0, 0), "RightShoulder": arm(-30, 0), "LeftShoulder": arm(30, 0)}, "Out"), k(1.3, {})], weapon="staff", layer="Full")
clip("Witch_Swat", 0.7, [k(0.0, {}), k(0.25, {"Waist": yaw(-40), "RightShoulder": arm(-100, 30), "RightElbow": (30, 0, 0)}, "Out"),
                         k(0.36, {"Waist": yaw(35), "RightShoulder": arm(50, -10), "RightElbow": (10, 0, 0)}, "Out"), k(0.7, {})], weapon="staff")
clip("Lord_Swipe", 1.3, [k(0.0, {}), k(0.4, {"Waist": yaw(-45), "RightShoulder": arm(-120, 40), "RightElbow": (30, 0, 0)}, "Out"),
                         k(0.52, {"Waist": yaw(35), "RightShoulder": arm(40, -20), "RightElbow": (10, 0, 0)}, "Out"),
                         k(0.82, {"Waist": yaw(45), "LeftShoulder": arm(120, 40), "LeftElbow": (30, 0, 0)}, "Out"),
                         k(0.94, {"Waist": yaw(-35), "LeftShoulder": arm(-40, -20), "LeftElbow": (10, 0, 0)}, "Out"), k(1.3, {})], layer="Full")
LORD_UP = {"Waist": (20, 0, 0), "Neck": (-25, 0, 0), "RightShoulder": arm(-25, 160), "LeftShoulder": arm(25, 160), "RightElbow": (30, 0, 0), "LeftElbow": (30, 0, 0),
           "RootPos": (0, 0.4, 0.5)}
LORD_DOWN = {"Waist": (-50, 0, 0), "Neck": (35, 0, 0), "RightShoulder": arm(-15, -40), "LeftShoulder": arm(15, -40), "RightElbow": (10, 0, 0), "LeftElbow": (10, 0, 0),
             "RootPos": (0, -1.8, -1.5), "RightHip": (40, 0, 0), "LeftHip": (40, 0, 0), "RightKnee": (-60, 0, 0), "LeftKnee": (-60, 0, 0)}
clip("Lord_Slam", 1.8, [k(0.0, {}), k(1.0, LORD_UP, "Out"), k(1.16, LORD_DOWN, "In"), k(1.5, LORD_DOWN), k(1.8, {})], layer="Full")
clip("Lord_Roots", 1.5, [k(0.0, {}), k(0.7, {"Waist": (10, -20, 0), "RightShoulder": arm(-30, 150), "RightElbow": (40, 0, 0)}, "Out"),
                         k(0.85, {"Waist": (-40, 10, 0), "RightShoulder": arm(-10, -60), "RightElbow": (10, 0, 0), "RootPos": (0, -1.2, -0.8), "RightKnee": (-40, 0, 0)}, "In"),
                         k(1.2, {"Waist": (-30, 10, 0), "RootPos": (0, -1.0, -0.6)}), k(1.5, {})], layer="Full")
clip("Lord_Roar", 1.6, [k(0.0, {}), k(0.4, {"Waist": (25, 0, 0), "Neck": (-35, 0, 0), "RightShoulder": arm(-70, 30), "LeftShoulder": arm(70, 30), "RightElbow": (40, 0, 0), "LeftElbow": (40, 0, 0)}, "Out"),
                        k(1.2, {"Waist": (25, 0, 0), "Neck": (-35, 0, 0), "RightShoulder": arm(-80, 35), "LeftShoulder": arm(80, 35)}), k(1.6, {})], layer="Full")
clip("Lord_Summon", 1.4, [k(0.0, {}), k(0.6, {"Waist": (15, 0, 0), "RightShoulder": arm(-40, 140), "LeftShoulder": arm(40, 140), "RightElbow": (20, 0, 0), "LeftElbow": (20, 0, 0)}, "Out"),
                          k(1.0, {"Waist": (-10, 0, 0), "RightShoulder": arm(-60, -30), "LeftShoulder": arm(60, -30)}, "Out"), k(1.4, {})], layer="Full")
clip("Lord_Rain", 1.4, [k(0.0, {}), k(0.7, {"Neck": (-40, 0, 0), "RightShoulder": arm(-20, 170), "LeftShoulder": arm(20, 170)}, "Out"), k(1.4, {})], layer="Full")
