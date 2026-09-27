"""Asset: 하나의 Roblox 모델이 될 에셋을 절차적으로 구성하는 빌더.

같은 호출로 두 가지 결과물을 동시에 만든다.
  1) 고품질 메시 (머티리얼 키별로 병합 -> FBX -> Studio 3D Importer -> MeshPart)
  2) Part 버전 (박스/원기둥/구 프리미티브 목록 -> Lune -> .rbxm, 임포트 없이 즉시 사용)
또한 충돌 박스(콜라이더), 조명, 마커(Attachment)를 매니페스트로 내보낸다.
"""

import json
import math
import random
from contextlib import contextmanager

import bpy
from mathutils import Matrix, Vector, Euler

from . import config, geom
from .materials import make_preview_material, roblox_info

# Blender(Z-up) -> Roblox(Y-up) 회전:  (x,y,z) -> (x, z, -y)
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))
C_INV = C.transposed()


def to_rbx_pos(v):
    return (v[0], v[2], -v[1])


def to_rbx_rot(R3):
    """Blender 회전(3x3) -> Roblox CFrame 회전(행 우선 9개)."""
    Rr = C @ R3 @ C_INV
    return [Rr[i][j] for i in range(3) for j in range(3)]


def deg(e):
    return Euler((math.radians(e[0]), math.radians(e[1]), math.radians(e[2])), "XYZ")


def rot_matrix(rot):
    if rot is None:
        return Matrix.Identity(4)
    if isinstance(rot, Matrix):
        return rot.to_4x4()
    return deg(rot).to_matrix().to_4x4()


def _r(x, n=4):
    v = round(float(x), n)
    return 0.0 if v == 0 else v


def _decompose(M):
    """M(4x4) -> (위치, 직교 회전 3x3, 축별 스케일). 반사(음수 스케일)는 스케일로 흡수."""
    loc = M.to_translation()
    m3 = M.to_3x3()
    sx, sy, sz = m3.col[0].length, m3.col[1].length, m3.col[2].length
    R = Matrix((m3.col[0] / sx, m3.col[1] / sy, m3.col[2] / sz)).transposed()
    if R.determinant() < 0:
        R = Matrix((-R.col[0], R.col[1], R.col[2])).transposed()
        sx = -sx
    return loc, R, (abs(sx), abs(sy), abs(sz))


class _Acc:
    """머티리얼 키 하나에 대한 메시 누적기 (프리미티브 경계를 기억해 분할 가능)."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.uvs = []
        self.smooth = []
        self.prim_bounds = []  # (face_start, face_end)

    def add(self, verts, faces, uvs, smooth, M, uv_off, flip):
        base = len(self.verts)
        m3 = M.to_3x3()
        t = M.to_translation()
        self.verts.extend([(m3 @ Vector(v)) + t for v in verts])
        fs = len(self.faces)
        tile = config.UV_STUDS_PER_TILE
        for f, uv, s in zip(faces, uvs, smooth):
            if flip:
                f = tuple(reversed(f)); uv = tuple(reversed(uv))
            self.faces.append(tuple(base + i for i in f))
            self.uvs.append(tuple(((a + uv_off[0]) / tile, (b + uv_off[1]) / tile) for a, b in uv))
            self.smooth.append(s)
        self.prim_bounds.append((fs, len(self.faces)))

    def tri_count(self, a=0, b=None):
        b = len(self.faces) if b is None else b
        return sum(len(f) - 2 for f in self.faces[a:b])


class Asset:
    def __init__(self, name, category="Building", replicated=False, seed=None, description=""):
        self.name = name
        self.category = category
        self.replicated = replicated
        self.description = description
        self.rng = random.Random(seed if seed is not None else sum(map(ord, name)) * 7919)
        self.stack = [Matrix.Identity(4)]
        self.acc = {}          # (group, matkey) -> _Acc
        self.prims = []        # Part 버전 프리미티브
        self.colliders = []
        self.lights = []
        self.markers = []
        self.attributes = {}
        self.part_enabled = [True]
        self.objects = []      # 생성된 Blender 오브젝트
        self.group = ["Main"]

    # ── 변환 스택 ──────────────────────────────────────────
    @property
    def M(self):
        return self.stack[-1]

    @contextmanager
    def at(self, loc=(0, 0, 0), rot=None, scale=None, matrix=None):
        m = Matrix.Translation(Vector(loc)) @ rot_matrix(rot)
        if scale is not None:
            if isinstance(scale, (int, float)):
                scale = (scale, scale, scale)
            m = m @ Matrix.Diagonal(Vector((*scale, 1.0)))
        if matrix is not None:
            m = m @ matrix
        self.stack.append(self.M @ m)
        try:
            yield self
        finally:
            self.stack.pop()

    @contextmanager
    def no_parts(self):
        """메시 전용 디테일 (Part 버전에서는 생략)."""
        self.part_enabled.append(False)
        try:
            yield
        finally:
            self.part_enabled.pop()

    @contextmanager
    def in_group(self, name):
        """하위 그룹 (예: 배의 돛 / 발판 - Roblox 에서 별도 Model 로 애니메이션)."""
        self.group.append(name)
        try:
            yield
        finally:
            self.group.pop()

    def _emit(self, key, geo, M, uv_rand=True):
        verts, faces, uvs, smooth = geo
        acc = self.acc.setdefault((self.group[-1], key), _Acc())
        off = (self.rng.uniform(0, 64), self.rng.uniform(0, 64)) if uv_rand else (0.0, 0.0)
        flip = M.to_3x3().determinant() < 0
        acc.add(verts, faces, uvs, smooth, M, off, flip)

    def _prim(self, shape, M_local, size, key):
        if not self.part_enabled[-1]:
            return
        loc, R, s = _decompose(M_local)
        size = (size[0] * s[0], size[1] * s[1], size[2] * s[2])
        self.prims.append({"shape": shape, "loc": loc, "R": R, "size": size, "key": key, "group": self.group[-1]})

    # ── 프리미티브 ─────────────────────────────────────────
    def box(self, center, size, key, rot=None, bevel=0.05, part=True):
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        self._emit(key, geom.box(size, bevel), M)
        if part:
            self._prim("Block", M, size, key)

    def box_between(self, p0, p1, thick, key, up=(0, 0, 1), bevel=0.05, part=True, width=None):
        """두 점을 잇는 각재 (보, 버팀목). 로컬 X = 길이 방향."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        if L < 1e-6:
            return
        x = d.normalized()
        upv = Vector(up)
        if abs(x.dot(upv)) > 0.98:
            upv = Vector((0, 1, 0)) if abs(x.y) < 0.9 else Vector((1, 0, 0))
        y = upv.cross(x).normalized()
        z = x.cross(y).normalized()
        R = Matrix((x, y, z)).transposed().to_4x4()
        M = self.M @ Matrix.Translation((p0 + p1) / 2) @ R
        size = (L, width if width is not None else thick, thick)
        self._emit(key, geom.box(size, bevel), M)
        if part:
            self._prim("Block", M, size, key)

    def cyl(self, p0, p1, r, key, r1=None, sides=12, bevel=0.0, caps=True, part=True):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        if L < 1e-6:
            return
        x = d.normalized()
        ref = Vector((0, 0, 1)) if abs(x.z) < 0.95 else Vector((1, 0, 0))
        y = ref.cross(x).normalized()
        z = x.cross(y).normalized()
        R = Matrix((x, y, z)).transposed().to_4x4()
        M = self.M @ Matrix.Translation((p0 + p1) / 2) @ R
        self._emit(key, geom.cylinder_x(L, r, r1, sides, bevel, caps), M)
        if part:
            ravg = r if r1 is None else (r + r1) / 2
            self._prim("Cylinder", M, (L, ravg * 2, ravg * 2), key)

    def sphere(self, center, r, key, seg=12, rings=8, scale=(1, 1, 1), rot=None, part=True):
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        self._emit(key, geom.uv_sphere(r, seg, rings, scale), M)
        if part:
            if abs(scale[0] - scale[1]) < 0.05 and abs(scale[1] - scale[2]) < 0.05:
                self._prim("Ball", M, (2 * r * scale[0],) * 3, key)
            else:
                self._prim("Block", M, (1.7 * r * scale[0], 1.7 * r * scale[1], 1.7 * r * scale[2]), key)

    def blob(self, center, r, key, seg=12, rings=8, amp=0.25, freq=0.8, scale=(1, 1, 1), rot=None, part=True, flat_bottom=None):
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        self._emit(key, geom.blob(r, seg, rings, amp, freq, self.rng.random() * 50, scale, flat_bottom), M)
        if part:
            if abs(scale[0] - scale[1]) < 0.15 and abs(scale[1] - scale[2]) < 0.15:
                self._prim("Ball", M, (2 * r * scale[0],) * 3, key)
            else:
                self._prim("Block", M, (1.6 * r * scale[0], 1.6 * r * scale[1], 1.6 * r * scale[2]), key)

    def tube(self, points, radii, key, sides=8, caps=True, noise_amp=0.0, noise_freq=0.6, part=True, part_step=1, part_joints=False, twist=0.0):
        if isinstance(radii, (int, float)):
            radii = [radii] * len(points)
        geo = geom.tube(points, radii, sides, caps, noise_amp, noise_freq, seed=self.rng.random() * 100, twist=twist)
        self._emit(key, geo, self.M)
        if part and self.part_enabled[-1]:
            idx = list(range(0, len(points), max(1, part_step)))
            if idx[-1] != len(points) - 1:
                idx.append(len(points) - 1)
            for a, b in zip(idx[:-1], idx[1:]):
                ra = (radii[a] + radii[b]) / 2
                self._cyl_prim(points[a], points[b], ra, key)
                if part_joints and b != idx[-1]:
                    Mj = self.M @ Matrix.Translation(Vector(points[b]))
                    self._prim("Ball", Mj, (2 * radii[b],) * 3, key)

    def _cyl_prim(self, p0, p1, r, key):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        if L < 1e-6:
            return
        x = d.normalized()
        ref = Vector((0, 0, 1)) if abs(x.z) < 0.95 else Vector((1, 0, 0))
        y = ref.cross(x).normalized()
        z = x.cross(y).normalized()
        R = Matrix((x, y, z)).transposed().to_4x4()
        M = self.M @ Matrix.Translation((p0 + p1) / 2) @ R
        self._prim("Cylinder", M, (L + r * 0.6, 2 * r, 2 * r), key)

    def _prim_box_only(self, center, size, key, rot=None):
        """Part 버전 전용 박스 (메시 없음)."""
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        self._prim("Block", M, size, key)

    def _prim_cyl_only(self, p0, p1, r, key):
        """Part 버전 전용 원기둥 (메시 없음)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        if L < 1e-6:
            return
        x = d.normalized()
        ref = Vector((0, 0, 1)) if abs(x.z) < 0.95 else Vector((1, 0, 0))
        y = ref.cross(x).normalized()
        z = x.cross(y).normalized()
        R = Matrix((x, y, z)).transposed().to_4x4()
        M = self.M @ Matrix.Translation((p0 + p1) / 2) @ R
        self._prim("Cylinder", M, (L, 2 * r, 2 * r), key)

    def mesh(self, geo, key, part_boxes=None, uv_rand=True):
        """임의 메시. part_boxes=[(center,size,rot)] 로 Part 근사 제공."""
        self._emit(key, geo, self.M, uv_rand)
        if part_boxes:
            for c, s, r in part_boxes:
                M = self.M @ Matrix.Translation(Vector(c)) @ rot_matrix(r)
                self._prim("Block", M, s, key)

    def wedge_part(self, center, size, key, rot=None):
        """Part 버전 전용 쐐기 (지붕 박공 등). 메시는 호출측에서 따로."""
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        self._prim("Wedge", M, size, key)

    # ── 게임플레이 요소 ────────────────────────────────────
    def collider(self, center, size, rot=None, shape="Block", tag=None):
        M = self.M @ Matrix.Translation(Vector(center)) @ rot_matrix(rot)
        loc, R, s = _decompose(M)
        self.colliders.append({"shape": shape, "loc": loc, "R": R, "size": (size[0] * s[0], size[1] * s[1], size[2] * s[2]), "tag": tag, "group": self.group[-1]})

    def collider_between(self, p0, p1, width, height, tag=None):
        """두 점을 잇는 경사로/보행로 콜라이더 (윗면이 p0-p1 선을 지남)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        x = d.normalized()
        y = Vector((0, 0, 1)).cross(x).normalized()
        z = x.cross(y).normalized()
        R = Matrix((x, y, z)).transposed().to_4x4()
        center = (p0 + p1) / 2 - z * (height / 2)
        M = self.M @ Matrix.Translation(center) @ R
        loc, Rr, s = _decompose(M)
        self.colliders.append({"shape": "Block", "loc": loc, "R": Rr, "size": (d.length * s[0], width * s[1], height * s[2]), "tag": tag, "group": self.group[-1]})

    def light(self, pos, color=(255, 180, 110), range_=16, brightness=1.4, kind="Point", shadows=False, angle=60, face=None):
        p = self.M @ Vector(pos)
        self.lights.append({"pos": p, "color": color, "range": range_, "brightness": brightness, "kind": kind, "shadows": shadows, "angle": angle, "face": face, "group": self.group[-1]})

    def marker(self, name, pos, rot=None, **attrs):
        M = self.M @ Matrix.Translation(Vector(pos)) @ rot_matrix(rot)
        loc, R, _ = _decompose(M)
        self.markers.append({"name": name, "loc": loc, "R": R, "attrs": attrs, "group": self.group[-1]})

    # ── 마무리 ─────────────────────────────────────────────
    def finalize(self, collection=None):
        """누적된 메시를 Blender 오브젝트로 생성. 삼각형 한도 초과 시 분할."""
        col = collection or bpy.context.scene.collection
        self.objects = []
        self.mesh_parts = []
        for (group, key), acc in sorted(self.acc.items()):
            # 프리미티브 단위로 청크 분할
            chunks, cur, cur_t = [], [], 0
            for (a, b) in acc.prim_bounds:
                t = acc.tri_count(a, b)
                if cur and cur_t + t > config.MAX_TRIS_PER_PART:
                    chunks.append(cur); cur, cur_t = [], 0
                cur.append((a, b)); cur_t += t
            if cur:
                chunks.append(cur)
            for ci, chunk in enumerate(chunks):
                suffix = "" if len(chunks) == 1 else f"_{ci + 1}"
                gname = "" if group == "Main" else f"{group}_"
                pname = f"{self.name}__{gname}{key}{suffix}"
                face_ids = [fi for a, b in chunk for fi in range(a, b)]
                used = sorted({vi for fi in face_ids for vi in acc.faces[fi]})
                remap = {v: i for i, v in enumerate(used)}
                verts = [acc.verts[v] for v in used]
                faces = [tuple(remap[v] for v in acc.faces[fi]) for fi in face_ids]
                me = bpy.data.meshes.new(pname)
                me.from_pydata([tuple(v) for v in verts], [], faces)
                uvl = me.uv_layers.new(name="UVMap")
                flat = []
                for fi in face_ids:
                    for u, v in acc.uvs[fi]:
                        flat.extend((u, v))
                uvl.data.foreach_set("uv", flat)
                me.polygons.foreach_set("use_smooth", [acc.smooth[fi] for fi in face_ids])
                me.validate(clean_customdata=False)
                me.update()
                me.materials.append(make_preview_material(key))
                ob = bpy.data.objects.new(pname, me)
                col.objects.link(ob)
                self.objects.append(ob)
                xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
                mn = Vector((min(xs), min(ys), min(zs))); mx = Vector((max(xs), max(ys), max(zs)))
                self.mesh_parts.append({
                    "name": pname, "key": key, "group": group,
                    "center": (mn + mx) / 2, "size": mx - mn,
                    "tris": sum(len(f) - 2 for f in faces),
                })
        # 미리보기용 조명
        for i, L in enumerate(self.lights):
            ld = bpy.data.lights.new(f"{self.name}_L{i}", "POINT" if L["kind"] != "Spot" else "SPOT")
            ld.color = tuple(c / 255 for c in L["color"])
            ld.energy = 60 * L["brightness"] * (L["range"] / 16) ** 2
            ld.shadow_soft_size = 0.3
            lo = bpy.data.objects.new(ld.name, ld)
            lo.location = L["pos"]
            col.objects.link(lo)
            self.objects.append(lo)
        return self.objects

    # ── 내보내기 ───────────────────────────────────────────
    def manifest(self):
        parts = []
        for mp in self.mesh_parts:
            info = roblox_info(mp["key"])
            size_b = mp["size"]
            parts.append({
                "name": mp["name"], "key": mp["key"], "group": mp["group"],
                "pos": [_r(v) for v in to_rbx_pos(mp["center"])],
                "size": [_r(max(size_b[0], 0.05)), _r(max(size_b[2], 0.05)), _r(max(size_b[1], 0.05))],
                "tris": mp["tris"], **info,
            })
        cols = []
        for c in self.colliders:
            s = c["size"]
            cols.append({"shape": c["shape"], "pos": [_r(v) for v in to_rbx_pos(c["loc"])], "rot": [_r(v, 5) for v in to_rbx_rot(c["R"])],
                         "size": [_r(s[0]), _r(s[2]), _r(s[1])], "tag": c["tag"], "group": c["group"]})
        lights = [{"pos": [_r(v) for v in to_rbx_pos(L["pos"])], "color": list(L["color"]), "range": L["range"], "brightness": L["brightness"],
                   "kind": L["kind"], "shadows": L["shadows"], "angle": L["angle"],
                   "face": L["face"], "group": L["group"]} for L in self.lights]
        markers = [{"name": m["name"], "pos": [_r(v) for v in to_rbx_pos(m["loc"])], "rot": [_r(v, 5) for v in to_rbx_rot(m["R"])],
                    "attrs": m["attrs"], "group": m["group"]} for m in self.markers]
        # 전체 바운즈 (Roblox 좌표)
        allv = []
        for mp in self.mesh_parts:
            c, s = mp["center"], mp["size"]
            allv.append(c - s / 2); allv.append(c + s / 2)
        if allv:
            mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
            mx = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
        else:
            mn = mx = Vector()
        bmin = to_rbx_pos(mn); bmax = to_rbx_pos(mx)
        bounds = {"min": [_r(min(bmin[i], bmax[i])) for i in range(3)], "max": [_r(max(bmin[i], bmax[i])) for i in range(3)]}
        return {
            "name": self.name, "category": self.category, "replicated": self.replicated,
            "description": self.description, "attributes": self.attributes,
            "parts": parts, "colliders": cols, "lights": lights, "markers": markers, "bounds": bounds,
            "partCount": len(self.prims), "triCount": sum(p["tris"] for p in parts),
        }

    def parts_json(self):
        out = []
        for p in self.prims:
            s = p["size"]
            dims = (s[0], s[2], s[1])  # Roblox 로컬 축 크기
            if p["shape"] == "Cylinder":
                dims = (s[0], s[1], s[2])  # 원기둥은 로컬 X 축 유지, 반지름은 대칭
            info = roblox_info(p["key"])
            out.append({
                "s": {"Block": "B", "Cylinder": "C", "Ball": "S", "Wedge": "W"}[p["shape"]],
                "k": p["key"], "g": p["group"],
                "p": [_r(v, 3) for v in to_rbx_pos(p["loc"])],
                "r": [_r(v, 5) for v in to_rbx_rot(p["R"])],
                "z": [_r(max(d, 0.02), 3) for d in dims],
                "sh": info["castShadow"] and max(dims) > config.PART_NO_SHADOW_MAX_DIM,
            })
        return out

    def export(self, fbx=True):
        config.FBX_DIR.mkdir(parents=True, exist_ok=True)
        config.PARTS_DIR.mkdir(parents=True, exist_ok=True)
        if fbx:
            bpy.ops.object.select_all(action="DESELECT")
            meshes = [o for o in self.objects if o.type == "MESH"]
            for o in meshes:
                o.select_set(True)
            if meshes:
                bpy.context.view_layer.objects.active = meshes[0]
                bpy.ops.export_scene.fbx(
                    filepath=str(config.FBX_DIR / f"{self.name}.fbx"),
                    use_selection=True, object_types={"MESH"},
                    apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
                    axis_forward="-Z", axis_up="Y", bake_space_transform=True,
                    mesh_smooth_type="FACE", use_mesh_modifiers=True,
                    add_leaf_bones=False, embed_textures=False, path_mode="STRIP",
                )
            bpy.ops.object.select_all(action="DESELECT")
        with open(config.PARTS_DIR / f"{self.name}.json", "w") as f:
            json.dump({"name": self.name, "parts": self.parts_json()}, f, separators=(",", ":"))
        return self.manifest()
