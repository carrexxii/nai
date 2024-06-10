import common
from std/strutils import to_lower_ascii

type
    TextureOp* {.size: sizeof(cint).} = enum
        Multiply
        Add
        Subtract
        Divide
        SmoothAdd
        SignedAdd

    TextureMapMode* {.size: sizeof(cint).} = enum
        Wrap
        Clamp
        Mirror
        Decal

    TextureMapping* {.size: sizeof(cint).} = enum
        UV
        Sphere
        Cylinder
        Box
        Plane
        Other

    TextureKind* {.size: sizeof(cuint).} = enum
        None
        Diffuse
        Specular
        Ambient
        Emissive
        Height
        Normals
        Shininess
        Opacity
        Displacement
        Lightmap
        Reflection
        BaseColour
        NormalCamera
        EmissionColour
        Metalness
        DiffuseRoughness
        AmbientOcclusion
        Unknown
        Sheen
        Clearcoat
        Transmission

    ShadingMode* {.size: sizeof(cint).} = enum
        Flat
        Gouraud
        Phong
        Blinn
        Toon
        OrenNayar
        Minnaert
        CookTorrance
        NoShading
        Fresnel
        PBRBRDF

    BlendMode* {.size: sizeof(cint).} = enum
        Default
        Additive

    PropertyKindInfo* {.size: sizeof(cint).} = enum
        Float
        Double
        String
        Integer
        Buffer

    TextureFlag {.size: sizeof(cint).} = enum
        None        = 0x0
        Invert      = 0x1
        UseAlpha    = 0x2
        IgnoreAlpha = 0x4

    Matkey* {.size: sizeof(cstring).} = enum
        Name                      = "?mat.name"
        TwoSided                  = "$mat.twosided"
        ShadingModel              = "$mat.shadingm"
        EnableWireframe           = "$mat.wireframe"
        BlendFunc                 = "$mat.blend"
        Opacity                   = "$mat.opacity"
        TransparencyFactor        = "$mat.transparencyfactor"
        BumpScaling               = "$mat.bumpscaling"
        Shininess                 = "$mat.shininess"
        Reflectivity              = "$mat.reflectivity"
        ShininessStrength         = "$mat.shinpercent"
        RefractI                  = "$mat.refracti"
        ColourDiffuse             = "$clr.diffuse"
        ColourAmbient             = "$clr.ambient"
        ColourSpecular            = "$clr.specular"
        ColourEmissive            = "$clr.emissive"
        ColourTransparent         = "$clr.transparent"
        ColourReflective          = "$clr.reflective"
        GlobalBackgroundImage     = "?bg.global"
        GlobalShaderLang          = "?sh.lang"
        ShaderVertex              = "?sh.vs"
        ShaderFragment            = "?sh.fs"
        ShaderGeo                 = "?sh.gs"
        ShaderTesselation         = "?sh.ts"
        ShaderPrimitive           = "?sh.ps"
        ShaderCompute             = "?sh.cs"
        UseColourMap              = "$mat.useColorMap"
        BaseColour                = "$clr.base"
        UseMetallicMap            = "$mat.useMetallicMap"
        MetallicFactor            = "$mat.metallicFactor"
        UseRoughnessMap           = "$mat.useRoughnessMap"
        RoughnessFactor           = "$mat.roughnessFactor"
        AnisotropyFactor          = "$mat.anisotropyFactor"
        SpecularFactor            = "$mat.specularFactor"
        GlossinessFactor          = "$mat.glossinessFactor"
        SheenColourFactor         = "$clr.sheen.factor"
        SheenRoughnessFactor      = "$mat.sheen.roughnessFactor"
        ClearcoatFactor           = "$mat.clearcoat.factor"
        ClearcoatRoughnessFactor  = "$mat.clearcoat.roughnessFactor"
        TransmissionFactor        = "$mat.transmission.factor"
        VolumeThicknessFactor     = "$mat.volume.thicknessFactor"
        VolumeAttenuationDistance = "$mat.volume.attenuationDistance"
        VolumeAttenuationColour   = "$mat.volume.attenuationColor"
        UseEmissiveMap            = "$mat.useEmissiveMap"
        EmissiveIntensity         = "$mat.emissiveIntensity"
        UseAOMap                  = "$mat.useAOMap"
        TextureBase               = "$tex.file"
        UVWSrcBase                = "$tex.uvwsrc"
        TexOpBase                 = "$tex.op"
        MappingBase               = "$tex.mapping"
        TexBlendBase              = "$tex.blend"
        MappingModeUBase          = "$tex.mapmodeu"
        MappingModeVBase          = "$tex.mapmodev"
        TexMapAxisBase            = "$tex.mapaxis"
        UVTransformBase           = "$tex.uvtrafo"
        TexFlagsBase              = "$tex.flags"

    #     BaseColourTexture         = (TextureKind.BaseColour      , 0)
    #     MetallicTexture           = (TextureKind.Metalness       , 0)
    #     RoughnessTexture          = (TextureKind.DiffuseRoughness, 0)
    #     SheenColourTexture        = (TextureKind.Sheen           , 0)
    #     SheenRoughnessTexture     = (TextureKind.Sheen           , 1)
    #     ClearcoatTexture          = (TextureKind.Clearcoat       , 0)
    #     ClearcoatRoughnessTexture = (TextureKind.Clearcoat       , 1)
    #     ClearcoatNormalTexture    = (TextureKind.Clearcoat       , 2)
    #     TransmissionTexture       = (TextureKind.Transmission    , 0)
    #     VolumeThicknessTexture    = (TextureKind.Transmission    , 1)

type
    Material* = object
        properties*      : ptr UncheckedArray[ptr MaterialProperty]
        properties_count*: uint32
        allocated_count* : uint32

    MaterialProperty* = object
        key        : AIString
        tex_kind   : TextureKind # "semantic"
        index      : uint32
        data_length: uint32
        kind       : PropertyKindInfo
        data       : ptr byte

    UVTransform* {.packed.} = object
        translation: Vec2
        scaling    : Vec2
        rotation   : Real

    TextureData* = object
        kind*        : TextureKind
        path*        : string
        mapping*     : TextureMapping
        uv_index*    : int
        blend_factor*: Real
        texture_op*  : TextureOp
        map_mode*    : TextureMapMode
        flags*       : TextureFlag

const
    Unlit*               = NoShading
    DefaultMaterialName* = "DefaultMaterial"
    MaxTextureKinds*     = (int high TextureKind) + 1

template `or`(a, b: TextureFlag): TextureFlag {.warning[HoleEnumConv]: off.} =
    TextureFlag ((cint a) or (cint b))

func `$`(prop: MaterialProperty): string =
    let key = green &"\"{prop.key}\""
    result = &"Material property ({key}) of kind {prop.kind}: "
    result &= &"index {prop.index}; data_length {prop.data_length}"
    if prop.tex_kind != None:
        result &= cyan &" ({to_lower_ascii $prop.tex_kind} texture)"

#[ -------------------------------------------------------------------- ]#

using
    pmtl    : ptr Material
    key     : cstring
    prop_out: ptr ptr MaterialProperty
    real_out: ptr UncheckedArray[Real]
    uint_out: ptr UncheckedArray[cuint]

proc texture_type_to_string*(kind: TextureKind): cstring                                              {.importc: "aiTextureTypeToString"    .}
proc get_material_property*(pmtl; key; kind, index: cuint; prop_out): AIReturn                        {.importc: "aiGetMaterialProperty"    .}
proc get_material_float_array*(pmtl; key; kind, index: cuint; real_out; count: ptr cuint): AIReturn   {.importc: "aiGetMaterialFloatArray"  .}
proc get_material_float*(pmtl; key; kind, index: cuint; real_out): AIReturn                           {.importc: "aiGetMaterialFloat"       .}
proc get_material_integer_array*(pmtl; key; kind, index: cuint; uint_out; count: ptr cuint): AIReturn {.importc: "aiGetMaterialIntegerArray".}
proc get_material_integer*(pmtl; key; kind, index: cuint; uint_out): AIReturn                         {.importc: "aiGetMaterialInteger"     .}
proc get_material_color*(pmtl; key; kind, index: cuint; colour_out: ptr Colour): AIReturn             {.importc: "aiGetMaterialColor"       .}
proc get_material_uv_transform*(pmtl; key; kind, index: cuint; trans_out: ptr UVTransform): AIReturn  {.importc: "aiGetMaterialUVTransform" .}
proc get_material_string*(pmtl; key; kind, index: cuint; str_out: ptr AIString): AIReturn             {.importc: "aiGetMaterialString"      .}
proc get_material_texture_count*(pmtl; kind: TextureKind): cuint                                      {.importc: "aiGetMaterialTextureCount".}
proc get_material_texture*(pmtl; kind: TextureKind; index: cuint; path: ptr AIString;
                           mapping: ptr TextureMapping = nil; uv_index: ptr cuint = nil; blend: ptr Real = nil;
                           op: ptr TextureOp = nil; map_mode: ptr TextureMapMode = nil; flags: ptr TextureFlag = nil):
                           AIReturn {.importc: "aiGetMaterialTexture".}

#[ -------------------------------------------------------------------- ]#

template `$`*(kind: TextureKind): string =
    $(texture_type_to_string kind)

template gen_matkey_set(name; base_kind: Matkey) =
    template `matkey name`(kind: TextureKind; n: int): auto = (base_kind, kind, n)
    template `matkey name diffuse`*     (n: int): auto = `matkey name`(Diffuse     , n)
    template `matkey name specular`*    (n: int): auto = `matkey name`(Specular    , n)
    template `matkey name ambient`*     (n: int): auto = `matkey name`(Ambient     , n)
    template `matkey name emissive`*    (n: int): auto = `matkey name`(Emissive    , n)
    template `matkey name normals`*     (n: int): auto = `matkey name`(Normals     , n)
    template `matkey name height`*      (n: int): auto = `matkey name`(Height      , n)
    template `matkey name shininess`*   (n: int): auto = `matkey name`(Shininess   , n)
    template `matkey name opacity`*     (n: int): auto = `matkey name`(Opacity     , n)
    template `matkey name displacement`*(n: int): auto = `matkey name`(Displacement, n)
    template `matkey name lightmap`*    (n: int): auto = `matkey name`(Lightmap    , n)
    template `matkey name reflection`*  (n: int): auto = `matkey name`(Reflection  , n)

gen_matkey_set(texture       , TextureBase)
gen_matkey_set(uvw_src       , UVWSrcBase)
gen_matkey_set(tex_op        , TexOpBase)
gen_matkey_set(mapping       , MappingBase)
gen_matkey_set(tex_blend     , TexBlendBase)
gen_matkey_set(mapping_mode_u, MappingModeUBase)
gen_matkey_set(mapping_mode_v, MappingModeVBase)
gen_matkey_set(tex_map_axis  , TexMapAxisBase)
gen_matkey_set(uv_transform  , UVTransformBase)
gen_matkey_set(tex_flags     , TexFlagsBase)

{.push inline.}

proc texture_count*(mtl: ptr Material; kind: TextureKind): int =
    int (mtl.get_material_texture_count kind)

proc texture*(mtl: ptr Material; kind: TextureKind; index = 0): Option[TextureData] =
    var
        data    : TextureData
        path    : AIString
        uv_index: cuint
    if mtl.get_material_texture(kind, cuint index, path.addr, data.mapping.addr,
                                uv_index.addr, data.blend_factor.addr, data.texture_op.addr,
                                data.map_mode.addr, data.flags.addr) != Success:
        none TextureData
    else:
        data.kind     = kind
        data.path     = $path
        data.uv_index = int uv_index
        some data

proc textures*(mtl: ptr Material): seq[TextureData] =
    for kind in TextureKind:
        let count = mtl.texture_count kind
        for i in 0 ..< count:
            let data = mtl.texture kind
            if is_some data:
                result.add (get data)

{.pop.}

proc `$`*(mtl: Material): string =
    var prop: array[Matkey, ptr MaterialProperty]
    result = &"Material ({mtl.allocated_count}B allocated for {mtl.properties_count} properties)\n"
    # for key in Matkey:
    #     if get_material_property(mtl.addr, $key, 0, 0, prop[key].addr) == Success:
    #         result &= cyan &"    {key}\n"

    for kind in TextureKind:
        let count = mtl.addr.texture_count kind
        for i in 0 ..< count:
            let data = mtl.addr.texture kind
            if is_some data:
                let data = get data
                result &= cyan &"    {count} {kind} ([{data.uv_index}] {data.path})\n"
