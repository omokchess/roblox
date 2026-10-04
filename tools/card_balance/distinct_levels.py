# -*- coding: utf-8 -*-
"""
distinct_levels.py — 2026-10-04. 모든 직업 카드: 레벨이 올라도 수치가 그대로인 레벨을 없앤다.

사용자(2026-10-04): "카드에 레벨이 다른데도 똑같은 수치를 가지는 카드들이 엄청 많아. 그런 카드들은 매 레벨마다
수치가 달라지게 설정해줘. 최대레벨을 낮춰도 좋으니까."
→ 레벨마다 (사다리 줄 전부의 값) 묶음을 보고, 바로 앞 레벨과 똑같은 레벨은 지운다. 남은 수가 새 최대 레벨.
   (예: 겹친 숨 [[1,1,1,1,1,1],[1,1,1,2,2,2]] → [[1,1],[1,2]], 최대 2레벨). 끝까지 같으면 1레벨 카드.
같이 고침: 월 메이슨 석공의 손 — 스택당 치명타 피해량 {7}→{15}% 를 {2}→{3}% 로(대성당과 겹쳐 벽 20 × 15% 에 따로 곱해졌다).

돌리기: python tools/card_balance/distinct_levels.py [--dry]   (직업별 밸런스 파일을 다시 돌렸다면 이것도 다시)
"""
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
from card_edit import apply, CARD_DIR, RULE  # noqa: E402

MANUAL = {
    "WallMason_E_MasonHand": {"Levels": [[5, 8], [2, 4], [2, 3]]},
}


def ladders():
    """카드 Id → (최대 레벨, 사다리)"""
    out = {}
    for path in glob.glob(os.path.join(CARD_DIR, "*Cards.luau")):
        text = open(path, encoding="utf-8").read()
        for block in re.split(r"\n\t\{\n", text)[1:]:
            m = re.search(r'Id = "(\w+)"', block)
            lv = re.search(r"Levels = \{ (.*) \},\n", block)
            if not m or not lv:
                continue
            grade = re.search(r'Grade = "(\w+)"', block).group(1)
            ml = re.search(r"MaxLevel = (\d+)", block)
            cap = int(ml.group(1)) if ml else RULE[grade]
            rows = [[float(v) for v in g.split(",") if v.strip()] for g in re.findall(r"\{([^{}]*)\}", lv.group(1))]
            out[m.group(1)] = (cap, rows)
    return out


def main():
    dry = "--dry" in sys.argv
    edits = dict(MANUAL)
    report = []
    for card_id, (cap, rows) in sorted(ladders().items()):
        if card_id in MANUAL:
            rows = [[float(v) for v in r] for r in MANUAL[card_id]["Levels"]]
        if cap <= 1 or not rows:
            continue
        keep = [0]
        for i in range(1, cap):
            if tuple(r[i] for r in rows) != tuple(r[keep[-1]] for r in rows):
                keep.append(i)
        if len(keep) == cap:
            continue
        new_rows = [[r[i] for i in keep] for r in rows]
        new_rows = [[int(v) if float(v).is_integer() else v for v in r] for r in new_rows]
        edits[card_id] = {"Levels": new_rows, "MaxLevel": len(keep)}
        report.append("%-36s %d → %d  %s" % (card_id, cap, len(keep), new_rows))
    for line in report:
        print(line)
    print("고친 카드 %d장" % len(report))
    if not dry:
        apply(edits)


if __name__ == "__main__":
    main()
