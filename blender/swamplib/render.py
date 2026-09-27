"""미리보기 렌더 (Cycles, 헤드리스)."""

import math

import bpy
from mathutils import Vector

from . import config
from .materials import water_material, make_preview_material


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.unit_settings.system = "METRIC"
    scn.unit_settings.scale_length = 1.0
    return scn


def setup_world(strength=1.0, sun_elev=28.0, sun_azim=215.0, sun_strength=3.2, warm=(1.0, 0.92, 0.80), haze=(0.62, 0.70, 0.72)):
    scn = bpy.context.scene
    world = bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes.get("Background")
    try:
        sky = nt.nodes.new("ShaderNodeTexSky")
        sky.sky_type = "MULTIPLE_SCATTERING"
        sky.sun_disc = False
        sky.sun_elevation = math.radians(sun_elev)
        sky.sun_rotation = math.radians(sun_azim)
        sky.air_density = 1.2 if hasattr(sky, "air_density") else 1.0
        if hasattr(sky, "aerosol_density"):
            sky.aerosol_density = 2.5
        nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.22 * strength
    except Exception:
        bg.inputs["Color"].default_value = (*haze, 1.0)
        bg.inputs["Strength"].default_value = 0.8 * strength
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = sun_strength
    sun.angle = math.radians(2.5)
    sun.color = warm
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(90 - sun_elev), 0, math.radians(sun_azim))
    scn.collection.objects.link(so)
    return so


def ground(env="water", size=400.0, water_rgb=(34, 52, 40)):
    scn = bpy.context.scene
    objs = []
    if env in ("water", "sea"):
        bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
        w = bpy.context.active_object
        w.name = "Water"
        rgb = water_rgb if env == "water" else (26, 70, 92)
        w.data.materials.append(water_material("M_Water_" + env, rgb, 0.0))
        objs.append(w)
        # 물 아래 진흙 바닥
        bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, -6 if env == "water" else -30))
        m = bpy.context.active_object
        m.data.materials.append(make_preview_material("mud"))
        objs.append(m)
    else:
        bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
        g = bpy.context.active_object
        g.data.materials.append(make_preview_material("mud" if env == "mud" else "moss"))
        objs.append(g)
    return objs


def frame_camera(bmin, bmax, azim=35.0, elev=18.0, lens=40.0, pad=1.12, target_bias=(0, 0, -0.12)):
    scn = bpy.context.scene
    bmin, bmax = Vector(bmin), Vector(bmax)
    center = (bmin + bmax) / 2
    ext = bmax - bmin
    center += Vector((ext.x * target_bias[0], ext.y * target_bias[1], ext.z * target_bias[2]))
    radius = ext.length / 2
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam_data.sensor_width = 36
    cam_data.clip_end = 20000
    cam = bpy.data.objects.new("Cam", cam_data)
    scn.collection.objects.link(cam)
    fov = 2 * math.atan(18 / lens) * (config.PREVIEW_RES[1] / config.PREVIEW_RES[0])
    dist = radius * pad / math.sin(fov / 2)
    a, e = math.radians(azim), math.radians(elev)
    direction = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = center + direction * dist
    look = center - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    return cam


def render(path, samples=None, res=None, exposure=0.0):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples or config.PREVIEW_SAMPLES
    scn.cycles.use_denoising = True
    try:
        scn.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    scn.cycles.max_bounces = 6
    scn.cycles.transparent_max_bounces = 8
    r = res or config.PREVIEW_RES
    scn.render.resolution_x, scn.render.resolution_y = r
    scn.render.resolution_percentage = 100
    scn.view_settings.view_transform = "AgX"
    scn.view_settings.exposure = exposure
    # 확장자로 포맷 결정: .jpg 는 저장소 용량을 아끼기 위한 기본값, .png 는 무손실이 필요할 때
    if str(path).lower().endswith((".jpg", ".jpeg")):
        scn.render.image_settings.file_format = "JPEG"
        scn.render.image_settings.color_mode = "RGB"
        scn.render.image_settings.quality = 90
    else:
        scn.render.image_settings.file_format = "PNG"
    scn.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
