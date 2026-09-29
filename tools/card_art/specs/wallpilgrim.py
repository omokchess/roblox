# -*- coding: utf-8 -*-
# 월 필그림스 카드 그림 — 못·광신·낙인·신앙
from cards import *  # noqa: F401,F403


@art("WallPilgrim_E_Fanatic")  # 광신도: 불타는 십자
def _(A):
    flame(A, C, 0.46, 0.74, color=A.accent, inner=False)
    cross(A, C, 0.56, 0.5)


@art("WallPilgrim_E_Stigmata")  # 성흔: 못 자국 난 손바닥
def _(A):
    hand_open(A, C, 0.52, 0.7)
    A.ring(C, 0.6, 0.045, w=THIN * 1.3, color=A.accent)
    drop(A, C, 0.82, 0.12, color=A.accent)


@art("WallPilgrim_E_Evangelism")  # 전도: 빛을 퍼뜨리는 책
def _(A):
    book(A, C, 0.62, 0.62)
    rays(A, C, 0.4, 0.14, 0.3, 7, -90, spread=150, color=A.accent, w=THIN)


@art("WallPilgrim_E_NailAndHammer")  # 못과 망치
def _(A):
    hammer(A, 0.44, 0.44, 0.6, -135)
    nail(A, 0.66, 0.6, 0.44, 90, color=A.accent)


@art("WallPilgrim_R_DeepNail")  # 깊은 못: 돌에 깊이 박힌 못
def _(A):
    A.rect(C, 0.7, 0.62, 0.26, 0, WHITE, 0.06, LINE)
    nail(A, C, 0.52, 0.66, 90, color=A.accent)


@art("WallPilgrim_R_DoubleStrike")  # 겹쳐 박기: 나란한 두 못
def _(A):
    nail(A, 0.4, 0.5, 0.58, 90)
    nail(A, 0.6, 0.54, 0.58, 90, color=A.accent)
    A.line(0.2, 0.8, 0.8, 0.8, w=THIN, tr=0.4)


@art("WallPilgrim_R_Brand")  # 낙인: 달군 인두
def _(A):
    A.line(0.28, 0.24, 0.52, 0.48, w=LINE * 1.3)
    A.ring(0.62, 0.58, 0.14, w=LINE, color=A.accent)
    cross(A, 0.62, 0.6, 0.16, color=A.accent, w=THIN)
    for (x, y) in ((0.82, 0.4), (0.84, 0.52)):
        A.arc(x, y, 0.04, 180, 360, w=THIN, tr=0.3)


@art("WallPilgrim_R_MadeExample")  # 본보기: 못 박힌 해골 위 십자
def _(A):
    skull(A, C, 0.6, 0.52)
    cross(A, C, 0.26, 0.3, color=A.accent)


@art("WallPilgrim_R_Sermon")  # 설교: 퍼지는 종소리
def _(A):
    bell(A, C, 0.5, 0.54)
    for r, tr in ((0.3, 0.0), (0.38, 0.4)):
        A.arc(C, 0.5, r, -40, 40, w=THIN, color=A.accent, tr=tr)
        A.arc(C, 0.5, r, 140, 220, w=THIN, color=A.accent, tr=tr)


@art("WallPilgrim_R_Contagion")  # 전염: 번지는 점들
def _(A):
    A.disc(C, C, 0.06, A.accent)
    for i in range(6):
        p = polar(C, C, 0.24, i * 60)
        A.line(*polar(C, C, 0.08, i * 60), *polar(C, C, 0.19, i * 60), w=THIN, tr=0.3)
        A.ring(*p, 0.045, w=THIN, color=A.accent)


@art("WallPilgrim_R_PilgrimStaff")  # 순례 지팡이
def _(A):
    staff(A, 0.44, 0.52, 0.74, -85)
    A.ring(0.46, 0.2, 0.04, w=THIN, color=A.accent)
    footprints(A, 0.7, 0.66, 0.4, ang=-90, n=2)


@art("WallPilgrim_R_Offering")  # 헌납: 불 피운 제단 그릇
def _(A):
    bowl(A, C, 0.6, 0.54)
    flame(A, C, 0.4, 0.34, color=A.accent, inner=False, w=THIN * 1.2)


@art("WallPilgrim_R_DivineOffice")  # 성무일도: 책과 시계
def _(A):
    book(A, 0.42, 0.62, 0.5)
    clock(A, 0.68, 0.32, 0.14, color=A.accent, w=THIN * 1.2)


@art("WallPilgrim_R_Penance")  # 고행: 채찍과 핏방울
def _(A):
    A.line(0.2, 0.2, 0.34, 0.34, w=LINE * 1.6)
    chain(A, 0.5, 0.5, 0.46, 45, 4)
    drop(A, 0.72, 0.78, 0.14, color=A.accent)
    drop(A, 0.84, 0.64, 0.1, color=A.accent)


@art("WallPilgrim_C_Setting")  # 고착: 돌에 박혀 굳은 못
def _(A):
    stone(A, C, 0.62, 0.26)
    nail(A, C, 0.46, 0.5, 90)
    A.ring(C, 0.62, 0.05, w=THIN, color=A.accent)


@art("WallPilgrim_C_NailHole")  # 못 자국 넓히기
def _(A):
    A.ring(C, C, 0.12, w=LINE * 1.3, color=A.accent)
    for a in (20, 110, 200, 290):
        A.poly([polar(C, C, 0.14, a), polar(C, C, 0.26, a + 10), polar(C, C, 0.34, a - 5)], w=THIN)


@art("WallPilgrim_C_FirstNail")  # 첫 못
def _(A):
    nail(A, C, 0.54, 0.66, 90)
    sparkle(A, 0.7, 0.26, 0.06, color=A.accent, w=THIN)


@art("WallPilgrim_C_Meditation")  # 묵상: 촛불
def _(A):
    candle(A, C, 0.56, 0.66, fire=A.accent)


@art("WallPilgrim_C_Companion")  # 동행: 나란히 걷는 둘
def _(A):
    person(A, 0.38, 0.56, 0.5)
    person(A, 0.62, 0.56, 0.5)
    A.line(0.44, 0.5, 0.56, 0.5, w=THIN, color=A.accent)


@art("WallPilgrim_C_Cleave")  # 쪼갬: 갈라진 돌과 못
def _(A):
    A.poly([(0.2, 0.46), (0.46, 0.46), (0.42, 0.62), (0.48, 0.8), (0.2, 0.8)], closed=True, w=LINE)
    A.poly([(0.54, 0.46), (0.8, 0.46), (0.8, 0.8), (0.56, 0.8), (0.5, 0.62)], closed=True, w=LINE)
    nail(A, C, 0.3, 0.36, 90, color=A.accent)


@art("WallPilgrim_C_RustyNail")  # 녹슨 못: 휜 못과 녹
def _(A):
    A.line(0.4, 0.22, 0.46, 0.56, w=LINE * 1.5)
    A.line(0.46, 0.56, 0.62, 0.72, w=LINE * 1.5)
    A.line(0.3, 0.22, 0.5, 0.2, w=LINE * 1.8)
    dots(A, [(0.44, 0.36), (0.48, 0.46), (0.55, 0.63), (0.6, 0.7)], 0.018, A.accent)


@art("WallPilgrim_C_Congregation")  # 회중: 모인 셋
def _(A):
    person(A, 0.3, 0.6, 0.42)
    person(A, C, 0.54, 0.46, arms=-20)
    person(A, 0.7, 0.6, 0.42)
    A.ring(C, 0.34, 0.06, w=THIN, color=A.accent)


@art("WallPilgrim_C_Hymn")  # 성가: 십자와 음표
def _(A):
    cross(A, 0.36, 0.5, 0.46)
    note(A, 0.66, 0.48, 0.4, color=A.accent)


@art("WallPilgrim_C_Weight")  # 무게: 추와 못
def _(A):
    A.poly([(0.3, 0.8), (0.36, 0.44), (0.64, 0.44), (0.7, 0.8)], closed=True, w=LINE)
    A.ring(C, 0.38, 0.06, w=LINE)
    nail(A, C, 0.64, 0.24, 90, color=A.accent)


@art("WallPilgrim_C_BleedNail")  # 출혈 못
def _(A):
    nail(A, 0.44, 0.44, 0.6, 90)
    drop(A, 0.64, 0.72, 0.18, color=A.accent)


@art("WallPilgrim_C_Martyr")  # 순교자: 광륜과 칼
def _(A):
    A.ellipse(C, 0.26, 0.16, 0.05, 0, w=LINE, color=A.accent)
    person(A, C, 0.6, 0.5, arms=-10)
    sword(A, 0.74, 0.6, 0.34, 90, w=THIN)


@art("WallPilgrim_C_Guilt")  # 죄책: 사슬 감긴 심장
def _(A):
    heart(A, C, 0.5, 0.64)
    chain(A, C, 0.52, 0.5, -20, 4, color=A.accent, w=THIN)


@art("WallPilgrim_C_Echo")  # 메아리: 못질 소리가 울린다
def _(A):
    nail(A, 0.34, 0.5, 0.5, 0)
    for r, tr in ((0.14, 0.0), (0.22, 0.3), (0.3, 0.55)):
        A.arc(0.54, 0.5, r, -50, 50, w=THIN, color=A.accent, tr=tr)


@art("WallPilgrim_C_Alms")  # 적선: 그릇과 동전
def _(A):
    bowl(A, C, 0.62, 0.5)
    coin(A, 0.44, 0.4, 0.06, color=A.accent)
    coin(A, 0.58, 0.32, 0.05, color=A.accent)


@art("WallPilgrim_C_LongArm")  # 긴 팔: 멀리 뻗는 못
def _(A):
    nail(A, C, C, 0.78, 0)
    chevrons(A, 0.24, 0.72, 0.14, 2, 0, gap=0.05, color=A.accent, w=THIN)


@art("WallPilgrim_C_ShortPrayer")  # 짧은 기도: 작은 초와 모래시계
def _(A):
    candle(A, 0.36, 0.58, 0.5)
    hourglass(A, 0.68, 0.54, 0.4, sand=A.accent)


@art("WallPilgrim_C_Whetted")  # 못 갈기: 숫돌에 튀는 불똥
def _(A):
    A.rect(C, 0.7, 0.6, 0.12, -5, WHITE, 0.2, LINE)
    nail(A, 0.46, 0.44, 0.5, 60)
    for a in (-60, -30, 0):
        A.line(*polar(0.62, 0.62, 0.05, a), *polar(0.62, 0.62, 0.14, a), w=THIN, color=A.accent)


@art("WallPilgrim_C_PointOut")  # 지목: 가리키는 화살과 과녁
def _(A):
    target(A, 0.66, 0.4, 0.14, w=THIN, dot=A.accent)
    arrow(A, 0.2, 0.76, 0.56, 0.5, w=LINE)


@art("WallPilgrim_C_Inherited")  # 물려받은 못: 한 못에서 다른 못으로
def _(A):
    nail(A, 0.32, 0.52, 0.46, 90)
    nail(A, 0.7, 0.52, 0.46, 90, color=A.accent)
    A.arc(C, 0.4, 0.2, 200, 340, w=THIN, tr=0.2)
    arrow(A, 0.62, 0.3, 0.68, 0.34, w=THIN, head=0.04)
