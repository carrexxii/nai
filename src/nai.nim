# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import assimp/assimp
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
        ZLIB

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

    TextureKind* = AITextureKind

    TextureFormat* {.size: sizeof(uint32).} = enum
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
        N8
        N16
        N32

type
    Header* = object
        magic*           : array[4, byte]
        version*         : array[2, byte]
        layout_flags*    : LayoutMask
        vertex_flags*    : array[8, VertexKind]
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
        verts*         : UncheckedArray[float32]

    MaterialHeader* = object
        base_colour*     : array[4, float32]
        metallic_factor* : float32
        roughness_factor*: float32
        texture_count*   : uint8
        textures*        : UncheckedArray[uint8]

    TextureHeader* = object
        kind*  : TextureKind
        format*: TextureFormat
        w*, h* : uint16
        data*  : UncheckedArray[byte]

#[ -------------------------------------------------------------------- ]#

proc `$`*(header: Header): string =
    let valid_msg = if header.magic == NAIMagic: "valid" else: "invalid"
    &"Nai object header:\n"                                  &
    &"    Magic number    -> {header.magic} ({valid_msg})\n" &
    &"    Output flags    -> {header.layout_flags}\n"        &
    &"    Vertex flags    -> {header.vertex_flags}\n"        &
    &"    Mesh count      -> {header.mesh_count}\n"          &
    &"    Material count  -> {header.material_count}\n"      &
    &"    Animation count -> {header.animation_count}\n"     &
    &"    Texture count   -> {header.texture_count}\n"       &
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

# Keep synced with the header file
static:
    assert (sizeof Header)         == 28
    assert (sizeof MeshHeader)     == 12
    assert (sizeof MaterialHeader) == 28
    assert (sizeof TextureHeader)  == 12
