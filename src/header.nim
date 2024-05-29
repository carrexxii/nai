from std/strformat import `&`

const NaiMagic*: array[4, byte] = [78, 65, 73, 126]

type
    OutputFlag* = enum
        VerticesInterleaved
        VerticesSeparated
    OutputMask* {.size: sizeof(uint16).} = set[OutputFlag]

    VertexFlag* = enum
        VertexPosition
        VertexNormal
        VertexTangent
        VertexBitangent
        VertexColourRGBA
        VertexColourRGB
        VertexUV
        VertexUV3
    VertexMask* {.size: sizeof(uint16).} = set[VertexFlag]

    Header* {.packed.} = object
        magic*          : array[4, byte]
        version*        : array[2, byte]
        output_flags*   : OutputMask
        vertex_flags*   : VertexMask
        mesh_count*     : uint16
        material_count* : uint16
        animation_count*: uint16
        texture_count*  : uint16
        skeleton_count* : uint16

    # total size: 8 + vert_count*sizeof(Vertex) + index_count*sizeof(uint32)
    Vertices* = object
        vert_count* : uint32
        index_count*: uint32
        verts*: ptr UncheckedArray[float32] # offset: 8
        inds* : ptr UncheckedArray[uint32]  # offset: 8 + vert_count*sizeof(Vertex)

proc `$`*(header: Header): string =
    let valid_msg = if header.magic == NaiMagic: "valid" else: "invalid"
    &"Nai object header:\n"                                  &
    &"    Magic number    -> {header.magic} ({valid_msg})\n" &
    &"    Output flags    -> {header.output_flags}\n"        &
    &"    Vertex flags    -> {header.vertex_flags}\n"        &
    &"    Mesh count      -> {header.mesh_count}\n"          &
    &"    Material count  -> {header.material_count}\n"      &
    &"    Animation count -> {header.animation_count}\n"     &
    &"    Texture count   -> {header.texture_count}\n"       &
    &"    Skeleton count  -> {header.skeleton_count}\n"
