"""머티리얼 팔레트.

각 키는 Roblox 쪽 (Enum.Material, Color3, 투명도 등) 과
Blender 미리보기용 절차적 셰이더 파라미터를 함께 정의한다.
에셋 스크립트는 오직 이 키만 사용한다 -> Roblox/Blender 양쪽이 항상 일치.
"""

import bpy

# key: (RobloxMaterial, (r,g,b) 0-255, extra)
# extra: transparency, reflectance, shadow(bool), double(bool: 양면), rough, metal, emit
PALETTE = {
    # ── 목재 (늪지의 풍화된 나무) ─────────────────────────────
    "wood_a":        ("Wood", (112, 92, 72), {}),
    "wood_b":        ("Wood", (96, 82, 66), {}),
    "wood_c":        ("Wood", (126, 108, 86), {}),
    "wood_dark":     ("Wood", (66, 52, 42), {}),
    "wood_wet":      ("Wood", (48, 42, 35), {}),
    "wood_pale":     ("Wood", (150, 136, 112), {}),
    "wood_red":      ("Wood", (124, 64, 50), {}),
    "wood_teal":     ("Wood", (70, 104, 98), {}),
    "wood_moss":     ("Wood", (84, 92, 62), {}),
    "planks_hull":   ("WoodPlanks", (104, 76, 54), {}),
    "planks_hull_dk":("WoodPlanks", (58, 44, 36), {}),
    "hull_paint":    ("WoodPlanks", (44, 70, 68), {}),
    "deck":          ("WoodPlanks", (142, 118, 88), {}),
    # ── 지붕 ────────────────────────────────────────────────
    "shingle_a":     ("Wood", (78, 74, 64), {}),
    "shingle_b":     ("Wood", (92, 84, 70), {}),
    "shingle_c":     ("Wood", (66, 66, 58), {}),
    "thatch":        ("Grass", (150, 128, 82), {}),
    "thatch_dk":     ("Grass", (118, 100, 66), {}),
    # ── 돌 ──────────────────────────────────────────────────
    "stone":         ("Slate", (104, 104, 96), {}),
    "stone_dk":      ("Slate", (72, 74, 70), {}),
    "stone_moss":    ("Cobblestone", (90, 100, 78), {}),
    "stone_ruin":    ("Limestone", (148, 144, 128), {}),
    "stone_rune":    ("Neon", (90, 255, 170), {"emit": 3.0, "shadow": False}),
    "brick":         ("Brick", (126, 84, 66), {}),
    # ── 금속/천/밧줄 ─────────────────────────────────────────
    "iron":          ("CorrodedMetal", (72, 66, 60), {"metal": 0.6, "rough": 0.65}),
    "brass":         ("Metal", (168, 128, 62), {"metal": 1.0, "rough": 0.35}),
    "gold":          ("Metal", (196, 156, 70), {"metal": 1.0, "rough": 0.25}),
    "steel":         ("Metal", (150, 154, 158), {"metal": 1.0, "rough": 0.3}),
    "rope":          ("Fabric", (158, 134, 94), {}),
    "rope_dk":       ("Fabric", (110, 92, 66), {}),
    "sail":          ("Fabric", (216, 204, 178), {"double": True}),
    "sail_patch":    ("Fabric", (184, 164, 128), {"double": True}),
    "cloth_red":     ("Fabric", (142, 54, 46), {"double": True}),
    "cloth_green":   ("Fabric", (72, 100, 74), {"double": True}),
    "cloth_purple":  ("Fabric", (92, 64, 110), {"double": True}),
    "leather":       ("Leather", (96, 62, 42), {}),
    "net":           ("Fabric", (120, 112, 90), {"double": True}),
    # ── 발광 ────────────────────────────────────────────────
    "glow_lantern":  ("Neon", (255, 184, 104), {"emit": 5.0, "shadow": False}),
    "glow_mushroom": ("Neon", (110, 255, 205), {"emit": 4.0, "shadow": False}),
    "glow_potion":   ("Neon", (180, 110, 255), {"emit": 4.0, "shadow": False}),
    "glow_fire":     ("Neon", (255, 120, 40), {"emit": 6.0, "shadow": False}),
    "glass":         ("Glass", (170, 200, 190), {"transparency": 0.45, "rough": 0.05}),
    "glass_green":   ("Glass", (96, 160, 96), {"transparency": 0.3, "rough": 0.05}),
    "candle":        ("SmoothPlastic", (232, 220, 190), {}),
    # ── 식생 ────────────────────────────────────────────────
    "bark":          ("Wood", (74, 64, 54), {}),
    "bark_dead":     ("Wood", (104, 98, 88), {}),
    "bark_cypress":  ("Wood", (96, 74, 58), {}),
    "moss":          ("LeafyGrass", (80, 104, 54), {}),
    "moss_hang":     ("Fabric", (118, 128, 94), {"double": True}),
    "leaf":          ("LeafyGrass", (70, 98, 50), {"double": True}),
    "leaf_dk":       ("LeafyGrass", (52, 74, 42), {"double": True}),
    "reed":          ("Grass", (126, 132, 72), {"double": True}),
    "cattail":       ("Fabric", (96, 62, 40), {}),
    "lily":          ("LeafyGrass", (76, 122, 62), {"double": True}),
    "flower_pink":   ("SmoothPlastic", (236, 180, 204), {}),
    "flower_white":  ("SmoothPlastic", (236, 232, 214), {}),
    "mushroom_cap":  ("SmoothPlastic", (150, 72, 60), {}),
    "mushroom_stem": ("SmoothPlastic", (220, 208, 180), {}),
    # ── 크리처 ──────────────────────────────────────────────
    "skin_bog":      ("SmoothPlastic", (84, 112, 70), {"rough": 0.45}),
    "skin_bog_lt":   ("SmoothPlastic", (150, 164, 112), {"rough": 0.45}),
    "skin_mud":      ("Mud", (96, 78, 58), {}),
    "skin_witch":    ("SmoothPlastic", (132, 150, 118), {"rough": 0.6}),
    "skin_lord":     ("Slate", (58, 70, 56), {}),
    "eye_glow":      ("Neon", (255, 222, 90), {"emit": 5.0, "shadow": False}),
    "eye_red":       ("Neon", (255, 90, 60), {"emit": 5.0, "shadow": False}),
    "claw":          ("Limestone", (40, 36, 32), {}),
    "mouth":         ("SmoothPlastic", (40, 20, 24), {}),
    "robe":          ("Fabric", (70, 52, 84), {}),
    "robe_dk":       ("Fabric", (44, 36, 54), {}),
    "hair":          ("Fabric", (170, 176, 160), {}),
    # ── 기타 ────────────────────────────────────────────────
    "bone":          ("Limestone", (222, 212, 188), {}),
    "mud":           ("Mud", (72, 60, 46), {}),
    "sand":          ("Sand", (196, 178, 136), {}),
    "straw":         ("Grass", (190, 168, 104), {}),
    "fish":          ("SmoothPlastic", (150, 160, 150), {"rough": 0.35}),
    "cauldron_brew": ("Neon", (120, 230, 90), {"emit": 3.0, "shadow": False}),
    "paper":         ("SmoothPlastic", (220, 206, 172), {}),
    "paint_white":   ("SmoothPlastic", (226, 222, 210), {}),
    "paint_red":     ("SmoothPlastic", (170, 48, 40), {}),
}


def roblox_info(key):
    mat, rgb, extra = PALETTE[key]
    return {
        "material": mat,
        "color": list(rgb),
        "transparency": extra.get("transparency", 0.0),
        "reflectance": extra.get("reflectance", 0.0),
        "castShadow": extra.get("shadow", True),
        "doubleSided": extra.get("double", False),
    }


# ─────────────────────────────────────────────────────────────
# Blender 미리보기 셰이더
# ─────────────────────────────────────────────────────────────

def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lin(rgb, mul=1.0):
    return tuple(min(1.0, _srgb_to_linear(v) * mul) for v in rgb) + (1.0,)


class _NB:
    """노드 트리 빌더 헬퍼."""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nodes = self.nt.nodes
        self.links = self.nt.links
        self.x = -1400

    def node(self, idname, **props):
        n = self.nodes.new(idname)
        n.location = (self.x, 0)
        self.x += 180
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.links.new(a, b)

    def uv(self):
        n = self.node("ShaderNodeTexCoord")
        return n.outputs["UV"]

    def obj(self):
        return self.node("ShaderNodeTexCoord").outputs["Object"]

    def mix_rgb(self, fac, a, b):
        m = self.node("ShaderNodeMix", data_type="RGBA")
        self._in(m.inputs[0], fac)
        self._in(m.inputs[6], a)
        self._in(m.inputs[7], b)
        return m.outputs[2]

    def ramp(self, fac, stops):
        r = self.node("ShaderNodeValToRGB")
        cr = r.color_ramp
        # 기본 2개 스톱 재사용
        while len(cr.elements) < len(stops):
            cr.elements.new(0.5)
        for el, (pos, col) in zip(cr.elements, stops):
            el.position = pos
            el.color = col
        self._in(r.inputs[0], fac)
        return r.outputs[0]

    def _in(self, sock, val):
        if hasattr(val, "is_output"):
            self.link(val, sock)
        else:
            sock.default_value = val

    def math(self, op, a, b=0.0):
        m = self.node("ShaderNodeMath", operation=op)
        self._in(m.inputs[0], a)
        self._in(m.inputs[1], b)
        return m.outputs[0]

    def bump(self, height, strength=0.3, distance=0.1):
        b = self.node("ShaderNodeBump")
        b.inputs["Strength"].default_value = strength
        b.inputs["Distance"].default_value = distance
        self.link(height, b.inputs["Height"])
        return b.outputs["Normal"]


def _principled(nb):
    p = nb.nodes.get("Principled BSDF")
    return p


def make_preview_material(key):
    name = f"M_{key}"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    rmat, rgb, extra = PALETTE[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nb = _NB(mat)
    p = _principled(nb)
    base = _lin(rgb)
    dark = _lin(rgb, 0.62)
    light = _lin(rgb, 1.25)
    rough = extra.get("rough", 0.8)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = extra.get("metal", 0.0)

    if rmat in ("Wood", "WoodPlanks"):
        uv = nb.uv()
        # 결: UV u 방향으로 뻗는 물결 무늬
        wave = nb.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Y")
        wave.inputs["Scale"].default_value = 3.0
        wave.inputs["Distortion"].default_value = 7.0
        wave.inputs["Detail"].default_value = 3.0
        nb.link(uv, wave.inputs["Vector"])
        noise = nb.node("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 6.0
        noise.inputs["Detail"].default_value = 6.0
        nb.link(uv, noise.inputs["Vector"])
        fac = nb.math("MULTIPLY", wave.outputs["Fac"], noise.outputs["Factor"])
        col = nb.ramp(fac, [(0.0, dark), (0.35, base), (1.0, light)])
        if rmat == "WoodPlanks":
            brick = nb.node("ShaderNodeTexBrick")
            brick.inputs["Scale"].default_value = 1.0
            brick.inputs["Brick Width"].default_value = 2.0
            brick.inputs["Row Height"].default_value = 0.125
            brick.inputs["Mortar Size"].default_value = 0.006
            brick.inputs["Color1"].default_value = (1, 1, 1, 1)
            brick.inputs["Color2"].default_value = (0.8, 0.8, 0.8, 1)
            brick.inputs["Mortar"].default_value = (0.15, 0.15, 0.15, 1)
            nb.link(uv, brick.inputs["Vector"])
            m = nb.node("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
            m.inputs[0].default_value = 1.0
            nb.link(col, m.inputs[6])
            nb.link(brick.outputs["Color"], m.inputs[7])
            col = m.outputs[2]
            nb.link(nb.bump(brick.outputs["Fac"], 0.25, 0.05), p.inputs["Normal"])
        else:
            nb.link(nb.bump(fac, 0.25, 0.05), p.inputs["Normal"])
        nb.link(col, p.inputs["Base Color"])
    elif rmat in ("Slate", "Cobblestone", "Limestone", "Rock", "Brick", "Basalt", "Concrete"):
        obj = nb.obj()
        vor = nb.node("ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = 0.9
        nb.link(obj, vor.inputs["Vector"])
        noise = nb.node("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 2.0
        noise.inputs["Detail"].default_value = 8.0
        nb.link(obj, noise.inputs["Vector"])
        fac = nb.math("ADD", nb.math("MULTIPLY", vor.outputs["Distance"], 0.6), nb.math("MULTIPLY", noise.outputs["Factor"], 0.6))
        col = nb.ramp(fac, [(0.15, dark), (0.5, base), (0.95, light)])
        if rmat == "Cobblestone":
            moss = nb.node("ShaderNodeTexNoise")
            moss.inputs["Scale"].default_value = 0.35
            moss.inputs["Detail"].default_value = 4.0
            nb.link(obj, moss.inputs["Vector"])
            mf = nb.ramp(moss.outputs["Factor"], [(0.45, (0, 0, 0, 1)), (0.6, (1, 1, 1, 1))])
            col = nb.mix_rgb(mf, col, _lin((74, 96, 48)))
        nb.link(col, p.inputs["Base Color"])
        nb.link(nb.bump(fac, 0.5, 0.2), p.inputs["Normal"])
        p.inputs["Roughness"].default_value = 0.9
    elif rmat in ("Fabric", "Leather"):
        uv = nb.uv()
        noise = nb.node("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 40.0
        noise.inputs["Detail"].default_value = 4.0
        nb.link(uv, noise.inputs["Vector"])
        blotch = nb.node("ShaderNodeTexNoise")
        blotch.inputs["Scale"].default_value = 2.0
        nb.link(uv, blotch.inputs["Vector"])
        col = nb.ramp(blotch.outputs["Factor"], [(0.3, dark), (0.7, base)])
        nb.link(col, p.inputs["Base Color"])
        nb.link(nb.bump(noise.outputs["Factor"], 0.15, 0.02), p.inputs["Normal"])
        p.inputs["Roughness"].default_value = 0.95 if rmat == "Fabric" else 0.55
        p.inputs["Sheen Weight"].default_value = 0.3 if rmat == "Fabric" else 0.0
    elif rmat in ("Metal", "CorrodedMetal"):
        obj = nb.obj()
        noise = nb.node("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 3.0
        noise.inputs["Detail"].default_value = 10.0
        nb.link(obj, noise.inputs["Vector"])
        if rmat == "CorrodedMetal":
            col = nb.ramp(noise.outputs["Factor"], [(0.4, base), (0.62, _lin((120, 70, 40)))])
            rgh = nb.ramp(noise.outputs["Factor"], [(0.4, (0.45, 0.45, 0.45, 1)), (0.62, (0.95, 0.95, 0.95, 1))])
            nb.link(rgh, p.inputs["Roughness"])
        else:
            col = nb.ramp(noise.outputs["Factor"], [(0.3, dark), (0.7, base)])
        nb.link(col, p.inputs["Base Color"])
        nb.link(nb.bump(noise.outputs["Factor"], 0.1, 0.02), p.inputs["Normal"])
    elif rmat == "Neon":
        p.inputs["Base Color"].default_value = base
        p.inputs["Emission Color"].default_value = base
        p.inputs["Emission Strength"].default_value = extra.get("emit", 4.0)
    elif rmat == "Glass":
        p.inputs["Base Color"].default_value = base
        p.inputs["Transmission Weight"].default_value = 0.85
        p.inputs["Roughness"].default_value = 0.05
    elif rmat in ("Grass", "LeafyGrass", "Mud", "Sand", "Ground"):
        obj = nb.obj()
        noise = nb.node("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 1.5
        noise.inputs["Detail"].default_value = 8.0
        nb.link(obj, noise.inputs["Vector"])
        col = nb.ramp(noise.outputs["Factor"], [(0.3, dark), (0.5, base), (0.75, light)])
        nb.link(col, p.inputs["Base Color"])
        fine = nb.node("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 30.0
        nb.link(obj, fine.inputs["Vector"])
        nb.link(nb.bump(fine.outputs["Factor"], 0.3, 0.05), p.inputs["Normal"])
        p.inputs["Roughness"].default_value = 0.92
        if extra.get("double"):
            p.inputs["Subsurface Weight"].default_value = 0.0
    else:
        p.inputs["Base Color"].default_value = base
    return mat


def terrain_material(name, rgb):
    """레벨 개관 렌더용 지형 머티리얼(버텍스 컬러 사용)."""
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nb = _NB(mat)
    p = _principled(nb)
    attr = nb.node("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    obj = nb.obj()
    noise = nb.node("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.08
    noise.inputs["Detail"].default_value = 10.0
    nb.link(obj, noise.inputs["Vector"])
    shade = nb.ramp(noise.outputs["Factor"], [(0.3, (0.75, 0.75, 0.75, 1)), (0.7, (1.1, 1.1, 1.1, 1))])
    m = nb.node("ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY")
    m.inputs[0].default_value = 1.0
    nb.link(attr.outputs["Color"], m.inputs[6])
    nb.link(shade, m.inputs[7])
    nb.link(m.outputs[2], p.inputs["Base Color"])
    fine = nb.node("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 1.2
    fine.inputs["Detail"].default_value = 10.0
    nb.link(obj, fine.inputs["Vector"])
    nb.link(nb.bump(fine.outputs["Factor"], 0.35, 0.4), p.inputs["Normal"])
    p.inputs["Roughness"].default_value = 0.95
    return mat


def water_material(name="M_Water", rgb=(34, 52, 40), clarity=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nb = _NB(mat)
    p = _principled(nb)
    p.inputs["Base Color"].default_value = _lin(rgb)
    p.inputs["Roughness"].default_value = 0.04
    p.inputs["Specular IOR Level"].default_value = 0.6
    p.inputs["Transmission Weight"].default_value = clarity
    obj = nb.obj()
    noise = nb.node("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.35
    noise.inputs["Detail"].default_value = 6.0
    nb.link(obj, noise.inputs["Vector"])
    nb.link(nb.bump(noise.outputs["Factor"], 0.12, 0.5), p.inputs["Normal"])
    return mat
