# -*- coding: utf-8 -*-
"""
카드 그림 빌드 (2026-09-28). 돌리기: python tools/card_art/build.py [카드Id ...]

  cards.py 의 SPECS(카드 Id → 그리는 함수)로 도형 목록을 만들어
  src/shared/CardArtworksGen/<직업>.luau 에 적고(CardArtworks 가 합친다),
  카드 정의의 Art 필드를 그 그림 Id(= 카드 Id)로 맞춘다(card_edit.apply).

  사용자가 편집기로 그린 그림(구간 밖)은 건드리지 않는다. 이미 Art 가 있는 카드는 SPECS 에 없다.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))

from motifs import Art  # noqa: E402
from cards import SPECS, NAMES, ARTS, accent_for  # noqa: E402

ARTWORKS = os.path.join(ROOT, "src", "shared", "CardArtworks.luau")
TAB, LF, CR = chr(9), chr(10), chr(13)
BEGIN = "\t-- @생성 그림 시작 (tools/card_art/build.py 가 다시 쓴다 — 손대지 말 것)"
END = "\t-- @생성 그림 끝"


def lua_shape(s):
    return ("{ X = %s, Y = %s, W = %s, H = %s, Rotation = %s, Color = \"%s\", Corner = %s, Stroke = %s, ZIndex = %d, Transparency = %s }"
            % (s["X"], s["Y"], s["W"], s["H"], s["Rotation"], s["Color"], s["Corner"], s["Stroke"], s["ZIndex"], s["Transparency"]))


def render(card_id):
    art = Art(accent_for(card_id))
    SPECS[card_id](art)
    return art.shapes


def main(only=None):
    # 사용자가 그린 그림을 가리키는 카드는 건너뛴다
    for card_id in list(SPECS):
        if ARTS.get(card_id) and ARTS[card_id] != card_id:
            print("[card_art] 건너뜀(사용자 그림):", card_id, ARTS[card_id])
            del SPECS[card_id]
    blocks = []
    count = 0
    sheet = []
    for card_id in sorted(SPECS):
        shapes = render(card_id)
        grade = {"E": "Essential", "R": "Rare", "C": "Common"}.get(card_id.split("_")[1], "Common")
        sheet.append({"Id": card_id, "Name": NAMES.get(card_id, card_id), "Grade": grade, "Shapes": shapes})
        assert shapes, card_id
        for s in shapes:
            # 메달리온 밖으로 나가는 도형은 게임에서 잘리지 않는다(CardArt 주석) — 안쪽에 머물게
            assert -0.05 <= s["X"] <= 1.05 and -0.05 <= s["Y"] <= 1.05, (card_id, s)
        count += 1
        lines = ["\t[\"%s\"] = {" % card_id, "\t\tId = \"%s\"," % card_id, "\t\tName = \"%s\"," % NAMES.get(card_id, card_id), "\t\tShapes = {"]
        lines += ["\t\t\t" + lua_shape(s) + "," for s in shapes]
        lines += ["\t\t},", "\t},"]
        blocks.append("\n".join(lines))

    import json
    os.makedirs(os.path.join(HERE, "preview"), exist_ok=True)
    with open(os.path.join(HERE, "preview", "art.json"), "w", encoding="utf-8") as f:
        json.dump(sheet, f, ensure_ascii=False)

    # 생성 그림은 직업별 모듈로(한 파일이 수백 KB 가 되지 않게). 도형은 배열 {X,Y,W,H,Rot,Color,Corner,Stroke,Z,Tr}.
    gen_dir = os.path.join(ROOT, "src", "shared", "CardArtworksGen")
    os.makedirs(gen_dir, exist_ok=True)
    by_class = {}
    for item in sheet:
        by_class.setdefault(item["Id"].split("_")[0], []).append(item)
    for name in os.listdir(gen_dir):
        if name.endswith(".luau") and name[:-5] not in by_class:
            os.remove(os.path.join(gen_dir, name))
    for class_id, items in sorted(by_class.items()):
        out = ["--!strict", "-- tools/card_art/build.py 가 만든 카드 그림(%s). 손대지 말고 tools/card_art/specs 를 고친 뒤 다시 돌린다." % class_id,
               "-- [그림 Id] = { 이름, { {X, Y, W, H, Rotation, Color, Corner, Stroke, ZIndex, Transparency}, ... } }", "return {"]
        for item in items:
            out.append(TAB + "[%s] = { %s, {" % (json.dumps(item["Id"], ensure_ascii=False), json.dumps(item["Name"], ensure_ascii=False)))
            for sh in item["Shapes"]:
                out.append(TAB * 2 + "{ %s, %s, %s, %s, %s, \"%s\", %s, %s, %d, %s }," % (
                    sh["X"], sh["Y"], sh["W"], sh["H"], sh["Rotation"], sh["Color"], sh["Corner"], sh["Stroke"], sh["ZIndex"], sh["Transparency"]))
            out.append(TAB + "} },")
        out.append("}")
        with open(os.path.join(gen_dir, class_id + ".luau"), "w", encoding="utf-8", newline=LF) as f:
            f.write(LF.join(out) + LF)

    # 예전 판(ARTWORKS 표 안에 직접 적던 구간)이 남아 있으면 걷어낸다
    src = open(ARTWORKS, encoding="utf-8", newline="").read()
    if BEGIN in src:
        a = src.index(BEGIN)
        b = src.index(END, a) + len(END)
        src = src[:a].rstrip(TAB) + src[b:].lstrip(CR + LF)
        open(ARTWORKS, "w", encoding="utf-8", newline="").write(src)

    from card_edit import apply
    edits = {card_id: {"Art": card_id} for card_id in SPECS if not only or card_id in only}
    changed = apply(edits)
    print("[card_art] 그림 %d장 → CardArtworksGen/%d개 모듈, Art 지정 %d장" % (count, len(by_class), len(changed)))


if __name__ == "__main__":
    main(set(sys.argv[1:]) or None)
