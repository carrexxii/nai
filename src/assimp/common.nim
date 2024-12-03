# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import "../common"
export `&`

const
    NoArmaturePopulateProcess* = true
    AiMaxStringLen*     = 1024
    AiMaxColourSets*    = 0x8
    AiMaxTextureCoords* = 0x8

type
    AiReturn* {.size: sizeof(cint).} = enum
        returnSuccess     =  0x0
        returnFailure     = -0x1
        returnOutOfMemory = -0x3

    AiMetaDataKind* {.size: sizeof(cint).} = enum
        mdkBool
        mdkInt32
        mdkUInt64
        mdkFloat
        mdkDouble
        mdkString
        mdkVec3
        mdkMetaData
        mdkInt64
        mdkUInt32

type
    AiReal* = float32

    AiString* = object
        len* : uint32
        data*: array[AiMaxStringLen, char]

    AiVec2* = object
        x*, y*: AiReal
    AiVec3* = object
        x*, y*, z*: AiReal
    AiQuat* = object
        w*, x*, y*, z*: AiReal
    AiColour* = object
        r*, g*, b*, a*: AiReal
    AiColour3* = object
        r*, g*, b*: AiReal

    AiMat4x4* = object
        a1*, a2*, a3*, a4*: AiReal
        b1*, b2*, b3*, b4*: AiReal
        c1*, c2*, c3*, c4*: AiReal
        d1*, d2*, d3*, d4*: AiReal

    AiAabb* = object
        min*: AiVec3
        max*: AiVec3

    AiMetaDataEntry* = object
        kind*: AiMetaDataKind
        data*: pointer

    AiMetaData* = object
        properties_count*: uint32
        keys*            : ptr UncheckedArray[AiString]
        values*          : ptr UncheckedArray[AiMetaDataEntry]

    AiNode* = object
        name*          : AiString
        transform*     : AiMat4x4
        parent*        : ptr AiNode
        children_count*: uint32
        children*      : ptr UncheckedArray[ptr AiNode]
        mesh_count*    : uint32
        meshes*        : ptr uint32
        meta_data*     : AiMetaData

proc `$`*(str: AiString): string =
    if str.len == 0:
        result = ""
    else:
        result = new_string str.len
        copy_mem(result[0].addr, str.data[0].addr, str.len)

func `$`*(aabb: AiAabb): string =
    let max = aabb.max
    let min = aabb.min
    result = &"[max({max.x:.2f}, {max.y:.2f}, {max.z:.2f}) -> min({min.x:.2f}, {min.y:.2f}, {min.z:.2f})]"

proc get_assimp_error*(): cstring {.importc: "aiGetErrorString".}

func xy*(v: AiVec3): AiVec2 =
    AiVec2(x: v.x, y: v.y)
