# -*- coding: utf-8 -*-
"""
결투사 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/duelist.py
- 전직 갈래: 철벽(방어 전용) ⟂ 광검(공격 전용) ⟂ 양날(매 턴 강제 전환) — 셋 다 태세 규칙 자체를 바꾼다.
  무명검(집중 상한)은 어느 쪽과도 맞는다.
- 파수: "인접한 아군" 은 솔로에서 죽은 조건 → 전열(1~2열)에 서면 자신 +, 인접 아군 + 는 파티에서.
- 결속: 파티 전제.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Duelist_E_IronWall": {"Excludes": ["Duelist_E_LightBlade", "Duelist_E_DoubleEdge"]},
    "Duelist_E_LightBlade": {"Excludes": ["Duelist_E_IronWall", "Duelist_E_DoubleEdge"]},
    "Duelist_E_DoubleEdge": {"Excludes": ["Duelist_E_IronWall", "Duelist_E_LightBlade"]},
    "Duelist_C_Sentry": {
        "Description": "전열(1~2열)에 서 있으면 [패링 범위]가 {8}% 증가한다.\n인접한 아군의 [패링 범위]가 {4}% 증가한다.",
        "Levels": [[8, 10, 12, 14, 16, 18], [4, 6, 8, 10, 10, 10]],
    },
    "Duelist_C_Bond": {"Party": True},
}

if __name__ == "__main__":
    print(apply(EDITS))
