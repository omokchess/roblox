# -*- coding: utf-8 -*-
"""
음악가 카드 밸런스·구조 (2026-09-28). 기준: 사용자 편집본(카드들.json) → 어긋난 사다리·죽은 효과만 고치고
포지션·전직 갈래를 더했다. 돌리기: python tools/card_balance/musician.py
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    # 전직 갈래: 반주자(아군에게 몰아줌) ⟂ 협주자(자신에게 몰아줌). 긴 호흡·공명은 어느 쪽과도 맞는다.
    "Musician_E_Accompanist": {"Excludes": ["Musician_E_Concertist"]},
    "Musician_E_Concertist": {"Excludes": ["Musician_E_Accompanist"]},
    # 공명: 2레벨 "소모당 48%·상한 24%/24%" 는 편집 중 실수로 보인다 → 소모당 7%, 상한 45%/22%
    "Musician_E_Resonance": {
        "Description": "[음표]를 넘치게 얻어도 최대 {2}개까지 더 가질 수 있다.\n"
        "[음표]를 소모할 때마다 아군의 [치명타 피해량]과 자신의 [치명타 확률]이 {5}%씩 증가한다.\n"
        "[치명타 피해량]은 최대 {30}%, [치명타 확률]은 {15}%까지 증가한다.",
        "Levels": [[2, 4], [5, 7], [30, 45], [15, 22]],
    },
    # 메트로놈: 편집본은 1레벨이 "1턴마다"(2·3레벨보다 셈) — 칸이 뒤바뀐 것으로 보고 턴 간격 3→3→2, 개수 1→2→2
    "Musician_R_Metronome": {"Levels": [[3, 3, 2], [1, 2, 2]]},
    "Musician_R_Modulation": {
        "Description": "[박자표]를 얻을 때마다, 모든 적에게 소모한 [음표] 수×{1.5}만큼 피해를 입힌다.",
        "Levels": [[1.5, 2, 2.5, 3, 3.5, 4]],
    },
    # 투티: 3레벨 문턱 1명(=혼자서도 늘 켜짐)·+3 은 너무 셈. 파티 전제 카드로 두고 문턱 3→2→2, +1→+1→+2
    "Musician_R_Tutti": {"Levels": [[3, 2, 2], [1, 1, 2]], "Party": True},
    # 조율: 뒷열(5~6열)에서만 — 버퍼는 뒤에 선다. 조건이 붙은 만큼 값을 올렸다
    "Musician_C_Tuning": {
        "Description": "후열(5~6열)에 서 있으면 [박자표] 값 1당 자신이 [받는 피해량]이 {4}% 감소한다.",
        "Levels": [[4, 5, 6, 7, 8]],
    },
    # 온쉼표: 이동도 공격도 하지 않은 턴(온전한 쉼) — 피해 칸을 피하려면 움직여야 하므로 진짜 선택이 된다
    "Musician_C_Rest": {
        "Description": "이동하지도 공격하지도 않고 턴을 넘기면, 스테미나를 {8} 더 회복한다.",
        "Levels": [[8, 10, 12, 14, 16, 18]],
    },
    # 8분 강조: 적에게는 스테미나가 없다(죽은 효과) → 8분음표의 치명타 버프를 키우는 쪽으로
    "Musician_C_Eighth": {
        "Description": "8분음표의 [치명타 확률]·[치명타 피해량] 증가가 개수당 {0.5}%p 더 증가한다.",
        "Levels": [[0.5, 0.75, 1, 1.25, 1.5, 2]],
    },
    "Musician_C_Staccato": {"Levels": [[8, 10, 13, 16, 19, 22]]},
    # 서곡: 1레벨 값이 1%(편집 실수) → 10%부터
    "Musician_C_Lullaby": {"Levels": [[1, 1, 1, 2, 2, 2], [10, 12, 14, 16, 18, 20]]},
    "Musician_C_Echo": {"Levels": [[12, 15, 18, 21, 24, 27]]},
    "Musician_C_Crescendo": {"Levels": [[0.5, 0.6, 0.7, 0.8, 0.9, 1]]},
    "Musician_C_Encore": {"Levels": [[3, 3, 3, 3, 3, 3], [7, 10, 13, 16, 19, 22]]},
    "Musician_C_Chord": {"Party": True},
}

if __name__ == "__main__":
    print(apply(EDITS))
