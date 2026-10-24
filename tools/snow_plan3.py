# -*- coding: utf-8 -*-
"""
snow_plan3.py — 2026-10-24. 슈네라이히 '기능 건물 중심 마을' 정리안 설계도(그림만 — Studio 는 건드리지 않는다).

사용자(2026-10-24): "핵심 건물·기능 건물이 많으니 일반적인 기능이 없는 건물들은 조금만 남기거나 아예 없애고, 기능 건물 위주의 마을을" →
"일단 설계도면 먼저 보고 생각해봐야겠다."
원칙: 걷는 곳의 모든 문은 열린다(가짜 문 없음). 집은 ① 지움 ② 새 기능으로 바꿈 ③ 스토리 주민 집 ④ 배경 집(문 없는 판, 창 불빛·굴뚝만) 넷 중 하나.
비운 땅은 할 일이 있는 마당으로. 광장에서 걷기 시간 고리(16 스터드/초)와 대로 끝 랜드마크 시선을 함께 그린다.
돌리기: python tools/snow_plan3.py → tools/snow_plan3.svg
좌표 = 월드(x 동, z 남; 위 = 북). 배치·길·발자국은 snow_plan2.py 를 그대로 읽는다.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import snow_plan2 as P  # noqa: E402

CX, CZ = P.CX, P.CZ
X0, Z0, X1, Z1 = -5360.0, -4200.0, -4130.0, -3560.0
MAP_X1 = -4440.0                                            # 그 오른쪽은 범례·메모 판


def polar(th, r):
    a = math.radians(th)
    return CX + r * math.cos(a), CZ + r * math.sin(a)


# ── 바깥 고리(r 162) 집 자리 → 새 기능. (각, 이름, 짧은 설명, 집 몇 채 자리) — 두 채 자리는 가운데 각에 큰 채 하나 ──
RING_NEW = [
    (78.0, "의뢰소", "모험가 길드 · 의뢰판", 1),
    (102.0, "우체국", "아이템·편지 보내기", 1),
    # 2026-10-25 사용자: 직업은 탑 입장 전에 골라 탑에서 키운다 → 직업 회관(전직관) 넷은 빼고, 마을 → 탑 → 필드(보스) → 마을 고리를 돕는 것만(제안)
    (-19.5, "사냥꾼 길드(제안)", "보스 현상금·출현 시간표·파티 모집", 2),
    (-141.5, "훈련장(제안)", "기계 과녁 — 탑 전 손풀기·빌드 시험", 2),
    (147.0, "기록관(제안)", "명예의 전당 — 탑 최고 층·보스 처치", 2),
    (114.0, "식당·빵집", "음식 버프", 1),
    (54.0, "지도 제작소", "탑 순간이동·지도", 1),
    (-83.0, "모험가 숙소", "제너럴: 문마다 내 방", 2),
]
RING_USED = {-26.0, -13.0, -148.0, -135.0, 141.0, 153.0, 114.0, 54.0, -89.0, -77.0, 78.0, 102.0}   # 166(옛 연금 실험실 자리)은 비움


def classify(k, x, z, g):
    """집 → ('del' | 'new' | 'res' | 'bg', 이름표)"""
    th = round(math.degrees(math.atan2(z - CZ, x - CX)), 0)
    if g == "바깥고리":
        return ("new", "") if th in RING_USED else ("del", "")
    if g == "뒷골목":
        return ("bg", "") if z < -4130 else ("del", "")        # 북쪽 줄 = 북쪽 하늘선
    if g == "동쪽거리":
        return ("bg", "") if x > -4610 else ("del", "")        # 동쪽 줄 = 동쪽 하늘선
    if g == "남쪽거리":
        if abs(z + 3642) < 6 and x > -4860:
            return ("res", "주민")                              # 북쪽 줄 여섯 = 스토리 주민 골목
        if abs(z + 3600) < 3:
            return ("bg", "")                                   # 남쪽 줄 = 남쪽 하늘선(바위 턱 앞)
        return ("del", "")
    return ("del", "")                                          # 북쪽거리·공방골목·남서거리·변환로마당·서북거리·동문길·체스판


# ── 비운 땅의 새 쓰임(다각형, 이름, 설명) ──
AREAS = [
    ([(-5075, -4092), (-4858, -4092), (-4858, -4022), (-5075, -4022)], "북쪽 이벤트 광장", "제너럴 25인 행사·보스 알림·축제 무대"),
    ([(-5280, -4130), (-5090, -4130), (-5090, -3996), (-5280, -3996)], "썰매 언덕·눈싸움 마당", "놀이(스토리·제너럴 공통)"),
    ([(-4805, -4035), (-4642, -4035), (-4642, -3952), (-4805, -3952)], "플레이어 노점 마당", "경매장 옆 — 제너럴 플레이어 노점"),
    ([(-4650, -3628), (-4570, -3628), (-4570, -3596), (-4650, -3596)], "연병장 관람석", "체스 대전 구경"),
    ([(-5300, -3702), (-5175, -3702), (-5175, -3640), (-5300, -3640)], "천문대 정원", "별 관측 · 기록관 옆 쉼터"),
]
REMOVED_ROADS = {"북쪽거리", "뒷골목", "공방골목", "남서거리"}
LANDMARKS = {"Clock_Tower": "시계탑(광장)", "Zapfen_Werk": "차펜 공방", "Schule": "학교", "Steam_Factory": "공장",
             "Herzofen": "감정 변환로", "Observatory": "천문대", "Figuren_HQ": "기물군 본부",
             "Casino_Gate": "경매장·카지노(지하)", "Mooring_Mast": "계류탑·비행선(도착 광장)", "Ticket_Booth": "", "City_Gate": "동문"}
SVC_NAME = {"Svc_Smithy": "대장간", "Svc_Enhance": "강화소", "Svc_Bank": "은행·금고", "Svc_Inn": "여관·마구간",
            "Svc_Potion": "물약상점", "Svc_Hospital": "병원(부활)", "Svc_General": "잡화점"}
COL = {"del": "#e9b4b4", "new": "#2f9e6a", "res": "#e0912f", "bg": "#8d939b", "svc": "#2f6fb3", "yard": "#bcd3ea",
       "land": "#6b4aa0", "road": "#a39b90", "area": "#f3d75a"}


def svg():
    W = 1600
    H = W * (Z1 - Z0) / (X1 - X0)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" viewBox="{X0} {Z0} {X1 - X0} {Z1 - Z0}" '
           'font-family="Malgun Gothic, Apple SD Gothic Neo, sans-serif">',
           f'<rect x="{X0}" y="{Z0}" width="{X1 - X0}" height="{Z1 - Z0}" fill="#f4f7fa"/>']

    def poly(pts, fill, op=1.0, stroke="none", sw=0.0, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        out.append('<polygon points="%s" fill="%s" fill-opacity="%.2f" stroke="%s" stroke-width="%.2f"%s/>'
                   % (" ".join("%.1f,%.1f" % p for p in pts), fill, op, stroke, sw, d))

    def text(x, z, t, size=9.0, col="#1d232b", weight=700, anchor="middle", halo=True):
        h = ' stroke="#ffffff" stroke-width="%.1f" paint-order="stroke"' % (size * 0.28) if halo else ""
        out.append(f'<text x="{x:.1f}" y="{z:.1f}" font-size="{size:.1f}" fill="{col}" font-weight="{weight}" text-anchor="{anchor}"{h}>{t}</text>')

    # 땅: 평지(59.8) 밖 높은 바위는 회색(줄마다 이어 붙임)
    g = P.GROUND
    st = g["st"]
    for j, row in enumerate(g["rows"]):
        z = g["z0"] + j * st
        i = 0
        while i < len(row):
            h = row[i]
            if h is not None and h > 60.3:
                i0 = i
                while i < len(row) and row[i] is not None and row[i] > 60.3:
                    i += 1
                x = g["x0"] + i0 * st
                out.append(f'<rect x="{x - st / 2:.0f}" y="{z - st / 2:.0f}" width="{(i - i0) * st:.0f}" height="{st:.0f}" fill="#c9ced4"/>')
            else:
                i += 1
    # 걷기 시간 고리(광장에서, 16 스터드/초)
    for r, t in ((160, "걸어서 10초"), (320, "20초"), (480, "30초")):
        out.append(f'<circle cx="{CX}" cy="{CZ}" r="{r}" fill="none" stroke="#5a7fa8" stroke-width="1.2" stroke-dasharray="6 5" opacity="0.7"/>')
        text(CX + r * 0.71 + 4, CZ - r * 0.71 - 4, t, 8, "#5a7fa8", 700, "start")
    # 길(지울 길은 붉은 점선)
    for name, w, mat, pts, lift in P.ROADS:
        gone = name in REMOVED_ROADS
        d = " ".join("%.1f,%.1f" % p for p in pts)
        if gone:
            out.append(f'<polyline points="{d}" fill="none" stroke="#d26a6a" stroke-width="{w:.1f}" stroke-opacity="0.25" stroke-linejoin="round"/>')
            out.append(f'<polyline points="{d}" fill="none" stroke="#c0392b" stroke-width="1.4" stroke-dasharray="5 4"/>')
        else:
            out.append(f'<polyline points="{d}" fill="none" stroke="{COL["road"]}" stroke-width="{w:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')
    for pv in P.PAVES:
        if pv[-1] == "disc":
            out.append(f'<circle cx="{pv[1]}" cy="{pv[2]}" r="{pv[3]}" fill="#a39b90"/>')
        elif pv[-1] != "playtri":
            name, x0, z0, x1, z1, kind = pv
            poly([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], {"chess": "#55565c", "soot": "#5b5859"}.get(kind, "#b9b1a6"), 0.8)
    for name, pts in P.PIPES:
        out.append('<polyline points="%s" fill="none" stroke="#c07a48" stroke-width="2.2"/>' % " ".join("%.1f,%.1f" % p for p in pts))
    # 새 쓰임 마당
    for pts, name, sub in AREAS:
        poly(pts, COL["area"], 0.45, "#b8961c", 1.2, "4 3")
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        text(cx, cz - 2, name, 9.5, "#5c4a00")
        text(cx, cz + 9, sub, 6.5, "#5c4a00", 400)
    # 건물
    counts = {"del": 0, "new": 0, "res": 0, "bg": 0}
    for k, x, z, y, gname, t, sc in P.BUILD:
        if k.startswith("Steam_House"):
            cat, lab = classify(k, x, z, gname)
            counts[cat] += 1
            if cat == "new":
                continue                                        # 새 기능 채는 아래에서 크게 그린다
            pts = P.rect_world(k, x, z, y, 1, 0, sc)
            if cat == "del":
                poly(pts, COL["del"], 0.55, "#c0392b", 0.8, "3 2")
                out.append(f'<path d="M{pts[0][0]:.1f},{pts[0][1]:.1f} L{pts[2][0]:.1f},{pts[2][1]:.1f} M{pts[1][0]:.1f},{pts[1][1]:.1f} '
                           f'L{pts[3][0]:.1f},{pts[3][1]:.1f}" stroke="#c0392b" stroke-width="0.8" opacity="0.6"/>')
            else:
                poly(pts, COL[cat], 0.95, "#ffffff", 0.6)
                if lab:
                    text(x, z + 2.5, lab, 6.5, "#ffffff", 700, halo=False)
            continue
        if k in P.YARD_ZONES:
            for part in P.YARD_ZONES[k]["parts"]:
                poly([P._svc_local((k, x, z, y), bx, by) for bx, by in part], COL["yard"], 0.7)
            continue
        if k == "Gas_Lamp" or k not in P.KIT:
            continue
        pts = P.rect_world(k, x, z, y, 1, 0, sc)
        if k in SVC_NAME:
            poly(pts, COL["svc"], 1.0, "#ffffff", 0.8)
            text(x, z + 3, SVC_NAME[k], 8.5, "#ffffff", 700, halo=False)
        elif k in LANDMARKS:
            poly(pts, COL["land"], 0.95, "#ffffff", 0.8)
            wid = max(abs(pts[1][0] - pts[0][0]) + abs(pts[1][1] - pts[0][1]), abs(pts[2][0] - pts[1][0]) + abs(pts[2][1] - pts[1][1]))
            if wid > len(LANDMARKS[k]) * 8.0:
                text(x, z + 3, LANDMARKS[k], 8.5, "#ffffff", 700, halo=False)
            elif LANDMARKS[k]:
                text(x, min(q[1] for q in pts) - 4, LANDMARKS[k], 8.5, "#4b2f86")
        else:
            poly(pts, "#9aa3ad", 0.8)
    # 바깥 고리 새 기능 채(집 자리 1~2 채를 한 채로)
    for th, name, sub, n in RING_NEW:
        cx, cz = polar(th, 168.0)
        w, d = (34.0, 24.0) if n == 2 else (22.0, 20.0)
        a = math.radians(90.0 - th)
        c, s = math.cos(a), math.sin(a)
        pts = [(cx + lx * c + lz * s, cz - lx * s + lz * c) for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        poly(pts, COL["new"], 1.0, "#ffffff", 1.0)
        lx_, lz_ = polar(th, 196.0)
        if th in (78.0, 102.0):                                 # 남대로 끝(계류탑)·식당 이름표와 겹치지 않게 채 바로 밑에
            lx_, lz_ = cx, cz + 22.0
        text(lx_, lz_, name, 9.0, "#16603f")
        text(lx_, lz_ + 8.5, sub, 6.0, "#16603f", 400)
    # 대로 끝 랜드마크 시선
    for k_ in ("Schule", "Steam_Factory", "Zapfen_Werk", "Mooring_Mast", "Observatory", "Figuren_HQ"):
        e = next(b for b in P.BUILD if b[0] == k_)
        ex, ez = e[1], e[2]
        L = math.hypot(ex - CX, ez - CZ)
        ux, uz = (ex - CX) / L, (ez - CZ) / L
        out.append(f'<line x1="{CX + ux * 46:.1f}" y1="{CZ + uz * 46:.1f}" x2="{ex - ux * 30:.1f}" y2="{ez - uz * 30:.1f}" stroke="#6b4aa0" '
                   f'stroke-width="1.3" stroke-dasharray="2 4" marker-end="url(#ar)" opacity="0.8"/>')
    out.insert(2, '<defs><marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto">'
                  '<path d="M0,0 L10,5 L0,10 z" fill="#6b4aa0"/></marker></defs>')
    # 제목·범례·정하실 것(오른쪽 판)
    bx, bz = MAP_X1 + 10, Z0 + 8
    poly([(MAP_X1, Z0), (X1, Z0), (X1, Z1), (MAP_X1, Z1)], "#ffffff", 1.0)
    out.append(f'<line x1="{MAP_X1}" y1="{Z0}" x2="{MAP_X1}" y2="{Z1}" stroke="#9aa3ad" stroke-width="1"/>')
    text(bx, bz + 18, "슈네라이히 정리안", 16, "#111", 800, "start", False)
    text(bx, bz + 34, "기능 건물 중심 마을 (설계도 — 아직 Studio 안 바꿈)", 8, "#444", 500, "start", False)
    text(bx, bz + 47, "걷는 곳의 문은 모두 열린다 · 비운 땅은 할 일이 있는 마당으로", 7.5, "#444", 400, "start", False)
    rows = [(COL["svc"], "핵심 기능 7채 + 뜰 (그대로)", 1.0), (COL["land"], "큰 시설·랜드마크 (그대로)", 1.0),
            (COL["new"], "새 기능 %d곳 (바깥 고리 집 %d채 자리)" % (len(RING_NEW), counts["new"]), 1.0), (COL["res"], "스토리 주민 집 %d (안은 다음 단계)" % counts["res"], 1.0),
            (COL["bg"], "배경 집 %d (문 없앤 판 — 창 불빛·굴뚝만)" % counts["bg"], 1.0), (COL["del"], "지우는 집 %d" % counts["del"], 0.6),
            (COL["area"], "비운 땅의 새 쓰임", 0.5)]
    for i, (c, t, op) in enumerate(rows):
        yy = bz + 66 + i * 15
        poly([(bx, yy - 7), (bx + 14, yy - 7), (bx + 14, yy + 3), (bx, yy + 3)], c, op, "#555" if c == COL["del"] else "none", 0.6)
        text(bx + 20, yy + 1, t, 8, "#222", 600, "start", False)
    yy = bz + 66 + len(rows) * 15
    out.append(f'<line x1="{bx}" y1="{yy - 2}" x2="{bx + 14}" y2="{yy - 2}" stroke="#c0392b" stroke-width="1.4" stroke-dasharray="5 4"/>')
    text(bx + 20, yy + 1, "지우는 길 (북쪽거리·뒷골목·공방골목·남서거리)", 8, "#222", 600, "start", False)
    out.append(f'<line x1="{bx}" y1="{yy + 13}" x2="{bx + 14}" y2="{yy + 13}" stroke="#6b4aa0" stroke-width="1.3" stroke-dasharray="2 4"/>')
    text(bx + 20, yy + 16, "광장 → 대로 끝 랜드마크 시선", 8, "#222", 600, "start", False)
    out.append(f'<line x1="{bx}" y1="{yy + 28}" x2="{bx + 14}" y2="{yy + 28}" stroke="#5a7fa8" stroke-width="1.2" stroke-dasharray="6 5"/>')
    text(bx + 20, yy + 31, "광장에서 걷는 시간 (16 스터드/초)", 8, "#222", 600, "start", False)
    total = sum(counts.values())
    yy += 56
    text(bx, yy, "집 %d채 →" % total, 10, "#111", 800, "start", False)
    for i, t in enumerate(("지움 %d" % counts["del"], "새 기능 %d곳 (집 %d채 자리)" % (len(RING_NEW), counts["new"]), "주민 집 %d" % counts["res"], "배경 집 %d" % counts["bg"])):
        text(bx + 12, yy + 14 + i * 13, "· " + t, 8.5, "#222", 600, "start", False)
    yy += 78
    text(bx, yy, "정하실 것", 11, "#111", 800, "start", False)
    notes = ["① 새 기능 %d곳 — 목록·자리 괜찮은지" % len(RING_NEW),
             "    (의뢰소·우체국·식당/빵집·지도 제작소·모험가 숙소 +",
             "     제안: 사냥꾼 길드·훈련장·기록관 — 직업 회관은 뺌)",
             "② 배경 집 27채 — 남길지, 아예 0채로 할지",
             "③ 주민 집 6채 — 스토리 모드에 쓸지",
             "④ 기물군 본부·경매장 — 안쪽으로 당길지(지금 30초 거리)",
             "⑤ 비운 마당 5곳 — 쓰임 괜찮은지",
             "⑥ 천문대 — '조율자 전직' 설정을 뺀 뒤 쓰임",
             "",
             "승인 뒤 순서: 집 지우기(ServerStorage 보관) → 새 기능 채",
             "회색 상자로 동선 확인 → 블렌더로 꾸미기 → 마당 만들기"]
    for i, t in enumerate(notes):
        text(bx, yy + 15 + i * 12, t, 7.6, "#333", 500, "start", False)
    text(MAP_X1 - 10, Z1 - 12, "N ↑   눈금 1 칸 = 50 스터드", 8, "#444", 600, "end")
    for gx in range(int(X0 // 50 + 1) * 50, int(MAP_X1), 50):
        out.append(f'<line x1="{gx}" y1="{Z1 - 6}" x2="{gx}" y2="{Z1}" stroke="#888" stroke-width="0.6"/>')
    out.append("</svg>")
    return "\n".join(out), counts


if __name__ == "__main__":
    s, counts = svg()
    p = os.path.join(HERE, "snow_plan3.svg")
    with open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(s)
    print(counts, "→", p)
