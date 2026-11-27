# -*- coding: utf-8 -*-
"""
figuren_check.py — 2026-11-24 아트 1팀. 기물군 본부(Figuren_HQ, 2판 키트)를 설원 3판 검사에 넣는 연결 + 통로 폭 검사.

1) 구멍 검사(models/snow3/holes.py 그대로): holes.py 가 HOLES_MOD 로 이 파일을 모듈처럼 불러 NAME·PREFIX·build·INFO 를 쓴다.
   HOLES_MOD=models/figuren_check.py HOLES_OUT=models/render/figuren_holes.txt "$BL" -b -P models/snow3/holes.py
   (build 는 2판 키트와 같게 창을 벽 두께로 뚫는다 — build_steam_figuren.JOBS 의 job(cut=T) 와 같은 결과)
2) 통로 폭: "$BL" -b -P models/figuren_check.py -- walk  → models/render/figuren_walk.txt
   길·방 10 / 문 8 (사용자 바이블 9절: 지나다니는 길 10, 문 8). 가장 좁은 자리가 문 안(문 둘레 1.5)이면 문 기준을 쓴다.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_steam_town as TOWN  # noqa: E402  (먼저 — build_steam_figuren 과 서로 부르는 순서)
import build_steam_figuren as FIG  # noqa: E402

NAME = "Figuren_HQ"
PREFIX = "FiguIn"
ZF, Z1 = FIG.ZF, FIG.Z1


def build(g):
    TOWN.S.CUT_T = FIG.T          # job(cut=T) 처럼 창을 벽 두께로 뚫는다(이 함수를 감싼 snow3 job 이 끝에 apply_cuts 를 부른다)
    FIG.figuren_in(g)
    try:                          # holes.py 문 판정: 관문 아치(x ±4, 높이 9 + 반원 4) — 2판 키트는 lib.door_open 을 안 써서 직접 적는다
        import lib as K3
        K3.DOOR_INFO[NAME] = [((0.0, FIG.GY0), 8.6, 13.0, -1, "x")]
    except ImportError:
        pass


INFO = {
    "hole_seeds": [(0, -30.0, ZF + 4.5), (0, -21.0, ZF + 4.5), (0, 0.0, ZF + 4.5), (0, 22.0, ZF + 4.5), (-15, 10, ZF + 4.5), (15, 10, ZF + 4.5),
                   (-30.5, -12, ZF + 4.5), (30.5, -12, ZF + 4.5), (-29, 14, ZF + 4.5), (29, 14, ZF + 4.5),
                   (0, -21.5, Z1 + 4.5), (0, -29.5, Z1 + 4.5), (-18, 0, Z1 + 4.5), (18, 0, Z1 + 4.5), (0, 26, Z1 + 4.5),
                   (-30, -12, Z1 + 4.5), (30, -12, Z1 + 4.5), (-30, 12, Z1 + 4.5), (30, 12, Z1 + 4.5)],
}
# 문(가운데 x, y, 폭) — 가장 좁은 자리가 여기서 1.5 안이면 문 기준 8
DOORS = [((0.0, -33.4), 8.6), ((0.0, -16.0), 10.0), ((-24.0, -21.6), 8.4), ((24.0, -21.6), 8.4), ((-24.0, 6.0), 8.4), ((24.0, 6.0), 8.4),
         ((0.0, -16.0), 8.4), ((-24.0, 2.0), 8.4), ((24.0, 2.0), 8.4)]
LOWER = [("관문 → 로비", (0, -37.0), (0, -21.0)), ("로비 → 홀(큰 문)", (0, -21.0), (0, -8.0)),
         ("로비 → 왼 날개 문 안", (0, -20.6), (-26.5, -21.6)), ("로비 → 오른 날개 문 안", (0, -20.6), (26.0, -21.6)),
         ("홀 → 왼 날개(뒤 문) 안", (-6, 7.6), (-26.5, 6.0)), ("홀 → 오른 날개(뒤 문) 안", (6, 7.6), (26.5, 6.0)),
         ("홀 가운데 → 접수대 앞", (0, 0.0), (0, 19.0))]
# 날개 위 끝점 x ±27.5 → ±27.0(2026-11-27): 계단 폭 6(x ±30.8~)이라 ±27.5 칸은 계단 구멍 모서리 난간에서 3.7 — 문 가운데(y 2) 문 안 2.5 로
UPPER = [("앞 회랑 → 왼 서고(뒤 문)", (-17.5, 6.0), (-27.0, 2.0)), ("앞 회랑 → 길드장 방(뒤 문)", (17.5, 6.0), (27.0, 2.0)),
         ("앞 회랑 → 작전실 문", (0, -9.5), (0, -17.5))]
# 날개 계단(2026-11-27 꺾인 계단): 마디 폭 6.15 둘이 날개 안 폭 12.3 을 다 쓴다(옆 길 없음) — 마디 폭은 구조로 정해져 따로 재지 않는다
# ponytail: 방 안 가구 사이는 재지 않는다(작전실은 탁자·의자가 문에서 4.2 — 보고의 남은 일)


def walk():
    import math
    sys.path.insert(0, os.path.join(HERE, "snow3"))
    src = open(os.path.join(HERE, "snow3", "audit.py"), encoding="utf-8").read()
    src = src[:src.rstrip().rfind("main()")]
    A = {"__name__": "audit_lib", "__file__": os.path.join(HERE, "snow3", "audit.py")}
    exec(compile(src, "audit.py", "exec"), A)
    K = A["K"]
    K.L.clear_scene()
    g = TOWN.G(PREFIX)
    K.I.job(NAME, build)(g)
    hall_void = (-11.2, 11.2, -4.1, 19.5)          # 위층: 홀 가운데(회랑 안쪽)는 바닥이 없다
    stairs = [(24.5, 36.8, FIG.SA, 30.8), (-36.8, -24.5, FIG.SA, 30.8)]      # 2026-11-27 꺾인 계단: 위층 바닥은 y SA 에서 끝(계단실은 날개 폭 전부)
    lines, bad = ["figuren_check.py walk — 기물군 본부 통로 폭(길 10 / 문 8, 0.5 격자)"], 0
    for floor, paths, voids in ((ZF, LOWER, []), (Z1, UPPER, [hall_void] + stairs)):
        for label, a, b in paths:
            info = {"floor": floor, "inside": (-36.8, 36.8, min(a[1], b[1]) - 2.0, 30.8), "walk": (a, b),
                    "free": (b[0] - 2.5, b[0] + 2.5, b[1] - 0.5, b[1] + 4.5), "voids": voids}
            w, at, _ = A["walk_width"](NAME, info)
            near_door = any(math.hypot(at[0] - p[0], at[1] - p[1]) < max(1.5, dw / 2 + 0.5) for p, dw in DOORS)
            need = 8.4 if label.startswith("관문") else (8.0 if near_door else 10.0)    # 바이블 9절: 지나다니는 길 10 · 문 8(비평 본부_2차 4번 — 2026-11-27 길 기준 8 → 10)
            ok = w >= need - 0.5 - 1e-6             # 0.5 격자: 칸 가운데가 최대 0.25 어긋나 폭이 최대 0.5 작게 재진다
            bad += not ok
            lines.append("%-26s 바닥 %.1f  폭 %.1f  (가장 좁은 자리 x %.1f y %.1f — %s 기준 %g) → %s" % (
                label, floor, w, at[0], at[1], "문" if near_door else "길", need, "통과" if ok else "걸림"))
    lines.append("걸림 %d" % bad)
    out = os.path.join(HERE, "render", "figuren_walk.txt")
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if "--" in sys.argv and "walk" in sys.argv[sys.argv.index("--") + 1:]:
    walk()
