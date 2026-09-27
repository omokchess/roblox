"""R15 순운동학(FK) 미리보기 — Roblox 의 CFrame.Angles / Motor6D.Transform 규칙을 그대로 흉내.

좌표: Roblox 캐릭터 공간 (X=오른쪽, Y=위, Z=뒤, 전방=-Z), 원점=HumanoidRootPart 중심.
관절 회전은 부모(Part0) 공간에서 관절점 기준 회전 (PoseLibrary 규칙과 동일):
    R = CFrame.Angles(rx, ry, rz) = Rx @ Ry @ Rz
"""

import math

import numpy as np


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def angles(deg):
    x, y, z = (math.radians(v) for v in deg)
    return rx(x) @ ry(y) @ rz(z)


# 관절 트리: 이름 -> (부모 관절, 부모 기준 휴지 오프셋)
# 휴지 자세의 관절 위치(HRP 기준, 클래식 R15)
REST = {
    "Root": (None, np.array([0.0, -1.0, 0.0])),
    "Waist": ("Root", np.array([0.0, 0.4, 0.0])),
    "Neck": ("Waist", np.array([0.0, 1.6, 0.0])),
    "RightShoulder": ("Waist", np.array([1.0, 1.36, 0.0])),
    "RightElbow": ("RightShoulder", np.array([0.5, -0.72, 0.0])),
    "RightWrist": ("RightElbow", np.array([0.0, -0.76, 0.0])),
    "LeftShoulder": ("Waist", np.array([-1.0, 1.36, 0.0])),
    "LeftElbow": ("LeftShoulder", np.array([-0.5, -0.72, 0.0])),
    "LeftWrist": ("LeftElbow", np.array([0.0, -0.76, 0.0])),
    "RightHip": ("Root", np.array([0.5, -0.2, 0.0])),
    "RightKnee": ("RightHip", np.array([0.0, -0.84, 0.0])),
    "RightAnkle": ("RightKnee", np.array([0.0, -0.84, 0.0])),
    "LeftHip": ("Root", np.array([-0.5, -0.2, 0.0])),
    "LeftKnee": ("LeftHip", np.array([0.0, -0.84, 0.0])),
    "LeftAnkle": ("LeftKnee", np.array([0.0, -0.84, 0.0])),
}
ORDER = list(REST.keys())
BONES = [
    ("Root", "Waist"), ("Waist", "Neck"), ("Waist", "RightShoulder"), ("Waist", "LeftShoulder"),
    ("RightShoulder", "RightElbow"), ("RightElbow", "RightWrist"), ("LeftShoulder", "LeftElbow"), ("LeftElbow", "LeftWrist"),
    ("Root", "RightHip"), ("Root", "LeftHip"), ("RightHip", "RightKnee"), ("RightKnee", "RightAnkle"),
    ("LeftHip", "LeftKnee"), ("LeftKnee", "LeftAnkle"),
]


def rot_of(v):
    """(rx,ry,rz) 도 또는 3x3 행렬 -> 3x3 행렬."""
    if v is None:
        return np.eye(3)
    if isinstance(v, np.ndarray):
        return v
    return angles(v)


def solve(pose, root_offset=(0, 0, 0)):
    """pose: {joint: (rx,ry,rz) 도 | 3x3}. 반환: {joint: (world_pos, world_rot)}."""
    out = {}
    for j in ORDER:
        parent, off = REST[j]
        Rj = rot_of(pose.get(j))
        if parent is None:
            p = off + np.array(root_offset, dtype=float)
            R = Rj
        else:
            pp, pR = out[parent]
            p = pp + pR @ off
            R = pR @ Rj
        out[j] = (p, R)
    return out


def weapon_segment(sol, grip_len=0.35, blade=4.5, side="Right"):
    """손목에서 손(0.35 아래) → 그립은 손의 -Z 방향으로 칼날."""
    wp, wR = sol[f"{side}Wrist"]
    hand = wp + wR @ np.array([0, -grip_len, 0])
    # Grip = CFrame.new(0,-0.15,0) * CFrame.Angles(-90°,0,0): 무기 +Y -> 손 -Z
    tip = hand + wR @ np.array([0, 0, -blade])
    pommel = hand + wR @ np.array([0, 0, 0.6])
    return hand, tip, pommel
