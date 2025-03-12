# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, bitgen
from std/sequtils import foldl
from std/strutils import join

type AiPrimitiveFlag* = distinct uint32
AiPrimitiveFlag.gen_bit_ops primPoint, primLine, primTriangle, primPolygon, primNGonEncodingFlag

type AiMorphMethod* {.size: sizeof(cint).} = enum
    mmUnknown
    mmVertexBlend
    mmNormalized
    mmRelative

type
    AiMesh* = object
        prim_kinds*     : AiPrimitiveFlag
        vtx_cnt*        : uint32
        face_cnt*       : uint32
        vtxs*           : ptr UncheckedArray[AiVec3]
        normals*        : ptr UncheckedArray[AiVec3]
        tangents*       : ptr UncheckedArray[AiVec3]
        bitangents*     : ptr UncheckedArray[AiVec3]
        colours*        : array[AiMaxColourSets, ptr UncheckedArray[AiColour]]
        tex_coords*     : array[AiMaxTextureCoords, ptr UncheckedArray[AiVec3]]
        uv_comp_cnt*    : array[AiMaxTextureCoords, uint32]
        faces*          : ptr UncheckedArray[AiFace]
        bone_cnt*       : uint32
        bones*          : ptr UncheckedArray[ptr AiBone]
        mtl_idx*        : uint32
        name*           : AiString
        anim_mesh_cnt*  : uint32
        anim_meshes*    : ptr UncheckedArray[ptr AiAnimMesh]
        morph_method*   : AiMorphMethod
        aabb*           : AiAABB
        tex_coord_names*: ptr UncheckedArray[ptr AiString]

    AiAnimMesh* = object
        name*      : AiString
        vtxs*      : ptr UncheckedArray[AiVec3]
        normals*   : ptr UncheckedArray[AiVec3]
        tangents*  : ptr UncheckedArray[AiVec3]
        bitangents*: ptr UncheckedArray[AiVec3]
        colours*   : array[AiMaxColourSets, ptr UncheckedArray[AiColour]]
        tex_coords*: array[AiMaxTextureCoords, ptr UncheckedArray[AiVec3]]
        vtx_cnt*   : uint32
        weight*    : float32

    AiVertexWeight* = object
        id*    : uint32
        weight*: AiReal

    AiBone* = object
        parent*: int32
        when NoArmaturePopulateProcess:
            armature*: ptr AiNode
            node*    : ptr AiNode
        weight_cnt*: uint32
        mesh_idx*  : ptr AiMesh
        weights*   : ptr UncheckedArray[AiVertexWeight]
        offset_mat*: AiMat4x4
        local_mat* : AiMat4x4

    AiSkeleton* = object
        name*    : AiString
        bone_cnt*: uint32
        bones*   : ptr UncheckedArray[ptr AiBone]

    AiFace* = object
        idx_cnt*: uint32
        idxs*   : ptr UncheckedArray[uint32]

func `$`*(mesh: AiMesh | ptr AiMesh): string =
    template ifn(p: pointer; name: string): string =
        if p == nil: "" else: name
    let colour_cnt    = mesh.colours.foldl(a + (if b == nil: 0 else: 1), 0)
    let tex_coord_cnt = mesh.tex_coords.foldl(a + (if b == nil: 0 else: 1), 0)
    let vtx_kinds = [
        mesh.vtxs.ifn       "vertices",
        mesh.normals.ifn    "normals",
        mesh.tangents.ifn   "tangents",
        mesh.bitangents.ifn "bitangents",
        &"{colour_cnt   } colours",
        &"{tex_coord_cnt} texture coords",
    ].join ", "
# AiMesh '{mesh.name}' of {mesh.prim_kinds} (has {vtx_kinds})
    &"""
AiMesh '{mesh.name}' (has {vtx_kinds})
    {mesh.vtx_cnt } Vertices
    {mesh.face_cnt} Faces
    {mesh.bone_cnt} Bones
    {mesh.anim_mesh_cnt} Animation Meshes (morph method is {mesh.morph_method})
    AABB = {mesh.aabb}
"""

func `$`*(skel: AiSkeleton | ptr AiSkeleton): string =
    &"AiSkeleton '{skel.name}' with {skel.bone_cnt} bones"
