# -*- coding: utf-8 -*-
"""
audit_struct.py — 2026-11-08. 설원 마을 키트(build_steam_town JOBS) 구조 점검 — "실제 건물 올리듯 공사".
사용자: "난간 위에 기둥이 올려져 있어선 안 돼. 모델링할 때 예쁜가만 따지지 말고 실제 건물 올릴 때처럼 공사를 해야 해."

모델마다 지은 뒤(내보내지 않음) 메시 덩이(이어진 조각)를 모아:
  1. 난간 위 기둥 — 세운 덩이(높이 ≥ 2, 굵기 0.5~4, 높이 ≥ 1.5×굵기)의 밑면 바로 밑(±0.35)에 받치는 것이 가는 가로대(난간 윗대)뿐
  2. 뜬 기둥     — 돌·벽돌·대리석 기둥의 밑면 밑에 아무것도 없음(바닥 0.5 위)
  3. 얇은 받침   — 받치는 것이 기둥보다 훨씬 가늚(받침 굵기 < 기둥 굵기 × 0.5)
돌리기: blender -b -P models/audit_struct.py [-- 모델이름,모델이름]   → models/audit_struct.txt
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_steam_town as T  # noqa: E402
import build_steam as S  # noqa: E402
import hanok_lib as L  # noqa: E402

STRUCT = {"Stone", "StoneTrim", "Marble", "Brick", "DarkStone", "Concrete", "Granite"}
SKIP = {"Cut", "Pane", "LampPt", "Vent", "Glow", "GlowTeal", "Steam", "Smoke"}
TOL = 0.35


def islands(g):
    out = []
    for k, grp in g.items():
        if k in SKIP or not grp.bm.verts:
            continue
        for vs, fs in S._comps(grp.bm):
            lo, hi = S._aabb([v.co for v in vs])
            out.append((k, lo, hi))
    return out


def is_pillar(k, lo, hi):
    fx, fy, h = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    w = max(fx, fy)
    return h >= 2.0 and 0.5 <= min(fx, fy) and w <= 4.0 and h >= 1.5 * w


def is_rail(k, lo, hi):
    fx, fy, h = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    return min(fx, fy) <= 0.6 and max(fx, fy) >= 1.5 and h <= 0.6


def audit(name, isl):
    found = []
    for i, (k, lo, hi) in enumerate(isl):
        if not is_pillar(k, lo, hi):
            continue
        cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
        w = min(hi[0] - lo[0], hi[1] - lo[1])
        z = lo[2]
        sup = []
        for j, (k2, lo2, hi2) in enumerate(isl):
            if j == i or abs(hi2[2] - z) > TOL:
                continue
            # 기둥 밑면 가운데 둘레(굵기의 절반 원)와 겹치는가
            r = w * 0.25
            if lo2[0] - r <= cx <= hi2[0] + r and lo2[1] - r <= cy <= hi2[1] + r:
                sup.append((k2, lo2, hi2))
        # 기둥이 다른 덩이 속에 묻혀 서 있으면(밑면이 덩이 안) 받침 있음
        inside = any(j != i and lo2[0] <= cx <= hi2[0] and lo2[1] <= cy <= hi2[1] and lo2[2] - 0.05 <= z < hi2[2] - 0.05
                     for j, (k2, lo2, hi2) in enumerate(isl))
        tag = None
        if sup and all(is_rail(*s) for s in sup) and not inside:
            tag = "난간 위 기둥"
        elif not sup and not inside and z > 0.5 and k in STRUCT:
            tag = "뜬 기둥"
        elif sup and not inside:
            sw = max(min(s[2][0] - s[1][0], s[2][1] - s[1][1]) for s in sup)
            if sw < 0.5 * w and k in STRUCT:
                tag = "얇은 받침(%.2f < 기둥 %.2f)" % (sw, w)
        if tag:
            found.append("  %s: %s %s  자리(블렌더) x %.1f..%.1f y %.1f..%.1f z %.1f..%.1f  받침 %s" % (
                name, tag, k, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2],
                ", ".join("%s(%.1f×%.1f top %.2f)" % (s[0], s[2][0] - s[1][0], s[2][1] - s[1][1], s[2][2]) for s in sup[:4]) or "없음"))
    return found


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(args[0].split(",")) if args else None
    lines = ["설원 마을 키트 구조 점검 (audit_struct.py)"]
    L.clear_scene()
    for name, prefix, fn in T.JOBS:
        if only and name not in only:
            continue
        g = T.G(prefix)
        try:
            fn(g)
        except Exception as e:  # noqa: BLE001
            lines.append("  %s: 짓기 실패 %r" % (name, e))
            continue
        isl = islands(g)
        f = audit(name, isl)
        print("%-16s 덩이 %5d  걸림 %d" % (name, len(isl), len(f)))
        lines.append("%s (덩이 %d): %d" % (name, len(isl), len(f)))
        lines += f
        for grp in g.values():
            grp.bm.free()
    out = os.path.join(HERE, "audit_struct.txt")
    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("→", out)


main()
