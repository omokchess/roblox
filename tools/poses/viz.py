"""포즈 시각화: 각 클립의 키프레임을 정면/측면/위 3면도로 그린 시트 PNG.

    python tools/poses/viz.py [클립이름 ...]
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from fk import BONES, solve, weapon_segment  # noqa: E402
from clips import CLIPS, WEAPON_LEN  # noqa: E402

OUT = HERE.parents[1] / "assets" / "previews" / "poses"
S = 26  # px per stud
CELL = (220, 220)


def proj(p, view):
    x, y, z = p
    if view == "front":   # 정면 (카메라가 -Z 쪽에서 캐릭터를 봄): 화면 x = -X(거울) 대신 X 그대로
        return (CELL[0] / 2 - x * S, CELL[1] * 0.55 - y * S)
    if view == "side":    # 오른쪽에서 봄: 화면 x = -Z (전방이 오른쪽)
        return (CELL[0] / 2 - z * S, CELL[1] * 0.55 - y * S)
    return (CELL[0] / 2 + x * S, CELL[1] / 2 + z * S)  # top: 위에서, 전방(-Z)이 위


def draw_pose(img, ox, oy, pose, root, weapon, view, label):
    d = ImageDraw.Draw(img)
    sol = solve(pose, root)
    def P(p):
        u, v = proj(p, view)
        return (ox + u, oy + v)
    d.rectangle([ox, oy, ox + CELL[0] - 2, oy + CELL[1] - 2], outline=(70, 70, 70))
    # 지면선
    if view != "top":
        g = P(np.array([0, -3.0, 0]))[1]
        d.line([ox, g, ox + CELL[0], g], fill=(60, 80, 60))
    for a, b in BONES:
        pa, pb = sol[a][0], sol[b][0]
        col = (230, 120, 110) if "Right" in b else ((110, 160, 230) if "Left" in b else (220, 220, 220))
        d.line([P(pa), P(pb)], fill=col, width=3)
    # 머리
    hp = sol["Neck"][0] + sol["Neck"][1] @ np.array([0, 0.6, 0])
    x, y = P(hp)
    d.ellipse([x - 9, y - 9, x + 9, y + 9], outline=(230, 230, 230), width=2)
    # 시선(얼굴 앞)
    fp = hp + sol["Neck"][1] @ np.array([0, 0, -0.8])
    d.line([P(hp), P(fp)], fill=(255, 255, 0), width=2)
    if weapon:
        for side in weapon:
            hand, tip, pommel = weapon_segment(sol, blade=WEAPON_LEN.get(side[1], 4.5), side=side[0])
            d.line([P(pommel), P(tip)], fill=(250, 220, 90), width=4)
            d.ellipse([P(tip)[0] - 3, P(tip)[1] - 3, P(tip)[0] + 3, P(tip)[1] + 3], fill=(255, 80, 60))
    d.text((ox + 4, oy + 3), label, fill=(240, 240, 240))


def render(name, clip):
    keys = clip["keys"]
    views = ("front", "side", "top")
    W = CELL[0] * len(keys)
    H = CELL[1] * len(views) + 24
    img = Image.new("RGB", (W, H), (24, 26, 30))
    d = ImageDraw.Draw(img)
    d.text((6, 4), f"{name}  dur={clip['dur']}  weapon={clip.get('weapon')}", fill=(255, 220, 140))
    wpn = clip.get("weapon")
    weapon = [("Right", wpn)] if wpn else None
    for i, k in enumerate(keys):
        t, pose = k[0], k[1]
        root = pose.get("RootPos", (0, 0, 0))
        joints = {j: v for j, v in pose.items() if j != "RootPos"}
        for vi, v in enumerate(views):
            draw_pose(img, i * CELL[0], 24 + vi * CELL[1], joints, root, weapon, v, f"t={t:.2f} {v}")
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def main():
    names = sys.argv[1:] or list(CLIPS.keys())
    for n in names:
        render(n, CLIPS[n])
    print("rendered", len(names))


if __name__ == "__main__":
    main()
