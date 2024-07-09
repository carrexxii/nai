# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[strutils, sequtils],
    common, assimp/assimp, ispctc
from std/strformat import `&`

const NAIMagic*  : array[4, byte] = [78, 65, 73, 126] # "NAI~"
const NAIVersion*: array[2, byte] = [0, 0]

type
    LayoutFlag* = enum
        lfVerticesInterleaved
        lfVerticesSeparated
        lfTexturesInternal
        lfTexturesExternal
    LayoutMask* {.size: sizeof(uint16).} = set[LayoutFlag]

    CompressionKind* {.size: sizeof(uint16).} = enum
        cmpNone
        cmpZLib

    ContainerKind* = enum
        cntNone
        cntDDS
        cntPNG

    VertexKind* {.size: sizeof(uint8).} = enum
        vtxNone
        vtxPosition
        vtxNormal
        vtxTangent
        vtxBitangent
        vtxColourRGBA
        vtxColourRGB
        vtxUV
        vtxUV3

    MaterialValue* {.size: sizeof(uint8).} = enum
        mtlNone
        mtlName
        mtlTwoSided
        mtlBaseColour
        mtlMetallicFactor
        mtlRoughnessFactor
        mtlSpecularFactor
        mtlGlossinessFactor
        mtlAnisotropyFactor
        mtlSheenColourFactor
        mtlSheenRoughnessFactor
        mtlClearcoatFactor
        mtlClearcoatRoughnessFactor
        mtlOpacity
        mtlBumpScaling
        mtlShininess
        mtlReflectivity
        mtlRefractiveIndex
        mtlColourDiffuse
        mtlColourAmbient
        mtlColourSpecular
        mtlColourEmissive
        mtlColourTransparent
        mtlColourReflective
        mtlTransmissionFactor
        mtlVolumeThicknessFactor
        mtlVolumeAttenuationDistance
        mtlVolumeAttenuationColour
        mtlEmissiveIntensity

    TextureKind* {.size: sizeof(uint16).} = enum
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

    TextureFormat* {.size: sizeof(uint16).} = enum
        tfNone

        tfR
        tfRG
        tfRGB
        tfRGBA

        tfBC1 = 100
        tfBC3
        tfBC4
        tfBC5
        tfBC6H
        tfBC7

        tfETC1 = 200

        tfASTC4x4 = 300

    IndexSize* {.size: sizeof(uint16).} = enum
        iszNone
        isz8Bit
        isz16Bit
        isz32Bit
        isz64Bit

type
    Header* = object
        magic*           : array[4, byte]
        version*         : array[2, byte]
        layout_mask*     : LayoutMask
        vertex_kinds*    : array[8, VertexKind]
        material_values* : array[8, MaterialValue]
        compression_kind*: CompressionKind
        mesh_count*      : uint16
        material_count*  : uint16
        texture_count*   : uint16
        animation_count* : uint16
        skeleton_count*  : uint16

    MeshHeader* = object
        material_index*: uint16
        index_size*    : IndexSize
        vert_count*    : uint32
        index_count*   : uint32
        # verts: array[vert_count, float32]

    MaterialHeader* = object
        texture_count*: uint16
        _             : uint16
        # material_data: struct
        # texture_data : array[texture_count, TextureHeader]

    TextureHeader* = object
        kind*  : TextureKind
        format*: TextureFormat
        w*, h* : uint16
        # data: array[<format_size> * w * h, byte]

    TextureDescriptor* = object
        kind*     : TextureKind
        format*   : TextureFormat
        container*: ContainerKind
        texture*  : AITextureData

#[ -------------------------------------------------------------------- ]#

converter index_size_to_int*(kind: IndexSize): int =
    case kind
    of iszNone   : 0
    of isz8Bit : 1
    of isz16Bit: 2
    of isz32Bit: 4
    of isz64Bit: 8

converter tex_fmt_to_cmp_kind*(kind: TextureFormat): TextureCompressionKind =
    case kind
    of tfRGB    : NoneRGB
    of tfRGBA   : NoneRGBA
    of tfBC1    : BC1
    of tfBC3    : BC3
    of tfBC4    : BC4
    of tfBC5    : BC5
    of tfBC6H   : BC6H
    of tfBC7    : BC7
    of tfETC1   : ETC1
    of tfASTC4x4: ASTC
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
    &"Nai file header:\n"                                               &
    &"    Magic number    -> {header.magic} ({valid_msg})\n"            &
    &"    Version         -> {header.version[0]}.{header.version[1]}\n" &
    &"    Layout mask     -> {header.layout_mask}\n"                    &
    &"    Vertex kinds    -> {vert_kinds.join \", \"}\n"                &
    &"    Material values -> {mtl_values.join \", \"}\n"                &
    &"    Mesh count      -> {header.mesh_count}\n"                     &
    &"    Material count  -> {header.material_count}\n"                 &
    &"    Texture count   -> {header.texture_count}\n"                  &
    &"    Animation count -> {header.animation_count}\n"                &
    &"    Skeleton count  -> {header.skeleton_count}\n"

func size*(kind: VertexKind): int =
    case kind
    of vtxNone: 0
    of vtxPosition, vtxNormal,
       vtxTangent , vtxBitangent,
       vtxUV3       : 3 * (sizeof float32)
    of vtxColourRGBA: 4 * (sizeof uint8)
    of vtxColourRGB : 3 * (sizeof uint8)
    of vtxUV        : 2 * (sizeof float32)

func bpp*(kind: TextureFormat): int =
    case kind
    of tfNone: 0
    of tfRG  : 16
    of tfRGB : 24
    of tfRGBA: 32
    of tfBC1, tfBC4: 4
    of tfR, tfBC3, tfBC5, tfBC6H, tfBC7: 8
    of tfETC1   : 0 # TODO
    of tfASTC4x4: 0 # TODO

func size*(kind: MaterialValue): int =
    case kind
    of mtlBaseColour       , mtlColourDiffuse , mtlVolumeAttenuationColour,
       mtlColourAmbient    , mtlColourSpecular, mtlColourEmissive,
       mtlColourTransparent, mtlColourReflective: 16
    of mtlTwoSided: 1
    else: 4

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

# Keep synced with the header file
static:
    assert (sizeof Header)         == 36
    assert (sizeof MeshHeader)     == 12
    assert (sizeof MaterialHeader) == 4
    assert (sizeof TextureHeader)  == 8

