import common

type AIPrimitiveFlag* {.size: sizeof(uint32).} = enum
    Point            = 0x01
    Line             = 0x02
    Triangle         = 0x04
    Polygon          = 0x08
    NGonEncodingFlag = 0x10

type
    AIMesh* = object
        primitive_kinds*    : AIPrimitiveFlag
        vertex_count*       : uint32
        face_count*         : uint32
        vertices*           : ptr UncheckedArray[AIVec3]
        normals*            : ptr UncheckedArray[AIVec3]
        tangents*           : ptr UncheckedArray[AIVec3]
        bitangents*         : ptr UncheckedArray[AIVec3]
        colours*            : array[AIMaxColourSets, ptr UncheckedArray[AIColour]]
        texture_coords*     : array[AIMaxTextureCoords, ptr UncheckedArray[AIVec3]]
        uv_component_count* : array[AIMaxTextureCoords, uint32]
        faces*              : ptr UncheckedArray[AIFace]
        bone_count*         : uint32
        bones*              : ptr UncheckedArray[ptr AIBone]
        material_index*     : uint32
        name*               : AIString
        anim_mesh_count*    : uint32
        anim_meshes*        : ptr UncheckedArray[ptr AIAnimMesh]
        morph_method*       : AIMorphMethod
        aabb*               : AIAABB
        texture_coord_names*: ptr UncheckedArray[ptr AIString]

    AIAnimMesh* = object
        name*          : AIString
        vertices*      : ptr UncheckedArray[AIVec3]
        normals*       : ptr UncheckedArray[AIVec3]
        tangents*      : ptr UncheckedArray[AIVec3]
        bitangents*    : ptr UncheckedArray[AIVec3]
        colours*       : array[AIMaxColourSets, ptr UncheckedArray[AIColour]]
        texture_coords*: array[AIMaxTextureCoords, ptr UncheckedArray[AIVec3]]
        vertex_count*  : uint32
        weight*        : float32

    AIMorphMethod* = enum
        Unknown
        VertexBlend
        Normalized
        Relative

    AIVertexWeight* = object
        id*    : uint32
        weight*: AIReal

    AIBone* = object
        parent*: int32
        when NoArmaturePopulateProcess:
            armature*: ptr AINode
            node*    : ptr AINode
        weight_count*: uint32
        mesh_index*  : ptr AIMesh
        weights*     : ptr UncheckedArray[AIVertexWeight]
        offset_mat*  : AIMat4x4
        local_mat*   : AIMat4x4

    AISkeleton* = object
        name*       : AIString
        bones_count*: uint32
        bones*      : ptr UncheckedArray[ptr AIBone]

    AIFace* = object
        index_count*: uint32
        indices*    : ptr UncheckedArray[uint32]
