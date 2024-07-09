import common, assimp/assimp, nai, ispctc
from std/sequtils import filter_it
from std/strutils import join

type TextureDescriptor* = object
    kind*     : TextureKind
    format*   : TextureFormat
    container*: ContainerKind
    texture*  : AITextureData

converter tex_fmt_to_cmp_kind*(kind: TextureFormat): TextureCompressionKind =
    case kind
    of tfRGB    : cmpNoneRGB
    of tfRGBA   : cmpNoneRGBA
    of tfBC1    : cmpBC1
    of tfBC3    : cmpBC3
    of tfBC4    : cmpBC4
    of tfBC5    : cmpBC5
    of tfBC6H   : cmpBC6H
    of tfBC7    : cmpBC7
    of tfETC1   : cmpETC1
    of tfASTC4x4: cmpASTC
    else:
        error &"Cannot convert '{kind}' to `TextureCompressionKind`"
        quit 1

converter mtl_value_to_matkey*(val: MaterialValue): AIMatkey =
    case val
    of mtlName                     : mkName
    of mtlTwoSided                 : mkTwoSided
    of mtlBaseColour               : mkBaseColour
    of mtlMetallicFactor           : mkMetallicFactor
    of mtlRoughnessFactor          : mkRoughnessFactor
    of mtlSpecularFactor           : mkSpecularFactor
    of mtlGlossinessFactor         : mkGlossinessFactor
    of mtlAnisotropyFactor         : mkAnisotropyFactor
    of mtlSheenColourFactor        : mkSheenColourFactor
    of mtlSheenRoughnessFactor     : mkSheenRoughnessFactor
    of mtlClearcoatFactor          : mkClearcoatFactor
    of mtlClearcoatRoughnessFactor : mkClearcoatRoughnessFactor
    of mtlOpacity                  : mkOpacity
    of mtlBumpScaling              : mkBumpScaling
    of mtlShininess                : mkShininess
    of mtlReflectivity             : mkReflectivity
    of mtlRefractiveIndex          : mkRefractiveIndex
    of mtlColourDiffuse            : mkColourDiffuse
    of mtlColourAmbient            : mkColourAmbient
    of mtlColourSpecular           : mkColourSpecular
    of mtlColourEmissive           : mkColourEmissive
    of mtlColourTransparent        : mkColourTransparent
    of mtlColourReflective         : mkColourReflective
    of mtlTransmissionFactor       : mkTransmissionFactor
    of mtlVolumeThicknessFactor    : mkVolumeThicknessFactor
    of mtlVolumeAttenuationDistance: mkVolumeAttenuationDistance
    of mtlVolumeAttenuationColour  : mkVolumeAttenuationColour
    of mtlEmissiveIntensity        : mkEmissiveIntensity
    of mtlNone:
        error &"Cannot convert '{val}' to AIMatkey"
        quit 1

proc `$`*(header: Header): string =
    let valid_msg = if header.magic == NAIMagic: "valid" else: "invalid"
    let vert_kinds = header.vertex_kinds.filter_it   : it != vtxNone
    let mtl_values = header.material_values.filter_it: it != mtlNone
    &"""
Nai file header:
    Magic number    -> {header.magic} ({valid_msg})
    Version         -> {header.version[0]}.{header.version[1]}
    Layout mask     -> {header.layout_mask}
    Vertex kinds    -> {vert_kinds.join ", "}
    Material values -> {mtl_values.join ", "}
    Mesh count      -> {header.mesh_count}
    Material count  -> {header.material_count}
    Texture count   -> {header.texture_count}
    Animation count -> {header.animation_count}
    Skeleton count  -> {header.skeleton_count}
"""

func abbrev*(kind: VertexKind): string =
    case kind
    of vtxNone      : ""
    of vtxPosition  : "xyz"
    of vtxNormal    : "nnn"
    of vtxTangent   : "ttt"
    of vtxBitangent : "bbb"
    of vtxColourRGBA: "rgb"
    of vtxColourRGB : "rgba"
    of vtxUV        : "uv"
    of vtxUV3       : "uvt"

