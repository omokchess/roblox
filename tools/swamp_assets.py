# -*- coding: utf-8 -*-
"""
swamp_assets.py — 안개늪 군도 참고 프로젝트(C:/wth/roblox/assets)의 palette.json, manifest.json 에서
우리 SwampKit 에 든 에셋의 재질 팔레트·충돌체·불빛·경계를 Swamp_assets.luau 로 옮겨 적는다. (2026-09-28)
좌표는 에셋 로컬(로블록스). build_kit_swamp.py 가 메시를 같은 로컬로 맞춰 내보낸다.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "models"))
SRC = r"C:\wth\roblox\assets"


def f(v):
    return ("%.4f" % v).rstrip("0").rstrip(".")


def main():
    import importlib.util
    spec = importlib.util.spec_from_file_location("kit", os.path.join(HERE, "..", "models", "build_kit_swamp.py"))
    # 에셋 목록만 필요하다. 블렌더 없이 읽으려고 ASSETS 줄을 직접 뽑는다
    src = open(os.path.join(HERE, "..", "models", "build_kit_swamp.py"), encoding="utf-8").read()
    a0 = src.index("ASSETS = [")
    a1 = src.index("]", a0)
    assets = eval(src[a0 + len("ASSETS = "):a1 + 1])
    pal = json.load(open(os.path.join(SRC, "palette.json"), encoding="utf-8"))
    man = json.load(open(os.path.join(SRC, "manifest.json"), encoding="utf-8"))
    # 고친판(StiltHouseB2·BoardwalkOpen)
    extra = json.load(open(os.path.join(HERE, "..", "models", "swamp_ref", "manifest_extra.json"), encoding="utf-8"))
    man.update(extra)
    assets = assets + list(extra)
    L = ["-- swamp_assets.py 가 안개늪 군도 palette.json / manifest.json 에서 옮긴 자료. 손으로 고치지 말 것", "local D = {}", "D.PALETTE = {"]
    for k, v in pal.items():
        c = v["color"]
        L.append("\t%s = { \"%s\", %d, %d, %d, %s, %s, %s }," % (k, v["material"], c[0], c[1], c[2], f(v["transparency"]),
                                                               f(v["reflectance"]), "true" if v["castShadow"] else "false"))
    L.append("}")
    L.append("D.ASSETS = {")
    for a in assets:
        m = man[a]
        b = m["bounds"]
        L.append("\t%s = {" % a)
        L.append("\t\tmin = { %s }, max = { %s }," % (", ".join(f(x) for x in b["min"]), ", ".join(f(x) for x in b["max"])))
        L.append("\t\tcolliders = {")
        for c in m.get("colliders", []):
            L.append("\t\t\t{ \"%s\", %s, %s, %s, \"%s\" }," % (c["shape"], ", ".join(f(x) for x in c["pos"]),
                                                          ", ".join(f(x) for x in c["rot"]), ", ".join(f(x) for x in c["size"]),
                                                          c.get("tag", "")))
        L.append("\t\t},")
        L.append("\t\tlights = {")
        for l in m.get("lights", []):
            L.append("\t\t\t{ %s, %d, %d, %d, %s, %s }," % (", ".join(f(x) for x in l["pos"]), l["color"][0], l["color"][1],
                                                          l["color"][2], f(l["range"]), f(l["brightness"])))
        L.append("\t\t},")
        L.append("\t},")
    L.append("}")
    L.append("return D")
    out = os.path.join(HERE, "Swamp_assets.luau")
    open(out, "w", encoding="utf-8").write("\n".join(L) + "\n")
    print("에셋 %d, 팔레트 %d → %s" % (len(assets), len(pal), out))


if __name__ == "__main__":
    main()
