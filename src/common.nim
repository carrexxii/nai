import std/[sugar, enumerate]
from std/strformat import `&`
export sugar, enumerate, `&`

const NoArmaturePopulateProcess* = true

const
    MaxAIStringLen*   = 1024
    MaxColourSets*    = 0x8
    MaxTextureCoords* = 0x8

type AIReturn* {.size: sizeof(cint).} = enum
    Success     =  0x0
    Failure     = -0x1
    OutOfMemory = -0x3

type PrimitiveFlag* = distinct uint32
func `or`*(a, b: PrimitiveFlag): PrimitiveFlag {.borrow.}
func `==`*(a, b: PrimitiveFlag): bool          {.borrow.}
const
    PrimitivePoint*            = PrimitiveFlag 0x01
    PrimitiveLine*             = PrimitiveFlag 0x02
    PrimitiveTriangle*         = PrimitiveFlag 0x04
    PrimitivePolygon*          = PrimitiveFlag 0x08
    PrimitiveNGonEncodingFlag* = PrimitiveFlag 0x10

type
    Real* = float32

    AIString* = object
        len* : uint32
        data*: array[MaxAIStringLen, char]

    Vec2* = object
        x*, y*: Real
    Vec3* = object
        x*, y*, z*: Real
    Quat* = object
        w*, x*, y*, z*: Real
    Colour* = object
        r*, g*, b*, a*: Real
    Colour3* = object
        r*, g*, b*: Real

    Mat4x4* = object
        a1*, a2*, a3*, a4*: Real
        b1*, b2*, b3*, b4*: Real
        c1*, c2*, c3*, c4*: Real
        d1*, d2*, d3*, d4*: Real

    AABB* = object
        min*: Vec3
        max*: Vec3

    MetaDataKind* {.importc: "enum".} = enum
        MDBool
        MDInt32
        MDUInt64
        MDFloat
        MDDouble
        MDString
        MDVec3
        MDMetaData
        MDInt64
        MDUInt32
    MetaDataEntry* = object
        kind*: MetaDataKind
        data*: pointer
    MetaData* = object
        properties_count*: uint32
        keys*            : ptr UncheckedArray[AIString]
        values*          : ptr UncheckedArray[MetaDataEntry]

    Node* = object
        name*          : AIString
        transform*     : Mat4x4
        parent*        : ptr Node
        children_count*: uint32
        children*      : ptr UncheckedArray[ptr Node]
        mesh_count*    : uint32
        meshes*        : ptr uint32
        meta_data*     : MetaData

proc `$`*(str: AIString): string =
    if str.len == 0:
        result = ""
    else:
        result = new_string str.len
        copy_mem(result[0].addr, str.data[0].addr, str.len)

func `$`*(aabb: AABB): string =
    let max = aabb.max
    let min = aabb.min
    result = &"[max({max.x:.2f}, {max.y:.2f}, {max.z:.2f}) -> min({min.x:.2f}, {min.y:.2f}, {min.z:.2f})]"

proc get_assimp_error*(): cstring {.importc: "aiGetErrorString".}

#[ -------------------------------------------------------------------- ]#

proc red*    (s: string): string = "\e[31m" & s & "\e[0m"
proc green*  (s: string): string = "\e[32m" & s & "\e[0m"
proc yellow* (s: string): string = "\e[33m" & s & "\e[0m"
proc blue*   (s: string): string = "\e[34m" & s & "\e[0m"
proc magenta*(s: string): string = "\e[35m" & s & "\e[0m"
proc cyan*   (s: string): string = "\e[36m" & s & "\e[0m"

proc info*(msg: string)    = echo        &"{msg}"
proc error*(msg: string)   = echo red    &"Error: {msg}"
proc warning*(msg: string) = echo yellow &"Warning: {msg}"

template to_oa*(arr, c): untyped =
    to_open_array(arr, 0, int c - 1)
