# -*- coding: utf-8 -*-
"""
snow3/lib.py — 2026-11-13. 설원 마을(슈네라이히) 3판 건물 공용 부품. 레퍼런스: 회사/설원마을_레퍼런스.md

■ 쓰는 법(건물 파일 하나 = 모델 하나, b_smithy.py 가 본보기)
    models/snow3/b_<이름>.py 에
        NAME = "Sn3_<이름>"          # Studio 모델 이름(PREFIX 와 짝으로 tools/snow3_kit.json 에 적힌다)
        PREFIX = "Sn3<이름>"         # 메시 앞머리(메시 이름 = 앞머리_재질)
        def build(g): ...            # g = 재질 이름 → 덩이(L.Group). 아래 부품만 불러 짓는다
    build_kit.py 가 b_*.py 를 모두 찾아 짓는다(ONLY=Sn3_Smithy 로 하나만). preview.py -- Sn3_Smithy 로 렌더.

■ 좌표 규칙(옛 키트와 같다)
    블렌더 (x 오른쪽, y 뒤, z 위), 앞(문 쪽) = -y, 원점 = 땅 위 발자국 가운데. 로블록스 로컬 = (-x, z, y).
    바닥 윗면 높이 FZ(= 돌 밑단 높이). 걸을 때 부딪히는 것은 C 상자로 따로 적는다(보이는 메시는 Studio 에서 충돌 끔).

■ 짓는 순서(실제 공사처럼 — 스타일바이블 9절, 사용자 2026-11-08)
    1. foundation   돌 밑단(기초) + 바닥 판                         → FZ
    2. log_wall / frame_wall   벽(구멍 = 문·창, 구멍 위아래는 나무 인방)
       gable_logs / gable_boards  박공벽(지붕선 아래까지만 — 도리가 그 위에 얹힌다)
    3. post / beam / tie_truss   기둥·보·평보(천장)·동자기둥(도리를 받침)
    4. roof_gable   도리(처마도리·중도리·마룻대) → 서까래 → 개판 → 덮개 → 눈.  처마·박공 내밈은 도리·서까래 끝이 받친다
    5. chimney      굴뚝은 땅(z 0)에서 시작해 지붕 위로
    6. door_open · window · stair · hang_sign · steam_bundle · counter   마감
    → audit.py 로 "난간 위 기둥·뜬 기둥·얇은 받침" 0 확인, 통로 폭 10 확인.

■ 부품(한 줄씩)
    foundation(g, x0,x1,y0,y1, h)            돌 밑단: 모르타르 심(StoneTrim) + 엇갈린 돌 두 켜(Stone) + 바닥 판, 충돌 상자
    log_wall(g, ax, c, u0,u1, z0,z1, holes)   짙은 통나무 벽(DarkLog). 모서리는 켜마다 엇갈려 끝이 0.9 튀어나온다(뢰로스·발저 집)
    frame_wall(g, ax, c, u0,u1, z0,z1, holes, stone_to)  돌 아랫벽 + 굵은 목재 뼈대(기둥·띠장·가새) + 세로 판벽(검은 숲)
    gable_logs / gable_boards(g, ax, c, half, z0, ztop_fn)   박공 세모(통나무 켜 / 세로 판)
    post(g,x,y,z0,z1) · beam(g, ax, c0, c1, a0,a1, z0,z1)   기둥(받침돌 위)·보(끝점으로)
    brace(g, ax, c, u0,z0, u1,z1)               까치발·가새(두 점 사이 비스듬한 각재)
    tie_truss(g, y, R, mat)                     평보(천장 높이) + 동자기둥(마룻대·중도리 받침) + 버팀대
    roof_frame(half, y0, y1, z_plate, 안) → R   지붕 치수 묶음(R.zb(x) 서까래 밑선, R.ridge, R.top())
    roof_gable(g, R, openings=[굴뚝])           맞배지붕 한 벌(굴뚝 자리 서까래는 받을보로 끊음)
    chimney(g, x0,x1,y0,y1, ztop)               땅에서 올라가는 돌 굴뚝 + 갓 + 김 표지(Vent)
    door_open(g, ax, c, u, w, h, z0, face)      문틀(문설주·인방·문지방) + 열어 둔 널문 둘 + 문 비울 자리(DOORWAY)
    window(g, ax, c, u, z0, w, h, face, t)      2×3 살창 + 맑은 유리 + 창턱(눈) + 열린 덧창
    stair(g, cx, y_top, width, rise, base_z)    한 단 1 · 디딤 1.5 계단 + 양옆 측판(돌), 충돌 상자
    hang_sign(g, x,y,z, along='x', icon)        벽·기둥에 박은 쇠 팔 + 매단 간판(양면 그림, 지금은 x 방향 팔만)
    steam_bundle(g, x,y, wall_pts)              돌 받침 위 구리 증기 통 + 압력계 + 손잡이 밸브 + 벽으로 드는 관 + 김
    counter(g, x0,x1,y0,y1)                     높이 3.5 · 깊이 2.5 카운터(놋쇠 모서리), 충돌 상자
    lantern · coal_bed · NPC · DOORWAY · CLEAR · C · box2   옛 도구 그대로(build_steam_inside 에서 가져옴)
    bx(끝점 상자) · cbox(충돌 상자만) · build_model(mod)   도우미 / 짓기(build_kit·preview 공용)

■ 치수 상수(설원마을_3판_사양.md 3절) — 부품이 이 값을 쓴다. 건물 파일은 숫자를 새로 정하지 말고 이것을 쓴다.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
sys.path.insert(0, MODELS)
import hanok_lib as L  # noqa: E402
import build_steam as S  # noqa: E402
import build_steam_inside as I  # noqa: E402
from build_steam_inside import C, NPC, DOORWAY, CLEAR, lantern, coal_bed, box2  # noqa: E402,F401
import build_steam_service as SVC  # noqa: E402  (간판 그림·칼 걸이·상자 — 읽기만)
import build_steam_town as T  # noqa: E402

# ------------------------------------------------------------------ 치수(사양 3절, 1인칭 R6)
DOOR_W, DOOR_H = 8.0, 9.0          # 보통 문
MAIN_W, MAIN_H = 10.4, 10.0        # 정문(대장간 작업장 문·은행·병원·여관) — 10 + 문설주 여유 0.4(통로 폭 10 을 문에서도 지키게)
WALK = 10.0                         # 주 통로·바깥 길 최소 폭
CEIL = 11.0                         # 천장(평보 밑) 높이 — 10~11
COUNTER_H, COUNTER_D = 3.5, 2.5
FREE = 10.0                         # 카운터 앞 빈 바닥 10×10
STEP_RISE, STEP_TREAD, STAIR_W = 1.0, 1.5, 8.0
EYE = 4.5                           # 1인칭 눈높이(바닥 위)

# ------------------------------------------------------------------ 양식(회사/설원마을_레퍼런스.md 공통 양식 표)
FZ = 2.0            # 돌 밑단 높이 = 바닥 윗면(뢰로스·발저 집: 벽 높이의 1/5~1/6)
LOG = 1.2           # 통나무 한 켜 높이(= 벽 두께). 실제 20~30cm 를 문 8 스케일에 맞춰 키움
LOG_END = 0.9       # 모서리 통나무 끝 내밈
EAVE_SIDE = 3.0     # 처마 내밈(서까래 끝)
EAVE_GABLE = 2.5    # 박공 내밈(도리 끝)
SNOW_T = 0.8        # 지붕 눈 두께
RAFTER_GAP = 2.5    # 서까래 간격
WIN_W, WIN_H, WIN_SILL = 3.0, 4.5, 3.5    # 창 폭:높이 = 1:1.5, 창턱 바닥 위 3.5
PITCH = {"A": 40.0, "B": 50.0}            # 지붕 물매(도) — A 통나무(뢰로스·알프스 40), B 검은 숲(50)

PAL = dict(T.PAL)
PAL.update({"DarkLog": "#3B2A1F"})        # 새 재질: 짙은 통나무(사양 4절 "짙은 원목") — Studio SKIN 에 넣을 것(보고서)


def G(prefix):
    return L.new_groups(prefix, PAL)


DOOR_INFO = {}      # 모델 이름 → [(문 가운데 블렌더 x, y, 폭, 높이, 바라보는 쪽)] — build_kit 이 json 에 적는다


def _name():
    return I._cur[0]


# ------------------------------------------------------------------ 상자 도우미
def bx(g, mat, x0, x1, y0, y1, z0, z1):
    """끝점 상자(충돌 없음)"""
    if x1 - x0 > 1e-4 and y1 - y0 > 1e-4 and z1 - z0 > 1e-4:
        g[mat].box((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)


def cbox(x0, x1, y0, y1, z0, z1):
    """충돌 상자만(끝점)"""
    C((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)


def wbox(g, mat, ax, c, t, u0, u1, z0, z1):
    """벽 좌표(ax = 벽이 뻗은 축 'x'|'y', c = 벽 가운데 선, t = 두께, u = 벽을 따라)로 상자"""
    if ax == "x":
        bx(g, mat, u0, u1, c - t / 2, c + t / 2, z0, z1)
    else:
        bx(g, mat, c - t / 2, c + t / 2, u0, u1, z0, z1)


def _minus(segs, a, b):
    out = []
    for s0, s1 in segs:
        if b <= s0 or a >= s1:
            out.append((s0, s1))
            continue
        if a > s0:
            out.append((s0, a))
        if b < s1:
            out.append((b, s1))
    return [s for s in out if s[1] - s[0] > 0.05]


# ------------------------------------------------------------------ 1. 기초
# 돌 길이 본보기(손으로 정한 순서 — 켜마다 어긋나게 시작점을 바꾼다)
_STONES = (2.6, 1.7, 3.1, 2.0, 2.4, 1.5, 2.9, 2.2)


def foundation(g, x0, x1, y0, y1, h=FZ, coll=True):
    """돌 밑단: 모르타르 심 + 둘레에 엇갈린 돌 두 켜(0.12 내밀어 줄눈이 보이게) + 윗면 바닥 판(Stone). 돌려주는 값 = 바닥 높이"""
    bx(g, "StoneTrim", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, 0, h - 0.1)
    bx(g, "Stone", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, h - 0.1, h)
    rows = 2
    rh = (h - 0.1) / rows
    for r in range(rows):
        z0, z1 = r * rh + 0.04, (r + 1) * rh - 0.04
        for side, (a0, a1, fixed, ax, out) in enumerate(((x0, x1, y0, "x", -1), (x0, x1, y1, "x", 1),
                                                          (y0, y1, x0, "y", -1), (y0, y1, x1, "y", 1))):
            u, k = a0 + 0.1, (r * 3 + side * 2) % len(_STONES)
            while u < a1 - 0.3:
                ln = min(_STONES[k % len(_STONES)], a1 - 0.1 - u)
                k += 1
                if ln < 0.4:
                    break
                n0, n1 = sorted((fixed + out * 0.12, fixed - out * 0.5))     # 바깥으로 0.12 내민 돌(줄눈이 보이게)
                if ax == "x":
                    bx(g, "Stone", u + 0.04, u + ln - 0.04, n0, n1, z0, z1)
                else:
                    bx(g, "Stone", n0, n1, u + 0.04, u + ln - 0.04, z0, z1)
                u += ln
    if coll:
        cbox(x0, x1, y0, y1, 0, h)
    return h


# ------------------------------------------------------------------ 2. 벽
def log_wall(g, ax, c, u0, u1, z0, z1, holes=(), parity=0, t=LOG, mat="DarkLog", coll=True, ends=(True, True)):
    """
    통나무 벽. u0·u1 = 맞닿는 벽 가운데 선(모서리). parity 0/1 = 이 벽이 모서리를 차지하는 켜(맞은 벽과 반대로).
    켜마다 깊이를 t / 0.84t 로 바꿔 통나무 사이 그늘 줄이 생긴다. 모서리 켜는 끝이 LOG_END 튀어나온다(ends 로 끔 — 굴뚝·다른 채에 붙을 때).
    holes = [(a, b, za, zb)] 문·창 구멍. 구멍에 걸린 켜는 끊고, 구멍 위·아래 남는 틈은 나무 인방·창턱 판(Timber)으로 메운다(실제 통나무집 문틀).
    """
    n = max(1, int(round((z1 - z0) / LOG)))
    ch = (z1 - z0) / n
    for k in range(n):
        za, zb = z0 + k * ch, z0 + (k + 1) * ch
        own = (k + parity) % 2 == 0
        a = u0 - (t / 2 + LOG_END if ends[0] else t / 2) if own else u0 + t / 2
        b = u1 + (t / 2 + LOG_END if ends[1] else t / 2) if own else u1 - t / 2
        segs = [(a, b)]
        for h0, h1, hz0, hz1 in holes:
            if hz0 < zb - 0.01 and hz1 > za + 0.01:
                segs = _minus(segs, h0, h1)
        tt = t if k % 2 == 0 else t * 0.84
        for s0, s1 in segs:
            wbox(g, mat, ax, c, tt, s0, s1, za, zb)
    # 구멍 둘레: 인방(위)·창턱 판(아래)·문설주 판(옆)
    for h0, h1, hz0, hz1 in holes:
        top = z0 + math.ceil((hz1 - z0) / ch - 1e-6) * ch
        bot = z0 + math.floor((hz0 - z0) / ch + 1e-6) * ch
        if top - hz1 > 0.02:
            wbox(g, "Timber", ax, c, t * 0.9, h0 - 0.3, h1 + 0.3, hz1, min(top, z1))
        if hz0 - bot > 0.02:
            wbox(g, "Timber", ax, c, t * 0.9, h0 - 0.3, h1 + 0.3, bot, hz0)
        for e0, e1 in ((h0 - 0.3, h0), (h1, h1 + 0.3)):
            wbox(g, "Timber", ax, c, t + 0.1, e0, e1, max(bot, z0), min(top, z1))
    if coll:
        _wall_coll(ax, c, t, u0 - t / 2, u1 + t / 2, z0, z1, holes)


def frame_wall(g, ax, c, u0, u1, z0, z1, holes=(), stone_to=None, t=LOG, post_gap=4.0, coll=True, face=1):
    """
    검은 숲식 벽: (stone_to 까지) 돌 아랫벽 → 그 위 문턱보(sill) → 기둥(모서리·구멍 양옆·4 간격) → 머리보 → 세로 판(Timber)을 뼈대 안쪽으로 0.2 들여 채움,
    모서리 기둥 옆에 가새. holes 는 log_wall 과 같다(문 구멍은 돌벽도 끊는다). face = 바깥 쪽 부호(가새·판 들임 방향)
    """
    zs = z0 if stone_to is None else stone_to
    segs_full = [(u0 - t / 2, u1 + t / 2)]
    if stone_to is not None:
        segs = list(segs_full)
        for h0, h1, hz0, hz1 in holes:
            if hz0 < zs - 0.01:
                segs = _minus(segs, h0, h1)
        for s0, s1 in segs:
            wbox(g, "StoneTrim", ax, c, t + 0.1, s0, s1, z0, zs)
            u = s0
            k = int(abs(s0) * 7) % len(_STONES)
            rows = max(1, int(round((zs - z0) / 1.1)))
            rh = (zs - z0) / rows
            for r in range(rows):
                u, k = s0, k + 3
                while u < s1 - 0.3:
                    ln = min(_STONES[k % len(_STONES)] * 0.8, s1 - u)
                    k += 1
                    wbox(g, "Stone", ax, c, t + 0.3, u + 0.05, u + ln - 0.05, z0 + r * rh + 0.05, z0 + (r + 1) * rh - 0.05)
                    u += ln
    # 문턱보(돌벽 위 / 바닥 위)
    sw = 0.9
    sill_segs = list(segs_full)
    for h0, h1, hz0, hz1 in holes:
        if hz0 <= zs + sw:
            sill_segs = _minus(sill_segs, h0, h1)
    for s0, s1 in sill_segs:
        wbox(g, "DarkLog", ax, c, t, s0, s1, zs, zs + sw)
    head = z1 - sw
    wbox(g, "DarkLog", ax, c, t, u0 - t / 2, u1 + t / 2, head, z1)
    # 기둥 자리: 모서리 + 구멍 양옆 + 사이 간격
    ps = {round(u0, 2), round(u1, 2)}
    for h0, h1, hz0, hz1 in holes:
        ps |= {round(h0 - 0.45, 2), round(h1 + 0.45, 2)}
    ps = sorted(ps)
    fill = []
    for a, b in zip(ps, ps[1:]):
        n = int((b - a) / post_gap)
        fill += [a + (b - a) * (i + 1) / (n + 1) for i in range(n)]
    ps = sorted(set(ps) | {round(p, 2) for p in fill})
    pw = 0.9
    for p in ps:
        inside = any(h0 < p < h1 and hz0 < head and hz1 > zs + sw for h0, h1, hz0, hz1 in holes)
        if inside:
            continue
        # 문 구멍 옆 기둥은 바닥(z0)부터 — 문턱보가 끊긴 곳
        door_side = any(abs(p - (h0 - 0.45)) < 0.01 or abs(p - (h1 + 0.45)) < 0.01 for h0, h1, hz0, hz1 in holes if hz0 <= zs + sw)
        pz0 = z0 if door_side else zs + sw
        wbox(g, "DarkLog", ax, c, t, p - pw / 2, p + pw / 2, pz0, head)
    # 띠장(창턱·창 머리 높이) + 판
    for a, b in zip(ps, ps[1:]):
        a1, b1 = a + pw / 2, b - pw / 2
        if b1 - a1 < 0.3:
            continue
        hole = [h for h in holes if h[0] < b1 and h[1] > a1]
        if hole:
            h0, h1, hz0, hz1 = hole[0]
            if hz0 > zs + sw + 0.1:
                wbox(g, "DarkLog", ax, c, t * 0.9, a1, b1, hz0 - 0.5, hz0)
                _boards(g, ax, c, t, a1, b1, zs + sw, hz0 - 0.5, face)
            if hz1 < head - 0.1:
                wbox(g, "DarkLog", ax, c, t * 0.9, a1, b1, hz1, hz1 + 0.6)
                _boards(g, ax, c, t, a1, b1, hz1 + 0.6, head, face)
            continue
        mid = (zs + sw + head) / 2
        wbox(g, "DarkLog", ax, c, t * 0.9, a1, b1, mid - 0.35, mid + 0.35)
        _boards(g, ax, c, t, a1, b1, zs + sw, mid - 0.35, face)
        _boards(g, ax, c, t, a1, b1, mid + 0.35, head, face)
    # 모서리 가새(아래 띠장 ~ 머리보, 모서리 기둥 안쪽 칸)
    for p, s in ((ps[0], 1), (ps[-1], -1)):
        nxt = ps[1] if s > 0 else ps[-2]
        span = abs(nxt - p) - pw
        if span < 1.5:
            continue
        mid = (zs + sw + head) / 2
        L_ = math.hypot(span, head - mid)
        ang = math.atan2(head - mid, span)
        cu = p + s * (pw / 2 + span / 2)
        cz = (mid + head) / 2
        if ax == "x":
            g["DarkLog"].obox(cu, c + face * 0.05, cz, L_, t * 0.85, 0.6, ry=-s * ang)
        else:
            g["DarkLog"].obox(c + face * 0.05, cu, cz, t * 0.85, L_, 0.6, rx=s * ang)
    if coll:
        _wall_coll(ax, c, t, u0 - t / 2, u1 + t / 2, z0, z1, holes)


def _boards(g, ax, c, t, a, b, z0, z1, face):
    """세로 판(폭 1, 하나 걸러 0.1 두껍게 — 덧판 그늘). 뼈대보다 바깥 면에서 0.2 들인다"""
    if z1 - z0 < 0.1:
        return
    n = max(1, int(round((b - a) / 1.0)))
    w = (b - a) / n
    for i in range(n):
        th = t * 0.55 + (0.12 if i % 2 else 0.0)
        off = face * (t / 2 - 0.2 - th / 2)
        wbox(g, "Timber", ax, c + off, th, a + i * w, a + (i + 1) * w, z0, z1)


def _wall_coll(ax, c, t, a, b, z0, z1, holes):
    segs = [(a, b)]
    for h0, h1, hz0, hz1 in holes:
        if hz0 <= z0 + 0.5:                      # 바닥까지 내려온 구멍(문)만 길이 된다
            segs = _minus(segs, h0, h1)
            if hz1 >= z1 - 0.05:                 # 벽 끝까지 뚫린 자리(굴뚝)는 그 덩이가 충돌을 맡는다
                continue
            if ax == "x":
                cbox(h0, h1, c - t / 2, c + t / 2, hz1, z1)
            else:
                cbox(c - t / 2, c + t / 2, h0, h1, hz1, z1)
    for s0, s1 in segs:
        if ax == "x":
            cbox(s0, s1, c - t / 2, c + t / 2, z0, z1)
        else:
            cbox(c - t / 2, c + t / 2, s0, s1, z0, z1)


def gable_logs(g, ax, c, half, z0, ztop_at, t=LOG, mat="DarkLog", holes=()):
    """통나무 박공: z0(벽 윗면)부터 켜마다 지붕 밑선(ztop_at(u) = 그 자리 서까래 밑)까지만 짧아진다. 맨 위는 마룻대 밑"""
    k = 0
    while True:
        za, zb = z0 + k * LOG, z0 + (k + 1) * LOG
        # 켜 윗면이 지붕 밑에 닿는 |u|
        lo, hi = 0.0, half
        for _ in range(30):
            m = (lo + hi) / 2
            if ztop_at(m) > zb + 0.05:
                lo = m
            else:
                hi = m
        w = lo
        if w < 0.6:
            break
        segs = [(-w, w)]
        for h0, h1, hz0, hz1 in holes:
            if hz0 < zb and hz1 > za:
                segs = _minus(segs, h0, h1)
        tt = t if k % 2 == 0 else t * 0.84
        for s0, s1 in segs:
            wbox(g, mat, ax, c, tt, s0, s1, za, zb)
        k += 1
    return z0 + k * LOG


def gable_boards(g, ax, c, half, z0, ztop_at, t=LOG, face=1):
    """판 박공: 머리보 위 세로 판(폭 1)이 지붕 밑선까지. 판 사이 덧판"""
    n = int(half * 2 / 1.0)
    w = half * 2 / n
    for i in range(n):
        a, b = -half + i * w, -half + (i + 1) * w
        zt = min(ztop_at(abs(a)), ztop_at(abs(b))) - 0.05
        if zt - z0 < 0.2:
            continue
        th = t * 0.6 + (0.15 if i % 2 else 0.0)
        wbox(g, "Timber", ax, c + face * (t / 2 - th / 2), th, a, b, z0, zt)
    wbox(g, "DarkLog", ax, c, t * 0.5, -half, half, z0, z0 + 0.3)
    # 지붕선 따라 비스듬한 박공 테(판 윗끝의 계단을 덮는다) — 서까래 밑선 바로 아래, 처마도리 위에서 마룻대 밑까지
    for s in (-1, 1):
        lo, hi = 0.6, half - 0.2
        p = math.atan2(ztop_at(lo) - ztop_at(hi), hi - lo)
        Ln = (hi - lo) / math.cos(p)
        um = s * (lo + hi) / 2
        zm = (ztop_at(lo) + ztop_at(hi)) / 2 - 0.45
        if ax == "x":
            g["DarkLog"].obox(um, c + face * (t / 2 - 0.35), zm, Ln, 0.7, 0.9, ry=s * p)
        else:
            g["DarkLog"].obox(c + face * (t / 2 - 0.35), um, zm, 0.7, Ln, 0.9, rx=-s * p)


# ------------------------------------------------------------------ 3. 기둥·보
def post(g, x, y, z0, z1, s=1.0, mat="DarkLog", pad=True, coll=True):
    """기둥(받침돌 위). pad = 바닥에 돌 받침(0.3) — 기둥은 늘 받침·보·바닥 위에 선다"""
    if pad:
        bx(g, "Stone", x - s * 0.8, x + s * 0.8, y - s * 0.8, y + s * 0.8, z0, z0 + 0.3)
        z0 += 0.3
    bx(g, mat, x - s / 2, x + s / 2, y - s / 2, y + s / 2, z0, z1)
    if coll:
        cbox(x - s / 2, x + s / 2, y - s / 2, y + s / 2, z0, z1)


def beam(g, ax, c0, c1, a0, a1, z0, z1, mat="DarkLog"):
    """보(끝점): ax 방향으로 a0..a1, 단면 중심선 c0..c1(다른 축), 높이 z0..z1"""
    if ax == "x":
        bx(g, mat, a0, a1, c0, c1, z0, z1)
    else:
        bx(g, mat, c0, c1, a0, a1, z0, z1)


def brace(g, ax, c, u0, z0, u1, z1, s=0.5, mat="DarkLog"):
    """버팀대(가새·까치발): (u0, z0) → (u1, z1), ax 축 평면 위"""
    du, dz = u1 - u0, z1 - z0
    Ln = math.hypot(du, dz)
    ang = math.atan2(dz, du)
    if ax == "x":
        g[mat].obox((u0 + u1) / 2, c, (z0 + z1) / 2, Ln, s, s, ry=-ang)
    else:
        g[mat].obox(c, (u0 + u1) / 2, (z0 + z1) / 2, s, Ln, s, rx=ang)


# ------------------------------------------------------------------ 4. 지붕
class RoofFrame:
    """맞배지붕 치수 묶음(용마루는 y 방향, 박공은 앞·뒤). half = 벽 바깥면까지 반폭, z_plate = 벽 윗면"""

    def __init__(self, half, y0, y1, z_plate, pitch_deg, eave=EAVE_SIDE, eave_g=EAVE_GABLE, rafter=(0.6, 0.9)):
        self.half, self.y0, self.y1 = half, y0, y1
        self.p = math.radians(pitch_deg)
        self.t = math.tan(self.p)
        self.z_plate = z_plate
        self.plate_h = 0.9
        self.z_seat = z_plate + self.plate_h              # 서까래 밑이 벽 바깥면 위(처마도리 윗면)에 걸리는 높이
        self.eave, self.eave_g = eave, eave_g
        self.rw, self.rh = rafter
        self.ry0, self.ry1 = y0 - eave_g, y1 + eave_g     # 지붕 앞뒤 끝
        self.mid = half / 2                               # 중도리 자리 |x|

    def zb(self, x):
        """서까래 밑선 높이"""
        return self.z_seat + (self.half - abs(x)) * self.t

    def zt(self, x):
        """서까래 윗선(개판 밑)"""
        return self.zb(x) + self.rh / math.cos(self.p)

    @property
    def ridge(self):
        return self.zb(0)

    def top(self):
        """눈 윗면 꼭대기"""
        return self.zt(0) + (0.35 + 0.4 + SNOW_T) / math.cos(self.p)


def roof_frame(half, y0, y1, z_plate, variant):
    return RoofFrame(half, y0, y1, z_plate, PITCH[variant])


def _slope(g, mat, R, s, x_in, x_out, off, th, y0, y1):
    """한쪽 물매 판: 서까래 윗선에서 off 위에 두께 th, x_in..x_out(|x|) 구간"""
    cp, sp = math.cos(R.p), math.sin(R.p)
    xm = s * (x_in + x_out) / 2
    zm = R.zt(xm) + (off + th / 2) / cp
    Ln = (x_out - x_in) / cp
    g[mat].obox(xm, (y0 + y1) / 2, zm, Ln, y1 - y0, th, ry=s * R.p)


def roof_gable(g, R, deck="Timber", cover="RoofMetal", openings=()):
    """
    맞배지붕 한 벌(실제 순서): 처마도리(벽 위) · 중도리 · 마룻대 → 서까래(RAFTER_GAP 간격, 처마 끝까지) → 개판 → 덮개 → 눈 + 처마 눈 턱.
    도리 셋은 앞뒤 박공 밖으로 eave_g 만큼 내밀어 박공 처마를 받친다. 처마 끝 막이판·박공 널(풍판).
    openings = [(x0, x1, y0, y1)] 지붕을 뚫고 나가는 굴뚝 자리: 걸린 서까래는 굴뚝 앞뒤에서 끊고 받을보(헤더)로 이웃 서까래에 건다
    """
    H = R.half
    xe = H + R.eave
    # 도리(길이 방향): 처마도리 · 중도리 · 마룻대
    for s in (-1, 1):
        bx(g, "DarkLog", *sorted((s * (H - 1.1), s * H)), R.ry0 + 0.4, R.ry1 - 0.4, R.z_plate, R.z_seat)    # 처마도리(벽 윗면 위)
        xm = s * R.mid
        bx(g, "DarkLog", xm - 0.5, xm + 0.5, R.ry0 + 0.4, R.ry1 - 0.4, R.zb(R.mid + 0.5) - 1.0, R.zb(R.mid + 0.5))
    bx(g, "DarkLog", -0.55, 0.55, R.ry0 + 0.4, R.ry1 - 0.4, R.ridge - 1.1, R.zb(0.55))
    # 서까래
    n = max(2, int(round((R.ry1 - R.ry0 - 0.8) / RAFTER_GAP)))
    cp = math.cos(R.p)

    def rafter(xa, xb, y, s):
        xm = s * (xa + xb) / 2
        g["Timber"].obox(xm, y, R.zb(xm) + R.rh / cp / 2, (xb - xa) / cp, R.rw, R.rh, ry=s * R.p)
    ys = [R.ry0 + 0.3 + (R.ry1 - R.ry0 - 0.6) * i / n for i in range(n + 1)]
    for y in ys:
        for s in (-1, 1):
            cut = [o for o in openings if o[2] - 0.4 < y < o[3] + 0.4 and (o[0] + o[1]) * s > 0]
            if not cut:
                rafter(0.0, xe, y, s)
                continue
            a = min(abs(cut[0][0]), abs(cut[0][1])) - 0.2
            b = max(abs(cut[0][0]), abs(cut[0][1])) + 0.2
            rafter(0.0, a, y, s)
            if b < xe - 0.3:
                rafter(b, xe, y, s)
    for x0, x1, y0, y1 in openings:                 # 받을보: 굴뚝 앞뒤 끊긴 서까래 끝을 이웃 서까래에 건다
        s = 1 if x0 + x1 > 0 else -1
        ya = max([y for y in ys if y < y0 - 0.4] or [y0 - 1.0])
        yb = min([y for y in ys if y > y1 + 0.4] or [y1 + 1.0])
        for xx in (min(abs(x0), abs(x1)) - 0.2 - R.rw / 2, max(abs(x0), abs(x1)) + 0.2 + R.rw / 2):
            if xx > xe - 0.3:
                continue
            g["Timber"].box(s * xx, (ya + yb) / 2, R.zb(xx) + R.rh / cp / 2, R.rw, yb - ya, R.rh)
    # 개판 · 덮개 · 눈
    for s in (-1, 1):
        _slope(g, deck, R, s, 0.0, xe + 0.15, 0.0, 0.35, R.ry0, R.ry1)
        _slope(g, cover, R, s, 0.0, xe + 0.3, 0.35, 0.4, R.ry0 - 0.15, R.ry1 + 0.15)
        _slope(g, "SnowCap", R, s, 0.0, xe + 0.35, 0.75, SNOW_T, R.ry0 - 0.3, R.ry1 + 0.3)
        # 처마 눈 턱(처마 끝에서 조금 흘러내린 눈)
        xx = s * (xe + 0.2)
        bx(g, "SnowCap", xx - 0.32, xx + 0.32, R.ry0 - 0.3, R.ry1 + 0.3, R.zt(xe) + 0.2, R.zt(xe) + 0.75 + SNOW_T * 0.8)
        # 처마 끝 막이판
        xf = s * (xe + 0.05)
        g["Timber"].obox(xf, (R.ry0 + R.ry1) / 2, R.zb(xe) + 0.35, 0.3, R.ry1 - R.ry0, 1.3, ry=0.0)
    # 용마루 눈
    bx(g, "SnowCap", -0.9, 0.9, R.ry0 - 0.3, R.ry1 + 0.3, R.zt(0) + 0.5, R.zt(0) + 0.75 + SNOW_T + 0.35)
    # 박공 널(풍판): 앞뒤 박공 끝을 따라
    for y in (R.ry0 - 0.05, R.ry1 + 0.05):
        for s in (-1, 1):
            xm = s * (xe + 0.3) / 2
            zm = R.zt(xm) + 0.2
            g["Timber"].obox(xm, y, zm, (xe + 0.3) / cp, 0.3, 1.4, ry=s * R.p)


def tie_truss(g, y, R, t=1.0, posts=True, mat="DarkLog"):
    """평보(천장 높이 — 벽 위) + 동자기둥(마룻대 밑·중도리 밑) + 까치발. 평보 밑 = z_plate - 0.9 → 천장"""
    H = R.half
    zt0 = R.z_plate - 0.9
    bx(g, mat, -H + 0.05, H - 0.05, y - t / 2, y + t / 2, zt0, R.z_plate)
    if not posts:
        return zt0
    bx(g, mat, -0.4, 0.4, y - 0.4, y + 0.4, R.z_plate, R.ridge - 1.1)
    for s in (-1, 1):
        xm = s * R.mid
        bx(g, mat, xm - 0.4, xm + 0.4, y - 0.4, y + 0.4, R.z_plate, R.zb(R.mid + 0.5) - 1.0)
        # 버팀대: 마룻대 동자기둥 허리 → 중도리 동자기둥 밑(세모를 짠다)
        brace(g, "x", y, s * 0.4, R.z_plate + (R.ridge - R.z_plate) * 0.45, s * (R.mid - 0.4), R.z_plate + 0.6, s=0.45, mat=mat)
    return zt0


# ------------------------------------------------------------------ 5. 굴뚝
def chimney(g, x0, x1, y0, y1, ztop, mat="Stone", coll=True, z0=0.0):
    """땅(z0)에서 올라가는 굴뚝: 아래 넓은 몸(밑 1/3) → 띠돌 → 위 몸 → 갓 돌 + 쇠 갓 + 김 표지. 위 몸 둘레 눈은 얹지 않는다(열기)"""
    zs = z0 + (ztop - z0) * 0.35
    bx(g, mat, x0, x1, y0, y1, z0, zs)
    bx(g, "StoneTrim", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, zs, zs + 0.4)
    bx(g, mat, x0 + 0.25, x1 - 0.25, y0 + 0.25, y1 - 0.25, zs + 0.4, ztop)
    # 줄눈 띠(1.6 간격, 0.06 내밈)
    z = zs + 2.0
    while z < ztop - 1.0:
        bx(g, "StoneTrim", x0 + 0.2, x1 - 0.2, y0 + 0.2, y1 - 0.2, z, z + 0.12)
        z += 1.6
    bx(g, "StoneTrim", x0 - 0.1, x1 + 0.1, y0 - 0.1, y1 + 0.1, ztop, ztop + 0.5)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for s in (-1, 1):
        bx(g, "Iron", cx + s * (x1 - x0) * 0.32 - 0.15, cx + s * (x1 - x0) * 0.32 + 0.15, cy - 0.15, cy + 0.15, ztop + 0.5, ztop + 1.6)
    bx(g, "Iron", x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, ztop + 1.6, ztop + 1.85)
    bx(g, "SnowCap", x0 + 0.2, x1 - 0.2, y0 + 0.2, y1 - 0.2, ztop + 1.85, ztop + 2.05)
    S.vent(g, cx, cy, ztop + 1.1)
    if coll:
        cbox(x0, x1, y0, y1, z0, ztop)


# ------------------------------------------------------------------ 6. 마감
def door_open(g, ax, c, u, w, h, z0, face=-1, t=LOG, open_deg=95.0, leaves=2, outward=True):
    """
    문틀(문설주 0.6 · 인방 · 문지방) + 열어 둔 널문(겉 띠 3줄·Z 가새·쇠 경첩). 문은 바깥으로 열어 벽에 붙인다(길을 막지 않게).
    ax = 벽 축, c = 벽 가운데, u = 문 가운데, face = 바깥 쪽 부호. 문 비울 자리(DOORWAY)·json 문 정보 등록
    """
    a, b = u - w / 2, u + w / 2
    # 문설주·인방(벽 두께 + 0.2)
    for e0, e1 in ((a - 0.6, a), (b, b + 0.6)):
        wbox(g, "Timber", ax, c, t + 0.2, e0, e1, z0, z0 + h + 0.6)
    wbox(g, "Timber", ax, c, t + 0.2, a - 0.6, b + 0.6, z0 + h, z0 + h + 0.6)
    wbox(g, "Timber", ax, c, t + 0.2, a, b, z0, z0 + 0.12)            # 문지방(0.12 — 걸리지 않는 높이)
    # 널문: 경첩 = 문설주 바깥 모서리, 열린 각도만큼 돌림
    lw = w / leaves
    sgn_out = face if outward else -face
    ang = math.radians(open_deg)
    for side in (-1, 1):
        if leaves == 1 and side > 0:
            break
        hu = a if side < 0 else b                     # 경첩 자리(벽을 따라)
        # 닫힌 문짝 방향 d0(경첩 → 문 가운데), 바깥 법선 nn. 연 각 ang 만큼 바깥으로 돌린다(0 = 닫힘, 90 = 벽에 직각)
        if ax == "x":
            hx, hy = hu, c + sgn_out * (t / 2 + 0.25)
            d0, nn = (-side, 0.0), (0.0, sgn_out)
        else:
            hx, hy = c + sgn_out * (t / 2 + 0.25), hu
            d0, nn = (0.0, -side), (sgn_out, 0.0)
        dx = math.cos(ang) * d0[0] + math.sin(ang) * nn[0]
        dy = math.cos(ang) * d0[1] + math.sin(ang) * nn[1]
        _leaf(g, hx + dx * lw / 2, hy + dy * lw / 2, math.atan2(dy, dx), z0 + 0.15, lw - 0.1, h - 0.3)
    if ax == "x":
        DOORWAY(a, b, c - t / 2 - 0.1, c + t / 2 + 0.1, z0, h)
    else:
        DOORWAY(c - t / 2 - 0.1, c + t / 2 + 0.1, a, b, z0, h)
    DOOR_INFO.setdefault(_name(), []).append(((u, c) if ax == "x" else (c, u), w, h, face, ax))


def _leaf(g, cx, cy, rz, z0, w, h):
    """널문 한 짝: 가운데 (cx, cy), 문짝 폭 방향 각 rz. 세로 널(두 색 번갈아) + 가로 띠 셋 + 쇠 경첩 띠"""
    cr, sr = math.cos(rz), math.sin(rz)

    def O(mat, du, dn, z, su, sn, sz):
        g[mat].obox(cx + du * cr - dn * sr, cy + du * sr + dn * cr, z, su, sn, sz, rz=rz)
    nb = max(3, int(round(w / 1.1)))
    for i in range(nb):
        O("DarkLog" if i % 2 else "Timber", -w / 2 + w * (i + 0.5) / nb, 0, z0 + h / 2, w / nb - 0.04, 0.35, h)
    for zz in (0.18, 0.5, 0.82):
        O("Timber", 0, 0.3, z0 + h * zz, w, 0.25, 0.6)
        O("Iron", 0, 0.47, z0 + h * zz, w * 0.7, 0.08, 0.28)


def window(g, ax, c, u, z0, w=WIN_W, h=WIN_H, face=-1, t=LOG, frame="Paint", shutters=True, sill_snow=True):
    """
    벽 구멍(벽 함수의 holes 에 (u-w/2, u+w/2, z0, z0+h) 를 같이 넣을 것)에 끼우는 창:
    벽 두께 가운데 틀 + 2×3 살 + 맑은 유리(WinGlass) · 바깥 창턱(눈) · 열린 덧창 둘(뢰로스·검은 숲)
    """
    a, b = u - w / 2, u + w / 2
    fw = 0.3
    for e0, e1 in ((a, a + fw), (b - fw, b)):
        wbox(g, frame, ax, c, 0.5, e0, e1, z0, z0 + h)
    wbox(g, frame, ax, c, 0.5, a, b, z0, z0 + fw)
    wbox(g, frame, ax, c, 0.5, a, b, z0 + h - fw, z0 + h)
    wbox(g, frame, ax, c, 0.35, u - 0.09, u + 0.09, z0 + fw, z0 + h - fw)
    for k in (1, 2):
        zz = z0 + fw + (h - 2 * fw) * k / 3
        wbox(g, frame, ax, c, 0.35, a + fw, b - fw, zz - 0.08, zz + 0.08)
    wbox(g, "WinGlass", ax, c, 0.08, a + fw, b - fw, z0 + fw, z0 + h - fw)
    # 창턱(바깥으로 0.5 내밈) + 눈
    sc = c + face * (t / 2 + 0.25)
    wbox(g, "Timber", ax, sc, 0.7, a - 0.3, b + 0.3, z0 - 0.3, z0)
    if sill_snow:
        wbox(g, "SnowCap", ax, sc, 0.6, a - 0.2, b + 0.2, z0, z0 + 0.18)
    if shutters:
        sc2 = c + face * (t / 2 + 0.12)
        for e0, e1 in ((a - 0.15 - w / 2, a - 0.15), (b + 0.15, b + 0.15 + w / 2)):
            wbox(g, "DarkLog", ax, sc2, 0.2, e0, e1, z0, z0 + h)
            for zz in (0.25, 0.75):
                wbox(g, "Timber", ax, sc2 + face * 0.12, 0.08, e0, e1, z0 + h * zz - 0.2, z0 + h * zz + 0.2)


def stair(g, cx, y_top, width, rise, base_z=0.0, face=-1, mat="Stone", cheek=True, coll=True):
    """y_top(윗단 앞 끝)에서 face 쪽으로 내려가는 계단. 한 단 STEP_RISE 이하·디딤 STEP_TREAD. 양옆 측판(단마다 0.5 높은 돌 턱). 돌려주는 값 = 계단 앞 끝 y"""
    n = max(1, int(math.ceil(rise / STEP_RISE - 1e-6)))
    rs = rise / n
    for k in range(n):
        top = base_z + rs * (k + 1)
        ya = y_top + face * STEP_TREAD * (n - k)
        y0, y1 = sorted((ya, y_top))
        bx(g, mat, cx - width / 2, cx + width / 2, y0, y1, base_z, top)
        if coll:
            cbox(cx - width / 2, cx + width / 2, y0, y1, base_z, top)
    if cheek:
        for s in (-1, 1):
            xa, xb = sorted((cx + s * width / 2, cx + s * (width / 2 + 0.8)))
            for k in range(n):
                top = base_z + rs * (k + 1) + 0.5
                ya = y_top + face * STEP_TREAD * (n - k)
                y0, y1 = sorted((ya, ya - face * STEP_TREAD if k < n - 1 else y_top))
                bx(g, "StoneTrim", xa, xb, y0, y1, base_z, top)
            if coll:
                y0, y1 = sorted((y_top + face * STEP_TREAD * n, y_top))
                cbox(xa, xb, y0, y1, base_z, base_z + rise + 0.5)
    return y_top + face * STEP_TREAD * n


def hang_sign(g, x, y, z, along="x", icon=None, arm=3.0, board=(2.8, 2.0), face_sign=1):
    """
    쇠 팔 간판: 벽·기둥 면(x, y, z = 팔 높이)에 박은 받침판 → along 축(+) 방향 팔 arm + 아래 비스듬 버팀 → 고리 둘 → 매단 판(Timber + 놋쇠 테 + 양면 그림 icon).
    icon(g, x, y, z, face) 는 build_steam_service 의 anvil_icon·flask_icon 같은 그림(판 면에 붙는다)
    """
    s = face_sign
    bw, bh = board
    if along == "x":
        bx(g, "Iron", *sorted((x, x + s * 0.15)), y - 0.5, y + 0.5, z - 1.4, z + 0.3)
        bx(g, "Iron", *sorted((x, x + s * arm)), y - 0.1, y + 0.1, z - 0.1, z + 0.12)
        brace(g, "x", y, x, z - 1.3, x + s * arm * 0.6, z, s=0.12, mat="Iron")
        cx = x + s * (0.4 + arm / 2)
        for dx in (-bw * 0.35, bw * 0.35):
            bx(g, "Iron", cx + dx - 0.05, cx + dx + 0.05, y - 0.05, y + 0.05, z - 0.6, z)
        bx(g, "Timber", cx - bw / 2, cx + bw / 2, y - 0.12, y + 0.12, z - 0.6 - bh, z - 0.6)
        bx(g, "Brass", cx - bw / 2 - 0.1, cx + bw / 2 + 0.1, y - 0.15, y + 0.15, z - 0.7, z - 0.55)
        bx(g, "SnowCap", cx - bw / 2, cx + bw / 2, y - 0.14, y + 0.14, z - 0.55, z - 0.45)
        if icon:
            icon(g, cx, y - 0.12, z - 0.6 - bh * 0.62, -1)
            icon(g, cx, y + 0.12, z - 0.6 - bh * 0.62, 1)
    else:
        raise NotImplementedError("along='y' 간판은 필요할 때 추가")


def steam_bundle(g, x, y, z0, h=7.0, r=1.3, pipe_pts=None, gauge_face=-1):
    """증기 묶음: 돌 받침 → 놋쇠 띠 구리 통 → 위 안전밸브(김) · 앞 압력계(쇠 테·흰 판·바늘) · 손잡이 밸브 → 벽으로 드는 관(pipe_pts, 직각 꺾임)"""
    bx(g, "Stone", x - r - 0.4, x + r + 0.4, y - r - 0.4, y + r + 0.4, z0, z0 + 0.6)
    S.banded_cyl(g, "Copper", x, y, z0 + 0.6, r, h, every=2.2)
    g["Brass"].cyl(x, y, z0 + 0.6 + h + 0.8, 0.25, 0.25, 0.9, seg=10)
    S.vent(g, x, y, z0 + h + 2.5)
    gy = y + gauge_face * (r + 0.25)
    gz = z0 + 0.6 + h * 0.62
    g["Brass"].hcyl(x, y + gauge_face * (r + 0.05), gz, 0.12, 0.5, axis="y", seg=8)
    g["Iron"].hcyl(x, gy, gz, 0.65, 0.18, axis="y", seg=16)
    g["Dial"].hcyl(x, gy + gauge_face * 0.06, gz, 0.52, 0.1, axis="y", seg=16)
    g["Iron"].obox(x + 0.15, gy + gauge_face * 0.12, gz + 0.12, 0.06, 0.04, 0.42, ry=-0.9)
    # 손잡이 밸브(바퀴)
    vz = z0 + 0.6 + h * 0.3
    vy = y + gauge_face * (r + 0.35)
    g["Iron"].hcyl(x, y + gauge_face * (r + 0.1), vz, 0.15, 0.5, axis="y", seg=8)
    g["Iron"].hcyl(x, vy, vz, 0.5, 0.1, axis="y", seg=14)
    g["Brass"].hcyl(x, vy + gauge_face * 0.06, vz, 0.18, 0.1, axis="y", seg=8)
    if pipe_pts:
        S.pipe(g, pipe_pts, 0.3, mat="Copper")
    cbox(x - r - 0.4, x + r + 0.4, y - r - 0.4, y + r + 0.4, z0, z0 + 0.6 + h)


def counter(g, x0, x1, y0, y1, z0=FZ, face=-1):
    """카운터(높이 COUNTER_H): 짙은 나무 몸 + 판벽 줄 + 밝은 나무 상판 + 놋쇠 모서리 + 발 차는 쇠띠. 충돌 상자"""
    zt = z0 + COUNTER_H
    bx(g, "Timber", x0 + 0.2, x1 - 0.2, y0 + 0.15, y1 - 0.15, z0, zt - 0.3)
    fy = y0 if face < 0 else y1
    n = int((x1 - x0) / 1.6)
    for i in range(n + 1):
        xx = x0 + 0.3 + (x1 - x0 - 0.6) * i / max(1, n)
        bx(g, "DarkLog", xx - 0.15, xx + 0.15, *sorted((fy, fy + face * 0.1)), z0 + 0.3, zt - 0.4)
    bx(g, "Iron", x0 + 0.2, x1 - 0.2, *sorted((fy, fy + face * 0.12)), z0, z0 + 0.35)
    bx(g, "Wood", x0 - 0.1, x1 + 0.1, y0 - 0.15, y1 + 0.15, zt - 0.3, zt)
    for xx in (x0 + 0.05, x1 - 0.05):           # 놋쇠 모서리(상판 안 — 앞 빈 바닥으로 내밀지 않게)
        for yy in (y0, y1):
            bx(g, "Brass", xx - 0.18, xx + 0.18, yy - 0.18, yy + 0.18, zt - 0.32, zt + 0.02)
    cbox(x0 - 0.1, x1 + 0.1, y0 - 0.15, y1 + 0.15, z0, zt)
    return zt


# ------------------------------------------------------------------ 짓기(build_kit · preview 가 같이 쓴다)
def build_model(mod, zfix=True):
    """b_*.py 모듈 하나를 지어 재질 덩이 오브젝트 목록과 삼각형 수를 돌려준다(내보내기 없음)"""
    import bpy
    import zfight_scan as Z
    g = G(mod.PREFIX)
    I.job(mod.NAME, mod.build)(g)
    zm = zl = 0
    if zfix:
        zm, zl = Z.fix(g, mod.NAME)
    objs, tris = [], {}
    for k in PAL:
        ob = g[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert n <= 10000, (ob.name, n)
        tris[k] = n
        objs.append(ob)
    return objs, tris, (zm, zl)
