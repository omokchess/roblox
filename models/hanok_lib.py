# -*- coding: utf-8 -*-
"""
hanok_lib.py — 한옥 모델들이 함께 쓰는 부품.

건물마다 스크립트를 따로 두되, 지붕 곡면과 문짝 짜는 법과 색은 여기 하나만 둔다.
한쪽에서 고친 것이 다른 건물에 안 들어가 제각각이 되는 것을 막으려는 것이다.

지키는 것
  1. 색은 PALETTE 에서만 쓴다. 월드에서 실제로 재서 뽑은 값이다.
  2. 재질마다 오브젝트를 따로 만든다. 로블록스는 메시 하나에 색 하나만 준다.
  3. 지붕은 닫힌 덩이로 만든다. 열린 판은 아래에서 투시된다.
  4. 벽은 기둥 중심에서 기둥 중심까지 꽉 채우고, 구멍은 둘레를 네 조각으로 짠다.
  5. 치수는 표대로 짓고 내보낼 때 MODEL_SCALE 한 번만 곱한다.

좌표는 블렌더 기준이다. x 오른쪽, y 뒤, z 위. **정면은 -y** 이다.
-Z 정면으로 내보내므로 로블록스에서도 -Z 를 본다.
"""

import bpy
import bmesh
import os
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))

# 월드에서 실측한 색으로만 짠 팔레트. sRGB 16진수
PALETTE = {
    "Stylobate": "#C1BEB0",   # 기단. 탑의성역 석재와 같은 계열
    "Stairs":    "#C5C2B3",   # 계단
    "Plinth":    "#A9A597",   # 초석
    "Column":    "#8A5A45",   # 기둥. 단청 주홍을 죽인 흙빛 적갈
    "Beam":      "#7E5340",   # 창방과 평방
    "Bracket":   "#6E4736",   # 공포
    "Wall":      "#D8D2C0",   # 회벽. 순백을 쓰지 않는다
    "Lattice":   "#9A6A4E",   # 창살과 난간
    "Paper":     "#E4DCC6",   # 창호지
    "Roof":      "#55584F",   # 기와. 암반색과 같은 계열의 어두운 회녹
    "RoofEdge":  "#474A43",   # 용마루와 내림마루
    "Eave":      "#5E4033",   # 처마 밑 서까래
    "Trim":      "#4E6F63",   # 단청. 탁한 청록 한 점
    "Ochre":     "#B4884A",   # 단청. 탁한 황토 한 점
    "Masonry":   "#9D998B",   # 성벽 돌. 기단보다 한 톤 어둡다
    "Thatch":    "#9C8660",   # 초가. 마른 볏짚
    "Onggi":     "#5C4032",   # 옹기. 기둥보다 어둡고 덜 붉다
    "Soil":      "#7A6449",   # 텃밭 흙. 마을 흙길과 같은 계열
    "Leaf":      "#5E7147",   # 채소. 평원 풀빛보다 한 톤 짙게
    "Brush":     "#8E7D66",   # 싸리. 껍질 벗긴 가는 가지. 기둥보다 훨씬 옅고 잿빛이 돈다
}


# ---------------------------------------------------------------- 기반

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, palette=None):
    hexs = (palette or PALETTE)[name].lstrip("#")
    rgb = tuple(_srgb_to_linear(int(hexs[i:i + 2], 16)) for i in (0, 2, 4))
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.diffuse_color = (*rgb, 1.0)
    return m


class Group:
    """재질 하나가 쓰일 덩어리. 조각을 모았다가 한 오브젝트로 만든다."""

    def __init__(self, name, mat):
        self.name = name
        self.mat = mat
        self.bm = bmesh.new()

    def box(self, cx, cy, cz, sx, sy, sz):
        if sx <= 0 or sy <= 0 or sz <= 0:
            return
        bmesh.ops.create_cube(
            self.bm, size=1.0,
            matrix=Matrix.Translation((cx, cy, cz)) @ Matrix.Diagonal((sx, sy, sz, 1.0)),
        )

    def cyl(self, cx, cy, cz, r_bottom, r_top, h, seg=12):
        bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=seg,
            radius1=r_bottom, radius2=r_top, depth=h,
            matrix=Matrix.Translation((cx, cy, cz + h / 2)),
        )

    def hcyl(self, cx, cy, cz, r, length, axis="x", seg=12, rz=0.0):
        """눕힌 원통. 가운데가 (cx, cy, cz) 이고 axis 쪽으로 누워 있다. rz 로 수평으로 더 돌린다"""
        rot = Matrix.Rotation(1.5707963, 4, "Y" if axis == "x" else "X")
        bmesh.ops.create_cone(
            self.bm, cap_ends=True, cap_tris=False, segments=seg,
            radius1=r, radius2=r, depth=length,
            matrix=Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(rz, 4, "Z") @ rot,
        )

    def obox(self, cx, cy, cz, sx, sy, sz, rx=0.0, rz=0.0, ry=0.0):
        """돌린 상자. rx 는 x 축(앞뒤로 젖힘), ry 는 y 축(옆으로 젖힘), rz 는 z 축(수평 회전), 라디안"""
        m = (Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y")
             @ Matrix.Rotation(rx, 4, "X") @ Matrix.Diagonal((sx, sy, sz, 1.0)))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)

    def add_mesh(self, verts, faces):
        vs = [self.bm.verts.new(v) for v in verts]
        for f in faces:
            try:
                self.bm.faces.new([vs[i] for i in f])
            except ValueError:
                pass

    def finish(self):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(self.name, me)
        ob.data.materials.append(self.mat)
        bpy.context.collection.objects.link(ob)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.shade_flat()
        return ob


def new_groups(prefix, palette=None):
    pal = palette or PALETTE
    return {k: Group(prefix + "_" + k, material(k, pal)) for k in pal}


def transformed(g, matrix, fn, *args, **kwargs):
    """
    fn 을 제 좌표에서 지은 뒤 matrix 로 옮겨 g 에 합친다.
    ㄱ자 집의 날개채처럼 몸채와 90도 돌아앉은 채를, 곧은 채 짓는 부품 그대로 짓게 한다.
    회전만 쓰고 뒤집기는 쓰지 않는다. 뒤집으면 면 방향이 거꾸로 된다
    """
    tmp = {k: Group("tmp_" + k, grp.mat) for k, grp in g.items()}
    result = fn(tmp, *args, **kwargs)
    for k, t in tmp.items():
        if t.bm.verts:
            bmesh.ops.transform(t.bm, matrix=matrix, verts=t.bm.verts)
            me = bpy.data.meshes.new("tmp_" + k)
            t.bm.to_mesh(me)
            g[k].bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        t.bm.free()
    return result


# ---------------------------------------------------------------- 지붕

def roof_height(x, y, A, B, ridge_half, H, style="hip", exp=1.42, lift=0.24, round_p=None):
    """
    지붕 한 점의 높이. 처마 끝이 0, 용마루가 H.

    **곡선이 핵심이다.** 직선으로 기울이면 창고가 된다.
      t ** exp   용마루 쪽이 가파르고 처마 쪽이 완만하다. 1 이면 직선이다
      corner     네 귀가 위로 들린다(앙곡). 두 처마가 만나는 모서리에서만 더한다
    style
      hip     팔작/우진각. ridge_half 로 용마루 길이를 준다. 0 이면 사모지붕
      gable   맞배. 앞뒤로만 기울고 옆은 박공으로 막힌다
    """
    dy = max(0.0, B - abs(y))
    ty = dy / B if B > 1e-6 else 1.0
    if style == "gable":
        t = min(1.0, ty)
        z = H * (t ** exp)
        # 맞배는 처마 양 끝만 살짝 든다
        cx = 1.0 - min(1.0, (A - abs(x)) / (A * 0.25))
        z += max(0.0, cx) * (1.0 - t) * H * lift * 0.5
        return z
    dx = max(0.0, A - abs(x))
    span_x = A - ridge_half
    tx = dx / span_x if span_x > 1e-6 else 1.0
    if round_p:
        # 초가처럼 네 면이 모서리 없이 이어지는 지붕. min 대신 p-노름으로 섞는다.
        # min 은 대각선에 골이 서서 격자에 계단이 진다
        u = max(0.0, 1.0 - tx)
        w = max(0.0, 1.0 - ty)
        t = 1.0 - (u ** round_p + w ** round_p) ** (1.0 / round_p)
        if t < 0.0:
            # 네 귀는 판으로 남기지 않고 짚이 흘러내리듯 처지게 한다
            # 0.6 이면 너무 처져 귀 밑 도리 끝이 짚을 뚫고 나온다
            return H * t * 0.3
    else:
        t = min(1.0, min(tx, ty))
    z = H * (t ** exp)
    cx = 1.0 - min(1.0, dx / (A * 0.42))
    cy = 1.0 - min(1.0, dy / (B * 0.42))
    z += max(0.0, cx) * max(0.0, cy) * H * lift
    return z


def build_roof(g, base_z, W, D, eave_out, H, style="hip", ridge_half=None,
               thick=2.0, exp=1.42, lift=0.24, nx=46, ny=32, mat="Roof",
               eave=True, ridge=True, chimi=True, cx=0.0, x_lo=None, x_hi=None, round_p=None,
               gable_ends=(True, True)):
    """
    지붕을 **닫힌 덩이 하나**로 만든다. 위판, 밑판, 옆구리를 한 오브젝트에 넣는다.
    열린 판은 법선을 밖으로 정리해도 어느 쪽이 밖인지 정해지지 않아 아래에서 투시된다.
    돌려주는 값은 용마루 높이다.
      cx          지붕 가운데를 x 로 옮긴다
      x_lo/x_hi   지붕 자체 좌표로 x 를 자른다. 옆 채에 맞붙거나 담장처럼 이어 붙일 때
                  처마가 이웃 지붕을 파고들지 않게 한다. 잘린 면도 닫힌다
    """
    A = W / 2 + eave_out
    B = D / 2 + eave_out
    if ridge_half is None:
        ridge_half = (W - D) / 2 * 0.5 + 6.0 if style == "hip" else A
    ridge_half = max(0.0, min(ridge_half, A))
    lo = -A if x_lo is None else max(-A, x_lo)
    hi = A if x_hi is None else min(A, x_hi)

    top, bot = [], []
    for i in range(nx + 1):
        x = lo + (hi - lo) * i / nx
        for j in range(ny + 1):
            y = -B + 2 * B * j / ny
            z = roof_height(x, y, A, B, ridge_half, H, style, exp, lift, round_p)
            top.append((cx + x, y, base_z + z))
            bot.append((cx + x, y, base_z + z - thick))

    def idx(i, j):
        return i * (ny + 1) + j

    n = len(top)
    faces = []
    for i in range(nx):
        for j in range(ny):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            faces.append((a, b, c, d))
            faces.append((a + n, d + n, c + n, b + n))
    for i in range(nx):
        for j0 in (0, ny):
            a, b = idx(i, j0), idx(i + 1, j0)
            faces.append((a, b, b + n, a + n))
    for j in range(ny):
        for i0 in (0, nx):
            a, b = idx(i0, j), idx(i0, j + 1)
            faces.append((a, b, b + n, a + n))
    g[mat].add_mesh(top + bot, faces)

    # 서까래와 평고대. 처마 밑에 곡선을 따라 나무를 덧댄다
    if eave:
        step = 2
        for i in range(0, nx, step):
            for j0 in (0, ny):
                p0, p1 = top[idx(i, j0)], top[idx(min(i + step, nx), j0)]
                g["Eave"].box((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2,
                              (p0[2] + p1[2]) / 2 - thick - 0.5,
                              abs(p1[0] - p0[0]) + 0.4, 2.6, 1.3)
        if style != "gable":
            for j in range(0, ny, step):
                for i0 in (0, nx):
                    p0, p1 = top[idx(i0, j)], top[idx(i0, min(j + step, ny))]
                    g["Eave"].box((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2,
                                  (p0[2] + p1[2]) / 2 - thick - 0.5,
                                  2.6, abs(p1[1] - p0[1]) + 0.4, 1.3)

    ridge_z = base_z + roof_height(0, 0, A, B, ridge_half, H, style, exp, lift, round_p)
    if ridge:
        # 용마루도 자른 범위 안에만 둔다
        r0, r1 = max(-ridge_half, lo), min(ridge_half, hi)
        RL, rc = max(3.0, r1 - r0), cx + (r0 + r1) / 2
        if style == "hip" and ridge_half < 1.0:
            # 사모지붕. 꼭대기에 절병통을 얹는다
            g["RoofEdge"].box(cx, 0, ridge_z + 0.6, 3.2, 3.2, 1.6)
            g["RoofEdge"].cyl(cx, 0, ridge_z + 1.4, 1.4, 0.6, 3.6)
        else:
            g["RoofEdge"].box(rc, 0, ridge_z + 1.0, RL, 3.4, 2.0)
            g["RoofEdge"].box(rc, 0, ridge_z + 2.4, RL - 1.5, 2.6, 1.2)
            if chimi:
                for s in (-1, 1):
                    ex = rc + s * (RL / 2 - 1.0)
                    g["RoofEdge"].box(ex, 0, ridge_z + 2.2, 2.6, 3.6, 4.4)
                    g["RoofEdge"].box(ex + s * 0.6, 0, ridge_z + 5.6, 2.0, 2.8, 2.8)
                    g["RoofEdge"].box(ex + s * 1.1, 0, ridge_z + 7.4, 1.4, 2.0, 1.6)
    if style == "gable":
        # 박공. 옆면 세모를 벽으로 막는다. 안 막으면 지붕 속이 옆에서 보인다
        for s in (-1, 1):
            # 다른 지붕 속으로 파고드는 끝(ㄱ자 날개)은 박공을 두지 않는다
            if not gable_ends[(s + 1) // 2]:
                continue
            # 벽 바깥면에 맞춰 안쪽으로만 두께를 준다. 밖으로 나가면 이어 붙인 이웃과 겹친다
            x = cx + s * (W / 2)
            xa, xb = sorted((x, x - s * 1.8))
            verts = [
                (xa, -D / 2, base_z - 0.2), (xa, D / 2, base_z - 0.2),
                (xa, 0.0, ridge_z - thick),
                (xb, -D / 2, base_z - 0.2), (xb, D / 2, base_z - 0.2),
                (xb, 0.0, ridge_z - thick),
            ]
            faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
            g["Wall"].add_mesh(verts, faces)
    return ridge_z


def heightfield_roof(g, fn, x0, x1, y0, y1, base_z, thick=2.0, nx=16, ny=16, mat="Roof"):
    """
    fn(x, y) 로 높이를 주는 지붕을 닫힌 덩이로 만든다. build_roof 로 안 되는 모양
    (ㄱ자 행각 모서리의 골과 추녀)에 쓴다. 테두리 네 면까지 막는다
    """
    top, bot = [], []
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        for j in range(ny + 1):
            y = y0 + (y1 - y0) * j / ny
            z = base_z + fn(x, y)
            top.append((x, y, z))
            bot.append((x, y, z - thick))

    def idx(i, j):
        return i * (ny + 1) + j

    n = len(top)
    faces = []
    for i in range(nx):
        for j in range(ny):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            faces.append((a, b, c, d))
            faces.append((a + n, d + n, c + n, b + n))
    for i in range(nx):
        for j0 in (0, ny):
            a, b = idx(i, j0), idx(i + 1, j0)
            faces.append((a, b, b + n, a + n))
    for j in range(ny):
        for i0 in (0, nx):
            a, b = idx(i0, j), idx(i0, j + 1)
            faces.append((a, b, b + n, a + n))
    g[mat].add_mesh(top + bot, faces)


# ---------------------------------------------------------------- 몸통 부품

def stylobate(g, W, D, h1, h2, margin1=14, margin2=6, stairs=True, stair_w=26.0, steps=5,
              mat="Stylobate"):
    """기단 두 켜와 앞 계단. 돌려주는 값은 마루 높이다."""
    g[mat].box(0, 0, h1 / 2, W + margin1, D + margin1, h1)
    g[mat].box(0, 0, h1 + h2 / 2, W + margin2, D + margin2, h2)
    floor = h1 + h2
    if stairs:
        stair(g, 0, -(D + margin1) / 2, floor, stair_w, steps)
    return floor


def stair(g, cx, front_y, rise, width, steps=5, tread=2.2, cheek=True, base_z=0.0):
    """front_y 에서 앞(-y)으로 내려가는 계단. base_z 높이의 땅에서 rise 만큼 오른다"""
    for k in range(steps):
        h = rise * (k + 1) / steps
        g["Stairs"].box(cx, front_y - tread * (steps - k) + tread / 2, base_z + h / 2,
                        width, tread + 0.2, h)
    if cheek:
        for s in (-1, 1):
            g["Stairs"].box(cx + s * (width / 2 + 1.5), front_y - tread * steps / 2,
                            base_z + rise * 0.55, 3.0, tread * steps, rise * 1.1)


def column_grid(W, D, bay_x, bay_y):
    xs = [(-W / 2 + W * i / bay_x) for i in range(bay_x + 1)]
    ys = [(-D / 2 + D * j / bay_y) for j in range(bay_y + 1)]
    return xs, ys


def columns(g, xs, ys, floor, col_h, r=2.1, plinth=True, edge_only=True):
    """기둥과 초석. 배흘림으로 아래가 굵고 위가 가늘다"""
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            edge = i in (0, len(xs) - 1) or j in (0, len(ys) - 1)
            if edge_only and not edge:
                continue
            if plinth:
                g["Plinth"].cyl(x, y, floor, r * 1.43, r * 1.29, 1.8)
            g["Column"].cyl(x, y, floor + (1.8 if plinth else 0), r, r * 0.83, col_h)
    return floor + (1.8 if plinth else 0) + col_h


def beams(g, xs, ys, top, brackets=True, W=None, D=None):
    """창방과 평방, 공포. 돌려주는 값은 지붕을 얹을 높이다"""
    W = W if W is not None else xs[-1] - xs[0]
    D = D if D is not None else ys[-1] - ys[0]
    # 가운데를 원점으로 두지 않는다. 문간방처럼 옆으로 비킨 채도 제자리에 얹힌다
    mx, my = (xs[0] + xs[-1]) / 2, (ys[0] + ys[-1]) / 2
    for y in (ys[0], ys[-1]):
        g["Beam"].box(mx, y, top + 1.2, W + 4, 2.2, 2.4)
    for x in (xs[0], xs[-1]):
        g["Beam"].box(x, my, top + 1.2, 2.2, D + 4, 2.4)
    g["Beam"].box(mx, my, top + 3.0, W + 5, D + 5, 1.4)
    if not brackets:
        return top + 4.6
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            if not (i in (0, len(xs) - 1) or j in (0, len(ys) - 1)):
                continue
            for k in range(3):
                w = 7.0 + k * 2.2
                g["Bracket"].box(x, y, top + 4.4 + k * 1.7, w, 2.0, 1.5)
                g["Bracket"].box(x, y, top + 4.4 + k * 1.7, 2.0, w, 1.5)
    return top + 4.4 + 2 * 1.7 + 0.75 + 0.9


def dancheong(g, W, D, top):
    """단청 띠. 처마 밑 앞뒤로 한 줄씩"""
    for s in (-1, 1):
        g["Trim"].box(0, s * (D / 2 + 1.2), top + 0.2, W + 3, 0.6, 1.6)
        g["Ochre"].box(0, s * (D / 2 + 1.2), top - 1.6, W + 3, 0.6, 1.0)


def opening(g, cx, cy, span, along_x, floor, wall_h, sill, oh, ow, kind="window", WT=1.8):
    """
    벽 한 칸을 꽉 채우고 구멍 하나를 둘레 네 조각으로 짜 넣는다.
      window   창살만 넣어 실제로 뚫려 보인다
      lattice  창살 문짝. 속이 보이되 드나들 수 없다
      open     드나드는 문. 구멍을 비운다
      solid    구멍 없이 막힌 벽
    """
    if kind == "none":
        # 벽을 두지 않는다. 날개채가 맞붙어 안이 이어지는 칸이다
        return
    if kind == "solid":
        if along_x:
            g["Wall"].box(cx, cy, floor + wall_h / 2, span, WT, wall_h)
        else:
            g["Wall"].box(cx, cy, floor + wall_h / 2, WT, span, wall_h)
        return
    jamb = (span - ow) / 2
    nv, nh = max(2, int(ow / 3.2)), max(2, int(oh / 3.2))
    if along_x:
        g["Wall"].box(cx, cy, floor + sill / 2, span, WT, sill)
        g["Wall"].box(cx - (span - jamb) / 2, cy, floor + sill + oh / 2, jamb, WT, oh)
        g["Wall"].box(cx + (span - jamb) / 2, cy, floor + sill + oh / 2, jamb, WT, oh)
        g["Wall"].box(cx, cy, floor + (sill + oh + wall_h) / 2, span, WT, wall_h - sill - oh)
        if kind != "open":
            for k in range(nv):
                g["Lattice"].box(cx - ow / 2 + ow * (k + 0.5) / nv, cy, floor + sill + oh / 2,
                                 0.5, WT * 0.8, oh)
            for k in range(nh):
                g["Lattice"].box(cx, cy, floor + sill + oh * (k + 0.5) / nh, ow, WT * 0.8, 0.5)
        g["Lattice"].box(cx, cy, floor + sill + oh + 0.5, ow + 1.4, WT * 1.1, 1.0)
        g["Lattice"].box(cx, cy, floor + sill - 0.5, ow + 1.4, WT * 1.1, 1.0)
    else:
        g["Wall"].box(cx, cy, floor + sill / 2, WT, span, sill)
        g["Wall"].box(cx, cy - (span - jamb) / 2, floor + sill + oh / 2, WT, jamb, oh)
        g["Wall"].box(cx, cy + (span - jamb) / 2, floor + sill + oh / 2, WT, jamb, oh)
        g["Wall"].box(cx, cy, floor + (sill + oh + wall_h) / 2, WT, span, wall_h - sill - oh)
        if kind != "open":
            for k in range(nv):
                g["Lattice"].box(cx, cy - ow / 2 + ow * (k + 0.5) / nv, floor + sill + oh / 2,
                                 WT * 0.8, 0.5, oh)
            for k in range(nh):
                g["Lattice"].box(cx, cy, floor + sill + oh * (k + 0.5) / nh, WT * 0.8, ow, 0.5)


def walls(g, xs, ys, floor, wall_h, front, back, side, side2=None):
    """
    바깥 벽을 칸마다 짠다. front/back 은 앞뒤 칸 수만큼, side 는 옆 칸 수만큼
    ("window" | "lattice" | "open" | "solid" | "none") 을 적는다.
    side2 를 주면 +x 쪽 옆벽은 그것을 쓴다. 없으면 양옆이 같다
    """
    for i in range(len(xs) - 1):
        cx, span = (xs[i] + xs[i + 1]) / 2, xs[i + 1] - xs[i]
        for y, plan in ((ys[0], front), (ys[-1], back)):
            kind = plan[i]
            if kind == "open":
                opening(g, cx, y, span, True, floor, wall_h, 1.2, wall_h - 5.0, span * 0.72, "open")
            elif kind == "lattice":
                opening(g, cx, y, span, True, floor, wall_h, 2.4, wall_h - 6.0, span * 0.62, "lattice")
            else:
                opening(g, cx, y, span, True, floor, wall_h, wall_h * 0.42, wall_h * 0.3, span * 0.46, kind)
    for j in range(len(ys) - 1):
        cy, span = (ys[j] + ys[j + 1]) / 2, ys[j + 1] - ys[j]
        for x, plan in ((xs[0], side), (xs[-1], side2 or side)):
            kind = plan[j]
            if kind == "open":
                opening(g, x, cy, span, False, floor, wall_h, 1.2, wall_h - 5.0, span * 0.72, "open")
            else:
                opening(g, x, cy, span, False, floor, wall_h, wall_h * 0.42, wall_h * 0.3, span * 0.46, kind)


def railing(g, x0, y0, x1, y1, z, h=4.0, post_gap=5.0):
    """난간. 기둥을 세우고 위아래 가로대를 건다"""
    dx, dy = x1 - x0, y1 - y0
    length = (dx * dx + dy * dy) ** 0.5
    n = max(2, int(length / post_gap) + 1)
    for k in range(n):
        t = k / (n - 1)
        g["Lattice"].box(x0 + dx * t, y0 + dy * t, z + h / 2, 0.9, 0.9, h)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if abs(dx) >= abs(dy):
        g["Lattice"].box(cx, cy, z + h - 0.3, length + 0.9, 0.7, 0.6)
        g["Lattice"].box(cx, cy, z + h * 0.45, length + 0.9, 0.5, 0.5)
    else:
        g["Lattice"].box(cx, cy, z + h - 0.3, 0.7, length + 0.9, 0.6)
        g["Lattice"].box(cx, cy, z + h * 0.45, 0.5, length + 0.9, 0.5)


# ---------------------------------------------------------------- 내놓기

def render(out_dir, name, loc, look, res=(1100, 750)):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    if scene.world is None:
        scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.42, 0.55, 0.66)
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 42
    scene.camera = cam
    scene.render.filepath = os.path.join(out_dir, "preview_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def export_model(name, groups, scale, renders=(), min_objs=5, tri_limit=10000, palette=None):
    """
    그룹을 오브젝트로 만들고, 배율을 한 번 곱해 FBX 로 내보내고, 미리보기를 찍는다.
    renders 는 (이름, 카메라위치, 바라볼곳) 을 **배율 곱하기 전 치수**로 적는다.
    """
    objs, report = [], []
    for k in (palette or PALETTE):
        ob = groups[k].finish()
        if len(ob.data.polygons) == 0:
            bpy.data.objects.remove(ob, do_unlink=True)
            continue
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        report.append((ob.name, tris))
        objs.append(ob)

    out_dir = os.path.join(HERE, name)
    os.makedirs(out_dir, exist_ok=True)
    fbx = os.path.join(out_dir, name + ".fbx")

    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if scale != 1.0:
        for ob in objs:
            ob.scale = (scale, scale, scale)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=True, global_scale=1.0, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y",
        object_types={"MESH"}, mesh_smooth_type="FACE", use_mesh_modifiers=True,
        bake_space_transform=False,
    )

    for rn, loc, look in renders:
        render(out_dir, rn, tuple(v * scale for v in loc), tuple(v * scale for v in look))

    # 크기 재기. 배율을 곱한 뒤의 실제 치수다
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            mn = Vector((min(mn.x, p.x), min(mn.y, p.y), min(mn.z, p.z)))
            mx = Vector((max(mx.x, p.x), max(mx.y, p.y), max(mx.z, p.z)))
    size = mx - mn

    print("=== %s ===" % name)
    total = 0
    for nm, t in report:
        print("  %-22s %6d tri" % (nm, t))
        total += t
        assert t <= tri_limit, "%s 가 삼각형 %d 을 넘는다 (%d)" % (nm, tri_limit, t)
    print("  합계 %d tri / 오브젝트 %d / 크기 %.1f x %.1f x %.1f (가로 x 깊이 x 높이)"
          % (total, len(objs), size.x, size.y, size.z))
    print("FBX: " + fbx)
    assert len(objs) >= min_objs, "오브젝트가 %d 개뿐이다. 재질별로 갈라지지 않았다" % len(objs)
    assert mn.z > -0.01, "모델 바닥이 원점보다 %.2f 아래에 있다. 땅에 묻힌다" % mn.z
    return fbx, total, len(objs), size
