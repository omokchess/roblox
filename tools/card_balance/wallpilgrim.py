# -*- coding: utf-8 -*-
"""
월 필그림스 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/wallpilgrim.py
- 34장 전부 사다리가 없었다 → 새로 매김. 숫자 없던 6레벨 카드(본보기·쪼갬·출혈 못)는 오르는 값을 {괄호}로.
- 전직 갈래: 광신도(광신 상한 20·중첩당 절반) ⟂ 성흔(광신이 지속 피해로) — 둘 다 광신 규칙 자체를 바꾼다.
- 적은 회복하지 않는다 → "회복량 감소" 카드는 죽어 있었다:
  녹슨 못 → 광신 걸린 적의 주는 피해 추가 감소.  ([낙인]의 회복 감소는 설명대로 두고 낙인 카드가 피해를 더한다)
- 묵상: "행동하지 않고" 는 스킬을 안 쓰는 턴이라 사실상 없다 → "공격하지 않고"(가드·명상 가능).
- 파티 전제: 동행(같은 행 월 필그림 아군), 죄책(표적 확률)
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "WallPilgrim_E_Fanatic": {"Levels": [[10, 10], [20, 25], [3, 2]], "Excludes": ["WallPilgrim_E_Stigmata"]},
    "WallPilgrim_E_Stigmata": {"Levels": [[1, 1], [3, 4]], "Excludes": ["WallPilgrim_E_Fanatic"]},
    "WallPilgrim_E_Evangelism": {"Levels": [[6, 5]]},
    "WallPilgrim_E_NailAndHammer": {
        "Description": "같은 행의 월 필그림스 아군(자신 포함)이 주는 피해가 대상의 [광신] 중첩 {1}당 {2}% 증가한다.",
        "Levels": [[1, 1], [2, 3]],
    },
    "WallPilgrim_R_DeepNail": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "WallPilgrim_R_DoubleStrike": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 2, 2, 2]]},
    "WallPilgrim_R_Brand": {"Levels": [[3, 3, 3, 3, 3, 3], [15, 18, 21, 24, 27, 30]]},
    "WallPilgrim_R_MadeExample": {
        "Description": "[낙인]이 찍힌 적을 처치하면, 남은 [광신]이 흩어지지 않고 중첩이 가장 높은 적에게 통째로 옮겨가며 {1}중첩이 더해진다.",
        "Levels": [[1, 1, 2, 2, 3, 3]],
    },
    "WallPilgrim_R_Sermon": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "WallPilgrim_R_Contagion": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "WallPilgrim_R_PilgrimStaff": {"Levels": [[12, 14, 16, 18, 20, 24]]},
    "WallPilgrim_R_Offering": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1], [10, 12, 14, 16, 18, 20]]},
    "WallPilgrim_R_DivineOffice": {"Levels": [[40, 40, 38, 36, 34, 30], [2, 2, 2, 2, 3, 3]]},
    "WallPilgrim_R_Penance": {"Levels": [[2, 2, 2, 2, 3, 3], [1, 1, 1, 1, 1, 2], [2, 2, 3, 3, 4, 4]]},
    "WallPilgrim_C_Setting": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "WallPilgrim_C_NailHole": {"Levels": [[2, 2, 3, 3, 4, 5]]},
    "WallPilgrim_C_FirstNail": {"Levels": [[3, 3, 4, 4, 5, 6]]},
    "WallPilgrim_C_Meditation": {
        "Description": "공격하지 않고 턴을 마치면, 신앙심이 {4} 증가한다.",
        "Levels": [[4, 5, 6, 7, 8, 10]],
    },
    "WallPilgrim_C_Companion": {"Levels": [[4, 5, 6, 7, 8, 10]], "Party": True},
    "WallPilgrim_C_Cleave": {
        "Description": "2스킬이 위아래 줄의 맨 앞 적에게도 {50}%의 피해와 [광신]을 준다.",
        "Levels": [[50, 55, 60, 65, 70, 80]],
    },
    "WallPilgrim_C_RustyNail": {
        "Description": "[광신]이 걸린 적이 주는 피해량이 {4}% 더 감소한다.",
        "Levels": [[4, 5, 6, 7, 8, 10]],
    },
    "WallPilgrim_C_Congregation": {"Levels": [[10, 12, 14, 16, 18, 20]]},
    "WallPilgrim_C_Hymn": {"Levels": [[8, 9, 10, 11, 12, 14]]},
    "WallPilgrim_C_Weight": {"Levels": [[1, 1, 1, 1, 1, 1], [0.5, 0.6, 0.7, 0.8, 0.9, 1], [5, 6, 7, 8, 9, 10]]},
    "WallPilgrim_C_BleedNail": {
        "Description": "[광신]을 걸 때 [출혈]도 {1} 부여한다.",
        "Levels": [[1, 1, 2, 2, 3, 3]],
    },
    "WallPilgrim_C_Martyr": {"Levels": [[6, 7, 8, 9, 10, 12]]},
    "WallPilgrim_C_Guilt": {"Levels": [[25, 28, 31, 34, 37, 40]], "Party": True},
    "WallPilgrim_C_Echo": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "WallPilgrim_C_Alms": {
        "Description": "같은 행의 아군(자신 포함)이 적을 처치하면 신앙심이 {4} 증가한다.",
        "Levels": [[4, 4, 5, 5, 6, 6]],
    },
    "WallPilgrim_C_LongArm": {
        "Description": "1스킬이 같은 줄 {1}칸 뒤의 적도 맞힌다.",
        "Levels": [[1, 1, 1, 2, 2, 2]],
    },
    "WallPilgrim_C_ShortPrayer": {"Levels": [[1, 1, 1, 1, 1, 2]]},
    "WallPilgrim_C_Whetted": {"Levels": [[12, 14, 16, 18, 20, 24]]},
    "WallPilgrim_C_PointOut": {"Levels": [[1, 1, 1, 1, 1, 1], [4, 5, 6, 7, 8, 10]]},
    "WallPilgrim_C_Inherited": {"Levels": [[3, 3, 4, 4, 5, 6]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
