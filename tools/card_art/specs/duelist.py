# -*- coding: utf-8 -*-
# 결투사 카드 그림
from cards import *  # noqa: F401,F403


@art("Duelist_E_IronWall")  # 철벽: 벽돌로 찬 방패
def _(A):
    shield(A, C, 0.5, 0.72, w=LINE * 1.2)
    bricks(A, C, 0.42, 0.34, rows=3, cols=3, color=A.accent, w=THIN)


@art("Duelist_R_Bloodletting")  # 방혈: 레이피어 끝에서 떨어지는 피
def _(A):
    rapier(A, 0.46, 0.46, 0.7, -40)
    drop(A, 0.72, 0.62, 0.16, color=A.accent)
    drop(A, 0.78, 0.8, 0.11, color=A.accent)


@art("Duelist_R_Counter")  # 기회 노리기: 눈과 겨눈 칼
def _(A):
    eye(A, C, 0.36, 0.5, pupil=A.accent)
    rapier(A, C, 0.66, 0.56, 180)


@art("Duelist_R_Pivot")  # 발끝 전환: 도는 발자국
def _(A):
    footprints(A, C, 0.56, 0.5, ang=-90)
    loop_arrow(A, C, 0.52, 0.3, color=A.accent, w=THIN * 1.3, start=-40, end=210)


@art("Duelist_R_Feint")  # 페인트: 칼과 그 잔상
def _(A):
    rapier(A, 0.42, 0.5, 0.66, -60)
    for i in range(3):
        A.line(0.5 + i * 0.04, 0.26 + i * 0.03, 0.72 + i * 0.04, 0.62 + i * 0.03, w=THIN, color=A.accent, tr=0.3 + i * 0.2)


@art("Duelist_R_BloodLoss")  # 실혈: 떨어지는 핏방울 셋
def _(A):
    drop(A, C, 0.36, 0.34, color=A.accent)
    drop(A, 0.34, 0.66, 0.22, color=A.accent, filled=False)
    drop(A, 0.66, 0.7, 0.18, color=A.accent, filled=False)


@art("Duelist_R_Slip")  # 흘리기: 칼날에 미끄러지는 화살
def _(A):
    rapier(A, 0.46, 0.56, 0.64, -20)
    A.arc(0.54, 0.62, 0.3, 200, 290, w=LINE, color=A.accent)
    arrow(A, 0.48, 0.33, 0.72, 0.18, color=A.accent, w=LINE)


@art("Duelist_R_Vigil")  # 경계: 크게 뜬 눈
def _(A):
    eye(A, C, C, 0.72, pupil=A.accent)
    rays(A, C, C, 0.32, 0.38, 7, -90, spread=150, w=THIN)


@art("Duelist_C_CatchBreath")  # 숨 고르기: 숨결
def _(A):
    swirl(A, C, C, 0.26, color=A.accent)
    wave(A, C, 0.7, 0.5, 0.03, 2, w=THIN)


@art("Duelist_C_SwitchGuard")  # 전환 보호: 두 태세를 바꾸는 방패
def _(A):
    shield(A, C, 0.52, 0.56)
    A.line(C, 0.26, C, 0.78, w=THIN)
    arrow(A, 0.3, 0.22, 0.7, 0.22, color=A.accent, w=THIN, head=0.05)
    arrow(A, 0.7, 0.84, 0.3, 0.84, color=A.accent, w=THIN, head=0.05)


@art("Duelist_C_ShallowCut")  # 얕은 상처: 가는 베인 자국
def _(A):
    A.line(0.26, 0.64, 0.74, 0.36, w=THIN * 1.2)
    A.line(0.3, 0.66, 0.7, 0.42, w=THIN * 0.7, color=A.accent)
    drop(A, 0.62, 0.62, 0.12, color=A.accent)
    rapier(A, 0.5, 0.3, 0.4, 0)


@art("Duelist_C_FlowThrough")  # 반동: 튕겨 나가는 화살
def _(A):
    A.line(0.2, 0.7, 0.8, 0.7, w=LINE)
    arrow(A, 0.24, 0.26, 0.48, 0.66, w=LINE)
    arrow(A, 0.52, 0.66, 0.78, 0.26, color=A.accent, w=LINE)


@art("Duelist_C_FindTheSpot")  # 급소 찾기
def _(A):
    target(A, C, C, 0.3, dot=A.accent)


@art("Duelist_C_Offense")  # 공세
def _(A):
    rapier(A, 0.42, 0.5, 0.66, 0)
    chevrons(A, 0.76, 0.5, 0.2, 2, 0, gap=0.07, color=A.accent, w=THIN)


@art("Duelist_C_Defense")  # 수세
def _(A):
    shield(A, 0.56, 0.52, 0.56)
    rapier(A, 0.4, 0.56, 0.56, 110)


@art("Duelist_C_Sentry")  # 파수: 세운 칼과 망루
def _(A):
    A.rect(0.62, 0.62, 0.24, 0.42, 0, WHITE, 0.06, LINE)
    A.poly([(0.48, 0.41), (0.52, 0.34), (0.58, 0.41), (0.62, 0.34), (0.66, 0.41), (0.72, 0.34), (0.76, 0.41)], w=THIN)
    A.rect(0.62, 0.56, 0.06, 0.1, 0, A.accent, 0.5, THIN)
    rapier(A, 0.3, 0.5, 0.7, -90)


@art("Duelist_C_LowStance")  # 자세 낮추기: 낮게 겨눈 칼
def _(A):
    A.line(0.16, 0.78, 0.84, 0.78, w=THIN, tr=0.4)
    rapier(A, 0.5, 0.66, 0.66, 10)
    chevrons(A, C, 0.32, 0.22, 2, 90, gap=0.08, color=A.accent, w=THIN)


@art("Duelist_C_Retribution")  # 복수: 되돌아가는 칼
def _(A):
    rapier(A, 0.5, 0.6, 0.6, 180)
    loop_arrow(A, 0.5, 0.42, 0.22, color=A.accent, w=THIN * 1.3, start=160, end=380)


@art("Duelist_C_Bond")  # 결속: 매듭으로 묶인 두 칼
def _(A):
    rapier(A, 0.44, 0.5, 0.64, -70)
    rapier(A, 0.56, 0.5, 0.64, -110)
    A.ring(C, 0.56, 0.07, w=LINE, color=A.accent)


@art("Duelist_C_BleedInduce")  # 깊은 상처
def _(A):
    A.line(0.24, 0.3, 0.76, 0.7, w=LINE * 1.8, color=A.accent)
    A.line(0.28, 0.28, 0.78, 0.66, w=THIN * 0.7)
    for (x, y, sz) in ((0.4, 0.62, 0.14), (0.52, 0.8, 0.1)):
        drop(A, x, y, sz, color=A.accent)


@art("Duelist_C_Steady")  # 안정: 평형 저울
def _(A):
    scales(A, C, 0.52, 0.62)
    A.disc(C, 0.22, 0.02, A.accent)


@art("Duelist_C_StepBack")  # 흐름: 물러서는 발과 물결
def _(A):
    footprints(A, C, 0.46, 0.5, ang=90)
    wave(A, C, 0.78, 0.56, 0.035, 2, color=A.accent)


@art("Duelist_C_GripWrap")  # 칼자루 감기: 끈을 감은 손잡이
def _(A):
    A.line(C, 0.12, C, 0.5, w=LINE)
    A.line(0.32, 0.5, 0.68, 0.5, w=LINE * 1.4)
    A.rect(C, 0.66, 0.08, 0.28, 0, WHITE, 0.3, LINE)
    for i in range(5):
        y = 0.55 + i * 0.05
        A.line(0.45, y + 0.02, 0.55, y - 0.02, w=THIN, color=A.accent)
    A.disc(C, 0.84, 0.03)
