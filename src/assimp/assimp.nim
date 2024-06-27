# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, animation, camera, light, material, mesh
from std/strutils import split
export common, animation, camera, light, material, mesh

type
    AIProcessFlag* {.size: sizeof(cuint).} = enum
        CalcTangentSpace         = 0x0000_0001
        JoinIdenticalVertices    = 0x0000_0002
        MakeLeftHanded           = 0x0000_0004
        Triangulate              = 0x0000_0008
        RemoveComponent          = 0x0000_0010
        GenNormals               = 0x0000_0020
        GenSmoothNormals         = 0x0000_0040
        SplitLargeMeshes         = 0x0000_0080
        PreTransformVertices     = 0x0000_0100
        LimitBoneWeights         = 0x0000_0200
        ValidateDataStructure    = 0x0000_0400
        ImproveCacheLocality     = 0x0000_0800
        RemoveRedundantMaterials = 0x0000_1000
        FixInfacingNormals       = 0x0000_2000
        PopulateArmatureData     = 0x0000_4000
        SortByPType              = 0x0000_8000
        FindDegenerates          = 0x0001_0000
        FindInvalidData          = 0x0002_0000
        GenUVCoords              = 0x0004_0000
        TransformUVCoords        = 0x0008_0000
        FindInstances            = 0x0010_0000
        OptimizeMeshes           = 0x0020_0000
        OptimizeGraph            = 0x0040_0000
        FlipUVs                  = 0x0080_0000
        FlipWindingOrder         = 0x0100_0000
        SplitByBoneCount         = 0x0200_0000
        Debone                   = 0x0400_0000
        GlobalScale              = 0x0800_0000
        EmbedTextures            = 0x1000_0000
        ForceGenNormals          = 0x2000_0000
        DropNormals              = 0x4000_0000
        GenBoundingBoxes         = 0x8000_0000

    AISceneFlag* {.size: sizeof(cuint)} = enum
        Incomplete        = 0x0000_0001
        Validated         = 0x0000_0002
        ValidationWarning = 0x0000_0004
        NonVerboseFormat  = 0x0000_0008
        Terrain           = 0x0000_0010
        AllowShared       = 0x0000_0020

func `or`*(a, b: AIProcessFlag): AIProcessFlag {.warning[holeEnumConv]: off.} = cast[AIProcessFlag]((cuint a) or (cuint b))
func `or`*(a, b: AISceneFlag)  : AISceneFlag   {.warning[holeEnumConv]: off.} = cast[AISceneFlag]  ((cuint a) or (cuint b))

type AIScene* = object
    flags*          : AISceneFlag
    root_node*      : ptr AINode
    mesh_count*     : uint32
    meshes*         : ptr UncheckedArray[ptr AIMesh]
    material_count* : uint32
    materials*      : ptr UncheckedArray[ptr AIMaterial]
    animation_count*: uint32
    animations*     : ptr UncheckedArray[ptr AIAnimation]
    texture_count*  : uint32
    textures*       : ptr UncheckedArray[ptr AITexture]
    light_count*    : uint32
    lights*         : ptr UncheckedArray[ptr AILight]
    camera_count*   : uint32
    cameras*        : ptr UncheckedArray[ptr AICamera]
    meta_data*      : ptr AIMetaData
    name*           : AIString
    skeleton_count* : uint32
    skeletons*      : ptr UncheckedArray[ptr AISkeleton]
    private         : pointer

#[ -------------------------------------------------------------------- ]#

# TODO: variable index size with an 'auto` option that detects size needed
# TODO: import_file interface for memory load
#       property imports
{.push dynlib: "lib/libassimp.so".}
proc is_extension_supported*(ext: cstring): bool                     {.importc: "aiIsExtensionSupported".}
proc get_extension_list*(lst: ptr AIString)                          {.importc: "aiGetExtensionList"    .}
proc import_file*(path: cstring; flags: uint32): ptr AIScene         {.importc: "aiImportFile"          .}
proc process*(scene: ptr AIScene; flags: AIProcessFlag): ptr AIScene {.importc: "aiApplyPostProcessing" .}
proc free_scene*(scene: ptr AIScene)                                 {.importc: "aiReleaseImport"       .}
{.pop.}

proc import_file*(path: string; flags: AIProcessFlag): ptr AIScene =
    result = import_file(path.cstring, flags.uint32)
    if result == nil:
        echo &"Error: failed to load '{path}'"
        quit 1

proc get_extension_list*(): seq[string] =
    var lst: AIString
    get_extension_list lst.addr
    result = ($lst).split ';'
