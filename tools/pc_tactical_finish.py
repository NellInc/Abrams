"""Offline Cycles finishes for Tactical assets, with no runtime dependencies.

Generated coordinates are normalized per object. All patterns are anchored in
object space, never camera space. Materials change shading only, never meshes.
Palette values are authored sRGB bytes and converted to scene-linear colour.
"""
from __future__ import annotations


def _linear(rgb):
    def channel(v):
        v = v / 255.0
        return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4
    return tuple(channel(v) for v in rgb) + (1.0,)


def _profile(name):
    """Return finish, nominal roughness, metallic and microrelief amplitude."""
    if name.startswith(('insignia_', 'us_flag_')) or name in ('army_flag', 'signal_red', 'red'):
        return 'signal', .65, 0., 0.
    if name in ('glass', 'cockpit', 'optic', 'lamp'):
        return 'optic', .19 if name != 'lamp' else .27, 0., 0.
    if name in ('tyre', 'vent', 'ruin_void', 'rubber'):
        return 'rubber', .89, 0., .0003
    if name in ('steel', 'exposed', 'track_edge'):
        return 'metal', .39 if name != 'track_edge' else .50, .86, .00028
    if name == 'track':
        return 'track', .76, .55, .0006
    if name.startswith(('wreck', 'ruin_char')) or name in ('burnt', 'rust', 'scorch'):
        return 'burnt', .91, .08, .0008
    if name in ('canvas', 'canvas_edge', 'cloth', 'cloth_light', 'cloth_shadow', 'webbing', 'army_cloth'):
        return 'fabric', .88, 0., .00045
    if name == 'skin':
        return 'skin', .66, 0., .00012
    if name == 'leather':
        return 'leather', .64, 0., .00025
    if name in ('timber', 'bark', 'tree_trunk', 'door'):
        return 'wood', .79, 0., .00065
    if name in ('ruin_brick', 'brick'):
        return 'brick', .88, 0., .0012
    if name in ('roof_clay', 'roof_ridge'):
        return 'clay', .83, 0., .0007
    if name in ('roof', 'roof_slate'):
        return 'slate', .75, 0., .0006
    if name in ('plaster', 'ruin_plaster'):
        return 'plaster', .91, 0., .0005
    if name in ('stone_edge', 'ruin_stone', 'ruin_mortar', 'road', 'earth'):
        return 'stone', .94, 0., .0009
    if name in ('grass', 'yard_grass', 'foliage', 'tree_crown'):
        return 'organic', .92, 0., .0005
    if name == 'water':
        return 'water', .25, 0., .00015
    return 'paint', .67, 0., .00025


CAMOUFLAGE_SHAPES = tuple(range(115, 145)) + (159, 160, 163, 164)
CAMOUFLAGE_PALETTES = {
    'nato': ((73, 86, 57), (91, 73, 53), (33, 39, 32)),
    'eastern': ((86, 103, 59), (148, 139, 96), (46, 63, 41)),
    'hind': ((84, 99, 58), (153, 143, 103), (59, 75, 46)),
}


def camouflage_role(shape, name, component=''):
    """Paint eligibility only; rubber, glazing, signals and bare metal stay intact."""
    if shape not in CAMOUFLAGE_SHAPES:
        return ''
    if shape in tuple(range(116, 145, 2)) + (160,):
        plate = any(part in component for part in
                    ('sidewall', 'deck', 'turret', 'fender', 'roof', 'hull',
                     'plate', 'canister', 'gun_barrel', 'gun_root', 'glacis', 'bustle'))
        return 'wreck' if name in ('burnt', 'rust') and plate and not component.endswith('_torn_edge') else ''
    return 'paint' if name in ('olive', 'olive_edge', 'wheel', 'hub', 'hatch',
                              'equipment', 'signal_red', 'hind_olive', 'hind_pale') else ''


def camouflage_family(shape):
    intact = shape - 1 if shape in tuple(range(116, 145, 2)) + (160,) else shape
    if intact in (125, 127, 129, 131):
        return 'nato'
    return 'hind' if shape in (163, 164) else 'eastern'


def material(bpy, name, shape, camo_role=None):
    """Create a distinct procedural material for one original material role.

    The caller may extend MATERIALS before calling. Linked Metallic is meaningful
    and should be emission-baked from its socket, rather than its default value.
    Signals intentionally bypass all weathering so source markings stay legible.
    """
    from tools.build_pc_modern_assets import MATERIALS, WALL_PAINT, ROOF_PAINT, DOOR_PAINT
    polish=shape not in (158,159)

    # These legacy source-colour roles mark vehicle weapon/rack sheets,
    # not red-painted hardware. True scene signals retain their exact colour.
    if camo_role is None:camo_role=camouflage_role(shape,name)
    if name=='signal_red' and (115<=shape<=144 or shape in (159,160)):name='equipment'
    custom=None
    if name.startswith('cabin_'):
        from tools.pc_tactical_cabin import FINISHES
        custom=FINISHES[name]
    elif name.startswith('architecture_'):
        from tools.pc_tactical_architecture import FINISHES
        custom=FINISHES[name]
    elif name.startswith('crew_head_'):
        from tools.pc_tactical_crew_heads import FINISHES
        custom=FINISHES[name]
    elif name.startswith('crew_'):
        from tools.pc_tactical_crews import FINISHES
        custom=FINISHES[name]
    elif name.startswith('bridge_'):
        from tools.pc_tactical_bridges import FINISHES
        custom=FINISHES[name]
    elif name.startswith('refinement_'):
        from tools.pc_tactical_vehicle_refinement import FINISHES
        custom=FINISHES[name]
    elif name.startswith('truck_'):
        from tools.pc_tactical_wheeled_vehicles import FINISHES
        custom=FINISHES[name]
    rgb = custom[1] if custom else MATERIALS.get(name, MATERIALS['olive'])
    if shape==157 and name=='yard_grass':rgb=(89,109,60)
    if name == 'plaster':
        rgb = WALL_PAINT.get(shape, rgb)
    elif name in ('roof', 'roof_slate'):
        rgb = ROOF_PAINT.get(shape, rgb)
    elif name == 'door':
        rgb = DOOR_PAINT.get(shape, rgb)
    color = _linear(rgb)
    finish, roughness, metallic, relief = (custom[2] or _profile(custom[0])) if custom else _profile(name)
    mat = bpy.data.materials.new(f'Tactical_{shape}_{name}')
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = color
    mat['tactical_finish'] = finish
    mat['source_material'] = name
    if camo_role:mat['camouflage_family']=camouflage_family(shape)

    def node(kind, label):
        n = nodes.new(kind)
        n.label = label
        return n

    def connect(source, target):
        links.new(source, target)

    def math(op, a, b=0.):
        n = node('ShaderNodeMath', op)
        n.operation = op
        for i, value in enumerate((a, b)):
            if isinstance(value, (int, float)):
                n.inputs[i].default_value = value
            else:
                connect(value, n.inputs[i])
        return n.outputs[0]

    def remap(value, low, high, outlow=0., outhigh=1.):
        n = node('ShaderNodeMapRange', 'Clamped finish mask')
        n.clamp = True
        for socket, value_ in zip(('From Min', 'From Max', 'To Min', 'To Max'),
                                  (low, high, outlow, outhigh)):
            n.inputs[socket].default_value = value_
        connect(value, n.inputs['Value'])
        return n.outputs['Result']

    def mix(factor, a, b, mode='MIX'):
        n = node('ShaderNodeMixRGB', 'Finish colour layering')
        n.blend_type = mode
        for i, value in enumerate((factor, a, b)):
            if isinstance(value, (int, float, tuple, list)):
                n.inputs[i].default_value = value
            else:
                connect(value, n.inputs[i])
        return n.outputs[0]

    def scaled(vector, scale):
        n = node('ShaderNodeVectorMath', 'Object-anchored anisotropy')
        n.operation = 'MULTIPLY'
        connect(vector, n.inputs[0])
        n.inputs[1].default_value = scale
        return n.outputs['Vector']

    def noise(vector, scale, detail=2.):
        n = node('ShaderNodeTexNoise', 'Stable pigment / surface variation')
        connect(vector, n.inputs['Vector'])
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        n.inputs['Roughness'].default_value = .65
        return n.outputs['Fac']

    if finish == 'signal':
        return mat
    if finish == 'optic':
        # Opaque coated lenses survive diffuse baking; transmission would bake black.
        if 'Coat Weight' in bsdf.inputs:
            bsdf.inputs['Coat Weight'].default_value = .42
            bsdf.inputs['Coat Roughness'].default_value = .12
        return mat

    coords = node('ShaderNodeTexCoord', 'Normalized object bounds')
    vector = coords.outputs['Generated']
    separate = node('ShaderNodeSeparateXYZ', 'Normalized height')
    connect(vector, separate.inputs[0])
    physical=None;collapse=None;contact=None
    if shape in (158,159):
        # Offline positions are raw source units, shared by game and master.
        physical=node('ShaderNodeSeparateXYZ','Source-unit contact coordinates')
        connect(scaled(coords.outputs['Object'],(64.,64.,64.)),physical.inputs[0])
        if shape==158:
            from tools.pc_tactical_architecture import FARM_RUBBLE_CLUSTERS
            collapse=0.
            for x,y,size in FARM_RUBBLE_CLUSTERS:
                dx=math('DIVIDE',math('SUBTRACT',physical.outputs['X'],x),62*size)
                dy=math('DIVIDE',math('SUBTRACT',physical.outputs['Y'],y),43*size)
                d2=math('ADD',math('MULTIPLY',dx,dx),math('MULTIPLY',dy,dy))
                d2=math('MULTIPLY',d2,remap(noise(vector,37.,3.),.25,.75,.58,1.55))
                halo=remap(d2,.05,1.5,1.,0.)
                collapse=math('MAXIMUM',collapse,halo)
        else:
            arch=0.
            for y in (-59,-22,70):
                dy=math('SUBTRACT',physical.outputs['Y'],y)
                dz=math('ADD',physical.outputs['Z'],20.)
                radial=math('SQRT',math('ADD',math('MULTIPLY',dy,dy),math('MULTIPLY',dz,dz)))
                band=remap(math('ABSOLUTE',math('SUBTRACT',radial,18.)),.5,6.,1.,0.)
                arch=math('MAXIMUM',arch,band)
            lower=remap(physical.outputs['Z'],-8.,6.,1.,0.)
            contact=math('MULTIPLY',math('MAXIMUM',arch,lower),
                         remap(math('ABSOLUTE',physical.outputs['X']),25.,37.,0.,1.))
    broad = noise(vector, 5.5, 3.)
    fine = noise(vector, 155., 2.)
    # Pigment modulation is broad and quiet; microrelief does not glitter.
    amplitude = .018 if shape==159 and finish=='paint' else .035 if shape==158 and finish in ('plaster','stone') else .055 if finish in ('paint', 'skin', 'rubber') else .11
    if polish and finish in ('paint','plaster','stone','skin'):amplitude=.02 if finish in ('paint','skin') else .035
    pigment = remap(broad, 0., 1., 1. - amplitude, 1. + amplitude)
    if camo_role:
        # Shared physical object coordinates keep patches continuous across
        # material boundaries and identical on low/master shells. No UV changes.
        family=camouflage_family(shape)
        intact=shape-1 if shape in tuple(range(116,145,2))+(160,) else shape
        if intact in (143,164):intact-=2 if intact==143 else 1
        pattern=node('ShaderNodeTexNoise','Broad object-space woodland patches')
        pattern.noise_dimensions='4D'
        connect(scaled(coords.outputs['Object'],(1.05,.70,1.0) if family!='hind' else (.34,.26,.34)),pattern.inputs['Vector'])
        pattern.inputs['Scale'].default_value=2.2
        pattern.inputs['Detail'].default_value=1.2
        pattern.inputs['Roughness'].default_value=.56
        pattern.inputs['Distortion'].default_value=.28
        pattern.inputs['W'].default_value=intact*.731
        ramp=node('ShaderNodeValToRGB','Green brown charcoal camouflage')
        ramp.color_ramp.interpolation='EASE'
        palette=CAMOUFLAGE_PALETTES[family]
        stops=((0.,palette[0]),(.485,palette[0]),(.505,palette[1]),(.585,palette[1]),(.605,palette[2]),(1.,palette[2]))
        for element in list(ramp.color_ramp.elements)[1:]:ramp.color_ramp.elements.remove(element)
        for i,(position,rgb_) in enumerate(stops):
            element=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(position)
            element.position=position;element.color=_linear(rgb_)
        connect(pattern.outputs['Fac'],ramp.inputs[0])
        color=mix(.58,color,ramp.outputs['Color']) if camo_role=='wreck' else ramp.outputs['Color']
    surface = mix(1., color, pigment, 'MULTIPLY')
    height = fine
    rough_variation=.025 if finish=='paint' else .055
    rough = remap(fine, 0., 1., max(.05, roughness - rough_variation), min(1., roughness + rough_variation))

    if finish == 'fabric':
        # Crossing raised threads, softly irregular rather than a checker print.
        threads = []
        axes = ('X', 'Z') if name.startswith('bridge_flag_') else ('X', 'Y')
        for axis in axes:
            wave = node('ShaderNodeTexWave', 'Woven canvas threads')
            wave.wave_type = 'BANDS'
            wave.bands_direction = axis
            connect(vector, wave.inputs['Vector'])
            wave.inputs['Scale'].default_value = 115.
            wave.inputs['Distortion'].default_value = .65
            threads.append(wave.outputs['Fac'])
        height = math('MULTIPLY', threads[0], threads[1])
        surface = mix(.045 if polish else .12, surface, mix(height, (.68, .68, .68, 1), (1., 1., 1., 1)), 'MULTIPLY')
    elif finish == 'wood':
        grain = noise(scaled(vector, (15., 15., .7)), 8., 3.)
        height = grain
        surface = mix(.30, surface, mix(grain, (.48, .40, .30, 1), (1.1, 1.04, .91, 1)), 'MULTIPLY')
    elif finish in ('brick', 'clay', 'slate'):
        # Wall courses use horizontal tangent and vertical object height.
        # Pick the horizontal projection by the object-space face normal.
        geometry = node('ShaderNodeNewGeometry', 'Face-oriented masonry')
        transform = node('ShaderNodeVectorTransform', 'World normal to object')
        transform.vector_type = 'NORMAL'
        transform.convert_from = 'WORLD'
        transform.convert_to = 'OBJECT'
        connect(geometry.outputs['Normal'], transform.inputs['Vector'])
        ns = node('ShaderNodeSeparateXYZ', 'Object normal axes')
        connect(transform.outputs['Vector'], ns.inputs[0])
        side = math('GREATER_THAN', math('ABSOLUTE', ns.outputs['X']), math('ABSOLUTE', ns.outputs['Y']))
        horizontal = math('ADD', math('MULTIPLY', separate.outputs['X'], math('SUBTRACT', 1., side)),
                          math('MULTIPLY', separate.outputs['Y'], side))
        projection = node('ShaderNodeCombineXYZ', 'Masonry courses')
        connect(horizontal, projection.inputs['X'])
        connect(separate.outputs['Z'] if finish == 'brick' else separate.outputs['Y'], projection.inputs['Y'])
        brick = node('ShaderNodeTexBrick', 'Coursed brick or individual roof tiles')
        connect(projection.outputs[0], brick.inputs['Vector'])
        brick.inputs['Color1'].default_value = tuple(c * .94 for c in color[:3]) + (1.,)
        brick.inputs['Color2'].default_value = tuple(c * 1.06 for c in color[:3]) + (1.,)
        brick.inputs['Mortar'].default_value = _linear((112, 106, 93) if finish == 'brick' else (55, 54, 49))
        brick.inputs['Scale'].default_value = 13. if finish == 'brick' else 18.
        brick.inputs['Mortar Size'].default_value = .018 if finish == 'brick' else .008
        brick.inputs['Mortar Smooth'].default_value = .006
        brick.inputs['Brick Width'].default_value = .7
        brick.inputs['Row Height'].default_value = .28 if finish == 'brick' else .5
        surface = mix(.12, brick.outputs['Color'], surface)
        height = math('ADD', math('MULTIPLY', math('SUBTRACT', 1., brick.outputs['Fac']), .8), math('MULTIPLY', fine, .2))
    elif finish == 'burnt':
        oxide = remap(noise(vector, 19., 3.), .48, .76, 0., .56 if name != 'scorch' else .09)
        if polish:
            geom=node('ShaderNodeNewGeometry','Heat-damaged edge oxidation')
            oxide=math('MULTIPLY',oxide,remap(geom.outputs['Pointiness'],.48,.56,.12,.9))
        surface = mix(oxide, surface, _linear((104, 61, 34)))
        surface = mix(remap(broad, .56, .82, 0., .46), surface, _linear((22, 24, 23)))
        if polish:
            soot=remap(separate.outputs['Z'],.12,.62,.24,0.)
            surface=mix(soot,surface,_linear((25,26,23)))
        height = noise(vector, 90., 4.)
    elif finish == 'leather':
        height = noise(scaled(vector, (1., 1., 3.)), 92., 3.)

    # Pointiness is curvature-sensitive on the beveled high mesh. It cannot
    # invent random isolated metallic pixels across flat rubber or fabric.
    if finish in ('paint', 'metal', 'track'):
        geom = node('ShaderNodeNewGeometry', 'Convex mechanical contact edges')
        edge = remap(geom.outputs['Pointiness'], .515, .565)
        broken = remap(noise(vector, 39., 2.), .52, .75)
        wear = math('MULTIPLY', edge, broken)
        wear = math('MULTIPLY', wear, .42 if finish == 'paint' else .68)
        if shape==159:
            wear=math('MULTIPLY',wear,math('ADD',.10,math('MULTIPLY',contact,.35)))
        elif polish:
            wear=math('MULTIPLY',wear,.16 if finish=='paint' else .55)
        surface = mix(wear, surface, _linear((132, 136, 124)))
        rough = math('SUBTRACT', rough, math('MULTIPLY', wear, .28))
        metal = math('ADD', metallic, math('MULTIPLY', wear, .78 if finish == 'paint' else .12))
        connect(metal, bsdf.inputs['Metallic'])

    # Sparse rain streaks run vertically. Dust is limited to the lower body,
    # with a soft irregular boundary, never a blanket over flags or optics.
    if finish in ('paint', 'metal', 'track', 'rubber', 'burnt', 'plaster', 'stone', 'brick') or (polish and finish=='leather' and not name.startswith('crew_head_')):
        streak = noise(scaled(vector, (32., 32., 1.1)), 3., 2.)
        streak = remap(streak, .69, .86, 0., .055)
        normal=node('ShaderNodeNewGeometry','Side-facing rain stain mask')
        transform=node('ShaderNodeVectorTransform','World normal to object')
        transform.vector_type='NORMAL';transform.convert_from='WORLD';transform.convert_to='OBJECT'
        connect(normal.outputs['Normal'],transform.inputs['Vector'])
        axes=node('ShaderNodeSeparateXYZ','Side-facing normal')
        connect(transform.outputs[0],axes.inputs[0])
        streak=math('MULTIPLY',streak,math('SUBTRACT',1.,math('ABSOLUTE',axes.outputs['Z'])))
        surface = mix(streak, surface, _linear((61, 57, 43)))
        lower = remap(separate.outputs['Z'], .02, .39, .22, 0.)
        dust = math('MULTIPLY', lower, remap(broad, .2, .8, .35, 1.))
        if shape==159:
            dust=math('MULTIPLY',contact,.16 if finish=='rubber' else .24)
            dust=math('MULTIPLY',dust,remap(broad,.15,.85,.65,1.))
        elif shape==158:
            low=remap(physical.outputs['Z'],0.,24.,.34,0.)
            dust=0. if name=='architecture_yard_dust' else math('MULTIPLY',collapse,low)
        elif polish:
            # Upper armour remains quiet. Dust collects at the running gear,
            # masonry footing and boot soles instead of fogging the whole skin.
            dust=math('MULTIPLY',remap(separate.outputs['Z'],.03,.29,.22,0.),remap(broad,.2,.8,.5,1.))
        surface = mix(dust, surface, _linear((144, 130, 96)))
        rough = math('ADD', rough, math('MULTIPLY', dust, .12))
        if finish in ('paint', 'metal', 'track'):
            # Dust is dielectric; preserve exposed metal only where clean.
            metal = math('MULTIPLY', metal, math('SUBTRACT', 1., dust))
            connect(metal, bsdf.inputs['Metallic'])

    if shape==158 and name=='architecture_yard_dust':
        # Pulverized render fades into the original yard. A restrained dark
        # core and roughness anchor piles without a decal, actor or new owner.
        powder=math('MULTIPLY',collapse,remap(noise(vector,29.,3.),.15,.85,.19,.42))
        surface=mix(powder,surface,_linear((158,149,128)))
        core=math('MULTIPLY',remap(collapse,.70,1.,0.,.14),remap(broad,.3,.8,.3,1.))
        surface=mix(core,surface,_linear((64,61,51)))
        rough=math('MAXIMUM',rough,.94)

    if polish and name.startswith('bridge_'):
        if shape==47:
            wave=node('ShaderNodeTexWave','Shallow rolled cladding ribs')
            wave.wave_type='BANDS';wave.bands_direction='X';connect(vector,wave.inputs['Vector'])
            wave.inputs['Scale'].default_value=82.;wave.inputs['Distortion'].default_value=.08
            height=wave.outputs['Fac'];relief=.0007
            surface=mix(.035,surface,mix(height,(.80,.80,.80,1),(1.,1.,1.,1)),'MULTIPLY')
        elif name.startswith('bridge_concrete_'):
            across=separate.outputs['X'] if shape in (0,46) else separate.outputs['Y']
            traffic=0.
            for line in (.26,.74):
                band=remap(math('ABSOLUTE',math('SUBTRACT',across,line)),.025,.12,1.,0.)
                traffic=math('MAXIMUM',traffic,band)
            traffic=math('MULTIPLY',traffic,remap(broad,.2,.8,.025,.085))
            surface=mix(traffic,surface,_linear((98,103,94)))

    if shape==157 and name=='yard_grass':
        # Source-owned trampled approach from the gate to trough and animal.
        raw=node('ShaderNodeSeparateXYZ','Farmyard source-unit paths')
        connect(scaled(coords.outputs['Object'],(64.,64.,64.)),raw.inputs[0])
        path=0.
        for x0,y0,x1,y1,width in ((-365,-320,-392,-118,17.),(-392,-118,-403,35,15.),(-392,-118,-344,-75,22.)):
            dx,dy=x1-x0,y1-y0;length=dx*dx+dy*dy
            px=math('SUBTRACT',raw.outputs['X'],x0);py=math('SUBTRACT',raw.outputs['Y'],y0)
            t=remap(math('DIVIDE',math('ADD',math('MULTIPLY',px,dx),math('MULTIPLY',py,dy)),length),0.,1.)
            ex=math('SUBTRACT',px,math('MULTIPLY',t,dx));ey=math('SUBTRACT',py,math('MULTIPLY',t,dy))
            distance=math('SQRT',math('ADD',math('MULTIPLY',ex,ex),math('MULTIPLY',ey,ey)))
            path=math('MAXIMUM',path,remap(distance,width*.3,width*1.6,1.,0.))
        path=math('MULTIPLY',path,remap(noise(vector,31.,3.),.2,.8,.20,.43))
        surface=mix(path,surface,_linear((119,106,76)))

    if polish and name=='architecture_ruin_dust':
        grit=remap(noise(vector,19.,3.),.3,.75,0.,.18)
        surface=mix(grit,surface,_linear((169,155,127)))

    connect(surface, bsdf.inputs['Base Color'])
    connect(rough, bsdf.inputs['Roughness'])
    if relief:
        bump = node('ShaderNodeBump', 'Material-specific microscopic relief')
        bump.inputs['Strength'].default_value = .045 if finish=='paint' else .20 if finish in ('fabric', 'brick', 'wood') else .13
        bump.inputs['Distance'].default_value = relief
        connect(height, bump.inputs['Height'])
        connect(bump.outputs['Normal'], bsdf.inputs['Normal'])
    return mat
