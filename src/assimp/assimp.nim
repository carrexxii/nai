# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, animation, camera, light, material, mesh
from std/strutils import split
export common, animation, camera, light, material, mesh

import "../bitgen"
type AIProcessFlag* = distinct uint32
AIProcessFlag.gen_bit_ops(
    pfCalcTangentSpace        , pfJoinIdenticalVertices, pfMakeLeftHanded,
    pfTriangulate             , pfRemoveComponent      , pfGenNormals,
    pfGenSmoothNormals        , pfSplitLargeMeshes     , pfPreTransformVertices,
    pfLimitBoneWeights        , pfValidateDataStructure, pfImproveCacheLocality,
    pfRemoveRedundantMaterials, pfFixInfacingNormals   , pfPopulateArmatureData,
    pfSortByPType             , pfFindDegenerates      , pfFindInvalidData,
    pfGenUVCoords             , pfTransformUVCoords    , pfFindInstances,
    pfOptimizeMeshes          , pfOptimizeGraph        , pfFlipUVs,
    pfFlipWindingOrder        , pfSplitByBoneCount     , pfDebone,
    pfGlobalScale             , pfEmbedTextures        , pfForceGenNormals,
    pfDropNormals             , pfGenBoundingBoxes
)

type AISceneFlag* = distinct uint32
AISceneFlag.gen_bit_ops(
    sfIncomplete,
    sfValidated,
    sfValidationWarning,
    sfNonVerboseFormat,
    sfTerrain,
    sfAllowShared,
)

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
{.push dynlib: AssimpPath.}
proc is_extension_supported*(ext: cstring): bool                     {.importc: "aiIsExtensionSupported".}
proc get_extension_list*(lst: ptr AIString)                          {.importc: "aiGetExtensionList"    .}
proc import_file*(path: cstring; flags: uint32): ptr AIScene         {.importc: "aiImportFile"          .}
proc process*(scene: ptr AIScene; flags: AIProcessFlag): ptr AIScene {.importc: "aiApplyPostProcessing" .}
proc free_scene*(scene: ptr AIScene)                                 {.importc: "aiReleaseImport"       .}
{.pop.}

proc import_file*(path: string; flags: AIProcessFlag): ptr AIScene =
    result = import_file(path.cstring, flags.uint32)
    if result == nil:
        echo &"[AI] Error: failed to load '{path}'"
        quit 1

proc get_extension_list*(): seq[string] =
    var lst: AIString
    get_extension_list lst.addr
    result = ($lst).split ';'

proc dump*(scene: ptr AIScene; file_name: string) =
    echo &"""
Scene '{scene.name}' from '{file_name}' ({scene.flags})
    {scene.mesh_count:2.} Meshes
    {scene.material_count:2.} Materials
    {scene.texture_count:2.} Textures
    {scene.animation_count:2.} Animations
    {scene.skeleton_count:2.} Skeletons
    {scene.camera_count:2.} Cameras
    {scene.light_count:2.} Lights
"""
    template for_each(arr, count) =
        if count > 0:
            for item in arr.to_oa count:
                echo $item

    for_each scene.meshes    , scene.mesh_count
    for_each scene.materials , scene.material_count
    for_each scene.textures  , scene.texture_count
    for_each scene.animations, scene.animation_count
    for_each scene.skeletons , scene.skeleton_count
    for_each scene.lights    , scene.light_count
    for_each scene.cameras   , scene.camera_count
    # TODO: meta data

