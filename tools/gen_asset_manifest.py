"""assets/manifest.json -> src/ServerStorage/SwampTools/AssetManifest.luau

Studio 에서 FBX 를 임포트한 뒤 AssetSetup 이 각 MeshPart 의 크기/위치/재질을 복원할 때 사용.
    python tools/gen_asset_manifest.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
man = json.loads((ROOT / "assets" / "manifest.json").read_text())


def f(v):
    r = round(float(v), 4)
    return str(int(r)) if r == int(r) else str(r)


lines = [
    "--!strict",
    "-- 자동 생성 파일 (tools/gen_asset_manifest.py). 직접 수정하지 마세요.",
    "-- 메시 버전(FBX 임포트) 복원 정보: 에셋 -> 파트 목록",
    "-- p=모델 원점 기준 위치, z=크기, m=Enum.Material 이름, c=색(RGB), t=투명도, sh=그림자, ds=양면, g=그룹",
    "",
    "export type MeshPartInfo = { n: string, g: string, p: { number }, z: { number }, m: string, c: { number }, t: number, sh: boolean, ds: boolean }",
    "export type AssetInfo = { Category: string, Replicated: boolean, Tris: number, Parts: { MeshPartInfo } }",
    "",
    "local M: { [string]: AssetInfo } = {",
]
for name in sorted(man):
    a = man[name]
    lines.append(f'\t["{name}"] = {{')
    lines.append(f'\t\tCategory = "{a["category"]}",')
    lines.append(f'\t\tReplicated = {"true" if a["replicated"] else "false"},')
    lines.append(f'\t\tTris = {a["triCount"]},')
    lines.append("\t\tParts = {")
    for p in a["parts"]:
        lines.append(
            f'\t\t\t{{ n = "{p["name"]}", g = "{p["group"]}", p = {{ {", ".join(f(v) for v in p["pos"])} }}, z = {{ {", ".join(f(v) for v in p["size"])} }}, '
            f'm = "{p["material"]}", c = {{ {", ".join(str(v) for v in p["color"])} }}, t = {f(p["transparency"])}, '
            f'sh = {"true" if p["castShadow"] else "false"}, ds = {"true" if p["doubleSided"] else "false"} }},'
        )
    lines.append("\t\t},")
    lines.append("\t},")
lines.append("}")
lines.append("")
lines.append("return M")
lines.append("")
out = ROOT / "src" / "ServerStorage" / "SwampTools" / "AssetManifest.luau"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines), encoding="utf-8")
print("[manifest] wrote", out.relative_to(ROOT), sum(len(a["parts"]) for a in man.values()), "mesh parts")
