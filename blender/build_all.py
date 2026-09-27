"""모든 에셋을 생성/내보내기/렌더.

사용법 (레포 루트에서):
    python blender/build_all.py                 # 전체 빌드 (FBX + Part JSON + 매니페스트)
    python blender/build_all.py --render        # + 미리보기 JPEG 렌더 (assets/previews)
    python blender/build_all.py --only StiltHouseA --render
    blender -b -P blender/build_all.py -- --render   # Blender 앱으로 실행할 때

bpy 모듈(pip install bpy) 또는 Blender 4.2+ / 5.x 에서 동작.
"""

import argparse
import importlib
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402

from swamplib import config, render  # noqa: E402

MODULES = [
    "assets.stilt_house",
    "assets.longhouse",
    "assets.witch_hut",
    "assets.watchtower",
    "assets.dock",
    "assets.boardwalk",
    "assets.shrine",
    "assets.market",
    "assets.lighthouse",
    "assets.props",
    "assets.vegetation",
    "assets.ship",
    "assets.weapons",
    "assets.creatures",
]

# 에셋별 미리보기 환경/카메라
PREVIEW = {
    "default": {"env": "water", "azim": 35, "elev": 18},
}


def parse():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--render", action="store_true")
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--no-fbx", action="store_true")
    ap.add_argument("--samples", type=int, default=None)
    ap.add_argument("--save-blend", action="store_true")
    ap.add_argument("--quick", action="store_true", help="저해상도 빠른 렌더 (검토용)")
    ap.add_argument("--skip-done", action="store_true", help="미리보기/.blend 가 이미 있는 에셋은 렌더·저장 생략 (중단된 렌더 이어하기)")
    return ap.parse_args(argv)


def collect_builders(only):
    out = []
    for m in MODULES:
        try:
            mod = importlib.import_module(m)
        except ModuleNotFoundError as e:
            if e.name == m:
                continue
            raise
        for fn in getattr(mod, "ASSETS", []):
            out.append((m, fn))
    if only:
        wanted = set(only)
        out = [(m, fn) for (m, fn) in out if fn.__name__ in wanted or _asset_name_guess(fn) in wanted]
    return out


def _asset_name_guess(fn):
    return "".join(p.capitalize() for p in fn.__name__.split("_"))


def main():
    args = parse()
    manifest = {}
    if config.MANIFEST_PATH.exists():
        manifest = json.loads(config.MANIFEST_PATH.read_text())
    builders = collect_builders(args.only)
    print(f"[build] {len(builders)} assets")
    for modname, fn in builders:
        t0 = time.time()
        render.reset_scene()
        a = fn()
        a.finalize()
        info = a.export(fbx=not args.no_fbx)
        manifest[a.name] = info
        print(f"[build] {a.name:<22} parts(mesh)={len(info['parts']):>3} tris={info['triCount']:>6} "
              f"prims={info['partCount']:>5} colliders={len(info['colliders']):>3} ({time.time() - t0:.1f}s)")
        blend_path = config.BLEND_DIR / f"{a.name}.blend"
        preview_path = config.PREVIEW_DIR / f"{a.name}.jpg"
        if args.save_blend and not (args.skip_done and blend_path.exists()):
            config.BLEND_DIR.mkdir(parents=True, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=str(blend_path), compress=True)
        if args.render and not (args.skip_done and preview_path.exists()):
            pv = dict(PREVIEW["default"])
            pv.update(getattr(fn, "preview", {}) or {})
            render.setup_world()
            render.ground(pv.get("env", "water"))
            b = info["bounds"]
            # Roblox bounds -> Blender (x, -z, y)
            bmin = (b["min"][0], -b["max"][2], b["min"][1])
            bmax = (b["max"][0], -b["min"][2], b["max"][1])
            render.frame_camera(bmin, bmax, azim=pv.get("azim", 35), elev=pv.get("elev", 18), lens=pv.get("lens", 40), pad=pv.get("pad", 1.05))
            config.PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
            t1 = time.time()
            if args.quick:
                render.render(preview_path, samples=args.samples or 20, res=(960, 540))
            else:
                render.render(preview_path, samples=args.samples)
            print(f"[render] {a.name} ({time.time() - t1:.1f}s)")
    config.MANIFEST_PATH.write_text(json.dumps(manifest, indent=1, ensure_ascii=False))
    print("[build] manifest ->", config.MANIFEST_PATH)
    # Roblox 쪽에서 쓰는 팔레트 (Lune 변환기가 읽음)
    from swamplib.materials import PALETTE, roblox_info
    (config.OUT_DIR / "palette.json").write_text(json.dumps({k: roblox_info(k) for k in PALETTE}, indent=1))


if __name__ == "__main__":
    main()
