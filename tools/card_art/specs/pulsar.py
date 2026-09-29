# -*- coding: utf-8 -*-
# 펄서 카드 그림 — 자기장·감극·공명·수호
from cards import *  # noqa: F401,F403


def field_lines(A, cx, cy, r, color=WHITE, tr=0.3):
    for k in (0.6, 1.0):
        A.ellipse(cx - r * k * 0.55, cy, r * k * 0.55, r * k * 0.35, 90, w=THIN, color=color, tr=tr)
        A.ellipse(cx + r * k * 0.55, cy, r * k * 0.55, r * k * 0.35, 90, w=THIN, color=color, tr=tr)


@art("Pulsar_E_ImperfectLight")  # 불완전한 빛: 금 간 별
def _(A):
    star(A, C, C, 0.34, 5, 0.45, color=WHITE, w=LINE)
    crack(A, C, C, 0.4, 70, color=A.accent, w=THIN * 1.2)


@art("Pulsar_E_NuclearPasta")  # 핵파스타: 빽빽한 격자
def _(A):
    A.ring(C, C, 0.34, w=LINE)
    for i in range(-3, 4):
        y = C + i * 0.08
        half = (0.3 ** 2 - (i * 0.08) ** 2) ** 0.5 if abs(i * 0.08) < 0.3 else 0
        if half > 0.02:
            A.line(C - half, y, C + half, y, w=THIN, color=A.accent if i == 0 else WHITE)


@art("Pulsar_E_DimSupernova")  # 열화된 초신성: 흐려진 폭발
def _(A):
    burst(A, C, C, 0.36, 16, w=THIN * 1.2)
    A.disc(C, C, 0.1, A.accent, tr=0.4)
    A.ring(C, C, 0.4, w=THIN, tr=0.6)


@art("Pulsar_E_Geostationary")  # 정지 궤도: 행성과 멈춘 위성
def _(A):
    A.ring(C, 0.56, 0.18, w=LINE)
    orbit(A, C, 0.56, 0.36, 0.14, -15)
    satellite(A, 0.72, 0.3, 0.3, color=A.accent)


@art("Pulsar_R_CriticalFlux")  # 임계 자속: 자석과 번개
def _(A):
    magnet(A, 0.42, 0.56, 0.6, 0, tips=A.accent)
    bolt(A, 0.74, 0.34, 0.28, color=A.accent, w=THIN)


@art("Pulsar_R_Lock")  # 고정 극: 자석에 걸린 자물쇠
def _(A):
    magnet(A, 0.36, 0.48, 0.5, 0, tips=A.accent)
    lock(A, 0.68, 0.6, 0.4, key=A.accent)


@art("Pulsar_R_Induction")  # 유도: 코일과 흐르는 화살
def _(A):
    for i in range(5):
        A.ellipse(0.3 + i * 0.09, C, 0.05, 0.16, 0, w=THIN)
    arrow(A, 0.2, 0.78, 0.82, 0.78, color=A.accent, w=LINE)


@art("Pulsar_R_Arc")  # 방전: 두 점 사이 번개
def _(A):
    A.disc(0.2, 0.36, 0.05)
    A.disc(0.8, 0.64, 0.05)
    A.poly([(0.24, 0.38), (0.4, 0.3), (0.46, 0.5), (0.6, 0.42), (0.66, 0.6), (0.76, 0.62)], w=LINE, color=A.accent)
    A.poly([(0.46, 0.5), (0.5, 0.66)], w=THIN, color=A.accent)


@art("Pulsar_R_Flywheel")  # 플라이휠: 도는 톱니
def _(A):
    gear(A, C, C, 0.24, 9)
    A.arc(C, C, 0.38, -40, 60, w=THIN, color=A.accent)
    A.arc(C, C, 0.38, 140, 240, w=THIN, color=A.accent)


@art("Pulsar_R_Beacon")  # 등대 증폭
def _(A):
    lighthouse(A, C, 0.56, 0.66, beam=A.accent)


@art("Pulsar_R_Recharge")  # 재충전: 도는 화살과 번개
def _(A):
    loop_arrow(A, C, C, 0.3, w=LINE, start=-30, end=290)
    bolt(A, C, C, 0.3, color=A.accent, w=THIN * 1.2)


@art("Pulsar_R_QteMastery")  # 정밀 조율: 조준과 눈금
def _(A):
    target(A, C, C, 0.24, dot=A.accent)
    for i in range(-4, 5):
        x = C + i * 0.06
        A.line(x, 0.84, x, 0.8 if i % 2 else 0.77, w=THIN)


@art("Pulsar_R_Grounding")  # 접지
def _(A):
    ground_symbol(A, C, 0.64, 0.6)
    bolt(A, C, 0.3, 0.3, color=A.accent, w=THIN)


@art("Pulsar_R_Shroud")  # 차폐: 둥근 장막
def _(A):
    A.arc(C, 0.66, 0.34, 180, 360, w=LINE, color=A.accent)
    A.arc(C, 0.66, 0.26, 180, 360, w=THIN, tr=0.4)
    A.line(0.14, 0.66, 0.86, 0.66, w=LINE)
    person(A, C, 0.6, 0.3)


@art("Pulsar_C_ReflectUp")  # 반사 강화
def _(A):
    A.rect(0.38, C, 0.08, 0.5, 0, WHITE, 0.2, LINE)
    for dy, tr in ((-0.12, 0), (0.0, 0.2), (0.12, 0.4)):
        arrow(A, 0.46, C + dy, 0.82, C + dy * 2, color=A.accent, w=THIN, head=0.05)


@art("Pulsar_C_DepolarDamage")  # 감극 활용: 자석의 음극과 과녁
def _(A):
    magnet(A, 0.36, 0.54, 0.46, 0)
    A.line(0.62, 0.3, 0.78, 0.3, w=LINE * 1.3, color=A.accent)
    target(A, 0.7, 0.66, 0.12, w=THIN)


@art("Pulsar_C_Spin")  # 회전: 도는 별
def _(A):
    star(A, C, C, 0.16, 4, 0.4, color=A.accent, w=THIN * 1.2)
    A.arc(C, C, 0.3, 200, 330, w=LINE)
    A.arc(C, C, 0.3, 20, 150, w=LINE)
    A.line(*polar(C, C, 0.3, 330), *polar(*polar(C, C, 0.3, 330), 0.06, 150), w=LINE)
    A.line(*polar(C, C, 0.3, 150), *polar(*polar(C, C, 0.3, 150), 0.06, -30), w=LINE)


@art("Pulsar_C_Orbit")  # 궤도
def _(A):
    A.disc(C, C, 0.07)
    orbit(A, C, C, 0.34, 0.16, -20, w=THIN * 1.2, moon=A.accent, moon_at=40)
    orbit(A, C, C, 0.24, 0.1, 25, w=THIN, moon=WHITE, moon_at=200)


@art("Pulsar_C_Afterglow")  # 잔광: 꼬리를 끄는 빛
def _(A):
    comet(A, 0.66, 0.36, 0.07, -150, 0.46, head=A.accent)
    dots(A, [(0.3, 0.7), (0.4, 0.64), (0.22, 0.58)], 0.012)


@art("Pulsar_C_Attraction")  # 인력: 자석으로 끌려오는 점
def _(A):
    magnet(A, 0.34, 0.5, 0.5, 90)
    for i, (x, y) in enumerate(((0.62, 0.36), (0.72, 0.5), (0.62, 0.64))):
        A.disc(x, y, 0.03, A.accent)
        A.line(x + 0.04, y, x + 0.12, y, w=THIN, tr=0.4)


@art("Pulsar_C_Magnetize")  # 자화: 반짝이는 자석
def _(A):
    magnet(A, C, 0.56, 0.62, 0, tips=A.accent)
    sparkle(A, 0.74, 0.24, 0.06, color=A.accent, w=THIN)
    sparkle(A, 0.26, 0.28, 0.04, w=THIN)


@art("Pulsar_C_Backflow")  # 역류: 되감기는 화살
def _(A):
    A.arc(C, C, 0.28, 90, 360, w=LINE)
    arrow(A, C + 0.28, C, C + 0.28, C + 0.02, w=LINE)
    arrow(A, C, C + 0.28, 0.2, C + 0.28, color=A.accent, w=LINE)


@art("Pulsar_C_Residue")  # 잔류: 남은 입자
def _(A):
    A.ring(C, C, 0.26, w=THIN, tr=0.5)
    import random
    rnd = random.Random(7)
    for i in range(14):
        a, d = rnd.uniform(0, 360), rnd.uniform(0.05, 0.32)
        A.disc(*polar(C, C, d, a), rnd.uniform(0.01, 0.022), A.accent if i % 3 == 0 else WHITE)


@art("Pulsar_C_Focused")  # 집속: 렌즈로 모이는 빛
def _(A):
    A.ellipse(0.4, C, 0.06, 0.26, 0, w=LINE)
    for dy in (-0.18, 0, 0.18):
        A.line(0.14, C + dy, 0.36, C + dy, w=THIN)
        A.line(0.44, C + dy, 0.78, C, w=THIN, color=A.accent)
    A.disc(0.8, C, 0.03, A.accent)


@art("Pulsar_C_GuardLight")  # 수호광: 빛나는 방패
def _(A):
    shield(A, C, 0.56, 0.54)
    rays(A, C, 0.56, 0.34, 0.44, 7, -90, spread=160, color=A.accent, w=THIN)


@art("Pulsar_C_StaticField")  # 정지장: 자기력선과 한가운데 점
def _(A):
    field_lines(A, C, C, 0.4)
    A.disc(C, C, 0.05, A.accent)


@art("Pulsar_C_Afterimage")  # 잔상: 별과 그 흐린 복제
def _(A):
    for i, tr in enumerate((0.7, 0.45, 0.0)):
        pts = []
        for k in range(10):
            rr = 0.18 if k % 2 == 0 else 0.08
            pts.append(polar(0.34 + i * 0.13, C, rr, -90 + k * 36))
        A.poly(pts, closed=True, w=THIN * 1.2, color=A.accent if i == 2 else WHITE, tr=tr)


@art("Pulsar_C_RecoilControl")  # 반동 제어: 용수철에 받친 화살
def _(A):
    for i in range(6):
        A.line(0.2 + i * 0.05, 0.56 + (0.08 if i % 2 else -0.08), 0.25 + i * 0.05, 0.56 + (-0.08 if i % 2 else 0.08), w=THIN)
    A.line(0.5, 0.44, 0.5, 0.68, w=LINE)
    arrow(A, 0.52, 0.56, 0.84, 0.56, color=A.accent, w=LINE)


@art("Pulsar_C_Relay")  # 중계: 이어진 세 마디
def _(A):
    pts = [(0.24, 0.66), (0.5, 0.34), (0.76, 0.66)]
    A.poly(pts, w=THIN)
    for i, (x, y) in enumerate(pts):
        A.ring(x, y, 0.07, w=LINE, color=A.accent if i == 1 else WHITE)


@art("Pulsar_C_LightUp")  # 점등: 켜진 전구
def _(A):
    bulb(A, C, 0.5, 0.62, glow=A.accent)
    rays(A, C, 0.44, 0.22, 0.3, 5, -90, spread=150, color=A.accent, w=THIN)


@art("Pulsar_C_Coil")  # 코일
def _(A):
    for i in range(6):
        A.ellipse(0.26 + i * 0.09, C, 0.07, 0.2, 15, w=THIN * 1.2, color=A.accent if i in (2, 3) else WHITE)
    A.line(0.12, C, 0.2, C, w=LINE)
    A.line(0.8, C, 0.88, C, w=LINE)


@art("Pulsar_C_Discharge")  # 방출 조율: 고리가 터지는 순간
def _(A):
    A.ring(C, C, 0.14, w=LINE)
    for i in range(8):
        a = i * 45 + 22
        A.line(*polar(C, C, 0.2, a), *polar(C, C, 0.34, a), w=LINE, color=A.accent)


@art("Pulsar_C_FixedAim")  # 고정 조준
def _(A):
    A.ring(C, C, 0.26, w=LINE)
    for a in (0, 90, 180, 270):
        A.line(*polar(C, C, 0.1, a), *polar(C, C, 0.36, a), w=THIN)
    A.disc(C, C, 0.035, A.accent)


@art("Pulsar_C_Trailing")  # 여광: 흐르는 빛줄기
def _(A):
    for i, tr in enumerate((0.0, 0.3, 0.55)):
        y = 0.4 + i * 0.1
        A.line(0.2, y + 0.1, 0.72, y - 0.1, w=LINE if i == 0 else THIN, color=A.accent if i == 0 else WHITE, tr=tr)
    A.disc(0.74, 0.3, 0.04, A.accent)
