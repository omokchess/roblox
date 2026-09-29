# -*- coding: utf-8 -*-
"""
전 직업 사다리 정리(2026-09-28). 돌리기: python tools/card_balance/fixups.py
- 화음: "일부" → {50}% 로 값을 보이게(레벨마다 오른다)
- 소모 않기: 6레벨인데 사다리가 없었다 → 주기가 3턴에서 1턴까지 준다
- 약점 파괴: 글의 {1}과 사다리 1레벨(2)이 어긋나 있었다 → 글을 2로
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Musician_C_Chord": {
        "Description": "둘 이상의 아군에게 [브릴란테]가 있으면, 자신의 `벨로체` 또한 [브릴란테] 효과를 {50}% 받는다.",
        "Levels": [[50, 55, 60, 65, 70, 80]],
    },
    "Duelist_R_NoSpend": {"Levels": [[3, 3, 2, 2, 2, 1]]},
    "WallBreaker_C_WeakPoint": {"Levels": [[2, 2, 2, 2, 2], [2, 3, 3, 4, 5]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
