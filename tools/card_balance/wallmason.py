# -*- coding: utf-8 -*-
"""
월 메이슨 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/wallmason.py
- 사다리가 없던 6레벨 카드 13장에 새로 매김.
- 고른 숨: 사다리가 뒤집혀 있었다("{1}스택당" 칸이 1→6 으로 올라 레벨이 오를수록 약해짐) → 스택당 고정, 회복량이 오른다.
- 버팀목(희귀): 아군에게 걸리는 디버프가 없어 죽은 카드였다 → [벽]을 가진 동안 그로기가 덜 찬다.
- 긴 정: 2스킬이 이미 줄 끝까지 닿는다 → 위아래 줄 맨 앞 적에게도 피해.
- 맞물린 돌: 파티 전제(가장 많은 [벽]을 가진 아군에게서 가져온다). 값이 없어 1레벨.
- 파티 전제: 맞물린 돌, 같은 돌, 나눔
- 적 치명타가 새로 생겨(기본 5%·150%) 버팀목 패시브·완충이 할 일이 생겼다.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "WallMason_E_InterlockedStone": {"MaxLevel": 1, "Party": True},
    "WallMason_R_Buttress": {
        # 2026-10-09 그로기 삭제로 변경
        "Description": "[벽]을 보유한 동안, 방어에 실패해 맞는 피해가 {30}% 감소한다.",
        "Levels": [[30]],
    },
    "WallMason_C_EvenBreath": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 2, 2, 2]]},
    "WallMason_C_SameStone": {"Party": True},
    "WallMason_C_Overlay": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 2, 2, 2]]},
    "WallMason_C_Grit": {
        "Description": "체력이 {50}% 미만일 때, [벽] 효과가 {20}% 증가한다.",
        "Levels": [[50, 50, 50, 50, 50, 50], [20, 25, 30, 35, 40, 50]],
    },
    "WallMason_C_MasonOath": {"Levels": [[10, 10, 10, 10, 10, 10], [3, 3, 4, 4, 5, 5], [15, 15, 18, 18, 21, 24]]},
    "WallMason_C_QuickRite": {"Levels": [[1, 1, 1, 1, 1, 2]]},
    "WallMason_C_Deflect": {"Levels": [[3, 4, 5, 6, 7, 8]]},
    "WallMason_C_StonePicking": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "WallMason_C_LongChisel": {
        "Description": "2스킬이 위아래 줄의 맨 앞 적에게도 {40}%의 피해를 준다.",
        "Levels": [[40, 45, 50, 55, 60, 70]],
    },
    "WallMason_C_Footstone": {"Levels": [[8, 10, 12, 14, 16, 20]]},
    "WallMason_C_LuckyChisel": {"Levels": [[3, 4, 5, 6, 7, 8]]},
    "WallMason_C_Sharing": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 1, 2, 2, 2]], "Party": True},
    "WallMason_C_Cushion": {"Levels": [[20, 24, 28, 32, 36, 40]]},
    "WallMason_C_StoneOffering": {"Levels": [[6, 7, 8, 9, 10, 12]]},
    "WallMason_C_Tireless": {"Levels": [[1, 1, 1, 1, 2, 2]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
