# -*- coding: utf-8 -*-
# 음악가 카드 그림
from cards import *  # noqa: F401,F403


@art("Musician_E_LongBreath")  # 긴 호흡: 숨결과 긴 음
def _(A):
    swirl(A, 0.34, 0.4, 0.2, color=A.accent, w=THIN * 1.3)
    A.add(0.46, 0.66, 0.18, 0.13, -20, WHITE, 0.5, LINE)
    A.add(0.76, 0.66, 0.18, 0.13, -20, WHITE, 0.5, LINE)
    A.arc(0.61, 0.66, 0.15, 205, 335, w=LINE)
    A.line(0.3, 0.8, 0.88, 0.8, w=THIN, tr=0.4)


@art("Musician_E_Accompanist")  # 반주자: 건반
def _(A):
    piano(A, C, 0.6, 0.66)
    note(A, 0.36, 0.26, 0.28, color=A.accent)


@art("Musician_E_Concertist")  # 협주자: 조명 아래 음표
def _(A):
    A.poly([(0.5, 0.12), (0.26, 0.78), (0.74, 0.78)], closed=True, w=THIN, color=A.accent)
    note(A, 0.52, 0.52, 0.42)
    A.line(0.24, 0.84, 0.76, 0.84, w=LINE)


@art("Musician_R_Sustain")  # 지속음: 붙임줄로 이어진 긴 음
def _(A):
    A.add(0.3, 0.58, 0.18, 0.13, -20, WHITE, 0.5, LINE)
    A.add(0.7, 0.58, 0.18, 0.13, -20, WHITE, 0.5, LINE)
    A.arc(C, 0.5, 0.22, 20, 160, w=LINE, color=A.accent)
    staff_lines(A, C, C, 0.72, 0.07, 5)


@art("Musician_R_Modulation")  # 전조: 올림표와 오르는 화살
def _(A):
    sharp(A, 0.4, 0.54, 0.5)
    arrow(A, 0.66, 0.74, 0.66, 0.26, color=A.accent, w=LINE)


@art("Musician_R_Cadenza")  # 울림: 종과 퍼지는 울림
def _(A):
    bell(A, 0.44, 0.52, 0.6)
    for r, tr in ((0.14, 0), (0.22, 0.35)):
        A.arc(0.58, 0.46, r, -50, 50, w=THIN, color=A.accent, tr=tr)


@art("Musician_R_Tutti")  # 투티: 여럿이 함께 — 음표 무리
def _(A):
    note(A, 0.3, 0.56, 0.34)
    note(A, 0.52, 0.46, 0.4, color=A.accent)
    note(A, 0.72, 0.58, 0.3)


@art("Musician_R_Fermata")  # 페르마타
def _(A):
    A.arc(C, 0.56, 0.26, 180, 360, w=LINE * 1.3)
    A.disc(C, 0.5, 0.04, A.accent)
    A.line(0.2, 0.7, 0.8, 0.7, w=THIN, tr=0.4)


@art("Musician_R_Ostinato")  # 오스티나토: 도돌이표와 되풀이
def _(A):
    repeat_sign(A, 0.56, 0.5, 0.6)
    loop_arrow(A, 0.32, 0.5, 0.14, color=A.accent, w=THIN * 1.2)


@art("Musician_R_Overture")  # 자장가: 초승달과 작은 음표
def _(A):
    moon(A, 0.44, 0.46, 0.26, ang=0)
    note(A, 0.72, 0.62, 0.26, color=A.accent)
    star(A, 0.72, 0.26, 0.04, w=THIN)


@art("Musician_R_Descant")  # 데스캉트: 높이 뜬 음과 별
def _(A):
    staff_lines(A, C, 0.66, 0.7, 0.05, 5)
    note(A, 0.5, 0.36, 0.4)
    star(A, 0.72, 0.2, 0.06, color=A.accent, w=THIN)


@art("Musician_C_BarLine")  # 마디줄
def _(A):
    staff_lines(A, C, C, 0.72, 0.07, 5, tr=0.1)
    A.line(0.36, 0.34, 0.36, 0.66, w=LINE)
    A.line(0.64, 0.34, 0.64, 0.66, w=LINE, color=A.accent)


@art("Musician_C_Rest")  # 온쉼표
def _(A):
    staff_lines(A, C, C, 0.7, 0.07, 5)
    A.fill(C, 0.48, 0.16, 0.06, 0, A.accent, corner=0.1)


@art("Musician_C_Rosin")  # 송진: 송진 덩어리와 활
def _(A):
    A.rect(0.4, 0.58, 0.28, 0.2, -10, A.accent, 0.3, LINE)
    A.line(0.2, 0.34, 0.86, 0.46, w=THIN)
    A.line(0.2, 0.28, 0.86, 0.4, w=LINE)


@art("Musician_C_Vibrato")  # 비브라토: 떨리는 음
def _(A):
    note(A, 0.36, 0.5, 0.42)
    wave(A, 0.66, 0.46, 0.34, 0.035, 3, color=A.accent)


@art("Musician_C_Staccato")  # 스타카토: 끊는 점
def _(A):
    note(A, 0.44, 0.44, 0.44)
    A.disc(0.4, 0.8, 0.03, A.accent)
    A.line(0.66, 0.3, 0.82, 0.3, w=THIN)
    A.line(0.66, 0.4, 0.78, 0.4, w=THIN)


@art("Musician_C_Tuning")  # 조율: 소리굽쇠
def _(A):
    tuning_fork(A, C, C, 0.62)
    for r, tr in ((0.12, 0), (0.2, 0.4)):
        A.arc(C, 0.26, r, -150, -30, w=THIN, color=A.accent, tr=tr)


@art("Musician_C_Lullaby")  # 서곡: 떠오르는 해와 오선
def _(A):
    A.arc(C, 0.6, 0.18, 180, 360, w=LINE, color=A.accent)
    rays(A, C, 0.6, 0.23, 0.32, 7, -90, spread=160, color=A.accent, w=THIN)
    staff_lines(A, C, 0.72, 0.7, 0.045, 3, tr=0.2)


@art("Musician_C_Echo")  # 카덴차: 휘몰아치는 음들
def _(A):
    spiral(A, C, C, 0.3, 1.4, w=THIN, color=A.accent)
    for (x, y, s) in ((0.3, 0.3, 0.2), (0.7, 0.4, 0.18), (0.44, 0.72, 0.2)):
        note(A, x, y, s)


@art("Musician_C_Encore")  # 앙코르: 다시 한 번
def _(A):
    loop_arrow(A, C, C, 0.28, color=A.accent, w=LINE)
    note(A, C, 0.5, 0.32)


@art("Musician_C_Chord")  # 화음: 한 기둥에 겹친 음
def _(A):
    for i, y in enumerate((0.72, 0.6, 0.48)):
        A.add(0.44, y, 0.16, 0.11, -20, A.accent if i == 1 else WHITE, 0.5, 0)
    A.line(0.52, 0.72, 0.52, 0.2, w=LINE)
    staff_lines(A, C, 0.6, 0.66, 0.06, 5, tr=0.4)
