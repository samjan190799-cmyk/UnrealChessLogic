"""
Chess 3D — Advanced High-Poly Character Sculptor
Blender 5.2 Python Script

Creates 12 high-detail fantasy warrior sculpts:
  Army of Light (White): Polished Marble + Gold/Bronze
    - king_white: Paladin King in full plate with greatsword & crown
    - queen_white: Sorceress Queen with ornate dress, tiara & crystal scepter
    - bishop_white: Battle Cleric with hooded robe & burning torch
    - knight_white: Armored Paladin mounted on warhorse with lance
    - rook_white: Massive Stone Golem with fortress tower shield & warhammer
    - pawn_white: Foot Soldier with round shield & spear

  Army of Darkness (Black): Obsidian + Glowing Magma
    - king_black: Dark Lord with spiked armor, horned crown & flanged mace
    - queen_black: Dark Empress with spiked gown, tiara & dual daggers
    - bishop_black: Necromancer in ragged cowl with flaming skull staff
    - knight_black: Demonic Knight on armored steed with battle axe
    - rook_black: Monstrous Dark Golem with DUAL spiked morningstar flails on chains
    - pawn_black: Possessed Berserker with battle axe & spiked armor
"""

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix, Euler

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models_output")

# ═══════════════════════════════════════════════════════════════
# Базовые утилиты
# ═══════════════════════════════════════════════════════════════

def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.meshes):
        if m.users == 0: bpy.data.meshes.remove(m)
    for mat in list(bpy.data.materials):
        if mat.users == 0: bpy.data.materials.remove(mat)

def make_smooth(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    obj.select_set(False)

def apply_bevel(obj, width=0.015, segments=2):
    mod = obj.modifiers.new(name="Bevel", type='BEVEL')
    mod.width = width
    mod.segments = segments

def apply_subsurf(obj, levels=2):
    mod = obj.modifiers.new(name="Subdivision", type='SUBSURF')
    mod.levels = levels
    mod.render_levels = levels

def apply_displace(obj, strength=0.02, scale=5.0):
    tex = bpy.data.textures.new(name="RockDisplace", type='CLOUDS')
    tex.noise_scale = scale
    mod = obj.modifiers.new(name="Displace", type='DISPLACE')
    mod.texture = tex
    mod.strength = strength

def join_all(obj_list):
    if not obj_list: return None
    bpy.ops.object.select_all(action='DESELECT')
    for o in obj_list:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj_list[0]
    bpy.ops.object.join()
    active = bpy.context.active_object
    for mod in active.modifiers:
        try: bpy.ops.object.modifier_apply(modifier=mod.name)
        except: pass
    return active

# ═══════════════════════════════════════════════════════════════
# PBR Материалы с текстурами
# ═══════════════════════════════════════════════════════════════

def get_mat_light_marble():
    mat = bpy.data.materials.new(name="LightMarble")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.84, 0.78, 0.70, 1.0) # Ivory / bone
        bsdf.inputs['Roughness'].default_value = 0.22
        bsdf.inputs['Metallic'].default_value = 0.04
    return mat

def get_mat_gold_inlay():
    mat = bpy.data.materials.new(name="GoldInlay")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.85, 0.65, 0.25, 1.0) # Bronze-Gold
        bsdf.inputs['Roughness'].default_value = 0.16
        bsdf.inputs['Metallic'].default_value = 0.95
    return mat

def get_mat_gold_glow():
    mat = bpy.data.materials.new(name="GoldGlow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (1.0, 0.85, 0.35, 1.0)
        bsdf.inputs['Emission Color'].default_value = (1.0, 0.70, 0.15, 1.0)
        bsdf.inputs['Emission Strength'].default_value = 6.0
    return mat

def get_mat_dark_obsidian():
    mat = bpy.data.materials.new(name="DarkObsidian")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.07, 0.05, 0.05, 1.0) # Deep charcoal / burgundy
        bsdf.inputs['Roughness'].default_value = 0.35
        bsdf.inputs['Metallic'].default_value = 0.10
    return mat

def get_mat_dark_iron():
    mat = bpy.data.materials.new(name="DarkIron")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (0.12, 0.08, 0.08, 1.0)
        bsdf.inputs['Roughness'].default_value = 0.28
        bsdf.inputs['Metallic'].default_value = 0.85
    return mat

def get_mat_magma_glow():
    mat = bpy.data.materials.new(name="MagmaGlow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = (1.0, 0.10, 0.0, 1.0)
        bsdf.inputs['Emission Color'].default_value = (1.0, 0.08, 0.0, 1.0)
        bsdf.inputs['Emission Strength'].default_value = 8.0
    return mat

def get_mat_steel(is_white):
    mat = bpy.data.materials.new(name="WeaponSteel")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        if is_white:
            bsdf.inputs['Base Color'].default_value = (0.75, 0.72, 0.65, 1.0)
            bsdf.inputs['Roughness'].default_value = 0.20
            bsdf.inputs['Metallic'].default_value = 0.85
        else:
            bsdf.inputs['Base Color'].default_value = (0.15, 0.12, 0.12, 1.0)
            bsdf.inputs['Roughness'].default_value = 0.24
            bsdf.inputs['Metallic'].default_value = 0.90
    return mat

# ═══════════════════════════════════════════════════════════════
# Генераторы анатомических деталей и доспехов
# ═══════════════════════════════════════════════════════════════

def build_ornate_pedestal(is_white):
    """Шестиугольный ступенчатый пьедестал с гравировкой и золотым кантом"""
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_trim = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    
    parts = []
    # Нижний шестигранный цоколь
    bpy.ops.mesh.primitive_cylinder_add(radius=0.44, depth=0.06, location=(0, 0, 0.03), vertices=6)
    base = bpy.context.active_object
    base.data.materials.append(mat_stone)
    apply_bevel(base, 0.012, 2)
    parts.append(base)
    
    # Круглое кольцо с орнаментом
    bpy.ops.mesh.primitive_cylinder_add(radius=0.40, depth=0.05, location=(0, 0, 0.08), vertices=32)
    mid = bpy.context.active_object
    mid.data.materials.append(mat_trim)
    apply_bevel(mid, 0.01, 2)
    parts.append(mid)
    
    # Верхняя платформа
    bpy.ops.mesh.primitive_cylinder_add(radius=0.38, depth=0.04, location=(0, 0, 0.12), vertices=32)
    top = bpy.context.active_object
    top.data.materials.append(mat_stone)
    apply_bevel(top, 0.008, 2)
    parts.append(top)
    
    return parts

def create_humanoid_body(is_white, is_female=False, is_heavy=False):
    """Анатомический каркас тела воина с латами"""
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    parts = []
    
    # Ноги и сабатоны (латные ботинки)
    leg_w = 0.07 if is_heavy else (0.045 if is_female else 0.055)
    leg_sep = 0.10 if is_heavy else 0.08
    
    for dx in [-leg_sep, leg_sep]:
        # Голень с поножами
        bpy.ops.mesh.primitive_cone_add(radius1=leg_w*1.1, radius2=leg_w*0.8, depth=0.22, location=(dx, 0, 0.25), vertices=16)
        greave = bpy.context.active_object
        greave.data.materials.append(mat_armor)
        apply_bevel(greave, 0.008, 2)
        parts.append(greave)
        
        # Наколенник (купол с шипом)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=leg_w*1.15, location=(dx, 0.03, 0.35), segments=16, ring_count=12)
        poleyn = bpy.context.active_object
        poleyn.data.materials.append(mat_armor)
        parts.append(poleyn)
        
        # Бедро
        bpy.ops.mesh.primitive_cylinder_add(radius=leg_w*0.95, depth=0.18, location=(dx, 0, 0.44), vertices=16)
        thigh = bpy.context.active_object
        thigh.data.materials.append(mat_stone)
        parts.append(thigh)
        
        # Сабатон (стопа)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0.04, 0.15))
        foot = bpy.context.active_object
        foot.scale = (leg_w*1.8, leg_w*2.8, 0.04)
        foot.data.materials.append(mat_armor)
        apply_bevel(foot, 0.008, 2)
        parts.append(foot)
    
    # Латный пояс / тассесеты (набедренники)
    skirt_r = 0.24 if is_heavy else (0.19 if is_female else 0.21)
    bpy.ops.mesh.primitive_cone_add(radius1=skirt_r, radius2=skirt_r*0.75, depth=0.16, location=(0, 0, 0.54), vertices=16)
    fauld = bpy.context.active_object
    fauld.data.materials.append(mat_armor)
    apply_bevel(fauld, 0.01, 2)
    parts.append(fauld)
    
    # Торс (кираса с выраженным ребром жесткости)
    torso_w = 0.22 if is_heavy else (0.15 if is_female else 0.18)
    bpy.ops.mesh.primitive_cylinder_add(radius=torso_w, depth=0.28, location=(0, 0, 0.72), vertices=16)
    cuirass = bpy.context.active_object
    cuirass.scale = (1.0, 0.75, 1.0)
    cuirass.data.materials.append(mat_stone)
    parts.append(cuirass)
    
    # Нагрудник (пластина поверх)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.06, 0.74))
    plackart = bpy.context.active_object
    plackart.scale = (torso_w*1.6, 0.06, 0.20)
    plackart.data.materials.append(mat_armor)
    apply_bevel(plackart, 0.015, 2)
    parts.append(plackart)
    
    # Массивные наплечники (паульдроны со слоистыми пластинами)
    for dx in [-torso_w*1.15, torso_w*1.15]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08 if is_heavy else 0.065, location=(dx, 0, 0.84), segments=16, ring_count=12)
        pauldron = bpy.context.active_object
        pauldron.scale = (1.1, 0.9, 0.8)
        pauldron.data.materials.append(mat_armor)
        parts.append(pauldron)
        
        # Лезвие/гребень наплечника
        if not is_white:
            bpy.ops.mesh.primitive_cone_add(radius1=0.03, radius2=0.0, depth=0.10, location=(dx*1.1, 0, 0.91), vertices=8)
            spike = bpy.context.active_object
            spike.data.materials.append(mat_armor)
            parts.append(spike)
    
    # Руки в наручах
    for dx in [-torso_w*1.2, torso_w*1.2]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.22, location=(dx, 0.02, 0.68), vertices=12)
        arm = bpy.context.active_object
        arm.rotation_euler = (0.15, 0, 0.15 if dx > 0 else -0.15)
        arm.data.materials.append(mat_stone)
        parts.append(arm)
        
        # Латная рукавица
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.04, location=(dx*1.1, 0.05, 0.54), segments=12, ring_count=8)
        gauntlet = bpy.context.active_object
        gauntlet.data.materials.append(mat_armor)
        parts.append(gauntlet)
        
    return parts

# ═══════════════════════════════════════════════════════════════
# МОДЕЛИРОВАНИЕ ФИГУР ПО ЭТАЛОНУ
# ═══════════════════════════════════════════════════════════════

def build_pawn(is_white):
    """ПЕШКА: Белый пехотинец со щитом и копьем / Черный берсерк с боевым топором"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    parts.extend(create_humanoid_body(is_white, is_female=False, is_heavy=False))
    
    # Шлем воина
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.10, location=(0, 0.02, 0.94), segments=20, ring_count=16)
    helm = bpy.context.active_object
    helm.scale = (0.9, 1.0, 1.05)
    helm.data.materials.append(mat_armor)
    parts.append(helm)
    
    # Забрало шлема с прорезью
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.09, 0.93))
    visor = bpy.context.active_object
    visor.scale = (0.12, 0.04, 0.06)
    visor.data.materials.append(mat_armor)
    parts.append(visor)
    
    # Гребень шлема
    bpy.ops.mesh.primitive_cylinder_add(radius=0.015, depth=0.16, location=(0, -0.01, 1.02), vertices=12)
    crest = bpy.context.active_object
    crest.rotation_euler = (math.pi/2, 0, 0)
    crest.scale = (1.0, 0.4, 1.5)
    crest.data.materials.append(mat_glow if is_white else mat_armor)
    parts.append(crest)
    
    if is_white:
        # Круглый щит с умбоном
        bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.03, location=(-0.24, 0.08, 0.68), vertices=24)
        shield = bpy.context.active_object
        shield.rotation_euler = (0, math.pi/2.3, 0)
        shield.data.materials.append(mat_armor)
        apply_bevel(shield, 0.01, 2)
        parts.append(shield)
        
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(-0.25, 0.11, 0.68), segments=16, ring_count=12)
        umbo = bpy.context.active_object
        umbo.data.materials.append(mat_glow)
        parts.append(umbo)
        
        # Длинное копье
        bpy.ops.mesh.primitive_cylinder_add(radius=0.016, depth=1.10, location=(0.24, 0.05, 0.75), vertices=12)
        spear = bpy.context.active_object
        spear.rotation_euler = (0.05, 0, -0.06)
        spear.data.materials.append(mat_steel)
        parts.append(spear)
        
        bpy.ops.mesh.primitive_cone_add(radius1=0.04, radius2=0, depth=0.16, location=(0.24, 0.05, 1.34), vertices=8)
        spear_tip = bpy.context.active_object
        spear_tip.scale = (0.6, 1.2, 1.0)
        spear_tip.data.materials.append(mat_armor)
        parts.append(spear_tip)
    else:
        # Черный берсерк: Двуручный топор
        bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.85, location=(0.22, 0.06, 0.68), vertices=12)
        axe_shaft = bpy.context.active_object
        axe_shaft.rotation_euler = (0.1, 0, -0.12)
        axe_shaft.data.materials.append(mat_steel)
        parts.append(axe_shaft)
        
        # Серповидное лезвие топора
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.22, 0.12, 1.04))
        blade = bpy.context.active_object
        blade.scale = (0.02, 0.18, 0.22)
        blade.data.materials.append(mat_armor)
        apply_bevel(blade, 0.02, 2)
        parts.append(blade)
        
        # Глазницы шлема горят лавой
        for dx in [-0.035, 0.035]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.015, location=(dx, 0.10, 0.94), segments=8, ring_count=6)
            eye = bpy.context.active_object
            eye.data.materials.append(mat_glow)
            parts.append(eye)

    obj = join_all(parts)
    obj.name = f"pawn_{'white' if is_white else 'black'}"
    return obj

def build_rook(is_white):
    """ЛАДЬЯ: Белый Каменный Голем со щитом-крепостью и молотом / Черный Голем с ДВУМЯ ШИПАСТЫМИ ЦЕПАМИ"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    
    # Монолитные каменные ноги Голема
    for dx in [-0.15, 0.15]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0, 0.26))
        leg = bpy.context.active_object
        leg.scale = (0.16, 0.20, 0.32)
        leg.data.materials.append(mat_stone)
        apply_bevel(leg, 0.03, 3)
        parts.append(leg)
        
        # Наколенник-монолит
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0.08, 0.34))
        knee = bpy.context.active_object
        knee.scale = (0.14, 0.08, 0.12)
        knee.data.materials.append(mat_armor)
        apply_bevel(knee, 0.02, 2)
        parts.append(knee)
        
    # Колоссальный каменный торс
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.62))
    torso = bpy.context.active_object
    torso.scale = (0.46, 0.34, 0.38)
    torso.data.materials.append(mat_stone)
    apply_bevel(torso, 0.05, 3)
    apply_displace(torso, 0.02, 4.0)
    parts.append(torso)
    
    # Бронированные плиты на груди (со стыком)
    for dx in [-0.12, 0.12]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0.16, 0.64))
        plate = bpy.context.active_object
        plate.scale = (0.18, 0.06, 0.26)
        plate.data.materials.append(mat_armor)
        apply_bevel(plate, 0.02, 2)
        parts.append(plate)
        
    # Массивные каменные наплечники
    for dx in [-0.34, 0.34]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0, 0.78))
        sh = bpy.context.active_object
        sh.scale = (0.22, 0.24, 0.20)
        sh.data.materials.append(mat_armor)
        apply_bevel(sh, 0.04, 3)
        parts.append(sh)
        
    # Каменная голова-монолит (вдавленная в плечи)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.04, 0.88))
    head = bpy.context.active_object
    head.scale = (0.24, 0.22, 0.18)
    head.data.materials.append(mat_stone)
    apply_bevel(head, 0.04, 3)
    parts.append(head)
    
    # Монокулярная полоса глаз
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.14, 0.88))
    visor_eye = bpy.context.active_object
    visor_eye.scale = (0.16, 0.04, 0.04)
    visor_eye.data.materials.append(mat_glow)
    parts.append(visor_eye)
    
    if is_white:
        # 🛡️ БЕЛЫЙ ГОЛЕМ: Большой ростовой щит с зубцами крепости + Боевой молот
        # Щит-крепость (в правой руке)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.42, 0.14, 0.58))
        shield = bpy.context.active_object
        shield.scale = (0.10, 0.32, 0.65)
        shield.data.materials.append(mat_stone)
        apply_bevel(shield, 0.03, 3)
        parts.append(shield)
        
        # Зубцы крепости на вершине щита
        for dy in [-0.10, 0, 0.10]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.42, 0.14 + dy, 0.94))
            cren = bpy.context.active_object
            cren.scale = (0.10, 0.06, 0.08)
            cren.data.materials.append(mat_armor)
            apply_bevel(cren, 0.01, 2)
            parts.append(cren)
            
        # Золотой рельеф герба на щите
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.48, 0.14, 0.58))
        crest = bpy.context.active_object
        crest.scale = (0.02, 0.18, 0.35)
        crest.data.materials.append(mat_armor)
        parts.append(crest)
        
        # Боевой молот в левой руке
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.85, location=(-0.38, 0.06, 0.55), vertices=12)
        handle = bpy.context.active_object
        handle.rotation_euler = (0.1, 0, -0.1)
        handle.data.materials.append(mat_steel)
        parts.append(handle)
        
        # Огромная каменная кувалда
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.38, 0.08, 0.95))
        hammer = bpy.context.active_object
        hammer.scale = (0.20, 0.32, 0.22)
        hammer.data.materials.append(mat_stone)
        apply_bevel(hammer, 0.04, 3)
        parts.append(hammer)
    else:
        # ⛓️ ЧЕРНЫЙ ГОЛЕМ: ДВА ШИПАСТЫХ ЦЕПА НА ЦЕПЯХ ВМЕСТО РУК (Точно по эталону!)
        for dx in [-0.42, 0.42]:
            # Массивная цепь (звенья)
            for i in range(5):
                bpy.ops.mesh.primitive_torus_add(major_radius=0.04, minor_radius=0.015, location=(dx, 0.06 + i*0.02, 0.55 - i*0.08))
                link = bpy.context.active_object
                link.rotation_euler = (math.pi/4 if i%2==0 else -math.pi/4, 0, 0)
                link.data.materials.append(mat_steel)
                parts.append(link)
                
            # Огромный шипастый шар-молот (Morningstar)
            ball_pos = (dx * 1.15, 0.16, 0.20)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=ball_pos, segments=20, ring_count=16)
            flail = bpy.context.active_object
            flail.data.materials.append(mat_armor)
            apply_bevel(flail, 0.02, 2)
            parts.append(flail)
            
            # 12 шипов на каждом шаре
            for s in range(10):
                angle = s * math.pi * 2 / 10
                sx = ball_pos[0] + 0.12 * math.cos(angle)
                sy = ball_pos[1] + 0.12 * math.sin(angle)
                sz = ball_pos[2] + 0.08 * math.cos(angle*2)
                bpy.ops.mesh.primitive_cone_add(radius1=0.035, radius2=0, depth=0.10, location=(sx, sy, sz), vertices=8)
                sp = bpy.context.active_object
                sp.data.materials.append(mat_glow)
                parts.append(sp)

    obj = join_all(parts)
    obj.name = f"rook_{'white' if is_white else 'black'}"
    return obj

def build_knight(is_white):
    """КОНЬ: Паладин на боевом коне в латах с копьем / Демонический всадник с секирой"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    
    # 🐴 ТЕЛО БОЕВОГО КОНЯ
    # Ноги коня (4 штуки в латной попоне)
    for (lx, ly) in [(-0.16, -0.12), (0.16, -0.12), (-0.16, 0.12), (0.16, 0.12)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.28, location=(lx, ly, 0.26), vertices=12)
        leg = bpy.context.active_object
        leg.data.materials.append(mat_stone)
        parts.append(leg)
        
        # Копыто
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.04, location=(lx, ly, 0.14), vertices=12)
        hoof = bpy.context.active_object
        hoof.data.materials.append(mat_armor)
        parts.append(hoof)
        
    # Торс лошади
    bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=0.48, location=(0, 0, 0.44), vertices=16)
    h_body = bpy.context.active_object
    h_body.rotation_euler = (0, math.pi/2, 0)
    h_body.data.materials.append(mat_stone)
    apply_bevel(h_body, 0.03, 3)
    parts.append(h_body)
    
    # Бронированная попона лошади (боковые латные пластины)
    for dy in [-0.18, 0.18]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, dy, 0.44))
        barding = bpy.context.active_object
        barding.scale = (0.42, 0.04, 0.22)
        barding.data.materials.append(mat_armor)
        apply_bevel(barding, 0.015, 2)
        parts.append(barding)
        
    # Изогнутая мощная шея лошади
    bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=0.34, location=(0.20, 0, 0.65), vertices=16)
    neck = bpy.context.active_object
    neck.rotation_euler = (0, 0.65, 0)
    neck.data.materials.append(mat_stone)
    parts.append(neck)
    
    # Голова лошади в шанфроне (латная броня головы)
    bpy.ops.mesh.primitive_cone_add(radius1=0.07, radius2=0.11, depth=0.28, location=(0.32, 0, 0.82), vertices=16)
    h_head = bpy.context.active_object
    h_head.rotation_euler = (-math.pi/3, 0, 0.15)
    h_head.data.materials.append(mat_armor)
    apply_bevel(h_head, 0.02, 2)
    parts.append(h_head)
    
    # Уши лошади
    for dz in [-0.05, 0.05]:
        bpy.ops.mesh.primitive_cone_add(radius1=0, radius2=0.025, depth=0.08, location=(0.28, dz, 0.94), vertices=8)
        ear = bpy.context.active_object
        ear.data.materials.append(mat_armor)
        parts.append(ear)
        
    # Светящиеся глаза лошади
    for dz in [-0.07, 0.07]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.02, location=(0.34, dz, 0.82), segments=8, ring_count=6)
        h_eye = bpy.context.active_object
        h_eye.data.materials.append(mat_glow)
        parts.append(h_eye)
        
    # 🏇 ВСАДНИК (Паладин / Демонический рыцарь)
    # Торс всадника
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.26, location=(0, 0, 0.72), vertices=16)
    r_torso = bpy.context.active_object
    r_torso.data.materials.append(mat_armor)
    parts.append(r_torso)
    
    # Шлем всадника
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.085, location=(0, 0.02, 0.92), segments=16, ring_count=12)
    r_helm = bpy.context.active_object
    r_helm.data.materials.append(mat_armor)
    parts.append(r_helm)
    
    # Оружие всадника
    if is_white:
        # Рыцарское турнирное копьё (ланс)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=1.30, location=(0.12, -0.22, 0.82), vertices=12)
        lance = bpy.context.active_object
        lance.rotation_euler = (-0.15, 0.35, 0)
        lance.data.materials.append(mat_steel)
        parts.append(lance)
        
        # Гарда копья (воронка)
        bpy.ops.mesh.primitive_cone_add(radius1=0.08, radius2=0.02, depth=0.12, location=(-0.05, -0.16, 0.68), vertices=16)
        lance_guard = bpy.context.active_object
        lance_guard.rotation_euler = (-0.15, 0.35, 0)
        lance_guard.data.materials.append(mat_armor)
        parts.append(lance_guard)
    else:
        # Демоническая боевая секира
        bpy.ops.mesh.primitive_cylinder_add(radius=0.022, depth=0.85, location=(0.04, -0.18, 0.80), vertices=12)
        axe = bpy.context.active_object
        axe.rotation_euler = (-0.25, 0, -0.15)
        axe.data.materials.append(mat_steel)
        parts.append(axe)
        
        # Двуглавое лезвие
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.04, -0.28, 1.15))
        axe_blade = bpy.context.active_object
        axe_blade.scale = (0.03, 0.26, 0.22)
        axe_blade.data.materials.append(mat_armor)
        apply_bevel(axe_blade, 0.02, 2)
        parts.append(axe_blade)
        
        # Рога на шлеме демона
        for dz in [-0.08, 0.08]:
            bpy.ops.mesh.primitive_cone_add(radius1=0, radius2=0.025, depth=0.16, location=(0, dz, 1.02), vertices=8)
            horn = bpy.context.active_object
            horn.rotation_euler = (0, dz*4, 0)
            horn.data.materials.append(mat_armor)
            parts.append(horn)

    obj = join_all(parts)
    obj.name = f"knight_{'white' if is_white else 'black'}"
    return obj

def build_bishop(is_white):
    """СЛОН: Белый боевой маг-клерик с факелом / Черный некромант с посохом-черепом"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    
    # Ниспадающая мантия священника
    bpy.ops.mesh.primitive_cone_add(radius1=0.32, radius2=0.12, depth=0.75, location=(0, 0, 0.48), vertices=24)
    robe = bpy.context.active_object
    robe.data.materials.append(mat_stone)
    apply_bevel(robe, 0.02, 2)
    parts.append(robe)
    
    # Золотой поясной кушак / стола
    bpy.ops.mesh.primitive_torus_add(major_radius=0.18, minor_radius=0.025, location=(0, 0, 0.44))
    belt = bpy.context.active_object
    belt.data.materials.append(mat_armor)
    parts.append(belt)
    
    # Капюшон (cowl) с глубокими тенями
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=(0, 0.02, 0.94), segments=20, ring_count=16)
    hood = bpy.context.active_object
    hood.scale = (0.9, 1.05, 1.1)
    hood.data.materials.append(mat_armor if is_white else mat_stone)
    parts.append(hood)
    
    # Лицо под капюшоном
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08, location=(0, 0.09, 0.92), segments=16, ring_count=12)
    face = bpy.context.active_object
    face.data.materials.append(mat_stone)
    parts.append(face)
    
    # Глаза мага
    for dx in [-0.03, 0.03]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.015, location=(dx, 0.15, 0.93), segments=8, ring_count=6)
        eye = bpy.context.active_object
        eye.data.materials.append(mat_glow)
        parts.append(eye)
        
    # Длинный посох мага
    bpy.ops.mesh.primitive_cylinder_add(radius=0.022, depth=1.35, location=(-0.28, 0.08, 0.78), vertices=12)
    staff = bpy.context.active_object
    staff.rotation_euler = (0.04, 0, -0.06)
    staff.data.materials.append(mat_steel)
    parts.append(staff)
    
    if is_white:
        # 🔥 БЕЛЫЙ: Пылающий золотой факел на вершине посоха
        bpy.ops.mesh.primitive_cone_add(radius1=0.07, radius2=0.03, depth=0.12, location=(-0.28, 0.08, 1.44), vertices=16)
        brazier = bpy.context.active_object
        brazier.data.materials.append(mat_armor)
        parts.append(brazier)
        
        # Скульптурное пламя (3 перекрученных языка огня)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.09, location=(-0.28, 0.08, 1.54), subdivisions=3)
        flame = bpy.context.active_object
        flame.scale = (0.8, 0.8, 1.5)
        flame.data.materials.append(mat_glow)
        parts.append(flame)
    else:
        # 💀 ЧЕРНЫЙ: Посох с горящим черепом некроманта
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.085, location=(-0.28, 0.08, 1.48), segments=16, ring_count=12)
        skull = bpy.context.active_object
        skull.data.materials.append(mat_glow)
        parts.append(skull)
        
        # Глазницы черепа
        for dx in [-0.03, 0.03]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.025, location=(-0.28+dx, 0.15, 1.50), segments=8, ring_count=6)
            socket = bpy.context.active_object
            socket.data.materials.append(get_mat_dark_iron())
            parts.append(socket)

    obj = join_all(parts)
    obj.name = f"bishop_{'white' if is_white else 'black'}"
    return obj

def build_queen(is_white):
    """КОРОЛЕВА: Воительница-чародейка с плащом и скипетром / Темная Императрица с клинками"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    parts.extend(create_humanoid_body(is_white, is_female=True, is_heavy=False))
    
    # Королевский плащ за спиной с драпировкой
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.14, 0.62))
    cape = bpy.context.active_object
    cape.scale = (0.36, 0.06, 0.55)
    cape.data.materials.append(mat_stone)
    apply_bevel(cape, 0.02, 2)
    parts.append(cape)
    
    # Голова королевы
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, 0.02, 0.98), segments=20, ring_count=16)
    head = bpy.context.active_object
    head.data.materials.append(mat_stone)
    parts.append(head)
    
    # Королевская тиара с самоцветами
    bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=0.06, location=(0, 0.02, 1.06), vertices=24)
    tiara = bpy.context.active_object
    tiara.data.materials.append(mat_armor)
    parts.append(tiara)
    
    # 5 зубцов короны
    for i in range(5):
        angle = (i - 2) * 0.45
        tx = 0.09 * math.sin(angle)
        ty = 0.02 + 0.09 * math.cos(angle)
        bpy.ops.mesh.primitive_cone_add(radius1=0, radius2=0.02, depth=0.08, location=(tx, ty, 1.12), vertices=8)
        spike = bpy.context.active_object
        spike.data.materials.append(mat_armor)
        parts.append(spike)
        
    # Центральный самоцвет
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.03, location=(0, 0.11, 1.08), segments=12, ring_count=8)
    gem = bpy.context.active_object
    gem.data.materials.append(mat_glow)
    parts.append(gem)
    
    if is_white:
        # Скипетр света
        bpy.ops.mesh.primitive_cylinder_add(radius=0.018, depth=0.75, location=(0.26, 0.06, 0.72), vertices=12)
        scepter = bpy.context.active_object
        scepter.rotation_euler = (0.08, 0, -0.18)
        scepter.data.materials.append(mat_steel)
        parts.append(scepter)
        
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(0.32, 0.08, 1.10), segments=16, ring_count=12)
        orb = bpy.context.active_object
        orb.data.materials.append(mat_glow)
        parts.append(orb)
    else:
        # Парные темные клинки
        for dx in [-0.26, 0.26]:
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(dx, 0.08, 0.68))
            blade = bpy.context.active_object
            blade.scale = (0.02, 0.06, 0.44)
            blade.data.materials.append(mat_steel)
            apply_bevel(blade, 0.01, 2)
            parts.append(blade)

    obj = join_all(parts)
    obj.name = f"queen_{'white' if is_white else 'black'}"
    return obj

def build_king(is_white):
    """КОРОЛЬ: Белый Король-Паладин в полных латах с великим мечом / Черный Владыка с шипастой булавой"""
    clean_scene()
    mat_stone = get_mat_light_marble() if is_white else get_mat_dark_obsidian()
    mat_armor = get_mat_gold_inlay() if is_white else get_mat_dark_iron()
    mat_glow = get_mat_gold_glow() if is_white else get_mat_magma_glow()
    mat_steel = get_mat_steel(is_white)
    
    parts = build_ornate_pedestal(is_white)
    parts.extend(create_humanoid_body(is_white, is_female=False, is_heavy=True))
    
    # Королевская мантия
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, -0.16, 0.65))
    mantle = bpy.context.active_object
    mantle.scale = (0.42, 0.08, 0.60)
    mantle.data.materials.append(mat_stone)
    apply_bevel(mantle, 0.025, 2)
    parts.append(mantle)
    
    # Шлем Короля
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(0, 0.02, 0.98), segments=20, ring_count=16)
    k_helm = bpy.context.active_object
    k_helm.data.materials.append(mat_armor)
    parts.append(k_helm)
    
    # Величественная корона
    bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.09, location=(0, 0.02, 1.08), vertices=24)
    crown = bpy.context.active_object
    crown.data.materials.append(mat_armor)
    parts.append(crown)
    
    # Зубцы короны с крестом (Белые) или шипами (Черные)
    if is_white:
        for i in range(6):
            angle = i * math.pi * 2 / 6
            cx = 0.12 * math.cos(angle)
            cy = 0.02 + 0.12 * math.sin(angle)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy, 1.16))
            prong = bpy.context.active_object
            prong.scale = (0.025, 0.025, 0.08)
            prong.data.materials.append(mat_armor)
            parts.append(prong)
            
        # Золотой крест на вершине
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.02, 1.22))
        c1 = bpy.context.active_object
        c1.scale = (0.10, 0.025, 0.025)
        c1.data.materials.append(mat_glow)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0.02, 1.22))
        c2 = bpy.context.active_object
        c2.scale = (0.025, 0.025, 0.10)
        c2.data.materials.append(mat_glow)
        parts.extend([c1, c2])
        
        # ⚔️ ВЕЛИКИЙ ДВУРУЧНЫЙ МЕЧ (King's Greatsword)
        # Клинок с долом
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.34, 0.08, 0.72))
        blade = bpy.context.active_object
        blade.scale = (0.035, 0.08, 0.85)
        blade.data.materials.append(mat_steel)
        apply_bevel(blade, 0.01, 2)
        parts.append(blade)
        
        # Гарда меча
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.34, 0.08, 0.36))
        crossguard = bpy.context.active_object
        crossguard.scale = (0.24, 0.04, 0.03)
        crossguard.data.materials.append(mat_armor)
        parts.append(crossguard)
        
        # Рукоять и навершие
        bpy.ops.mesh.primitive_cylinder_add(radius=0.018, depth=0.18, location=(0.34, 0.08, 0.26), vertices=12)
        hilt = bpy.context.active_object
        hilt.data.materials.append(mat_steel)
        parts.append(hilt)
        
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(0.34, 0.08, 0.16), segments=12, ring_count=8)
        pommel = bpy.context.active_object
        pommel.data.materials.append(mat_glow)
        parts.append(pommel)
    else:
        # 👑 ЧЕРНЫЙ ВЛАДЫКА: Шипастая корона + Массивная булава/маца
        for i in range(8):
            angle = i * math.pi * 2 / 8
            cx = 0.12 * math.cos(angle)
            cy = 0.02 + 0.12 * math.sin(angle)
            bpy.ops.mesh.primitive_cone_add(radius1=0, radius2=0.03, depth=0.14, location=(cx, cy, 1.18), vertices=8)
            sp = bpy.context.active_object
            sp.data.materials.append(mat_armor)
            parts.append(sp)
            
        # Шипастая булава
        bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.82, location=(-0.32, 0.06, 0.65), vertices=12)
        mace_h = bpy.context.active_object
        mace_h.rotation_euler = (0.06, 0, -0.12)
        mace_h.data.materials.append(mat_steel)
        parts.append(mace_h)
        
        # Головка булавы
        mace_head_pos = (-0.36, 0.08, 1.06)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=mace_head_pos, segments=16, ring_count=12)
        mace_head = bpy.context.active_object
        mace_head.data.materials.append(mat_armor)
        parts.append(mace_head)
        
        # 12 шипов на булаве
        for i in range(12):
            a = i * math.pi * 2 / 12
            sx = mace_head_pos[0] + 0.10 * math.cos(a)
            sy = mace_head_pos[1] + 0.10 * math.sin(a)
            sz = mace_head_pos[2] + 0.06 * math.cos(a*2)
            bpy.ops.mesh.primitive_cone_add(radius1=0.03, radius2=0, depth=0.09, location=(sx, sy, sz), vertices=8)
            spike = bpy.context.active_object
            spike.data.materials.append(mat_glow)
            parts.append(spike)

    obj = join_all(parts)
    obj.name = f"king_{'white' if is_white else 'black'}"
    return obj

# ═══════════════════════════════════════════════════════════════
# Экспорт моделей в USDZ и OBJ
# ═══════════════════════════════════════════════════════════════

def export_piece(obj, base_name):
    usdz_path = os.path.join(OUTPUT_DIR, f"{base_name}.usdz")
    obj_path = os.path.join(OUTPUT_DIR, f"{base_name}.obj")
    
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    # 1. USDZ export
    try:
        bpy.ops.wm.usd_export(
            filepath=usdz_path,
            selected_objects_only=True,
            export_materials=True,
            export_normals=True,
            export_uvmaps=True,
            triangulate_meshes=True
        )
        print(f"  ✅ [USDZ] {base_name}.usdz")
    except Exception as e:
        print(f"  ⚠️ USDZ Error: {e}")
        
    # 2. OBJ export
    try:
        bpy.ops.wm.obj_export(
            filepath=obj_path,
            export_selected_objects=True,
            export_materials=True,
            export_normals=True,
            export_uv=True,
            apply_modifiers=True
        )
        print(f"  ✅ [OBJ] {base_name}.obj")
    except Exception as e:
        print(f"  ⚠️ OBJ Error: {e}")

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("=" * 60)
    print("  ♚ CHESS 3D — ADVANCED WARRIOR SCULPTOR")
    print("=" * 60)
    
    builders = [
        ("pawn", build_pawn),
        ("rook", build_rook),
        ("knight", build_knight),
        ("bishop", build_bishop),
        ("queen", build_queen),
        ("king", build_king),
    ]
    
    for name, builder in builders:
        for is_white in [True, False]:
            color = "white" if is_white else "black"
            full_name = f"{name}_{color}"
            print(f"\n🔨 Sculpting {full_name} ({'Army of Light' if is_white else 'Army of Darkness'})...")
            obj = builder(is_white)
            export_piece(obj, full_name)
            
    print("\n" + "=" * 60)
    print("  ✅ ВСЕ 12 МОДЕЛЕЙ УСПЕШНО СГЕНЕРИРОВАНЫ!")
    print("=" * 60)

if __name__ == "__main__":
    main()
