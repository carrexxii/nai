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
        VerticesInterleaved = 1 shl 0
        VerticesSeparated   = 1 shl 1
        TexturesInternal    = 1 shl 2
        TexturesExternal    = 1 shl 3
    LayoutMask* {.size: sizeof(uint16).} = set[LayoutFlag]

    CompressionKind* {.size: sizeof(uint16).} = enum
        None
        ZLib

    ContainerKind* = enum
        None
        DDS
        PNG

    VertexKind* {.size: sizeof(uint8).} = enum
        None
        Position
        Normal
        Tangent
        Bitangent
        ColourRGBA
        ColourRGB
        UV
        UV3

    MaterialValue* {.size: sizeof(uint8).} = enum
        None
        Name
        TwoSided
        BaseColour
        MetallicFactor
        RoughnessFactor
        SpecularFactor
        GlossinessFactor
        AnisotropyFactor
        SheenColourFactor
        SheenRoughnessFactor
        ClearcoatFactor
        ClearcoatRoughnessFactor
        Opacity
        BumpScaling
        Shininess
        Reflectivity
        RefractiveIndex
        ColourDiffuse
        ColourAmbient
        ColourSpecular
        ColourEmissive
        ColourTransparent
        ColourReflective
        TransmissionFactor
        VolumeThicknessFactor
        VolumeAttenuationDistance
        VolumeAttenuationColour
        EmissiveIntensity

    TextureKind* {.size: sizeof(uint16).} = enum
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

    TextureFormat* {.size: sizeof(uint16).} = enum
        None

        R
        RG
        RGB
        RGBA

        BC1 = 100
        BC3
        BC4
        BC5
        BC6H
        BC7

        ETC1 = 200

        ASTC4x4 = 300

    IndexSize* {.size: sizeof(uint16).} = enum
        None
        Index8
        Index16
        Index32
        Index64

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
    of None   : 0
    of Index8 : 1
    of Index16: 2
    of Index32: 4
    of Index64: 8

converter tex_fmt_to_cmp_kind*(kind: TextureFormat): TextureCompressionKind =
    case kind
    of RGB    : NoneRGB
    of RGBA   : NoneRGBA
    of BC1    : BC1
    of BC3    : BC3
    of BC4    : BC4
    of BC5    : BC5
    of BC6H   : BC6H
    of BC7    : BC7
    of ETC1   : ETC1
    of ASTC4x4: ASTC
    else:
        error &"Cannot convert '{kind}' to `TextureCompressionKind`"
        quit 1

converter mtl_value_to_matkey*(val: MaterialValue): AIMatkey =
    case val
    of Name                     : AIMatkey.Name
    of TwoSided                 : AIMatkey.TwoSided
    of BaseColour               : AIMatkey.BaseColour
    of MetallicFactor           : AIMatkey.MetallicFactor
    of RoughnessFactor          : AIMatkey.RoughnessFactor
    of SpecularFactor           : AIMatkey.SpecularFactor
    of GlossinessFactor         : AIMatkey.GlossinessFactor
    of AnisotropyFactor         : AIMatkey.AnisotropyFactor
    of SheenColourFactor        : AIMatkey.SheenColourFactor
    of SheenRoughnessFactor     : AIMatkey.SheenRoughnessFactor
    of ClearcoatFactor          : AIMatkey.ClearcoatFactor
    of ClearcoatRoughnessFactor : AIMatkey.ClearcoatRoughnessFactor
    of Opacity                  : AIMatkey.Opacity
    of BumpScaling              : AIMatkey.BumpScaling
    of Shininess                : AIMatkey.Shininess
    of Reflectivity             : AIMatkey.Reflectivity
    of RefractiveIndex          : AIMatkey.RefractiveIndex
    of ColourDiffuse            : AIMatkey.ColourDiffuse
    of ColourAmbient            : AIMatkey.ColourAmbient
    of ColourSpecular           : AIMatkey.ColourSpecular
    of ColourEmissive           : AIMatkey.ColourEmissive
    of ColourTransparent        : AIMatkey.ColourTransparent
    of ColourReflective         : AIMatkey.ColourReflective
    of TransmissionFactor       : AIMatkey.TransmissionFactor
    of VolumeThicknessFactor    : AIMatkey.VolumeThicknessFactor
    of VolumeAttenuationDistance: AIMatkey.VolumeAttenuationDistance
    of VolumeAttenuationColour  : AIMatkey.VolumeAttenuationColour
    of EmissiveIntensity        : AIMatkey.EmissiveIntensity
    of None:
        error &"Should not be converting '{val}' to AIMatkey"
        quit 1

proc `$`*(header: Header): string =
    let valid_msg = if header.magic == NAIMagic: "valid" else: "invalid"
    let vert_kinds = header.vertex_kinds.filter_it   : it != None
    let mtl_values = header.material_values.filter_it: it != None
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
    of None: 0
    of Position, Normal,
       Tangent , Bitangent,
       UV3       : 3 * (sizeof float32)
    of ColourRGBA: 4 * (sizeof uint8)
    of ColourRGB : 3 * (sizeof uint8)
    of UV        : 2 * (sizeof float32)

func bpp*(kind: TextureFormat): int =
    case kind
    of None: 0
    of RG  : 16
    of RGB : 24
    of RGBA: 32
    of BC1, BC4: 4
    of R, BC3, BC5, BC6H, BC7: 8
    of ETC1   : 0 # TODO
    of ASTC4x4: 0 # TODO

func size*(kind: MaterialValue): int =
    case kind
    of BaseColour       , ColourDiffuse , VolumeAttenuationColour,
       ColourAmbient    , ColourSpecular, ColourEmissive,
       ColourTransparent, ColourReflective: 16
    of TwoSided: 1
    else: 4

func abbrev*(kind: VertexKind): string =
    case kind
    of None      : ""
    of Position  : "xyz"
    of Normal    : "nnn"
    of Tangent   : "ttt"
    of Bitangent : "bbb"
    of ColourRGBA: "rgb"
    of ColourRGB : "rgba"
    of UV        : "uv"
    of UV3       : "uvt"

# Keep synced with the header file
static:
    assert (sizeof Header)         == 36
    assert (sizeof MeshHeader)     == 12
    assert (sizeof MaterialHeader) == 4
    assert (sizeof TextureHeader)  == 8

