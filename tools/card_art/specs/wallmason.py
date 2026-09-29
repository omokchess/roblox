# -*- coding: utf-8 -*-
# 월 메이슨 카드 그림 — 벽·돌·정·신앙
from cards import *  # noqa: F401,F403


@art("WallMason_E_Cathedral")  # 대성당
def _(A):
    cathedral(A, C, 0.54, 0.7)
    A.ring(C, 0.51, 0.03, w=THIN, color=A.accent)


@art("WallMason_E_MasonHand")  # 석공의 손: 돌을 든 손
def _(A):
    hand_open(A, C, 0.62, 0.56)
    A.rect(C, 0.24, 0.3, 0.14, 0, A.accent, 0.1, LINE)


@art("WallMason_E_Cornerstone")  # 초석: 모서리 돌에 새긴 별
def _(A):
    A.poly([(0.2, 0.2), (0.2, 0.8), (0.8, 0.8)], w=LINE, tr=0.4)
    A.rect(0.36, 0.64, 0.26, 0.26, 0, WHITE, 0.06, LINE)
    star(A, 0.36, 0.64, 0.07, color=A.accent, w=THIN)


@art("WallMason_E_InterlockedStone")  # 맞물린 돌
def _(A):
    A.poly([(0.18, 0.3), (0.52, 0.3), (0.52, 0.46), (0.42, 0.46), (0.42, 0.62), (0.18, 0.62)], closed=True, w=LINE)
    A.poly([(0.46, 0.5), (0.58, 0.5), (0.58, 0.34), (0.82, 0.34), (0.82, 0.7), (0.46, 0.7)], closed=True, w=LINE, color=A.accent)


@art("WallMason_R_ChiselMastery")  # 정 다듬기 숙련
def _(A):
    chisel(A, 0.46, 0.46, 0.62, 40)
    sparkle(A, 0.74, 0.72, 0.07, color=A.accent, w=THIN)
    sparkle(A, 0.26, 0.24, 0.04, w=THIN)


@art("WallMason_R_FinishedWall")  # 완성된 벽
def _(A):
    bricks(A, C, 0.56, 0.62, rows=4, cols=3, w=THIN * 1.3)
    A.line(0.18, 0.28, 0.82, 0.28, w=LINE, color=A.accent)


@art("WallMason_R_Mortar")  # 회반죽: 흙손과 벽돌
def _(A):
    bricks(A, 0.44, 0.66, 0.48, rows=2, cols=2, w=THIN * 1.2)
    trowel(A, 0.64, 0.34, 0.46, -35, color=A.accent)


@art("WallMason_R_Quarry")  # 채석장: 곡괭이와 돌
def _(A):
    pick(A, 0.44, 0.42, 0.6, -50)
    stone(A, 0.66, 0.7, 0.1, color=A.accent)
    stone(A, 0.4, 0.76, 0.07, w=THIN)


@art("WallMason_R_Blessing")  # 축복: 벽 위로 내리는 빛
def _(A):
    bricks(A, C, 0.72, 0.56, rows=2, cols=3, w=THIN)
    rays(A, C, 0.3, 0.06, 0.2, 7, 90, spread=150, color=A.accent, w=THIN)
    A.disc(C, 0.3, 0.035, A.accent)


@art("WallMason_R_BackRowAim")  # 후열 조준: 벽 너머 과녁
def _(A):
    bricks(A, 0.38, 0.62, 0.36, rows=3, cols=2, w=THIN)
    target(A, 0.7, 0.34, 0.12, w=THIN, dot=A.accent)
    A.arc(0.46, 0.5, 0.26, 230, 310, w=THIN, color=A.accent)


@art("WallMason_R_Buttress")  # 버팀벽: 기대선 버팀
def _(A):
    A.rect(0.64, 0.54, 0.16, 0.6, 0, WHITE, 0.04, LINE)
    A.poly([(0.56, 0.3), (0.3, 0.84), (0.2, 0.84)], w=LINE, color=A.accent)
    A.line(0.44, 0.56, 0.56, 0.56, w=THIN)


@art("WallMason_R_Keystone")  # 쐐기돌
def _(A):
    arch(A, C, 0.56, 0.52, 0.56, keystone=A.accent)
    A.line(0.16, 0.84, 0.84, 0.84, w=THIN, tr=0.4)


@art("WallMason_R_Consecration")  # 성별: 빛나는 십자 아래 벽
def _(A):
    cross(A, C, 0.36, 0.38, color=A.accent)
    bricks(A, C, 0.72, 0.62, rows=2, cols=3, w=THIN)
    rays(A, C, 0.3, 0.2, 0.26, 6, 0, w=THIN, color=A.accent)


@art("WallMason_R_Relayer")  # 재적층: 도는 화살과 겹친 층
def _(A):
    for i, tr in enumerate((0.4, 0.2, 0.0)):
        A.rect(C, 0.4 + i * 0.12, 0.44, 0.08, 0, WHITE, 0.2, THIN * 1.2, tr)
    loop_arrow(A, C, 0.52, 0.34, color=A.accent, w=THIN, start=-60, end=60)


@art("WallMason_C_Harden")  # 굳히기: 방패를 두른 벽돌
def _(A):
    shield(A, C, 0.52, 0.64, color=A.accent)
    A.rect(C, 0.48, 0.26, 0.14, 0, WHITE, 0.1, LINE)


@art("WallMason_C_EvenBreath")  # 고른 숨: 벽돌과 고른 물결
def _(A):
    A.rect(C, 0.62, 0.34, 0.16, 0, WHITE, 0.1, LINE)
    wave(A, C, 0.36, 0.56, 0.035, 2, color=A.accent)


@art("WallMason_C_MasonPrayer")  # 석공의 기도: 돌 위 촛불
def _(A):
    A.rect(C, 0.76, 0.4, 0.12, 0, WHITE, 0.1, LINE)
    candle(A, C, 0.5, 0.5, fire=A.accent)


@art("WallMason_C_SameStone")  # 같은 돌: 쌍둥이 돌
def _(A):
    stone(A, 0.36, C, 0.14)
    stone(A, 0.64, C, 0.14, color=A.accent)
    A.line(0.46, C, 0.54, C, w=THIN)


@art("WallMason_C_Groundwork")  # 터 다지기: 땅에 박은 말뚝
def _(A):
    A.line(0.14, 0.62, 0.86, 0.62, w=LINE)
    for x in (0.28, 0.5, 0.72):
        A.line(x, 0.42, x, 0.76, w=LINE, color=A.accent if x == 0.5 else WHITE)
        A.line(x - 0.03, 0.42, x + 0.03, 0.42, w=THIN)
    A.line(0.2, 0.7, 0.8, 0.7, w=THIN, tr=0.4)


@art("WallMason_C_SelfBulwark")  # 자기 방벽: 벽돌로 된 방패
def _(A):
    shield(A, C, C, 0.64)
    bricks(A, C, 0.44, 0.36, rows=3, cols=2, color=A.accent, w=THIN)


@art("WallMason_C_DriveWedge")  # 쐐기 박기: 틈에 박히는 쐐기
def _(A):
    A.rect(0.3, 0.6, 0.2, 0.36, 0, WHITE, 0.06, LINE)
    A.rect(0.7, 0.6, 0.2, 0.36, 0, WHITE, 0.06, LINE)
    A.poly([(0.44, 0.24), (0.56, 0.24), (0.5, 0.56)], closed=True, w=LINE, color=A.accent)


@art("WallMason_C_Overlay")  # 덧대기: 겹친 판
def _(A):
    A.rect(0.44, 0.44, 0.36, 0.26, -8, WHITE, 0.08, LINE)
    A.rect(0.56, 0.58, 0.36, 0.26, 6, A.accent, 0.08, LINE)


@art("WallMason_C_Grit")  # 근성: 벽돌을 쥔 주먹
def _(A):
    fist(A, C, 0.56, 0.5)
    A.rect(C, 0.3, 0.28, 0.12, 0, A.accent, 0.1, LINE)


@art("WallMason_C_MasonOath")  # 석공의 맹세: 깃발
def _(A):
    banner(A, C, 0.52, 0.62)
    A.rect(0.56, 0.3, 0.12, 0.06, 0, A.accent, 0.1, THIN)


@art("WallMason_C_QuickRite")  # 빠른 축성: 모래시계와 벽
def _(A):
    hourglass(A, 0.4, C, 0.5, sand=A.accent)
    bricks(A, 0.7, 0.62, 0.26, rows=2, cols=1, w=THIN)


@art("WallMason_C_Deflect")  # 빗겨내기: 벽에 튕기는 화살
def _(A):
    A.rect(0.32, C, 0.16, 0.6, 0, WHITE, 0.04, LINE)
    for y in (0.34, 0.46, 0.58, 0.7):
        A.line(0.25, y, 0.39, y, w=THIN)
    arrow(A, 0.84, 0.22, 0.46, 0.48, w=THIN)
    arrow(A, 0.46, 0.52, 0.84, 0.8, color=A.accent, w=LINE)


@art("WallMason_C_StonePicking")  # 돌 고르기: 고른 돌 하나
def _(A):
    for (x, y, r) in ((0.3, 0.66, 0.08), (0.5, 0.72, 0.07), (0.7, 0.66, 0.08)):
        stone(A, x, y, r, w=THIN)
    stone(A, C, 0.38, 0.12, color=A.accent)
    A.line(0.44, 0.54, 0.5, 0.58, w=THIN)
    A.line(0.5, 0.58, 0.6, 0.5, w=THIN)


@art("WallMason_C_LongChisel")  # 긴 정
def _(A):
    chisel(A, C, C, 0.8, 30)
    A.line(0.2, 0.3, 0.3, 0.3, w=THIN, color=A.accent)
    A.line(0.2, 0.36, 0.34, 0.36, w=THIN, color=A.accent)


@art("WallMason_C_Footstone")  # 밑돌: 받침돌과 보호막
def _(A):
    A.rect(C, 0.74, 0.5, 0.12, 0, WHITE, 0.08, LINE)
    A.arc(C, 0.68, 0.34, 180, 360, w=THIN, color=A.accent)
    A.arc(C, 0.68, 0.26, 180, 360, w=THIN, color=A.accent, tr=0.4)


@art("WallMason_C_LuckyChisel")  # 운 좋은 정: 정과 네잎
def _(A):
    chisel(A, 0.44, 0.52, 0.6, 45)
    clover(A, 0.72, 0.3, 0.05, color=A.accent)


@art("WallMason_C_Sharing")  # 나눔: 돌을 건네는 두 화살
def _(A):
    stone(A, 0.3, C, 0.1)
    stone(A, 0.7, C, 0.1, color=A.accent)
    arrow(A, 0.4, 0.44, 0.6, 0.44, w=THIN, head=0.04)
    arrow(A, 0.6, 0.56, 0.4, 0.56, w=THIN, head=0.04)


@art("WallMason_C_Cushion")  # 완충: 물결 위에 얹힌 벽돌
def _(A):
    A.rect(C, 0.42, 0.34, 0.16, 0, WHITE, 0.1, LINE)
    wave(A, C, 0.6, 0.56, 0.03, 2, color=A.accent)
    wave(A, C, 0.68, 0.56, 0.03, 2, color=A.accent, tr=0.4)


@art("WallMason_C_StoneOffering")  # 헌석: 제단 위의 돌
def _(A):
    A.rect(C, 0.72, 0.5, 0.16, 0, WHITE, 0.06, LINE)
    A.line(0.3, 0.8, 0.3, 0.86, w=THIN)
    A.line(0.7, 0.8, 0.7, 0.86, w=THIN)
    stone(A, C, 0.52, 0.1, color=A.accent)
    rays(A, C, 0.52, 0.14, 0.2, 5, -90, spread=140, w=THIN)


@art("WallMason_C_Tireless")  # 쉬지 않는 축조: 도는 화살 안의 벽돌
def _(A):
    loop_arrow(A, C, C, 0.3, color=A.accent, w=LINE)
    A.rect(C, C, 0.26, 0.13, 0, WHITE, 0.1, LINE)
