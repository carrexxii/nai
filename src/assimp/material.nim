# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/options, common, bitgen
from std/strutils import to_lower_ascii, align_left

const AiMaxTextureHintLen* = 9

type AiTextureFlag* = distinct uint32
AiTextureFlag.gen_bit_ops texInvert, texUseAlpha, texIgnoreAlpha

type
    AiTextureKind* {.size: sizeof(cint).} = enum
        tkNone
        tkDiffuse
        tkSpecular
        tkAmbient
        tkEmissive
        tkHeight
        tkNormals
        tkShininess
        tkOpacity
        tkDisplacement
        tkLightmap
        tkReflection
        tkBaseColour
        tkNormalCamera
        tkEmissionColour
        tkMetalness
        tkDiffuseRoughness
        tkAmbientOcclusion
        tkUnknown
        tkSheen
        tkClearcoat
        tkTransmission

    AiTextureOp* {.size: sizeof(cint).} = enum
        toMultiply
        toAdd
        toSubtract
        toDivide
        toSmoothAdd
        toSignedAdd

    AiTextureMapMode* {.size: sizeof(cint).} = enum
        tmmWrap
        tmmClamp
        tmmMirror
        tmmDecal

    AiTextureMapping* {.size: sizeof(cint).} = enum
        tmUv
        tmSphere
        tmCylinder
        tmBox
        tmPlane
        tmOther

    AiShadingMode* {.size: sizeof(cint).} = enum
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
        smPbrBrfd

    AiBlendMode* {.size: sizeof(cint).} = enum
        bmDefault
        bmAdditive

    AiPropertyKindInfo* {.size: sizeof(cint).} = enum
        pkiFloat
        pkiDouble
        pkiString
        pkiInteger
        pkiBuffer

    AiMatKey* {.size: sizeof(cstring).} = enum
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

type
    AiTexture* = object
        w*, h*   : uint32
        fmt_hint*: array[AiMaxTextureHintLen, byte]
        data*    : ptr UncheckedArray[AiTexel]
        filename*: AiString

    AiTexel* = object
        b*, g*, r*, a*: uint8

    AiMaterial* = object
        props*     : ptr UncheckedArray[ptr AiMaterialProperty]
        prop_count*: uint32
        alloced*   : uint32

    AiMaterialProperty* = object
        key*     : AiString
        tex_kind*: AiTextureKind # "semantic"
        idx*     : uint32
        data_len*: uint32
        kind*    : AiPropertyKindInfo
        data*    : ptr byte

    AiUvTransform* {.packed.} = object
        trans*: AiVec2
        scale*: AiVec2
        rot*  : AiReal

    AiTextureData* = object
        kind*     : AiTextureKind
        path*     : string
        mapping*  : AiTextureMapping
        uv_idx*   : int
        blend_fac*: AiReal
        tex_op*   : AiTextureOp
        map_mode* : AiTextureMapMode
        flags*    : AiTextureFlag

    AiTextureValueKind* = enum
        tvkBoolean
        tvkInteger
        tvkFloat
        tvkString
        tvkVector
    AiTextureValue* = object
        case kind*: AiTextureValueKind
        of tvkBoolean: bln*: bool
        of tvkInteger: num*: int
        of tvkFloat  : flt*: float32
        of tvkString : str*: string
        of tvkVector : vec*: array[4, float32]

const
    Unlit*               = smNoShading
    DefaultMaterialName* = "DefaultMaterial"
    MaxTextureKinds*     = (int high AiTextureKind) + 1

func `$`(prop: AiMaterialProperty): string =
    let key = &"\"{prop.key}\""
    result = &"Material property ({key}) of kind {prop.kind}: "
    result &= &"index {prop.idx}; data_length {prop.data_len}"
    if prop.tex_kind != tkNone:
        result &= &" ({to_lower_ascii $prop.tex_kind} texture)"

#[ -------------------------------------------------------------------- ]#

using
    pmtl    : ptr AiMaterial
    key     : cstring
    prop_out: ptr ptr AiMaterialProperty
    real_out: ptr UncheckedArray[AiReal]
    uint_out: ptr UncheckedArray[cuint]

proc texture_type_to_string*(kind: AiTextureKind): cstring                                             {.importc: "aiTextureTypeToString"    .}
proc get_material_property*(pmtl; key; kind, index: cuint; prop_out): AiReturn                         {.importc: "aiGetMaterialProperty"    .}
proc get_material_float_array*(pmtl; key; kind, index: cuint; real_out; count: ptr cuint): AiReturn    {.importc: "aiGetMaterialFloatArray"  .}
proc get_material_integer_array*(pmtl; key; kind, index: cuint; uint_out; count: ptr cuint): AiReturn  {.importc: "aiGetMaterialIntegerArray".}
proc get_material_color*(pmtl; key; kind, index: cuint; colour_out: ptr AiColour): AiReturn            {.importc: "aiGetMaterialColor"       .}
proc get_material_uv_transform*(pmtl; key; kind, index: cuint; trans_out: ptr AiUVTransform): AiReturn {.importc: "aiGetMaterialUVTransform" .}
proc get_material_string*(pmtl; key; kind, index: cuint; str_out: ptr AiString): AiReturn              {.importc: "aiGetMaterialString"      .}
proc get_material_texture_count*(pmtl; kind: AiTextureKind): cuint                                     {.importc: "aiGetMaterialTextureCount".}
proc get_material_texture*(pmtl; kind: AiTextureKind; index: cuint; path: ptr AiString;
                           mapping: ptr AiTextureMapping = nil; uv_index: ptr cuint = nil; blend: ptr AiReal = nil;
                           op: ptr AiTextureOp = nil; map_mode: ptr AiTextureMapMode = nil; flags: ptr AiTextureFlag = nil;
                           ): AiReturn {.importc: "aiGetMaterialTexture".}

#[ -------------------------------------------------------------------- ]#

template `$`*(kind: AiTextureKind): string =
    $(texture_type_to_string kind)

proc texture_count*(mtl: ptr AiMaterial; kind: AiTextureKind): int =
    int (mtl.get_material_texture_count kind)

proc texture*(mtl: ptr AiMaterial; kind: AiTextureKind; index = 0): Option[AiTextureData] =
    var
        data  : AiTextureData
        path  : AiString
        uv_idx: cuint
    if mtl.get_material_texture(kind, cuint index, path.addr, data.mapping.addr,
                                uv_idx.addr, data.blend_fac.addr, data.tex_op.addr,
                                data.map_mode.addr, data.flags.addr) != returnSuccess:
        none AiTextureData
    else:
        data.kind   = kind
        data.path   = $path
        data.uv_idx = int uv_idx
        some data

proc textures*(mtl: ptr AiMaterial): seq[AiTextureData] =
    for kind in AiTextureKind:
        let count = mtl.texture_count kind
        for i in 0 ..< count:
            let data = mtl.texture kind
            if is_some data:
                result.add (get data)

proc get_value*(mtl: ptr AiMaterial; key: AiMatKey): AiTextureValue =
    var res: AiReturn
    template get(T: typedesc) =
        when T is array[4, float32]:
            result = AiTextureValue(kind: tvkVector)
            res = mtl.get_material_float_array(cstring $key, 0, 0, cast[ptr UncheckedArray[AiReal]](result.vec[0].addr), nil)
        elif T is float32:
            result = AiTextureValue(kind: tvkFloat)
            res = mtl.get_material_float_array(cstring $key, 0, 0, cast[ptr UncheckedArray[AiReal]](result.flt.addr), nil)
        elif T is string:
            var buf: AiString
            res = mtl.get_material_string(cstring $key, 0, 0, buf.addr)
            result = AiTextureValue(
                kind: tvkString,
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

    if res != returnSuccess:
        echo &"Failed to get material data ({key}) for {mtl[]}"

proc `$`*(mtl_in: AiMaterial | ptr AiMaterial): string =
    let mtl = when mtl_in is AiMaterial: mtl_in.addr else: mtl_in
    result = &"Material '{(mtl.get_value mkName).str}'\n"
    for kind in AiTextureKind:
        let count = mtl.texture_count kind
        for i in 0..<count:
            let data = mtl.texture kind
            if is_some data:
                let data = get data
                result &= (&"    {count} {kind}").align_left 28
                result &= &"(UVs: {data.uv_idx}; Path: '{data.path}')\n"

proc `$`*(tex: AiTexture | ptr AiTexture): string =
    var fmt_hint = new_string AiMaxTextureHintLen
    copy_mem(fmt_hint[0].addr, tex.fmt_hint[0].addr, AiMaxTextureHintLen)
    &"""
Texture '{tex.filename}' ({tex.w}x{tex.h}):
    Format hint         '{fmt_hint}'
    Data is internal    {tex.data != nil}
"""
