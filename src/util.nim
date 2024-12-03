import common, assimp/assimp, nai, ispctc
from std/sequtils import filter_it
from std/strutils import join

type TextureDescriptor* = object
    kind*     : TextureKind
    fmt*      : TextureFormat
    container*: ContainerKind
    tex*      : AiTextureData

converter tex_fmt_to_cmp_kind*(kind: TextureFormat): TextureCompressionKind =
    case kind
    of tfRgb    : tckNoneRgb
    of tfRgba   : tckNoneRgba
    of tfBc1    : tckBc1
    of tfBc3    : tckBc3
    of tfBc4    : tckBc4
    of tfBc5    : tckBc5
    of tfBc6H   : tckBc6H
    of tfBc7    : tckBc7
    of tfEtc1   : tckEtc1
    of tfAstc4x4: tckAstc
    else:
        error &"Cannot convert '{kind}' to `TextureCompressionKind`"
        quit 1

converter `MaterialValue -> AiMatkey`*(val: MaterialValue): AiMatkey =
    case val
    of mvName                     : mkName
    of mvTwoSided                 : mkTwoSided
    of mvBaseColour               : mkBaseColour
    of mvMetallicFactor           : mkMetallicFactor
    of mvRoughnessFactor          : mkRoughnessFactor
    of mvSpecularFactor           : mkSpecularFactor
    of mvGlossinessFactor         : mkGlossinessFactor
    of mvAnisotropyFactor         : mkAnisotropyFactor
    of mvSheenColourFactor        : mkSheenColourFactor
    of mvSheenRoughnessFactor     : mkSheenRoughnessFactor
    of mvClearcoatFactor          : mkClearcoatFactor
    of mvClearcoatRoughnessFactor : mkClearcoatRoughnessFactor
    of mvOpacity                  : mkOpacity
    of mvBumpScaling              : mkBumpScaling
    of mvShininess                : mkShininess
    of mvReflectivity             : mkReflectivity
    of mvRefractiveIndex          : mkRefractiveIndex
    of mvColourDiffuse            : mkColourDiffuse
    of mvColourAmbient            : mkColourAmbient
    of mvColourSpecular           : mkColourSpecular
    of mvColourEmissive           : mkColourEmissive
    of mvColourTransparent        : mkColourTransparent
    of mvColourReflective         : mkColourReflective
    of mvTransmissionFactor       : mkTransmissionFactor
    of mvVolumeThicknessFactor    : mkVolumeThicknessFactor
    of mvVolumeAttenuationDistance: mkVolumeAttenuationDistance
    of mvVolumeAttenuationColour  : mkVolumeAttenuationColour
    of mvEmissiveIntensity        : mkEmissiveIntensity
    of mvNone:
        error &"Cannot convert '{val}' to AiMatkey"
        quit 1

proc `$`*(header: Header): string =
    let valid_msg = if header.magic == Magic: "valid" else: "invalid"
    let vtx_kinds = header.vtx_kinds.filter_it: it != vkNone
    let mtl_vals  = header.mtl_vals.filter_it : it != mvNone
    &"""
Nai file header:
    Magic number    -> {header.magic} ({valid_msg})
    Version         -> {header.version[0]}.{header.version[1]}
    Layout mask     -> {header.layout_mask}
    Vertex kinds    -> {vtx_kinds.join ", "}
    Material values -> {mtl_vals.join ", "}
    Mesh count      -> {header.mesh_cnt}
    Material count  -> {header.mtl_cnt}
    Texture count   -> {header.tex_cnt}
    Animation count -> {header.anim_cnt}
    Skeleton count  -> {header.skeleton_cnt}
"""

func abbrev*(kind: VertexKind): string =
    case kind
    of vkNone      : ""
    of vkPosition  : "xyz"
    of vkNormal    : "nnn"
    of vkTangent   : "ttt"
    of vkBitangent : "bbb"
    of vkColourRgba: "rgb"
    of vkColourRgb : "rgba"
    of vkUv        : "uv"
    of vkUv3       : "uvt"
