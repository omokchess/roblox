# -*- coding: utf-8 -*-
"""
퀘이사 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/quasar.py
- 34장 전부 사다리(Levels)가 없었다 → 6레벨 카드가 레벨을 올려도 그대로였다. 전부 새로 매김.
- 전직 갈래: 광속 붕괴(늘 3단계·질량 전부 소모) ⟂ 거센 빛(상한 40) — 둘을 같이 들면 질량 40 을 매번
  3단계로 터뜨려 +200% 가 된다. 블랙홀·사건의 지평선은 어느 쪽과도 맞는다.
- 파티 전제: 대신 짊어지기·반발·덩치·광륜 (아군을 대신 맞기·인접 아군)
- 고정: "차징 중 밀려나면" — 밀치는 적이 없어 죽은 카드였다 → 차징 중 그로기 면역 + 턴마다 질량.
- 과충전: 값이 하나뿐(3턴) → 1레벨 카드.
- 패시브 아득한 빛: 한 번에 최대 질량 2 (스킬 한 번에 20 이 다 차서 질량 카드가 무의미했다) → 흡수·방출은 +N 으로.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Quasar_E_FierceLight": {"Levels": [[20, 20], [40, 50]], "Excludes": ["Quasar_E_LightspeedCollapse"]},
    "Quasar_E_BlackHole": {"Levels": [[25, 30], [5, 8]]},
    "Quasar_E_EventHorizon": {"Levels": [[50, 60]]},
    "Quasar_E_LightspeedCollapse": {"Levels": [[3, 3], [2, 1]], "Excludes": ["Quasar_E_FierceLight"]},
    "Quasar_R_ChargeGuard": {"Levels": [[30, 33, 36, 40, 44, 48]]},
    "Quasar_R_ShoulderIt": {"Levels": [[2, 2, 3, 3, 4, 4]], "Party": True},
    "Quasar_R_TidalForce": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "Quasar_R_Accretion": {"Levels": [[1, 1, 2, 2, 2, 3]]},
    "Quasar_R_Compression": {"Levels": [[5, 5, 5, 5, 5, 5], [7, 7.5, 8, 8.5, 9, 10]]},
    "Quasar_R_Jet": {"Levels": [[3, 3, 3, 3, 3, 3], [2, 2, 2, 3, 3, 3]]},
    "Quasar_R_Redshift": {"Levels": [[15, 17, 19, 21, 23, 25]]},
    "Quasar_R_HighDensity": {"Levels": [[15, 15, 14, 14, 13, 12], [12, 13, 14, 15, 16, 18]]},
    "Quasar_R_Recoil": {"Levels": [[25, 28, 31, 34, 37, 40]], "Party": True},
    "Quasar_R_Overcharge": {"MaxLevel": 1},
    "Quasar_C_FastCharge": {"Levels": [[1, 1, 1, 1, 1, 1], [5, 6, 7, 8, 9, 10]]},
    "Quasar_C_GravityCrush": {"Levels": [[8, 10, 12, 14, 16, 18]]},
    "Quasar_C_SeedMass": {"Levels": [[3, 3, 4, 4, 5, 6]]},
    # 아득한 빛에 한 번 최대 2 가 붙어 % 증가는 뜻이 없어졌다 → 한 번에 +N
    "Quasar_C_Absorb": {"Description": "피해를 받을 때 [질량]을 {1} 더 얻는다.", "Levels": [[1, 1, 1, 2, 2, 2]]},
    "Quasar_C_Emit": {"Description": "스킬로 피해를 줄 때 [질량]을 {1} 더 얻는다.", "Levels": [[1, 1, 1, 1, 2, 2]]},
    "Quasar_C_Bulk": {"Levels": [[20, 24, 28, 32, 36, 40]], "Party": True},
    "Quasar_C_FeedMass": {"Levels": [[3, 3, 4, 4, 5, 5]]},
    "Quasar_C_Planted": {
        # 2026-10-09 그로기 삭제로 변경
        "Description": "차징 중에는 받는 피해가 {10}% 감소하고, 턴을 시작할 때마다 [질량]을 {1} 얻는다.",
        "Levels": [[10, 10, 10, 15, 15, 15], [1, 1, 1, 2, 2, 2]],
    },
    "Quasar_C_Halo": {"Levels": [[8, 9, 10, 11, 12, 14]], "Party": True},
    "Quasar_C_Cooling": {"Levels": [[15, 15, 14, 13, 12, 12], [1, 1, 1, 1, 1, 2]]},
    "Quasar_C_Shockwave": {"Levels": [[3, 3, 3, 3, 3, 3], [1, 1, 1, 1, 1, 1], [10, 14, 18, 22, 26, 30]]},
    "Quasar_C_TidalSwing": {"Levels": [[1, 1, 1, 1, 1, 1], [2, 2, 3, 3, 4, 4]]},
    "Quasar_C_FallPractice": {"Levels": [[2, 2, 3, 3, 4, 5]]},
    "Quasar_C_Hull": {"Levels": [[5, 6, 7, 8, 9, 10]]},
    "Quasar_C_Tow": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "Quasar_C_Stagger": {"Levels": [[1, 1, 1, 1, 2, 2], [20, 22, 24, 26, 28, 30]]},
    "Quasar_C_RestMass": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "Quasar_C_MirrorFace": {"Levels": [[10, 15, 20, 25, 30, 40]]},
    "Quasar_C_Hold": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "Quasar_C_Afterglow": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1, 2, 2, 3, 3]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
