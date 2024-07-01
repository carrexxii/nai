# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/options, common, "../bitgen"
from std/strutils import to_lower_ascii, align_left

const AIMaxTextureHintLen* = 9

type
    AITextureKind* {.size: sizeof(cint).} = enum
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

    AITextureOp* {.size: sizeof(cint).} = enum
        Multiply
        Add
        Subtract
        Divide
        SmoothAdd
        SignedAdd

    AITextureMapMode* {.size: sizeof(cint).} = enum
        Wrap
        Clamp
        Mirror
        Decal

    AITextureMapping* {.size: sizeof(cint).} = enum
        UV
        Sphere
        Cylinder
        Box
        Plane
        Other

    AIShadingMode* {.size: sizeof(cint).} = enum
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

    AIBlendMode* {.size: sizeof(cint).} = enum
        Default
        Additive

    AIPropertyKindInfo* {.size: sizeof(cint).} = enum
        Float
        Double
        String
        Integer
        Buffer

    AIMatkey* {.size: sizeof(cstring).} = enum
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
        RefractiveIndex           = "$mat.refracti"
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

type AITextureFlag* = distinct uint32
AITextureFlag.gen_bit_ops(
    Invert,
    UseAlpha,
    IgnoreAlpha,
)

type
    AITexture* = object
        width*      : uint32
        height*     : uint32
        format_hint*: array[AIMaxTextureHintLen, byte]
        data*       : ptr UncheckedArray[AITexel]
        filename*   : AIString

    AITexel* = object
        b, g, r, a: uint8

    AIMaterial* = object
        properties*      : ptr UncheckedArray[ptr AIMaterialProperty]
        properties_count*: uint32
        allocated_count* : uint32

    AIMaterialProperty* = object
        key        : AIString
        tex_kind   : AITextureKind # "semantic"
        index      : uint32
        data_length: uint32
        kind       : AIPropertyKindInfo
        data       : ptr byte

    AIUVTransform* {.packed.} = object
        translation: AIVec2
        scaling    : AIVec2
        rotation   : AIReal

    AITextureData* = object
        kind*        : AITextureKind
        path*        : string
        mapping*     : AITextureMapping
        uv_index*    : int
        blend_factor*: AIReal
        texture_op*  : AITextureOp
        map_mode*    : AITextureMapMode
        flags*       : AITextureFlag

    AITextureValueKind* = enum
        Boolean
        Integer
        Float
        String
        Vector
    AITextureValue* = object
        case kind*: AITextureValueKind
        of Boolean: bln*: bool
        of Integer: num*: int
        of Float  : flt*: float32
        of String : str*: string
        of Vector : vec*: array[4, float32]

const
    Unlit*               = NoShading
    DefaultMaterialName* = "DefaultMaterial"
    MaxTextureKinds*     = (int high AITextureKind) + 1

template `or`(a, b: AITextureFlag): AITextureFlag {.warning[HoleEnumConv]: off.} =
    TextureFlag ((cint a) or (cint b))

func `$`(prop: AIMaterialProperty): string =
    let key = &"\"{prop.key}\""
    result = &"Material property ({key}) of kind {prop.kind}: "
    result &= &"index {prop.index}; data_length {prop.data_length}"
    if prop.tex_kind != None:
        result &= &" ({to_lower_ascii $prop.tex_kind} texture)"

#[ -------------------------------------------------------------------- ]#

using
    pmtl    : ptr AIMaterial
    key     : cstring
    prop_out: ptr ptr AIMaterialProperty
    real_out: ptr UncheckedArray[AIReal]
    uint_out: ptr UncheckedArray[cuint]

{.push dynlib: AssimpPath.}
proc texture_type_to_string*(kind: AITextureKind): cstring                                             {.importc: "aiTextureTypeToString"    .}
proc get_material_property*(pmtl; key; kind, index: cuint; prop_out): AIReturn                         {.importc: "aiGetMaterialProperty"    .}
proc get_material_float_array*(pmtl; key; kind, index: cuint; real_out; count: ptr cuint): AIReturn    {.importc: "aiGetMaterialFloatArray"  .}
proc get_material_integer_array*(pmtl; key; kind, index: cuint; uint_out; count: ptr cuint): AIReturn  {.importc: "aiGetMaterialIntegerArray".}
proc get_material_color*(pmtl; key; kind, index: cuint; colour_out: ptr AIColour): AIReturn            {.importc: "aiGetMaterialColor"       .}
proc get_material_uv_transform*(pmtl; key; kind, index: cuint; trans_out: ptr AIUVTransform): AIReturn {.importc: "aiGetMaterialUVTransform" .}
proc get_material_string*(pmtl; key; kind, index: cuint; str_out: ptr AIString): AIReturn              {.importc: "aiGetMaterialString"      .}
proc get_material_texture_count*(pmtl; kind: AITextureKind): cuint                                     {.importc: "aiGetMaterialTextureCount".}
proc get_material_texture*(pmtl; kind: AITextureKind; index: cuint; path: ptr AIString;
                           mapping: ptr AITextureMapping = nil; uv_index: ptr cuint = nil; blend: ptr AIReal = nil;
                           op: ptr AITextureOp = nil; map_mode: ptr AITextureMapMode = nil; flags: ptr AITextureFlag = nil):
                           AIReturn {.importc: "aiGetMaterialTexture".}
{.pop.}

#[ -------------------------------------------------------------------- ]#

template `$`*(kind: AITextureKind): string =
    $(texture_type_to_string kind)

proc texture_count*(mtl: ptr AIMaterial; kind: AITextureKind): int =
    int (mtl.get_material_texture_count kind)

proc texture*(mtl: ptr AIMaterial; kind: AITextureKind; index = 0): Option[AITextureData] =
    var
        data    : AITextureData
        path    : AIString
        uv_index: cuint
    if mtl.get_material_texture(kind, cuint index, path.addr, data.mapping.addr,
                                uv_index.addr, data.blend_factor.addr, data.texture_op.addr,
                                data.map_mode.addr, data.flags.addr) != Success:
        none AITextureData
    else:
        data.kind     = kind
        data.path     = $path
        data.uv_index = int uv_index
        some data

proc textures*(mtl: ptr AIMaterial): seq[AITextureData] =
    for kind in AITextureKind:
        let count = mtl.texture_count kind
        for i in 0 ..< count:
            let data = mtl.texture kind
            if is_some data:
                result.add (get data)

proc get_value*(mtl: ptr AIMaterial; key: AIMatkey): AITextureValue =
    var res: AIReturn
    template get(T: typedesc) =
        when T is array[4, float32]:
            result = AITextureValue(kind: Vector)
            res = mtl.get_material_float_array($key, 0, 0, cast[ptr UncheckedArray[AIReal]](result.vec[0].addr), nil)
        elif T is float32:
            result = AITextureValue(kind: Float)
            res = mtl.get_material_float_array($key, 0, 0, cast[ptr UncheckedArray[AIReal]](result.flt.addr), nil)
        elif T is string:
            var buf: AIString
            res = mtl.get_material_string($key, 0, 0, buf.addr)
            result = AITextureValue(
                kind: String,
                str : $buf,
            )

    case key
    of Name: get string
    of TwoSided: get bool
    of BaseColour               , ColourDiffuse     , ColourAmbient,
       ColourSpecular           , ColourEmissive    , ColourTransparent,
       ColourReflective         , TransmissionFactor, VolumeThicknessFactor,
       VolumeAttenuationDistance, EmissiveIntensity , VolumeAttenuationColour:
       get array[4, float32]
    of MetallicFactor      , RoughnessFactor , SpecularFactor,
       GlossinessFactor    , AnisotropyFactor, SheenColourFactor,
       SheenRoughnessFactor, ClearcoatFactor , ClearcoatRoughnessFactor,
       Opacity             , BumpScaling     , Shininess,
       Reflectivity        , RefractiveIndex:
       get float32
    else:
        assert false, &"'{key}' has not been implemented"

    if res != Success:
        echo &"Failed to get material data ({key}) for {mtl[]}"

proc `$`*(mtl: AIMaterial): string =
    let name = (mtl.addr.get_value Name).str
    var prop: array[AIMatkey, ptr AIMaterialProperty]
    result = &"Material '{name}' ({mtl.allocated_count}B allocated for {mtl.properties_count} properties)\n"
    # for key in Matkey:
    #     if get_material_property(mtl.addr, $key, 0, 0, prop[key].addr) == Success:
    #         result &= cyan &"    {key}\n"

    for kind in AITextureKind:
        let count = mtl.addr.texture_count kind
        for i in 0 ..< count:
            let data = mtl.addr.texture kind
            if is_some data:
                let data = get data
                result &= (&"    {count} {kind}").align_left 32
                result &= &"(UVs: {data.uv_index}; Path: '{data.path}')\n"

proc `$`*(texture: AITexture): string =
    var fmt_hint = new_string AIMaxTextureHintLen
    copy_mem(fmt_hint[0].addr, texture.format_hint[0].addr, AIMaxTextureHintLen)
    result = &"""
Texture '{texture.filename}' ({texture.width}x{texture.height}):
    Format hint      -> {fmt_hint}
    Data is internal -> {texture.data != nil}
"""

