# -*- coding: utf-8 -*-
"""
펄서 카드 밸런스·구조 (2026-09-28). 돌리기: python tools/card_balance/pulsar.py
- 34장 전부 사다리가 없었다 → 새로 매김. 글에 숫자가 없던 6레벨 카드(방전·자화·중계·방출 조율·여광)는
  오르는 값 하나를 {괄호}로 만들어 줬다.
- "{−10}" 처럼 유니코드 빼기가 든 괄호는 수치로 읽히지 않았다 → 양수 + "감소/낮아진다" 로.
- 전직 갈래: 핵파스타(자기장을 짧고 세게, 내가 반사) ⟂ 정지 궤도(자기장을 아군에게 — 파티)
- 파티 전제: 정지 궤도(자기장을 다른 아군에게), 인력(표적 확률)
- 코일: 2스킬 사거리가 이미 격자 끝까지라 "사거리 +칸" 이 뜻이 없었다 → 공명당 피해.
- 고정 조준: 스킬 QTE 판정 폭을 넓힐 자리가 없어 → 첫 발이 '방어'(Partial) 판정이면 확률로 '성공'.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from card_edit import apply

EDITS = {
    "Pulsar_E_ImperfectLight": {
        "Description": "2스킬이 [공명]과 상관없이 늘 {3}연타 최대치의 피해로 나가고, 쓸 때마다 피해량이 {15}%씩, 최대 {5}번까지 높아진다.\n대신 쓸 때마다 자신의 명중률이 {10}%씩 영구히 낮아진다.",
        "Levels": [[3, 3], [15, 20], [5, 5], [10, 8]],
    },
    "Pulsar_E_NuclearPasta": {
        "Description": "1스킬의 [자기장] 지속이 3턴에서 {2}턴으로 줄어든다. 반사 피해가 8에서 {20}으로 오르고, [감극] 중첩당 수치가 {2}배가 된다.",
        "Levels": [[2, 2], [20, 28], [2, 2]],
        "Excludes": ["Pulsar_E_Geostationary"],
    },
    "Pulsar_E_DimSupernova": {
        "Description": "3스킬이 적 전체를 대상으로 하고 명중률 감소가 {40}%가 된다. 3스킬을 쓰면 아군 전체에게 [가하는 피해량] +{15}% 버프를 {2}턴 제공한다.",
        "Levels": [[40, 50], [15, 20], [2, 2]],
    },
    "Pulsar_E_Geostationary": {
        "Levels": [[2, 2.5], [3, 3]],
        "Party": True,
        "Excludes": ["Pulsar_E_NuclearPasta"],
    },
    "Pulsar_R_CriticalFlux": {"Levels": [[1, 1, 1, 2, 2, 2], [1, 1, 1, 1, 1, 2]]},
    "Pulsar_R_Lock": {"Levels": [[2, 2, 2, 3, 3, 3]]},
    "Pulsar_R_Induction": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "Pulsar_R_Arc": {
        "Description": "반사 피해가 인접한 적에게도 {50}%로 퍼진다.",
        "Levels": [[50, 55, 60, 65, 70, 80]],
    },
    "Pulsar_R_Flywheel": {"Levels": [[1, 1, 1, 2, 2, 2]]},
    "Pulsar_R_Beacon": {"Levels": [[10, 10, 10, 10, 10, 10], [18, 20, 22, 24, 26, 30], [1, 1, 1, 1, 2, 2]]},
    "Pulsar_R_Recharge": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "Pulsar_R_QteMastery": {"Levels": [[20, 20, 20, 20, 20, 20], [35, 38, 41, 44, 47, 50]]},
    "Pulsar_R_Grounding": {"Levels": [[3, 3, 3, 3, 3, 3], [20, 23, 26, 29, 32, 35]]},
    "Pulsar_R_Shroud": {
        "Description": "[자기장]이 유지되는 동안 [그로기]가 차지 않는다. 그로기를 막을 때마다 자기장 지속이 {1}턴 감소한다.",
        "Levels": [[1, 1, 1, 1, 1, 0]],
    },
    "Pulsar_C_ReflectUp": {"Levels": [[4, 5, 6, 7, 8, 10]]},
    "Pulsar_C_DepolarDamage": {"Levels": [[1, 1, 1, 1, 1, 1], [3, 4, 5, 6, 7, 8]]},
    "Pulsar_C_Spin": {"Levels": [[3, 3, 4, 4, 5, 6]]},
    # 수렴은 재사용 대기 2턴이라 "이어 쓰면" 이 불가능했다 → 쓴 다음 턴 / 쓴 횟수
    "Pulsar_C_Orbit": {
        "Description": "2스킬을 쓴 다음 턴에는 스킬의 스테미나 소모가 {20}% 감소한다.",
        "Levels": [[20, 24, 28, 32, 36, 40]],
    },
    "Pulsar_C_Afterglow": {"Levels": [[6, 8, 10, 12, 14, 16]]},
    "Pulsar_C_Attraction": {"Levels": [[8, 10, 12, 14, 16, 18]], "Party": True},
    "Pulsar_C_Magnetize": {
        "Description": "전투 시작 시 [자기장]을 {2}턴 두른다.",
        "Levels": [[2, 2, 3, 3, 4, 4]],
    },
    "Pulsar_C_Backflow": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "Pulsar_C_Residue": {"Levels": [[1, 1, 1, 1, 2, 2]]},
    "Pulsar_C_Focused": {
        "Description": "2스킬의 피해량이 {10}% 증가한다.",
        "Levels": [[10, 12, 14, 16, 18, 20]],
    },
    "Pulsar_C_GuardLight": {"Levels": [[8, 10, 12, 14, 16, 18]]},
    "Pulsar_C_StaticField": {"Levels": [[50, 55, 60, 65, 70, 80]]},
    "Pulsar_C_Afterimage": {"Levels": [[5, 6, 7, 8, 9, 10]]},
    "Pulsar_C_RecoilControl": {
        "Description": "2스킬을 {3}번 쓸 때마다 다음 턴 받는 피해량이 {12}% 감소한다.",
        "Levels": [[3, 3, 3, 3, 2, 2], [12, 14, 16, 18, 20, 22]],
    },
    "Pulsar_C_Relay": {
        "Description": "[감극]이 걸린 적을 처치하면 남은 중첩의 {50}%가 가장 가까운 적에게 옮겨진다.",
        "Levels": [[50, 60, 70, 80, 90, 100]],
    },
    "Pulsar_C_LightUp": {"Levels": [[6, 8, 10, 12, 14, 16]]},
    "Pulsar_C_Coil": {
        "Description": "[공명] {1}스택당 2스킬의 [가하는 피해량]이 {4}%씩, 최대 {12}%까지 증가한다.",
        "Levels": [[1, 1, 1, 1, 1, 1], [4, 5, 6, 7, 8, 10], [12, 15, 18, 21, 24, 30]],
    },
    "Pulsar_C_Discharge": {
        "Description": "[자기장]이 끝날 때 주변 {1}칸의 적에게 반사 피해의 {100}%만큼 폭발한다.",
        "Levels": [[1, 1, 1, 1, 1, 1], [100, 110, 120, 130, 140, 160]],
    },
    "Pulsar_C_FixedAim": {
        "Description": "2스킬 QTE가 방어 판정이면 {15}% 확률로 성공 판정으로 바뀐다.",
        "Levels": [[15, 20, 25, 30, 35, 40]],
    },
    "Pulsar_C_Trailing": {
        "Description": "[자기장]이 끝난 다음 턴까지 받는 피해량 감소의 {50}%가 남는다.",
        "Levels": [[50, 55, 60, 65, 70, 80]],
    },
}

if __name__ == "__main__":
    print(apply(EDITS))
