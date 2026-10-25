# -*- coding: utf-8 -*-
# 청의 검사 카드 그림 — 대태도·검집·발도·집중·도발·방어(2026-10-25)
from cards import *  # noqa: F401,F403

AZURE = "#5aaaff"
ICE = "#c8e8ff"
SAYA = "#24407a"


def odachi(A, cx, cy, s=0.8, ang=-60, color=WHITE, sheathed=False, w=LINE):
    """휜 대태도(손잡이:날 = 1:3). 가운데 = 코등이. sheathed 면 날 자리에 검집"""
    hx, hy = polar(cx, cy, s * 0.25, ang + 180)
    A.line(cx, cy, hx, hy, w=w * 1.5, color=SAYA if sheathed else ICE)
    pts = []
    for i in range(7):
        t = i / 6
        bx, by = polar(cx, cy, s * 0.75 * t, ang)
        nx, ny = polar(0, 0, 0.06 * s * t * t, ang - 90)
        pts.append((bx + nx, by + ny))
    A.poly(pts, w=w * (2.2 if sheathed else 1.0), color=SAYA if sheathed else color)
    A.ellipse(cx, cy, 0.05, 0.02, ang + 90, w=THIN, color=WHITE)
    return pts[-1]


@art("AzureBlade_E_Provoke")  # 도발: 바뀌지 않는 손짓(자물쇠 걸린 손바닥)
def _(A):
    hand_open(A, 0.44, 0.52, 0.56)
    lock(A, 0.72, 0.68, 0.24, color=A.accent, key=WHITE)


@art("AzureBlade_E_Biased")  # 치우쳐진 검: 기운 저울 위의 칼
def _(A):
    scales(A, C, 0.6, 0.62, color=WHITE, tilt=-14)
    odachi(A, 0.3, 0.34, 0.5, -25, color=A.accent)


@art("AzureBlade_E_Mushin")  # 무념무상: 감은 눈과 고요한 물결
def _(A):
    A.arc(C, 0.44, 0.18, 20, 160, w=LINE, color=WHITE)
    wave(A, C, 0.7, 0.56, 0.03, 2, color=A.accent, w=THIN)
    wave(A, C, 0.78, 0.4, 0.02, 2, color=A.accent, w=THIN, tr=0.4)
    A.disc(C, 0.28, 0.03, ICE)


@art("AzureBlade_E_Riposte")  # 역수 발도: 거꾸로 쥔 칼과 되돌아가는 화살
def _(A):
    odachi(A, 0.36, 0.42, 0.62, 120, color=WHITE)
    loop_arrow(A, 0.66, 0.6, 0.18, color=A.accent, start=-40, end=200)


@art("AzureBlade_R_AllOut")  # 혼신의 도발: 모래시계를 붙잡은 손
def _(A):
    hourglass(A, C, 0.46, 0.42, color=WHITE, sand=A.accent)
    fist(A, 0.72, 0.72, 0.24)


@art("AzureBlade_R_Stance")  # 방어 태도: 방패 뒤에 세운 칼
def _(A):
    odachi(A, 0.62, 0.66, 0.7, -80, color=ICE)
    shield(A, 0.4, 0.56, 0.42, color=WHITE, w=LINE)


@art("AzureBlade_R_SwordWind")  # 검풍: 칼끝에서 이는 바람
def _(A):
    odachi(A, 0.28, 0.7, 0.78, -40, color=WHITE)
    for k in range(3):
        A.arc(0.62, 0.38, 0.12 + k * 0.08, 200, 320, w=THIN, color=A.accent, tr=k * 0.2)


@art("AzureBlade_R_Zanshin")  # 잔심: 벤 뒤 남은 눈길(칼과 눈)
def _(A):
    eye(A, C, 0.34, 0.4, color=WHITE, pupil=A.accent)
    odachi(A, 0.22, 0.7, 0.72, -8, color=ICE)


@art("AzureBlade_R_Ring")  # 칼집 울림: 검집 끝에서 퍼지는 고리
def _(A):
    odachi(A, 0.28, 0.74, 0.72, -50, sheathed=True)
    for k in range(3):
        A.ring(0.74, 0.26, 0.06 + k * 0.06, w=THIN, color=A.accent, tr=k * 0.25)


@art("AzureBlade_R_Price")  # 도발의 대가: 손바닥 앞의 금 간 방패
def _(A):
    shield(A, 0.56, 0.52, 0.5, color=WHITE, w=LINE)
    crack(A, 0.56, 0.5, 0.36, 80, color=A.accent, w=THIN)
    hand_open(A, 0.26, 0.7, 0.26)


@art("AzureBlade_R_OneBreath")  # 한 호흡: 입김과 반달
def _(A):
    wave(A, 0.44, 0.56, 0.5, 0.04, 1.5, color=WHITE, w=LINE)
    wave(A, 0.5, 0.66, 0.4, 0.03, 1.5, color=A.accent, w=THIN)
    moon(A, 0.72, 0.28, 0.1, color=ICE, w=THIN)


@art("AzureBlade_R_StillWater")  # 명경지수: 칼이 비친 잔잔한 물
def _(A):
    odachi(A, 0.2, 0.42, 0.8, 0, color=WHITE)
    A.line(0.12, 0.6, 0.88, 0.6, w=THIN, color=A.accent)
    odachi(A, 0.2, 0.76, 0.8, 0, color=A.accent, w=THIN)
    A.shapes[-1]["Transparency"] = 0.5


@art("AzureBlade_R_Mark")  # 역습 표식: 과녁 위의 칼끝
def _(A):
    target(A, 0.62, 0.42, 0.24, color=WHITE, dot=A.accent)
    odachi(A, 0.2, 0.78, 0.6, -45, color=ICE)


@art("AzureBlade_R_FalseGap")  # 거짓 틈: 열린 틈과 그 뒤의 칼
def _(A):
    A.rect(0.36, C, 0.2, 0.6, 0, WHITE, 0.04, LINE)
    A.rect(0.64, C, 0.2, 0.6, 0, WHITE, 0.04, LINE)
    odachi(A, C, 0.82, 0.6, -90, color=A.accent)


@art("AzureBlade_C_Agility")  # 민첩성: 날랜 발자국과 바람결
def _(A):
    footprints(A, 0.4, 0.62, 0.5, ang=-20, n=3)
    chevrons(A, 0.74, 0.4, 0.2, 3, 0, 0.07, color=A.accent)


@art("AzureBlade_C_FocusUp")  # 집중력의 향상: 칼끝에 모이는 점
def _(A):
    odachi(A, 0.26, 0.74, 0.7, -45, color=WHITE)
    A.ring(0.72, 0.3, 0.1, w=THIN, color=A.accent)
    A.disc(0.72, 0.3, 0.025, A.accent)


@art("AzureBlade_C_WindBlade")  # 바람의 검: 칼을 감는 바람
def _(A):
    odachi(A, 0.24, 0.72, 0.76, -40, color=ICE)
    swirl(A, 0.64, 0.42, 0.14, color=A.accent, w=THIN)


@art("AzureBlade_C_Point")  # 칼끝 겨누기: 검집 끝이 가리키는 점
def _(A):
    odachi(A, 0.22, 0.6, 0.74, -10, sheathed=True)
    sparkle(A, 0.84, 0.48, 0.07, color=A.accent)


@art("AzureBlade_C_DrawPractice")  # 발검 연습: 반쯤 뽑힌 칼과 되풀이 표
def _(A):
    odachi(A, 0.26, 0.66, 0.72, -30, sheathed=True)
    repeat_sign(A, 0.72, 0.3, 0.26, color=A.accent)


@art("AzureBlade_C_Settle")  # 칼 쉬게 하기: 칼집에 누운 칼과 숨결
def _(A):
    odachi(A, 0.16, 0.62, 0.86, 0, sheathed=True)
    wave(A, C, 0.36, 0.4, 0.03, 1.5, color=A.accent, w=THIN)


@art("AzureBlade_C_Jeer")  # 도발 연습: 까딱이는 손가락
def _(A):
    hand_open(A, C, 0.56, 0.5)
    A.arc(C, 0.3, 0.12, 200, 340, w=THIN, color=A.accent)
    A.arc(C, 0.3, 0.18, 210, 330, w=THIN, color=A.accent, tr=0.4)


@art("AzureBlade_C_SheathBlock")  # 검집 막기: 가로로 든 검집이 받아낸 불꽃
def _(A):
    odachi(A, 0.14, 0.56, 0.86, 0, sheathed=True)
    burst(A, 0.6, 0.4, 0.12, 8, color=A.accent, w=THIN)


@art("AzureBlade_C_Stare")  # 끝까지 노려보기: 날카로운 눈
def _(A):
    eye(A, C, C, 0.56, color=WHITE, pupil=A.accent)
    A.line(0.26, 0.34, 0.44, 0.4, w=LINE)
    A.line(0.74, 0.34, 0.56, 0.4, w=LINE)


@art("AzureBlade_C_Through")  # 베어 넘기기: 나란한 셋을 꿰는 한 줄
def _(A):
    for x in (0.3, 0.5, 0.7):
        A.ring(x, C, 0.08, w=THIN, color=WHITE)
    A.line(0.14, 0.58, 0.86, 0.42, w=LINE, color=A.accent)


@art("AzureBlade_C_Cleave")  # 공간 가르기: 갈라진 공간의 금
def _(A):
    A.rect(C, C, 0.6, 0.6, 0, WHITE, 0.06, THIN)
    crack(A, C, C, 0.62, 60, color=A.accent, w=LINE)


@art("AzureBlade_C_Rebuke")  # 검집 되치기: 검집 끝에 부딪쳐 꺾인 화살
def _(A):
    odachi(A, 0.2, 0.72, 0.6, -40, sheathed=True)
    A.poly([(0.84, 0.2), (0.62, 0.36), (0.78, 0.5)], w=LINE, color=A.accent)


@art("AzureBlade_C_Deflect")  # 흘려 넘기기: 비스듬한 칼에 미끄러지는 화살
def _(A):
    odachi(A, 0.26, 0.76, 0.74, -50, color=WHITE)
    arrow(A, 0.82, 0.3, 0.56, 0.4, color=A.accent, w=THIN)
    arrow(A, 0.56, 0.4, 0.74, 0.62, color=A.accent, w=THIN)


@art("AzureBlade_C_Momentum")  # 기세: 앞으로 쏟아지는 화살 셋
def _(A):
    chevrons(A, 0.56, C, 0.3, 3, 0, 0.1, color=A.accent)
    odachi(A, 0.16, 0.74, 0.5, -20, color=WHITE)


@art("AzureBlade_C_Answer")  # 도발 응수: 마주 선 손과 칼
def _(A):
    hand_open(A, 0.3, 0.56, 0.36)
    odachi(A, 0.56, 0.78, 0.6, -70, color=A.accent)


@art("AzureBlade_C_Linger")  # 집중 유지: 한 칸 더 남은 모래시계
def _(A):
    hourglass(A, 0.42, C, 0.46, color=WHITE, sand=A.accent)
    A.disc(0.72, 0.68, 0.03, A.accent)


@art("AzureBlade_C_Whet")  # 칼날 벼리기: 숫돌 위의 칼과 불티
def _(A):
    A.rect(C, 0.72, 0.56, 0.12, 0, WHITE, 0.2, LINE)
    odachi(A, 0.2, 0.56, 0.7, -8, color=ICE)
    sparkle(A, 0.7, 0.42, 0.06, color=A.accent)


@art("AzureBlade_C_Wanderer")  # 방랑 검객: 삿갓과 등에 멘 칼
def _(A):
    A.poly([(0.22, 0.5), (0.5, 0.3), (0.78, 0.5)], w=LINE * 1.3, color=WHITE)
    A.line(0.2, 0.5, 0.8, 0.5, w=LINE)
    odachi(A, 0.32, 0.62, 0.6, -15, sheathed=True)


@art("AzureBlade_C_Shoulder")  # 어깨 너머: 어깨 위로 솟은 칼자루
def _(A):
    A.arc(C, 0.78, 0.26, 180, 360, w=LINE, color=WHITE)
    odachi(A, 0.62, 0.4, 0.6, 120, sheathed=True)
    sparkle(A, 0.28, 0.3, 0.06, color=A.accent)


@art("AzureBlade_C_Glare")  # 도발의 눈빛: 눈에서 번지는 빛
def _(A):
    eye(A, C, 0.52, 0.48, color=WHITE, pupil=A.accent)
    rays(A, C, 0.52, 0.28, 0.36, 8, 0, color=A.accent, w=THIN)
