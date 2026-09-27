"""clips.py -> src/ReplicatedStorage/Shared/Combat/PoseLibrary.luau (+ 선택: 모든 클립 시트 렌더)

    python tools/poses/gen_luau.py [--render]
"""

import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from clips import CLIPS, HOLD  # noqa: E402
from fk import rot_of  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "src" / "ReplicatedStorage" / "Shared" / "Combat" / "PoseLibrary.luau"

UPPER = {"Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist"}


def f(v):
    r = round(float(v), 4)
    if r == 0:
        return "0"
    if r == int(r):
        return str(int(r))
    return repr(r)


def mat(v):
    R = rot_of(v)
    return "R(" + ", ".join(f(R[i][j]) for i in range(3) for j in range(3)) + ")"


lines = [
    "--!strict",
    "-- 자동 생성 파일 (tools/poses/gen_luau.py ← tools/poses/clips.py). 직접 수정하지 마세요.",
    "-- 관절 회전은 부모 파트 공간 기준 회전 행렬 (Motor6D C0 회전으로 켤레 변환해 적용)",
    "",
    "export type Key = { t: number, ease: string, joints: { [string]: CFrame }, root: Vector3? }",
    "export type Clip = { Duration: number, Layer: string, Loop: boolean, Hold: boolean, Weapon: string?, Keys: { Key } }",
    "",
    "local function R(a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number): CFrame",
    "\treturn CFrame.new(0, 0, 0, a, b, c, d, e, f, g, h, i)",
    "end",
    "",
    "local Clips: { [string]: Clip } = {}",
    "",
]
for name, c in CLIPS.items():
    if name == "Calib":
        continue
    lines.append(f"Clips.{name} = {{")
    lines.append(f"\tDuration = {f(c['dur'])},")
    lines.append(f"\tLayer = \"{c['layer']}\",")
    lines.append(f"\tLoop = {'true' if c['loop'] else 'false'},")
    lines.append(f"\tHold = {'true' if c['hold'] else 'false'},")
    if c.get("weapon"):
        lines.append(f"\tWeapon = \"{c['weapon']}\",")
    lines.append("\tKeys = {")
    for (t, pose, ease) in c["keys"]:
        parts = []
        for j, v in pose.items():
            if j == "RootPos":
                continue
            if c["layer"] == "Upper" and j not in UPPER:
                continue
            parts.append(f"{j} = {mat(v)}")
        root = pose.get("RootPos")
        root_s = f", root = Vector3.new({f(root[0])}, {f(root[1])}, {f(root[2])})" if root is not None and c["layer"] == "Full" else ""
        lines.append(f"\t\t{{ t = {f(t)}, ease = \"{ease}\", joints = {{ {', '.join(parts)} }}{root_s} }},")
    lines.append("\t},")
    lines.append("}")
lines.append("")
lines.append("-- 무기 종류 -> 들기 자세 클립")
lines.append("local Holds: { [string]: string } = { cleaver = \"Hold_Cleaver\", spear = \"Hold_Spear\", maul = \"Hold_Maul\" }")
lines.append("")
lines.append("return { Clips = Clips, Holds = Holds }")
lines.append("")
OUT.write_text("\n".join(lines), encoding="utf-8")
print("[poses] wrote", OUT.relative_to(ROOT), len(CLIPS) - 1, "clips")

if "--render" in sys.argv:
    import viz
    for n in CLIPS:
        viz.render(n, CLIPS[n])
    print("[poses] rendered sheets")
