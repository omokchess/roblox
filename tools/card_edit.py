# -*- coding: utf-8 -*-
"""
card_edit.py — 카드 파일(src/shared/AbilityCards/*Cards.luau)의 카드 한 장을 고친다. (2026-09-28)

밸런스·구조 작업에서 여러 장을 한 번에 손으로 고칠 때 쓴다. 표(아래 EDITS 형식)를 받아
  Description  글(줄바꿈은 \n). 숫자 자리는 {값} — 1레벨 값
  Levels       사다리 목록 [[lv1..], [..]] — 글의 {} 순서대로, 길이 = 최대 레벨
  MaxLevel     카드별 레벨 상한(등급 기본값과 같으면 지운다)
  Excludes     필수 카드끼리 함께 가질 수 없는 카드 Id 목록
  Party        파티 전투를 전제로 한 카드면 True
를 갈아 끼우거나 넣는다. 사다리 수와 {} 수, 사다리 길이와 최대 레벨이 어긋나면 멈춘다(assert).

쓰는 법(파이썬에서):
  from card_edit import apply
  apply({"Musician_R_Metronome": {"Description": "...", "Levels": [[3,3,2],[1,2,2]]}})
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CARD_DIR = os.path.join(ROOT, "src", "shared", "AbilityCards")
RULE = {"Essential": 2, "Rare": 6, "Common": 6}
FIELD_ORDER = ["Id", "MaxLevel", "Art", "Name", "Description", "Levels", "LevelKeywords", "Excludes", "Party", "Grade", "ClassId", "Tags"]


def _num(v):
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def _quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def _find_block(src, card_id):
    m = re.search(r'\n(\t\t)Id = "' + re.escape(card_id) + r'",(.*?)\n\t\},', src, re.S)
    return m


def _fields(block):
    """블록을 (키, 원문) 목록으로. 값은 다음 필드 줄 앞까지."""
    lines = block.split("\n")
    out = []
    for line in lines[1:]:
        m = re.match(r"\t\t([A-Za-z]+) = ", line)
        if m:
            out.append([m.group(1), line])
        elif out and line.startswith("\t\t\t"):
            out[-1][1] += "\n" + line
    return out


def apply(edits, dry=False):
    files = {}
    for path in glob.glob(os.path.join(CARD_DIR, "*Cards.luau")):
        files[path] = open(path, encoding="utf-8", newline="").read()
    done = set()
    for path, src in files.items():
        nl = "\r\n" if "\r\n" in src else "\n"
        text = src.replace("\r\n", "\n")
        for card_id, change in edits.items():
            m = _find_block(text, card_id)
            if not m:
                continue
            block = m.group(0)
            fields = _fields(block)
            keys = [k for k, _ in fields]
            grade = re.search(r'Grade = "(\w+)"', block).group(1)

            def setf(key, rendered):
                if rendered is None:
                    for f in fields:
                        if f[0] == key:
                            fields.remove(f)
                            return
                    return
                for f in fields:
                    if f[0] == key:
                        f[1] = rendered
                        return
                fields.append([key, rendered])

            if "Description" in change:
                setf("Description", "\t\tDescription = " + _quote(change["Description"]) + ",")
            elif change.get("Levels"):
                # 사다리만 바꾸면 글의 {1레벨 값}을 순서대로 새 사다리의 1레벨로 맞춘다
                old_line = next((f[1] for f in fields if f[0] == "Description"), "")
                raw = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', old_line))
                text_now = raw.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
                firsts = [g[0] for g in change["Levels"]]
                braces = len(re.findall(r"\{[\d\.\-]+\}", text_now))
                assert braces == len(firsts), (card_id, "글의 {숫자} %d개, 사다리 %d줄" % (braces, len(firsts)), text_now)
                counter = iter(firsts)
                text_now = re.sub(r"\{[\d\.\-]+\}", lambda _m: "{" + _num(next(counter)) + "}", text_now)
                setf("Description", "\t\tDescription = " + _quote(text_now) + ",")
            if "Name" in change:
                setf("Name", "\t\tName = " + _quote(change["Name"]) + ",")
            if "MaxLevel" in change:
                ml = change["MaxLevel"]
                setf("MaxLevel", None if ml is None or ml == RULE[grade] else "\t\tMaxLevel = %d," % ml)
            if "Levels" in change:
                lv = change["Levels"]
                if lv:
                    setf("Levels", "\t\tLevels = { " + ", ".join("{ " + ", ".join(_num(v) for v in g) + " }" for g in lv) + " },")
                else:
                    setf("Levels", None)
            if "Excludes" in change:
                ex = change["Excludes"]
                setf("Excludes", "\t\tExcludes = { " + ", ".join(_quote(e) for e in ex) + " }," if ex else None)
            if "Party" in change:
                setf("Party", "\t\tParty = true," if change["Party"] else None)
            if "Tags" in change:
                setf("Tags", "\t\tTags = { " + ", ".join(_quote(t) for t in change["Tags"]) + " },")
            if "Art" in change:
                setf("Art", "\t\tArt = " + _quote(change["Art"]) + "," if change["Art"] else None)

            # 순서 맞추기
            order = {k: i for i, k in enumerate(FIELD_ORDER)}
            fields.sort(key=lambda f: order.get(f[0], 99))

            # 검사: {} 수 = 사다리 수, 사다리 길이 = 최대 레벨
            desc_line = next((f[1] for f in fields if f[0] == "Description"), "")
            desc_text = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', desc_line))
            braces = re.findall(r"\{[\d\.\-]+\}", desc_text)
            lv_line = next((f[1] for f in fields if f[0] == "Levels"), None)
            ml_line = next((f[1] for f in fields if f[0] == "MaxLevel"), None)
            cap = int(re.search(r"\d+", ml_line).group(0)) if ml_line else RULE[grade]
            if lv_line:
                groups = re.findall(r"\{([^{}]*)\}", lv_line[lv_line.index("{") + 1: lv_line.rindex("}")])
                assert len(groups) == len(braces), (card_id, "사다리", len(groups), "중괄호", len(braces))
                for g in groups:
                    n = len([v for v in g.split(",") if v.strip()])
                    assert n == cap, (card_id, "사다리 길이", n, "최대", cap)
                for i, g in enumerate(groups):
                    first = g.split(",")[0].strip()
                    assert float(first) == float(braces[i][1:-1]), (card_id, "1레벨 값이 글과 다름", first, braces[i])
            new_block = "\n" + "\n".join(f[1] for f in fields) + "\n\t},"
            text = text.replace(block, new_block, 1)
            done.add(card_id)
        if not dry:
            open(path, "w", encoding="utf-8", newline="").write(text.replace("\n", nl))
    missing = set(edits) - done
    assert not missing, ("없는 카드", missing)
    return sorted(done)
