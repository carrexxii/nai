# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, "../bitgen"
from std/sequtils import foldl
from std/strutils import join

type AIPrimitiveFlag* = distinct uint32
AIPrimitiveFlag.gen_bit_ops(
    Point,
    Line,
    Triangle,
    Polygon,
    NGonEncodingFlag,
)

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
        name*      : AIString
        bone_count*: uint32
        bones*     : ptr UncheckedArray[ptr AIBone]

    AIFace* = object
        index_count*: uint32
        indices*    : ptr UncheckedArray[uint32]

func `$`*(mesh: AIMesh | ptr AIMesh): string =
    template ifn(p: pointer; name: string): string =
        if p == nil: "" else: name
    let colour_count    = mesh.colours.foldl(a + (if b == nil: 0 else: 1), 0)
    let tex_coord_count = mesh.texture_coords.foldl(a + (if b == nil: 0 else: 1), 0)
    let vert_kinds = [
        mesh.vertices.ifn   "vertices",
        mesh.normals.ifn    "normals",
        mesh.tangents.ifn   "tangents",
        mesh.bitangents.ifn "bitangents",
        &"{colour_count   } colours",
        &"{tex_coord_count} texture coords",
    ].join ", "
    &"""
AIMesh '{mesh.name}' of {mesh.primitive_kinds} (has {vert_kinds})
    {mesh.vertex_count   } Vertices
    {mesh.face_count     } Faces
    {mesh.bone_count     } Bones
    {mesh.anim_mesh_count} Animation Meshes (morph method is {mesh.morph_method})
    AABB = {mesh.aabb}
"""

func `$`*(skel: AISkeleton | ptr AISkeleton): string =
    &"AISkeleton '{skel.name}' with {skel.bone_count} bones"

