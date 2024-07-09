# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/options, common, "../bitgen"
from std/strutils import to_lower_ascii, align_left

const AIMaxTextureHintLen* = 9

type
    AITextureKind* {.size: sizeof(cint).} = enum
        texNone
        texDiffuse
        texSpecular
        texAmbient
        texEmissive
        texHeight
        texNormals
        texShininess
        texOpacity
        texDisplacement
        texLightmap
        texReflection
        texBaseColour
        texNormalCamera
        texEmissionColour
        texMetalness
        texDiffuseRoughness
        texAmbientOcclusion
        texUnknown
        texSheen
        texClearcoat
        texTransmission

    AITextureOp* {.size: sizeof(cint).} = enum
        opMultiply
        opAdd
        opSubtract
        opDivide
        opSmoothAdd
        opSignedAdd

    AITextureMapMode* {.size: sizeof(cint).} = enum
        texWrap
        texClamp
        texMirror
        texDecal

    AITextureMapping* {.size: sizeof(cint).} = enum
        mapUV
        mapSphere
        mapCylinder
        mapBox
        mapPlane
        mapOther

    AIShadingMode* {.size: sizeof(cint).} = enum
        smFlat
        smGouraud
        smPhong
        smBlinn
        smToon
        smOrenNayar
        smMinnaert
        smCookTorrance
        smNoShading
        smFresnel
        smPBRBRDF

    AIBlendMode* {.size: sizeof(cint).} = enum
        bmDefault
        bmAdditive

    AIPropertyKindInfo* {.size: sizeof(cint).} = enum
        pkFloat
        pkDouble
        pkString
        pkInteger
        pkBuffer

    AIMatkey* {.size: sizeof(cstring).} = enum
        mkName                      = "?mat.name"
        mkTwoSided                  = "$mat.twosided"
        mkShadingModel              = "$mat.shadingm"
        mkEnableWireframe           = "$mat.wireframe"
        mkBlendFunc                 = "$mat.blend"
        mkOpacity                   = "$mat.opacity"
        mkTransparencyFactor        = "$mat.transparencyfactor"
        mkBumpScaling               = "$mat.bumpscaling"
        mkShininess                 = "$mat.shininess"
        mkReflectivity              = "$mat.reflectivity"
        mkShininessStrength         = "$mat.shinpercent"
        mkRefractiveIndex           = "$mat.refracti"
        mkColourDiffuse             = "$clr.diffuse"
        mkColourAmbient             = "$clr.ambient"
        mkColourSpecular            = "$clr.specular"
        mkColourEmissive            = "$clr.emissive"
        mkColourTransparent         = "$clr.transparent"
        mkColourReflective          = "$clr.reflective"
        mkGlobalBackgroundImage     = "?bg.global"
        mkGlobalShaderLang          = "?sh.lang"
        mkShaderVertex              = "?sh.vs"
        mkShaderFragment            = "?sh.fs"
        mkShaderGeo                 = "?sh.gs"
        mkShaderTesselation         = "?sh.ts"
        mkShaderPrimitive           = "?sh.ps"
        mkShaderCompute             = "?sh.cs"
        mkUseColourMap              = "$mat.useColorMap"
        mkBaseColour                = "$clr.base"
        mkUseMetallicMap            = "$mat.useMetallicMap"
        mkMetallicFactor            = "$mat.metallicFactor"
        mkUseRoughnessMap           = "$mat.useRoughnessMap"
        mkRoughnessFactor           = "$mat.roughnessFactor"
        mkAnisotropyFactor          = "$mat.anisotropyFactor"
        mkSpecularFactor            = "$mat.specularFactor"
        mkGlossinessFactor          = "$mat.glossinessFactor"
        mkSheenColourFactor         = "$clr.sheen.factor"
        mkSheenRoughnessFactor      = "$mat.sheen.roughnessFactor"
        mkClearcoatFactor           = "$mat.clearcoat.factor"
        mkClearcoatRoughnessFactor  = "$mat.clearcoat.roughnessFactor"
        mkTransmissionFactor        = "$mat.transmission.factor"
        mkVolumeThicknessFactor     = "$mat.volume.thicknessFactor"
        mkVolumeAttenuationDistance = "$mat.volume.attenuationDistance"
        mkVolumeAttenuationColour   = "$mat.volume.attenuationColor"
        mkUseEmissiveMap            = "$mat.useEmissiveMap"
        mkEmissiveIntensity         = "$mat.emissiveIntensity"
        mkUseAOMap                  = "$mat.useAOMap"
        mkTextureBase               = "$tex.file"
        mkUVWSrcBase                = "$tex.uvwsrc"
        mkTexOpBase                 = "$tex.op"
        mkMappingBase               = "$tex.mapping"
        mkTexBlendBase              = "$tex.blend"
        mkMappingModeUBase          = "$tex.mapmodeu"
        mkMappingModeVBase          = "$tex.mapmodev"
        mkTexMapAxisBase            = "$tex.mapaxis"
        mkUVTransformBase           = "$tex.uvtrafo"
        mkTexFlagsBase              = "$tex.flags"

    #     mkBaseColourTexture         = (TextureKind.texBaseColour      , 0)
    #     mkMetallicTexture           = (TextureKind.texMetalness       , 0)
    #     mkRoughnessTexture          = (TextureKind.texDiffuseRoughness, 0)
    #     mkSheenColourTexture        = (TextureKind.texSheen           , 0)
    #     mkSheenRoughnessTexture     = (TextureKind.texSheen           , 1)
    #     mkClearcoatTexture          = (TextureKind.texClearcoat       , 0)
    #     mkClearcoatRoughnessTexture = (TextureKind.texClearcoat       , 1)
    #     mkClearcoatNormalTexture    = (TextureKind.texClearcoat       , 2)
    #     mkTransmissionTexture       = (TextureKind.texTransmission    , 0)
    #     mkVolumeThicknessTexture    = (TextureKind.texTransmission    , 1)

type AITextureFlag* = distinct uint32
AITextureFlag.gen_bit_ops(
    texInvert,
    texUseAlpha,
    texIgnoreAlpha,
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
        tvBoolean
        tvInteger
        tvFloat
        tvString
        tvVector
    AITextureValue* = object
        case kind*: AITextureValueKind
        of tvBoolean: bln*: bool
        of tvInteger: num*: int
        of tvFloat  : flt*: float32
        of tvString : str*: string
        of tvVector : vec*: array[4, float32]

const
    Unlit*               = smNoShading
    DefaultMaterialName* = "DefaultMaterial"
    MaxTextureKinds*     = (int high AITextureKind) + 1

func `$`(prop: AIMaterialProperty): string =
    let key = &"\"{prop.key}\""
    result = &"Material property ({key}) of kind {prop.kind}: "
    result &= &"index {prop.index}; data_length {prop.data_length}"
    if prop.tex_kind != texNone:
        result &= &" ({to_lower_ascii $prop.tex_kind} texture)"

#[ -------------------------------------------------------------------- ]#

using
    pmtl    : ptr AIMaterial
    key     : cstring
    prop_out: ptr ptr AIMaterialProperty
    real_out: ptr UncheckedArray[AIReal]
    uint_out: ptr UncheckedArray[cuint]

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
                                data.map_mode.addr, data.flags.addr) != aiSuccess:
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
            result = AITextureValue(kind: tvVector)
            res = mtl.get_material_float_array(cstring $key, 0, 0, cast[ptr UncheckedArray[AIReal]](result.vec[0].addr), nil)
        elif T is float32:
            result = AITextureValue(kind: tvFloat)
            res = mtl.get_material_float_array(cstring $key, 0, 0, cast[ptr UncheckedArray[AIReal]](result.flt.addr), nil)
        elif T is string:
            var buf: AIString
            res = mtl.get_material_string(cstring $key, 0, 0, buf.addr)
            result = AITextureValue(
                kind: tvString,
                str : $buf,
            )

    case key
    of mkName: get string
    of mkTwoSided: get bool
    of mkBaseColour               , mkColourDiffuse     , mkColourAmbient,
       mkColourSpecular           , mkColourEmissive    , mkColourTransparent,
       mkColourReflective         , mkTransmissionFactor, mkVolumeThicknessFactor,
       mkVolumeAttenuationDistance, mkEmissiveIntensity , mkVolumeAttenuationColour:
       get array[4, float32]
    of mkMetallicFactor      , mkRoughnessFactor , mkSpecularFactor,
       mkGlossinessFactor    , mkAnisotropyFactor, mkSheenColourFactor,
       mkSheenRoughnessFactor, mkClearcoatFactor , mkClearcoatRoughnessFactor,
       mkOpacity             , mkBumpScaling     , mkShininess,
       mkReflectivity        , mkRefractiveIndex:
       get float32
    else:
        assert false, &"'{key}' has not been implemented"

    if res != aiSuccess:
        echo &"Failed to get material data ({key}) for {mtl[]}"

proc `$`*(mtl_in: AIMaterial | ptr AIMaterial): string =
    let mtl = when mtl_in is AIMaterial: mtl_in.addr else: mtl_in
    result = &"Material '{(mtl.get_value mkName).str}'\n"
    for kind in AITextureKind:
        let count = mtl.texture_count kind
        for i in 0..<count:
            let data = mtl.texture kind
            if is_some data:
                let data = get data
                result &= (&"    {count} {kind}").align_left 28
                result &= &"(UVs: {data.uv_index}; Path: '{data.path}')\n"

proc `$`*(tex: AITexture | ptr AITexture): string =
    var fmt_hint = new_string AIMaxTextureHintLen
    copy_mem(fmt_hint[0].addr, tex.format_hint[0].addr, AIMaxTextureHintLen)
    &"""
Texture '{tex.filename}' ({tex.width}x{tex.height}):
    Format hint         '{fmt_hint}'
    Data is internal    {tex.data != nil}
"""

