# -*- coding: utf-8 -*-
"""
월 브레이커 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/wallbreaker.py
- 전직 갈래: 무너진 성벽(허물 벽을 크게, 더 아프게 맞는다) ⟂ 자해(제 살 깎기를 싸게) —
  둘을 함께 들면 싼 제 살 깎기로 상한 10 을 매 턴 채워 뒷일이 없다.
- 순교: 파티 전제(사망한 아군). 자비: 순례길(같은 행 월 필그림 아군) 파티 전제.
- 광적인 파괴: 글의 {2}턴과 사다리 1레벨 값(1)이 어긋나 있었다 → 2턴으로 맞춤.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "WallBreaker_E_BrokenRampart": {"Excludes": ["WallBreaker_E_SelfHarm"]},
    "WallBreaker_E_SelfHarm": {"Excludes": ["WallBreaker_E_BrokenRampart"]},
    # 글의 {5} 와 사다리 1레벨(3)이 어긋나 있었다 → 3·5
    "WallBreaker_E_Martyrdom": {"Party": True, "Levels": [[3, 5], [20, 25]]},
    "WallBreaker_C_SameStride": {"Party": True},
    "WallBreaker_C_ShortWindup": {"Levels": [[7, 6], [2, 2]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
