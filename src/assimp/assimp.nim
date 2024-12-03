# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, animation, camera, light, material, mesh
from std/strutils import split
export common, animation, camera, light, material, mesh

import "../bitgen"
type AiProcessFlag* = distinct uint32
AiProcessFlag.gen_bit_ops(
    processCalcTangentSpace        , processJoinIdenticalVertices, processMakeLeftHanded,
    processTriangulate             , processRemoveComponent      , processGenNormals,
    processGenSmoothNormals        , processSplitLargeMeshes     , processPreTransformVertices,
    processLimitBoneWeights        , processValidateDataStructure, processImproveCacheLocality,
    processRemoveRedundantMaterials, processFixInfacingNormals   , processPopulateArmatureData,
    processSortByPType             , processFindDegenerates      , processFindInvalidData,
    processGenUVCoords             , processTransformUVCoords    , processFindInstances,
    processOptimizeMeshes          , processOptimizeGraph        , processFlipUVs,
    processFlipWindingOrder        , processSplitByBoneCount     , processDebone,
    processGlobalScale             , processEmbedTextures        , processForceGenNormals,
    processDropNormals             , processGenBoundingBoxes
)

type AiSceneFlag* = distinct uint32
AiSceneFlag.gen_bit_ops(
    sceneIncomplete, sceneValidated, sceneValidationWarning, sceneNonVerboseFormat,
    sceneTerrain   , sceneAllowShared,
)

type AiScene* = object
    flags*       : AiSceneFlag
    root_node*   : ptr AiNode
    mesh_cnt*    : uint32
    meshes*      : ptr UncheckedArray[ptr AiMesh]
    mtl_cnt*     : uint32
    mtls*        : ptr UncheckedArray[ptr AiMaterial]
    anim_cnt*    : uint32
    anims*       : ptr UncheckedArray[ptr AiAnimation]
    tex_cnt*     : uint32
    texs*        : ptr UncheckedArray[ptr AiTexture]
    light_cnt*   : uint32
    lights*      : ptr UncheckedArray[ptr AiLight]
    cam_cnt*     : uint32
    cams*        : ptr UncheckedArray[ptr AiCamera]
    meta_data*   : ptr AiMetaData
    name*        : AiString
    skeleton_cnt*: uint32
    skeletons*   : ptr UncheckedArray[ptr AiSkeleton]
    private      : pointer

#[ -------------------------------------------------------------------- ]#

# TODO: variable index size with an 'auto` option that detects size needed
# TODO: import_file interface for memory load
#       property imports
proc is_extension_supported*(ext: cstring): bool                     {.importc: "aiIsExtensionSupported".}
proc get_extension_list*(lst: ptr AiString)                          {.importc: "aiGetExtensionList"    .}
proc import_file*(path: cstring; flags: uint32): ptr AiScene         {.importc: "aiImportFile"          .}
proc process*(scene: ptr AiScene; flags: AiProcessFlag): ptr AiScene {.importc: "aiApplyPostProcessing" .}
proc free_scene*(scene: ptr AiScene)                                 {.importc: "aiReleaseImport"       .}

proc import_file*(path: string; flags: AiProcessFlag): ptr AiScene =
    result = import_file(path.cstring, flags.uint32)
    if result == nil:
        echo &"[Ai] Error: failed to load '{path}'"
        quit 1

proc get_extension_list*(): seq[string] =
    var lst: AiString
    get_extension_list lst.addr
    result = ($lst).split ';'

proc dump*(scene: ptr AiScene; file_name: string) =
    echo &"""
Scene '{scene.name}' from '{file_name}' ({scene.flags})
    {scene.mesh_cnt:2.} Meshes
    {scene.mtl_cnt:2.} Materials
    {scene.tex_cnt:2.} Textures
    {scene.anim_cnt:2.} Animations
    {scene.skeleton_cnt:2.} Skeletons
    {scene.cam_cnt:2.} Cameras
    {scene.light_cnt:2.} Lights
"""
    template for_each(arr, count) =
        if count > 0:
            for item in arr.to_open_array(0, int count - 1):
                echo $item

    for_each scene.meshes   , scene.mesh_cnt
    for_each scene.mtls     , scene.mtl_cnt
    for_each scene.texs     , scene.tex_cnt
    for_each scene.anims    , scene.anim_cnt
    for_each scene.skeletons, scene.skeleton_cnt
    for_each scene.lights   , scene.light_cnt
    for_each scene.cams     , scene.cam_cnt
    # TODO: meta data
