# -*- coding: utf-8 -*-
"""
연금술사 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/alchemist.py
- 전직 갈래: 로우리스크 로우리턴(부작용을 받는 피해 감소로 뒤집는다) ⟂ 과다복용(중독의 버프·디버프 ×2) — 정반대 방향.
- 과다복용: 값이 없어 1레벨.
- 정제: "각 병을 얻을 확률을 32%로" 는 섞기가 세 종류 33%씩(사용자 지시)이라 뜻이 없었다 → 원액마다 32% 로 병 하나 더.
- 가득 찬 가방: 네 종류(회복 병 포함)는 섞기로 모을 수 없다 → 독·화염·기름 세 종류, 던지는 병 수가 오른다.
- 내성: [과다 회복]·도트 피해를 받을 일이 없었다 → 체력 절반 이하에서 받는 회복량 증가.
- 약초학: 사다리가 뒤집혀 있었다(약재 몇 개당 칸이 1→2 로 올라 레벨이 오를수록 약해짐) → 약재당 % 가 오른다.
- 새 자원 [회복 병]: 보험 패시브가 쓰는 병. 섞기로는 안 나오고 호신용 물약·꾸준한 조제(네 종류 중 무작위)로 얻는다.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Alchemist_E_LowRisk": {"Excludes": ["Alchemist_E_SelfPrescribe"]},
    "Alchemist_E_SelfPrescribe": {"MaxLevel": 1, "Excludes": ["Alchemist_E_LowRisk"]},
    "Alchemist_R_Distill": {
        "Description": "`섞기`를 쓰면 [화염병]을 하나 확정으로 더 얻고, 쓴 [원액] 하나마다 {32}% 확률로 [꽉 찬 병]을 하나 더 얻는다.\n화염병 말고 더 얻은 병이 없다면 [빈 병] {1}개를 돌려받는다.",
        "Levels": [[32, 34, 36, 38, 40, 42], [1, 1, 1, 1, 1, 1]],
    },
    "Alchemist_R_CriticalBlend": {
        "Description": "[독 병]·[화염병]·[기름 병]을 모두 가지고 있다면, `던지기`가 병을 {2}개 던진다.",
        "Levels": [[2, 2, 2, 2, 3, 3]],
    },
    "Alchemist_R_Antidote": {
        "Description": "자신에게 쌓인 `부작용` 중첩 {1}개를 {2}턴마다 지운다.",
        "Levels": [[1, 1, 1, 1, 1, 1], [2, 2, 2, 1, 1, 1]],
    },
    "Alchemist_C_Tolerance": {
        "Description": "체력이 절반 이하일 때 [받는 회복량]이 {30}% 증가한다.",
        "Levels": [[30, 34, 38, 42, 46, 50]],
    },
    "Alchemist_C_Herbal": {"Levels": [[1, 1, 1, 1, 1, 1], [1, 1.2, 1.4, 1.6, 1.8, 2]]},
}

if __name__ == "__main__":
    print(apply(EDITS))
