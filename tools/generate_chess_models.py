"""
Chess 3D — Blender Python скрипт генерации High-Poly моделей воинов.
Запуск: blender --background --python generate_chess_models.py

Генерирует 12 моделей шахматных фигур и экспортирует в .dae (Collada):
  Армия Света: king_white, queen_white, bishop_white, knight_white, rook_white, pawn_white
  Армия Тьмы:  king_black, queen_black, bishop_black, knight_black, rook_black, pawn_black

Автор: AI Chess3D Generator
(c) 2026
"""

import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

# ═══════════════════════════════════════════════════════════════
# Конфигурация
# ═══════════════════════════════════════════════════════════════

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models_output")
SUBDIVISION_LEVEL = 2  # Уровень сглаживания (2 = хороший баланс качества/производительности)

# ═══════════════════════════════════════════════════════════════
# Утилиты
# ═══════════════════════════════════════════════════════════════

def clear_scene():
    """Полная очистка сцены Blender"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    # Очистка осиротевших данных
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)

def set_smooth(obj):
    """Применение smooth shading"""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)

def add_subdivision(obj, levels=SUBDIVISION_LEVEL):
    """Добавление Subdivision Surface модификатора"""
    mod = obj.modifiers.new(name="Subdivision", type='SUBSURF')
    mod.levels = levels
    mod.render_levels = levels

def join_objects(objects):
    """Объединение нескольких объектов в один"""
    if not objects:
        return None
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    return result

def apply_all_modifiers(obj):
    """Применение всех модификаторов"""
    bpy.context.view_layer.objects.active = obj
    for mod in obj.modifiers:
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            pass

def create_cylinder(radius, depth, location, segments=32):
    """Создание цилиндра и возврат объекта"""
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, vertices=segments)
    obj = bpy.context.active_object
    return obj

def create_cone(r1, r2, depth, location, segments=32):
    """Создание конуса (усечённого)"""
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=location, vertices=segments)
    return bpy.context.active_object

def create_sphere(radius, location, segments=32, rings=16):
    """Создание UV-сферы"""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=segments, ring_count=rings)
    return bpy.context.active_object

def create_cube(size, location, scale=(1, 1, 1)):
    """Создание куба"""
    bpy.ops.mesh.primitive_cube_add(size=size, location=location, scale=scale)
    return bpy.context.active_object

def create_torus(major_r, minor_r, location):
    """Создание тора"""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_r, minor_radius=minor_r,
        location=location, major_segments=48, minor_segments=16
    )
    return bpy.context.active_object

def create_icosphere(radius, location, subdivisions=3):
    """Создание ICO-сферы"""
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, location=location, subdivisions=subdivisions)
    return bpy.context.active_object


# ═══════════════════════════════════════════════════════════════
# PBR Материалы
# ═══════════════════════════════════════════════════════════════

def create_white_stone_material():
    """Полированный светлый мрамор с золотой инкрустацией"""
    mat = bpy.data.materials.new(name="WhiteMarble")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Principled BSDF
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    bsdf.inputs['Base Color'].default_value = (0.85, 0.80, 0.72, 1.0)  # Тёплый ivory
    bsdf.inputs['Roughness'].default_value = 0.25
    bsdf.inputs['Metallic'].default_value = 0.0
    bsdf.inputs['Specular IOR Level'].default_value = 0.5

    # Output
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_white_armor_material():
    """Бронзово-золотая полированная броня"""
    mat = bpy.data.materials.new(name="GoldBronzeArmor")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (0.78, 0.58, 0.28, 1.0)  # Бронза/Золото
    bsdf.inputs['Roughness'].default_value = 0.18
    bsdf.inputs['Metallic'].default_value = 0.92

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_white_glow_material():
    """Золотое свечение (глаза, самоцветы, пламя)"""
    mat = bpy.data.materials.new(name="GoldGlow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (1.0, 0.80, 0.30, 1.0)
    bsdf.inputs['Emission Color'].default_value = (1.0, 0.65, 0.10, 1.0)
    bsdf.inputs['Emission Strength'].default_value = 5.0
    bsdf.inputs['Roughness'].default_value = 0.1

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_black_stone_material():
    """Грубый обсидиан с красными трещинами"""
    mat = bpy.data.materials.new(name="Obsidian")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.location = (0, 0)
    bsdf.inputs['Base Color'].default_value = (0.08, 0.05, 0.05, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.42
    bsdf.inputs['Metallic'].default_value = 0.05

    # Voronoi текстура для трещин
    voronoi = nodes.new('ShaderNodeTexVoronoi')
    voronoi.location = (-600, 0)
    voronoi.inputs['Scale'].default_value = 8.0
    voronoi.distance = 'MANHATTAN'

    # ColorRamp для маски трещин
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.location = (-300, 0)
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.08, 0.05, 0.05, 1.0)
    ramp.color_ramp.elements[1].position = 0.15
    ramp.color_ramp.elements[1].color = (0.08, 0.05, 0.05, 1.0)
    elem = ramp.color_ramp.elements.new(0.05)
    elem.color = (1.0, 0.15, 0.0, 1.0)  # Раскалённые трещины

    links.new(voronoi.outputs['Distance'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])

    # Emission от трещин
    ramp_em = nodes.new('ShaderNodeValToRGB')
    ramp_em.location = (-300, -200)
    ramp_em.color_ramp.elements[0].position = 0.0
    ramp_em.color_ramp.elements[0].color = (0, 0, 0, 1.0)
    ramp_em.color_ramp.elements[1].position = 0.15
    ramp_em.color_ramp.elements[1].color = (0, 0, 0, 1.0)
    elem_em = ramp_em.color_ramp.elements.new(0.05)
    elem_em.color = (1.0, 0.1, 0.0, 1.0)

    links.new(voronoi.outputs['Distance'], ramp_em.inputs['Fac'])
    links.new(ramp_em.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = 3.0

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_black_armor_material():
    """Тёмная кованая броня"""
    mat = bpy.data.materials.new(name="DarkArmor")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (0.12, 0.08, 0.08, 1.0)
    bsdf.inputs['Roughness'].default_value = 0.30
    bsdf.inputs['Metallic'].default_value = 0.80

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_black_glow_material():
    """Алое магматическое свечение"""
    mat = bpy.data.materials.new(name="MagmaGlow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (1.0, 0.08, 0.0, 1.0)
    bsdf.inputs['Emission Color'].default_value = (1.0, 0.05, 0.0, 1.0)
    bsdf.inputs['Emission Strength'].default_value = 8.0
    bsdf.inputs['Roughness'].default_value = 0.05

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat

def create_weapon_material(is_white):
    """Материал оружия"""
    mat = bpy.data.materials.new(name=f"Weapon_{'Light' if is_white else 'Dark'}")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    if is_white:
        bsdf.inputs['Base Color'].default_value = (0.72, 0.62, 0.50, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.6
        bsdf.inputs['Roughness'].default_value = 0.25
    else:
        bsdf.inputs['Base Color'].default_value = (0.10, 0.08, 0.08, 1.0)
        bsdf.inputs['Metallic'].default_value = 0.85
        bsdf.inputs['Roughness'].default_value = 0.22

    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (300, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    return mat


# ═══════════════════════════════════════════════════════════════
# Построители фигур — Армия Света (Белые)
# ═══════════════════════════════════════════════════════════════

def build_pedestal(is_white):
    """Круглый пьедестал с декоративным кольцом"""
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()

    parts = []

    # Основание
    base = create_cylinder(0.42, 0.08, (0, 0, 0.04))
    base.data.materials.append(stone)
    set_smooth(base)
    parts.append(base)

    # Верхнее кольцо
    ring = create_torus(0.40, 0.02, (0, 0, 0.10))
    ring.data.materials.append(armor)
    set_smooth(ring)
    parts.append(ring)

    # Нижнее кольцо
    ring2 = create_torus(0.42, 0.015, (0, 0, 0.0))
    ring2.data.materials.append(armor)
    set_smooth(ring2)
    parts.append(ring2)

    return parts


def build_pawn(is_white):
    """Пешка: Пехотинец со щитом и копьём / Одержимый воин с топором"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Ноги
    for dx in [-0.08, 0.08]:
        leg = create_cylinder(0.055, 0.22, (dx, 0, 0.22))
        leg.data.materials.append(stone)
        set_smooth(leg)
        # Наколенники
        knee = create_sphere(0.06, (dx, 0.04, 0.22))
        knee.data.materials.append(armor)
        set_smooth(knee)
        parts.extend([leg, knee])

    # Юбка кольчуги
    skirt = create_cone(0.22, 0.14, 0.16, (0, 0, 0.36))
    skirt.data.materials.append(armor)
    set_smooth(skirt)
    parts.append(skirt)

    # Торс
    torso = create_cylinder(0.14, 0.26, (0, 0, 0.55))
    torso.data.materials.append(stone)
    set_smooth(torso)
    parts.append(torso)

    # Нагрудная пластина
    chest = create_cube(0.24, (0, 0.08, 0.56), scale=(1.0, 0.3, 0.8))
    chest.data.materials.append(armor)
    set_smooth(chest)
    parts.append(chest)

    # Наплечники
    for dx in [-0.18, 0.18]:
        sh = create_sphere(0.07, (dx, 0, 0.64))
        sh.data.materials.append(armor)
        set_smooth(sh)
        parts.append(sh)

    # Руки
    for dx in [-0.20, 0.20]:
        arm = create_cylinder(0.04, 0.22, (dx, 0, 0.50))
        arm.rotation_euler = (0, 0.15 if dx > 0 else -0.15, 0)
        arm.data.materials.append(stone)
        set_smooth(arm)
        # Кисть
        hand = create_sphere(0.035, (dx * 1.1, 0, 0.38))
        hand.data.materials.append(stone)
        set_smooth(hand)
        parts.extend([arm, hand])

    # Голова
    head = create_sphere(0.10, (0, 0.02, 0.74))
    head.data.materials.append(stone)
    set_smooth(head)
    parts.append(head)

    # Шлем
    helmet = create_cylinder(0.11, 0.07, (0, 0, 0.81))
    helmet.data.materials.append(armor)
    set_smooth(helmet)
    parts.append(helmet)

    # Забрало шлема
    visor = create_cube(0.12, (0, 0.10, 0.76), scale=(1, 0.3, 0.6))
    visor.data.materials.append(armor)
    set_smooth(visor)
    parts.append(visor)

    if is_white:
        # Белый: Круглый щит + копьё
        shield = create_cylinder(0.16, 0.03, (-0.28, 0.06, 0.50))
        shield.rotation_euler = (0, math.pi / 2.2, 0)
        shield.data.materials.append(armor)
        set_smooth(shield)
        # Умбон щита
        umbo = create_sphere(0.04, (-0.28, 0.10, 0.50))
        umbo.data.materials.append(glow)
        set_smooth(umbo)
        # Копьё
        shaft = create_cylinder(0.018, 0.95, (0.24, 0, 0.60))
        shaft.rotation_euler = (0.06, 0, -0.08)
        shaft.data.materials.append(weapon_mat)
        # Наконечник
        tip = create_cone(0.04, 0, 0.12, (0.24, 0, 1.10))
        tip.data.materials.append(armor)
        set_smooth(tip)
        parts.extend([shield, umbo, shaft, tip])
    else:
        # Чёрный: Грубый топор
        axe_handle = create_cylinder(0.02, 0.65, (0.22, 0, 0.55))
        axe_handle.rotation_euler = (0.05, 0, -0.12)
        axe_handle.data.materials.append(weapon_mat)
        # Лезвие топора
        axe_blade = create_cube(0.20, (0.22, 0.05, 0.88), scale=(0.8, 0.15, 1.2))
        axe_blade.data.materials.append(weapon_mat)
        set_smooth(axe_blade)
        # Глаза свечение
        for dx in [-0.03, 0.03]:
            eye = create_sphere(0.015, (dx, 0.10, 0.76))
            eye.data.materials.append(glow)
            parts.append(eye)
        parts.extend([axe_handle, axe_blade])

    # Объединение и subdivision
    result = join_objects(parts)
    result.name = f"pawn_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


def build_rook(is_white):
    """Ладья-Голем: Белый — щит+молот, Чёрный — шипастые цепы"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Массивные ноги Голема
    for dx in [-0.12, 0.12]:
        leg = create_cube(0.14, (dx, 0, 0.22), scale=(1, 0.8, 1.6))
        leg.data.materials.append(stone)
        set_smooth(leg)
        parts.append(leg)

    # Огромный торс
    torso = create_cube(0.50, (0, 0, 0.58), scale=(1, 0.7, 0.85))
    torso.data.materials.append(stone)
    set_smooth(torso)
    parts.append(torso)

    # Нагрудная плита
    chest_plate = create_cube(0.36, (0, 0.14, 0.58), scale=(1, 0.1, 0.7))
    chest_plate.data.materials.append(armor)
    set_smooth(chest_plate)
    parts.append(chest_plate)

    # Мощные наплечники
    for dx in [-0.32, 0.32]:
        sh = create_cube(0.20, (dx, 0, 0.74), scale=(1, 0.9, 0.9))
        sh.data.materials.append(armor)
        set_smooth(sh)
        # Шип на наплечнике
        spike = create_cone(0.04, 0, 0.08, (dx, 0, 0.86))
        spike.data.materials.append(armor)
        parts.extend([sh, spike])

    # Руки (толстые, каменные)
    for dx in [-0.36, 0.36]:
        upper_arm = create_cylinder(0.08, 0.22, (dx, 0, 0.60))
        upper_arm.rotation_euler = (0, 0, 0.2 if dx > 0 else -0.2)
        upper_arm.data.materials.append(stone)
        set_smooth(upper_arm)
        forearm = create_cylinder(0.07, 0.20, (dx * 1.15, 0, 0.42))
        forearm.data.materials.append(stone)
        set_smooth(forearm)
        parts.extend([upper_arm, forearm])

    # Голова-монолит
    head = create_cube(0.22, (0, 0.02, 0.90), scale=(1, 0.9, 0.9))
    head.data.materials.append(armor)
    set_smooth(head)
    parts.append(head)

    # Светящиеся глаза
    eye_bar = create_cube(0.14, (0, 0.12, 0.90), scale=(1, 0.15, 0.2))
    eye_bar.data.materials.append(glow)
    parts.append(eye_bar)

    if is_white:
        # Щит-башня с гербом крепости (в правой руке)
        shield = create_cube(0.30, (0.42, 0.14, 0.52), scale=(0.9, 0.15, 1.8))
        shield.data.materials.append(armor)
        set_smooth(shield)
        # Герб на щите (стилизованная крепость)
        emblem1 = create_cube(0.08, (0.42, 0.22, 0.52), scale=(0.8, 0.1, 1.5))
        emblem1.data.materials.append(glow)
        emblem2 = create_cube(0.12, (0.42, 0.22, 0.62), scale=(1.2, 0.1, 0.4))
        emblem2.data.materials.append(glow)
        # Боевой молот (в левой руке)
        handle = create_cylinder(0.03, 0.70, (-0.40, 0, 0.50))
        handle.rotation_euler = (0.08, 0, -0.1)
        handle.data.materials.append(weapon_mat)
        hammer = create_cube(0.18, (-0.40, 0, 0.88), scale=(1, 0.7, 1.3))
        hammer.data.materials.append(armor)
        set_smooth(hammer)
        parts.extend([shield, emblem1, emblem2, handle, hammer])
    else:
        # Шипастые цепы вместо рук
        for dx in [-0.42, 0.42]:
            # Цепь (цилиндры)
            chain = create_cylinder(0.02, 0.35, (dx, 0.08, 0.35))
            chain.rotation_euler = (-0.3, 0, 0.2 if dx > 0 else -0.2)
            chain.data.materials.append(weapon_mat)
            # Шипастый шар
            ball = create_icosphere(0.10, (dx * 1.1, 0.12, 0.14))
            ball.data.materials.append(armor)
            set_smooth(ball)
            # Шипы на шаре
            for i in range(8):
                angle = i * math.pi * 2 / 8
                sx = dx * 1.1 + 0.08 * math.cos(angle)
                sy = 0.12 + 0.08 * math.sin(angle)
                sz = 0.14 + 0.06 * math.cos(angle + 1)
                spike = create_cone(0.025, 0, 0.06, (sx, sy, sz))
                spike.data.materials.append(weapon_mat)
                parts.append(spike)
            parts.extend([chain, ball])

    result = join_objects(parts)
    result.name = f"rook_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


def build_knight(is_white):
    """Конь: Белый — паладин с копьём, Чёрный — демонический всадник с секирой"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Ноги лошади (4 штуки)
    leg_positions = [(-0.14, -0.10), (0.14, -0.10), (-0.14, 0.10), (0.14, 0.10)]
    for (lx, ly) in leg_positions:
        leg = create_cylinder(0.035, 0.20, (lx, ly, 0.20))
        leg.data.materials.append(stone)
        set_smooth(leg)
        # Копыто
        hoof = create_cylinder(0.04, 0.03, (lx, ly, 0.10))
        hoof.data.materials.append(armor)
        parts.extend([leg, hoof])

    # Тело лошади (горизонтальная капсула)
    body = create_cylinder(0.14, 0.40, (0, 0, 0.36))
    body.rotation_euler = (0, math.pi / 2, 0)
    body.data.materials.append(stone)
    set_smooth(body)
    parts.append(body)

    # Боковая броня лошади
    for dy in [-0.14, 0.14]:
        plate = create_cube(0.34, (0, dy, 0.36), scale=(1, 0.1, 0.6))
        plate.data.materials.append(armor)
        set_smooth(plate)
        parts.append(plate)

    # Шея
    neck = create_cylinder(0.08, 0.26, (0.16, 0, 0.56))
    neck.rotation_euler = (0, 0.6, 0)
    neck.data.materials.append(stone)
    set_smooth(neck)
    parts.append(neck)

    # Голова коня
    horse_head = create_cone(0.05, 0.09, 0.22, (0.24, 0, 0.72))
    horse_head.rotation_euler = (-math.pi / 3, 0, 0.15)
    horse_head.data.materials.append(stone)
    set_smooth(horse_head)
    parts.append(horse_head)

    # Уши
    for dz in [-0.04, 0.04]:
        ear = create_cone(0, 0.02, 0.06, (0.20, dz, 0.80))
        ear.data.materials.append(stone)
        parts.append(ear)

    # Глаза коня
    for dz in [-0.06, 0.06]:
        eye = create_sphere(0.015, (0.26, dz, 0.72))
        eye.data.materials.append(glow)
        parts.append(eye)

    # Хвост
    tail = create_cylinder(0.02, 0.20, (-0.24, 0, 0.30))
    tail.rotation_euler = (0, -0.8, 0)
    tail.data.materials.append(stone)
    parts.append(tail)

    # ──────── Всадник ────────
    # Торс всадника
    rider = create_cylinder(0.09, 0.22, (0, 0, 0.62))
    rider.data.materials.append(armor)
    set_smooth(rider)
    parts.append(rider)

    # Голова всадника
    r_head = create_sphere(0.07, (0, 0.02, 0.80))
    r_head.data.materials.append(stone)
    set_smooth(r_head)
    parts.append(r_head)

    # Шлем
    r_helm = create_cylinder(0.08, 0.05, (0, 0, 0.86))
    r_helm.data.materials.append(armor)
    set_smooth(r_helm)
    parts.append(r_helm)

    # Наплечники всадника
    for dz in [-0.12, 0.12]:
        sh = create_sphere(0.05, (0, dz, 0.70))
        sh.data.materials.append(armor)
        set_smooth(sh)
        parts.append(sh)

    if is_white:
        # Копьё
        lance = create_cylinder(0.018, 1.10, (0.06, -0.16, 0.72))
        lance.rotation_euler = (-0.15, 0.35, 0)
        lance.data.materials.append(weapon_mat)
        tip = create_cone(0.04, 0, 0.14, (0.30, -0.30, 1.10))
        tip.data.materials.append(armor)
        set_smooth(tip)
        parts.extend([lance, tip])
    else:
        # Секира
        axe_h = create_cylinder(0.022, 0.70, (0, -0.14, 0.72))
        axe_h.rotation_euler = (-0.3, 0, -0.15)
        axe_h.data.materials.append(weapon_mat)
        axe_b = create_cube(0.18, (0, -0.24, 1.02), scale=(0.6, 0.15, 1.4))
        axe_b.data.materials.append(weapon_mat)
        set_smooth(axe_b)
        # Рога на шлеме демона
        for dz in [-0.06, 0.06]:
            horn = create_cone(0, 0.02, 0.12, (0, dz, 0.94))
            horn.rotation_euler = (0, dz * 5, 0)
            horn.data.materials.append(armor)
            parts.append(horn)
        parts.extend([axe_h, axe_b])

    result = join_objects(parts)
    result.name = f"knight_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


def build_bishop(is_white):
    """Слон: Белый — маг-клерик с факелом, Чёрный — некромант"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Длинная мантия
    robe = create_cone(0.28, 0.10, 0.65, (0, 0, 0.44))
    robe.data.materials.append(stone)
    set_smooth(robe)
    parts.append(robe)

    # Пояс
    belt = create_torus(0.16, 0.02, (0, 0, 0.40))
    belt.data.materials.append(armor)
    set_smooth(belt)
    parts.append(belt)

    # Руки (выступают из мантии)
    for dx in [-0.18, 0.18]:
        arm = create_cylinder(0.04, 0.25, (dx, 0.04, 0.58))
        arm.rotation_euler = (0.2, 0, 0.3 if dx > 0 else -0.3)
        arm.data.materials.append(stone)
        set_smooth(arm)
        parts.append(arm)

    # Наплечники
    for dx in [-0.16, 0.16]:
        sh = create_sphere(0.06, (dx, 0, 0.72))
        sh.data.materials.append(armor)
        set_smooth(sh)
        parts.append(sh)

    # Капюшон/голова
    hood = create_sphere(0.11, (0, 0.02, 0.86))
    hood.data.materials.append(armor)
    set_smooth(hood)
    parts.append(hood)

    # Лицо (спереди под капюшоном)
    face = create_sphere(0.07, (0, 0.08, 0.84))
    face.data.materials.append(stone)
    set_smooth(face)
    parts.append(face)

    # Глаза
    for dx in [-0.025, 0.025]:
        eye = create_sphere(0.012, (dx, 0.14, 0.85))
        eye.data.materials.append(glow)
        parts.append(eye)

    # Посох
    staff = create_cylinder(0.02, 1.15, (-0.26, 0.06, 0.68))
    staff.rotation_euler = (0.04, 0, -0.06)
    staff.data.materials.append(weapon_mat)
    parts.append(staff)

    if is_white:
        # Золотое пламя на посохе
        flame = create_icosphere(0.08, (-0.26, 0.06, 1.28))
        flame.data.materials.append(glow)
        set_smooth(flame)
        # Дополнительные языки пламени
        for i in range(3):
            flick = create_cone(0, 0.03, 0.10, (-0.26 + 0.04 * math.cos(i * 2.1), 0.06, 1.34))
            flick.data.materials.append(glow)
            parts.append(flick)
        parts.append(flame)
    else:
        # Красный череп на посохе
        skull = create_sphere(0.07, (-0.26, 0.06, 1.28))
        skull.data.materials.append(glow)
        set_smooth(skull)
        # Глазницы черепа
        for dx in [-0.025, 0.025]:
            socket = create_sphere(0.02, (-0.26 + dx, 0.12, 1.30))
            socket.data.materials.append(create_black_armor_material())
            parts.append(socket)
        parts.append(skull)

    result = join_objects(parts)
    result.name = f"bishop_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


def build_queen(is_white):
    """Королева: Белая — воительница-чародейка, Чёрная — тёмная императрица"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Длинное платье/доспех
    gown = create_cone(0.30, 0.12, 0.78, (0, 0, 0.50))
    gown.data.materials.append(stone)
    set_smooth(gown)
    parts.append(gown)

    # Корсет / броня
    corset = create_cylinder(0.13, 0.22, (0, 0, 0.72))
    corset.data.materials.append(armor)
    set_smooth(corset)
    parts.append(corset)

    # Наплечники
    for dx in [-0.17, 0.17]:
        sh = create_sphere(0.06, (dx, 0, 0.82))
        sh.data.materials.append(armor)
        set_smooth(sh)
        parts.append(sh)

    # Руки (изящные)
    for dx in [-0.20, 0.20]:
        arm = create_cylinder(0.032, 0.26, (dx, 0.02, 0.66))
        arm.rotation_euler = (0.12, 0, 0.3 if dx > 0 else -0.3)
        arm.data.materials.append(stone)
        set_smooth(arm)
        parts.append(arm)

    # Плащ (за спиной)
    cape = create_cube(0.34, (0, -0.10, 0.54), scale=(1, 0.06, 2.2))
    cape.data.materials.append(stone)
    set_smooth(cape)
    parts.append(cape)

    # Голова
    head = create_sphere(0.09, (0, 0.02, 0.96))
    head.data.materials.append(stone)
    set_smooth(head)
    parts.append(head)

    # Корона / тиара
    crown = create_cylinder(0.11, 0.07, (0, 0, 1.06))
    crown.data.materials.append(armor)
    set_smooth(crown)
    parts.append(crown)

    # Зубцы короны
    for i in range(6):
        angle = i * math.pi * 2 / 6
        prong = create_cone(0, 0.015, 0.06, (0.09 * math.cos(angle), 0.09 * math.sin(angle), 1.12))
        prong.data.materials.append(armor)
        parts.append(prong)

    # Самоцвет
    gem = create_sphere(0.035, (0, 0.08, 1.08))
    gem.data.materials.append(glow)
    parts.append(gem)

    if is_white:
        # Скипетр с кристаллом
        scepter = create_cylinder(0.018, 0.62, (0.24, 0.06, 0.64))
        scepter.rotation_euler = (0.08, 0, -0.18)
        scepter.data.materials.append(weapon_mat)
        orb = create_sphere(0.05, (0.28, 0.08, 0.98))
        orb.data.materials.append(glow)
        set_smooth(orb)
        parts.extend([scepter, orb])
    else:
        # Двойные клинки
        for dx in [-0.26, 0.26]:
            blade = create_cube(0.04, (dx, 0.06, 0.62), scale=(0.5, 0.08, 4.0))
            blade.data.materials.append(weapon_mat)
            set_smooth(blade)
            parts.append(blade)

    result = join_objects(parts)
    result.name = f"queen_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


def build_king(is_white):
    """Король: Белый — паладин с мечом, Чёрный — тёмный владыка с булавой"""
    clear_scene()
    stone = create_white_stone_material() if is_white else create_black_stone_material()
    armor = create_white_armor_material() if is_white else create_black_armor_material()
    glow = create_white_glow_material() if is_white else create_black_glow_material()
    weapon_mat = create_weapon_material(is_white)

    parts = build_pedestal(is_white)

    # Ноги (массивные, в латах)
    for dx in [-0.09, 0.09]:
        leg = create_cylinder(0.065, 0.24, (dx, 0, 0.22))
        leg.data.materials.append(stone)
        set_smooth(leg)
        # Наколенники
        knee = create_sphere(0.07, (dx, 0.04, 0.24))
        knee.data.materials.append(armor)
        set_smooth(knee)
        # Поножи
        greave = create_cylinder(0.07, 0.10, (dx, 0, 0.15))
        greave.data.materials.append(armor)
        set_smooth(greave)
        parts.extend([leg, knee, greave])

    # Юбка латного доспеха
    skirt = create_cone(0.24, 0.16, 0.18, (0, 0, 0.40))
    skirt.data.materials.append(armor)
    set_smooth(skirt)
    parts.append(skirt)

    # Массивный торс в полных латах
    torso = create_cube(0.38, (0, 0, 0.62), scale=(1, 0.7, 0.9))
    torso.data.materials.append(armor)
    set_smooth(torso)
    parts.append(torso)

    # Нагрудная эмблема
    emblem = create_cylinder(0.06, 0.015, (0, 0.14, 0.65))
    emblem.rotation_euler = (math.pi / 2, 0, 0)
    emblem.data.materials.append(glow)
    parts.append(emblem)

    # Наплечники (мощные)
    for dx in [-0.26, 0.26]:
        sh = create_cube(0.16, (dx, 0, 0.76), scale=(1, 0.85, 0.85))
        sh.data.materials.append(armor)
        set_smooth(sh)
        # Шип
        if not is_white:
            spike = create_cone(0, 0.02, 0.08, (dx, 0, 0.86))
            spike.data.materials.append(armor)
            parts.append(spike)
        parts.append(sh)

    # Руки
    for dx in [-0.28, 0.28]:
        arm = create_cylinder(0.05, 0.26, (dx, 0, 0.56))
        arm.rotation_euler = (0, 0, 0.18 if dx > 0 else -0.18)
        arm.data.materials.append(stone)
        set_smooth(arm)
        parts.append(arm)

    # Плащ
    cape = create_cube(0.36, (0, -0.12, 0.56), scale=(1, 0.06, 2.0))
    cape.data.materials.append(stone)
    set_smooth(cape)
    parts.append(cape)

    # Голова
    head = create_sphere(0.10, (0, 0.02, 0.88))
    head.data.materials.append(stone)
    set_smooth(head)
    parts.append(head)

    # Корона
    crown = create_cylinder(0.13, 0.10, (0, 0, 1.00))
    crown.data.materials.append(armor)
    set_smooth(crown)
    parts.append(crown)

    # Зубцы и крест
    for i in range(7):
        angle = i * math.pi * 2 / 7
        prong = create_cube(0.025, (0.11 * math.cos(angle), 0.11 * math.sin(angle), 1.08), scale=(1, 1, 2))
        prong.data.materials.append(armor)
        parts.append(prong)

    # Крест на вершине короны
    cross1 = create_cube(0.08, (0, 0, 1.14), scale=(1, 0.25, 0.25))
    cross1.data.materials.append(glow)
    cross2 = create_cube(0.08, (0, 0, 1.14), scale=(0.25, 0.25, 1))
    cross2.data.materials.append(glow)
    parts.extend([cross1, cross2])

    if is_white:
        # Великий двуручный меч
        blade = create_cube(0.06, (0.32, 0.06, 0.68), scale=(0.6, 0.08, 5.5))
        blade.data.materials.append(weapon_mat)
        set_smooth(blade)
        # Гарда
        guard = create_cube(0.16, (0.32, 0.06, 0.42), scale=(1, 0.3, 0.15))
        guard.data.materials.append(armor)
        # Навершие
        pommel = create_sphere(0.03, (0.32, 0.06, 0.36))
        pommel.data.materials.append(armor)
        parts.extend([blade, guard, pommel])
    else:
        # Шипастая булава/маца
        mace_h = create_cylinder(0.025, 0.72, (-0.30, 0.04, 0.60))
        mace_h.rotation_euler = (0.06, 0, -0.12)
        mace_h.data.materials.append(weapon_mat)
        mace_head = create_icosphere(0.09, (-0.32, 0.06, 0.98))
        mace_head.data.materials.append(weapon_mat)
        set_smooth(mace_head)
        # Шипы на булаве
        for i in range(10):
            a1 = i * math.pi * 2 / 10
            a2 = (i % 3) * 0.5
            sx = -0.32 + 0.08 * math.cos(a1)
            sy = 0.06 + 0.08 * math.sin(a1)
            sz = 0.98 + 0.06 * math.cos(a1 + a2)
            spike = create_cone(0, 0.018, 0.06, (sx, sy, sz))
            spike.data.materials.append(weapon_mat)
            parts.append(spike)
        parts.extend([mace_h, mace_head])

    result = join_objects(parts)
    result.name = f"king_{'white' if is_white else 'black'}"
    add_subdivision(result, levels=SUBDIVISION_LEVEL)
    return result


# ═══════════════════════════════════════════════════════════════
# Экспорт и главный цикл
# ═══════════════════════════════════════════════════════════════

def export_model(obj, filename):
    """Экспорт модели в .usdz и .obj — нативные форматы для SceneKit и iOS"""
    usdz_path = os.path.join(OUTPUT_DIR, f"{filename}.usdz")
    obj_path = os.path.join(OUTPUT_DIR, f"{filename}.obj")

    # Применяем модификаторы перед экспортом
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    apply_all_modifiers(obj)

    # 1. Экспорт в нативный формат Apple USDZ
    try:
        bpy.ops.wm.usd_export(
            filepath=usdz_path,
            selected_objects_only=True,
            export_materials=True,
            export_normals=True,
            export_uvmaps=True,
            triangulate_meshes=True
        )
        print(f"  ✅ Экспортировано USDZ: {usdz_path}")
    except Exception as e:
        print(f"  ⚠️ USDZ ошибка ({e}), пробуем OBJ...")

    # 2. Экспорт в универсальный Wavefront OBJ
    try:
        bpy.ops.wm.obj_export(
            filepath=obj_path,
            export_selected_objects=True,
            export_materials=True,
            export_normals=True,
            export_uv=True,
            apply_modifiers=True
        )
        print(f"  ✅ Экспортировано OBJ: {obj_path}")
    except Exception as e:
        print(f"  ⚠️ OBJ ошибка: {e}")

    return usdz_path


def main():
    """Главная функция — генерация и экспорт всех 12 моделей"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=" * 60)
    print("  ♚ Chess 3D — Генерация High-Poly моделей воинов")
    print("=" * 60)

    builders = {
        'pawn': build_pawn,
        'rook': build_rook,
        'knight': build_knight,
        'bishop': build_bishop,
        'queen': build_queen,
        'king': build_king,
    }

    total = len(builders) * 2
    current = 0

    for piece_name, builder_fn in builders.items():
        for is_white in [True, False]:
            current += 1
            color_name = 'white' if is_white else 'black'
            full_name = f"{piece_name}_{color_name}"
            army = "Армия Света" if is_white else "Армия Тьмы"

            print(f"\n[{current}/{total}] 🔨 Генерация: {full_name} ({army})")
            obj = builder_fn(is_white)
            export_model(obj, full_name)

    print("\n" + "=" * 60)
    print(f"  ✅ Все {total} моделей сгенерированы в: {OUTPUT_DIR}")
    print("=" * 60)


if __name__ == "__main__":
    main()

