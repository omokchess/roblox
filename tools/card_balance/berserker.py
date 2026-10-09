# -*- coding: utf-8 -*-
"""
광전사 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/berserker.py
- 전직 갈래: 흡혈(분노를 못 얻음) ⟂ 피의 대가(분노·자해로 종베기) — 흡혈은 분노 축과 정면으로 부딪친다.
  벼랑 끝·불굴은 어느 쪽과도 맞는다.
- 무모: 전열(1~2열)에서만 — 물러서면 안전하지만 화력을 잃는다(매 턴의 선택)
- 재기·견딤·고집: 사다리 정리(파일 안 주석)
- 들이받기: 편집본은 "출혈 {5}당" 칸에 2·3·4·4·6(피해 칸 값)이 들어가 있었다 → 5·5·4·4·3·3
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Berserker_E_Vampire": {"Excludes": ["Berserker_E_BloodPrice"]},
    "Berserker_E_BloodPrice": {"Excludes": ["Berserker_E_Vampire"]},
    "Berserker_R_Reckless": {
        "Description": "전열(1~2열)에 서 있으면 [받는 피해량]이 {20}% 증가하고, [가하는 피해량]이 {20}% 증가한다.",
        "Levels": [[20, 30, 40, 50], [20, 30, 40, 50]],
    },
    "Berserker_C_Ram": {"Levels": [[5, 5, 4, 4, 3, 3], [1, 2, 3, 4, 5, 6]]},
    # 재기: 사다리가 없었다(6레벨인데 값이 그대로) → 문턱 25% 고정, 회복량 25→40%
    "Berserker_R_SecondWind": {"Levels": [[25, 25, 25, 25, 25, 25], [25, 28, 31, 34, 37, 40]]},
    # 견딤: 문턱이 25→32 로 튀었다(감소량 줄을 옮겨 적은 듯) → 25→35 고르게
    "Berserker_R_PainTolerance": {"Levels": [[25, 27, 29, 31, 33, 35], [30, 32, 34, 36, 38, 40]]},
    # 고집: 기절은 1턴이라 "6턴 감소" 는 뜻이 없다 → 횟수가 오른다
    # 2026-10-09 그로기 삭제로 변경: 체력 30% 아래로 떨어지면 분노
    "Berserker_C_Stubborn": {
        "Description": "전투당 {1}회, 피해를 받아 체력이 30% 아래로 떨어지면 [분노]를 {2} 얻는다.",
        "Levels": [[1, 1, 2, 2, 3, 3], [2, 2, 2, 2, 3, 3]],
    },
    "Berserker_C_Numb": {"Description": "방어에 실패해 맞을 때 받는 피해가 {15}% 감소한다.", "Levels": [[15]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
