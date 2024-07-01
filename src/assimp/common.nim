# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import "../common"
export `&`, to_oa

const
    AssimpPath* = "lib/libassimp.so"
    NoArmaturePopulateProcess* = true

const
    AIMaxStringLen*     = 1024
    AIMaxColourSets*    = 0x8
    AIMaxTextureCoords* = 0x8

type AIReturn* {.size: sizeof(cint).} = enum
    Success     =  0x0
    Failure     = -0x1
    OutOfMemory = -0x3

type
    AIReal* = float32

    AIString* = object
        len* : uint32
        data*: array[AIMaxStringLen, char]

    AIVec2* = object
        x*, y*: AIReal
    AIVec3* = object
        x*, y*, z*: AIReal
    AIQuat* = object
        w*, x*, y*, z*: AIReal
    AIColour* = object
        r*, g*, b*, a*: AIReal
    AIColour3* = object
        r*, g*, b*: AIReal

    AIMat4x4* = object
        a1*, a2*, a3*, a4*: AIReal
        b1*, b2*, b3*, b4*: AIReal
        c1*, c2*, c3*, c4*: AIReal
        d1*, d2*, d3*, d4*: AIReal

    AIAABB* = object
        min*: AIVec3
        max*: AIVec3

    AIMetaDataKind* {.importc: "enum".} = enum
        Bool
        Int32
        UInt64
        Float
        Double
        String
        Vec3
        MetaData
        Int64
        UInt32
    AIMetaDataEntry* = object
        kind*: AIMetaDataKind
        data*: pointer
    AIMetaData* = object
        properties_count*: uint32
        keys*            : ptr UncheckedArray[AIString]
        values*          : ptr UncheckedArray[AIMetaDataEntry]

    AINode* = object
        name*          : AIString
        transform*     : AIMat4x4
        parent*        : ptr AINode
        children_count*: uint32
        children*      : ptr UncheckedArray[ptr AINode]
        mesh_count*    : uint32
        meshes*        : ptr uint32
        meta_data*     : AIMetaData

proc `$`*(str: AIString): string =
    if str.len == 0:
        result = ""
    else:
        result = new_string str.len
        copy_mem(result[0].addr, str.data[0].addr, str.len)

func `$`*(aabb: AIAABB): string =
    let max = aabb.max
    let min = aabb.min
    result = &"[max({max.x:.2f}, {max.y:.2f}, {max.z:.2f}) -> min({min.x:.2f}, {min.y:.2f}, {min.z:.2f})]"

proc get_assimp_error*(): cstring {.importc: "aiGetErrorString", dynlib: AssimpPath.}

