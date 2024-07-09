# zlib License
#
# (C) 2024 carrexxii
#
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.

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

converter index_size_to_int*(kind: IndexSize): int =
    case kind
    of iszNone : 0
    of isz8Bit : 1
    of isz16Bit: 2
    of isz32Bit: 4
    of isz64Bit: 8

func size*(kind: VertexKind): int =
    case kind
    of vtxNone: 0
    of vtxPosition, vtxNormal,
       vtxTangent , vtxBitangent,
       vtxUV3       : 3 * sizeof float32
    of vtxColourRGBA: 4 * sizeof uint8
    of vtxColourRGB : 3 * sizeof uint8
    of vtxUV        : 2 * sizeof float32

func size*(kind: MaterialValue): int =
    case kind
    of mtlBaseColour       , mtlColourDiffuse , mtlVolumeAttenuationColour,
       mtlColourAmbient    , mtlColourSpecular, mtlColourEmissive,
       mtlColourTransparent, mtlColourReflective: 16
    of mtlTwoSided: 1
    else: 4

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

