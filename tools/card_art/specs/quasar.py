# -*- coding: utf-8 -*-
# 퀘이사 카드 그림 — 질량·중력·차징·방출
from cards import *  # noqa: F401,F403


def core(A, cx=C, cy=C, r=0.1, color=None):
    A.disc(cx, cy, r, color or A.accent)
    A.ring(cx, cy, r * 1.5, w=THIN, tr=0.3)


@art("Quasar_R_ChargeGuard")  # 차징 방호: 당겨지는 소용돌이 앞 방패
def _(A):
    spiral(A, 0.6, 0.44, 0.26, 2.0, color=A.accent, w=THIN)
    shield(A, 0.4, 0.58, 0.42)


@art("Quasar_R_ShoulderIt")  # 대신 짊어지기: 별을 짊어진 사람
def _(A):
    person(A, C, 0.62, 0.52, arms=-60)
    A.ring(C, 0.24, 0.12, w=LINE, color=A.accent)
    A.line(0.38, 0.36, 0.62, 0.36, w=LINE)


@art("Quasar_R_TidalForce")  # 조석력: 달과 끌려오는 물결
def _(A):
    moon(A, 0.34, 0.34, 0.16)
    wave(A, C, 0.64, 0.66, 0.05, 2, color=A.accent)
    wave(A, C, 0.76, 0.66, 0.04, 2, tr=0.4)
    arrow(A, 0.56, 0.56, 0.42, 0.44, w=THIN, head=0.05)


@art("Quasar_R_Accretion")  # 강착: 원반에 둘러싸인 핵
def _(A):
    for rx, tr in ((0.38, 0.4), (0.3, 0.2), (0.22, 0.0)):
        A.ellipse(C, C, rx, rx * 0.3, -15, w=THIN, tr=tr)
    core(A, r=0.07)


@art("Quasar_R_Compression")  # 압축: 안으로 몰리는 화살
def _(A):
    for a in (0, 90, 180, 270):
        p1, p2 = polar(C, C, 0.38, a), polar(C, C, 0.16, a)
        arrow(A, *p1, *p2, w=LINE, head=0.06)
    A.disc(C, C, 0.06, A.accent)


@art("Quasar_R_Jet")  # 제트: 블랙홀에서 뿜는 두 줄기
def _(A):
    A.ellipse(C, C, 0.3, 0.09, -10, w=THIN)
    A.disc(C, C, 0.07)
    for sgn in (-1, 1):
        A.line(C, C + sgn * 0.1, C + sgn * 0.02, C + sgn * 0.4, w=LINE * 1.3, color=A.accent)
        A.line(C - 0.03, C + sgn * 0.14, C - 0.02, C + sgn * 0.34, w=THIN, color=A.accent, tr=0.4)


@art("Quasar_R_Redshift")  # 적색편이: 늘어나는 파동
def _(A):
    pts = []
    x = 0.14
    period = 0.06
    while x < 0.86:
        pts.append(x)
        x += period
        period *= 1.22
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        col = WHITE if i < 3 else A.accent
        A.arc((a + b) / 2, C, (b - a) / 2, 180 if i % 2 == 0 else 0, 360 if i % 2 == 0 else 180, w=LINE, color=col)


@art("Quasar_R_HighDensity")  # 고밀도: 빽빽한 육각 결정
def _(A):
    for i, (dx, dy) in enumerate(((0, 0), (0.15, 0.09), (-0.15, 0.09), (0, 0.18), (0.15, -0.09), (-0.15, -0.09), (0, -0.18))):
        stone(A, C + dx, C + dy, 0.085, color=A.accent if i == 0 else WHITE, w=THIN * 1.2, ang=30)


@art("Quasar_R_Recoil")  # 반발: 방패에 맞고 튕기는 화살
def _(A):
    shield(A, 0.34, 0.52, 0.44)
    arrow(A, 0.84, 0.24, 0.6, 0.46, w=THIN)
    arrow(A, 0.6, 0.52, 0.86, 0.74, color=A.accent, w=LINE)


@art("Quasar_R_Overcharge")  # 과충전: 넘치는 고리와 번개
def _(A):
    A.ring(C, C, 0.3, w=LINE)
    A.arc(C, C, 0.36, -60, 240, w=THIN, color=A.accent)
    bolt(A, C, C, 0.36, color=A.accent)


@art("Quasar_C_FastCharge")  # 가속 차징
def _(A):
    spiral(A, 0.42, C, 0.28, 2.0, w=THIN)
    chevrons(A, 0.74, C, 0.2, 2, 0, gap=0.07, color=A.accent, w=LINE)


@art("Quasar_C_Emit")  # 방출: 터져 나오는 빛
def _(A):
    burst(A, C, C, 0.36, 14, color=A.accent, w=THIN * 1.2, core=WHITE)


@art("Quasar_C_Planted")  # 고정: 닻
def _(A):
    anchor(A, C, 0.5, 0.66)
    A.line(0.2, 0.86, 0.8, 0.86, w=THIN, color=A.accent)


@art("Quasar_C_Halo")  # 광륜: 머리 위 고리
def _(A):
    person(A, C, 0.6, 0.5)
    A.ellipse(C, 0.3, 0.14, 0.04, 0, w=LINE, color=A.accent)


@art("Quasar_C_Cooling")  # 냉각: 눈송이
def _(A):
    snowflake(A, C, C, 0.3, color=A.accent)


@art("Quasar_C_TidalSwing")  # 조수 간만: 밀려오고 빠지는 물
def _(A):
    wave(A, C, 0.44, 0.66, 0.06, 1.5, w=LINE)
    wave(A, C, 0.6, 0.66, 0.06, 1.5, w=LINE, color=A.accent, phase=180)
    arrow(A, 0.3, 0.76, 0.7, 0.76, w=THIN, head=0.05)
    arrow(A, 0.7, 0.26, 0.3, 0.26, w=THIN, head=0.05)


@art("Quasar_C_FallPractice")  # 낙하 연습: 떨어지는 별
def _(A):
    comet(A, 0.62, 0.64, 0.07, 55, 0.44, head=A.accent)
    A.line(0.2, 0.82, 0.84, 0.82, w=THIN, tr=0.4)


@art("Quasar_C_Hull")  # 외피: 두 겹 껍질
def _(A):
    A.ring(C, C, 0.3, w=LINE * 1.2)
    A.ring(C, C, 0.22, w=THIN, color=A.accent)
    core(A, r=0.06, color=WHITE)


@art("Quasar_C_Tow")  # 견인: 끌려오는 사슬
def _(A):
    chain(A, 0.46, 0.5, 0.5, 0, 4)
    A.arc(0.8, 0.5, 0.08, 90, 270, w=LINE, color=A.accent)
    A.disc(0.18, 0.5, 0.05)


@art("Quasar_C_Stagger")  # 휘청임: 흔들리는 별 셋
def _(A):
    A.arc(C, 0.52, 0.28, 200, 340, w=THIN, ry=0.08)
    for (x, y) in ((0.3, 0.44), (0.5, 0.36), (0.7, 0.44)):
        star(A, x, y, 0.06, color=A.accent, w=THIN)
    wave(A, C, 0.7, 0.4, 0.03, 2, w=THIN)


@art("Quasar_C_MirrorFace")  # 반사면: 거울에 튕기는 빛
def _(A):
    A.rect(0.4, C, 0.1, 0.56, 0, WHITE, 0.2, LINE)
    arrow(A, 0.84, 0.22, 0.48, 0.48, w=THIN)
    arrow(A, 0.48, 0.52, 0.84, 0.78, color=A.accent, w=LINE)


@art("Quasar_C_Afterglow")  # 여운: 사라지는 고리
def _(A):
    for r, tr in ((0.12, 0.0), (0.2, 0.3), (0.28, 0.55), (0.36, 0.75)):
        A.ring(C, C, r, w=THIN * 1.2, color=A.accent, tr=tr)
    A.disc(C, C, 0.05)
