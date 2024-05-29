import
    std/[streams, macros],
    common, header, mesh, material, animation, texture
# from std/sequtils  import zip
from std/strutils  import split
from std/strformat import fmt

# TODO: variable index size with an 'auto` option that detects size needed

const output_flags* = OutputMask {VerticesInterleaved}
const vertex_flags* = VertexMask {VertexPosition, VertexNormal, VertexUV}

type ProcessFlag* {.size: sizeof(cint).} = enum
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
func `or`*(a, b: ProcessFlag): ProcessFlag =
    ProcessFlag ((cint a) or (cint b))

type SceneFlag* {.size: sizeof(cint)} = enum
    Incomplete        = 0x0000_0001
    Validated         = 0x0000_0002
    ValidationWarning = 0x0000_0004
    NonVerboseFormat  = 0x0000_0008
    Terrain           = 0x0000_0010
    AllowShared       = 0x0000_0020
func `or`*(a, b: SceneFlag): SceneFlag =
    SceneFlag ((cint a) or (cint b))

type Camera* = object
    name*       : AIString
    position*   : Vec3
    up*         : Vec3
    look_at*    : Vec3
    hfov*       : float32
    clip_near*  : float32
    clip_far*   : float32
    aspect*     : float32
    ortho_width*: float32

type
    LightSourceKind* = enum
        Undefined
        Directional
        Point
        Spot
        Ambient
        Area
    Light* = object
        name*                 : AIString
        kind*                 : LightSourceKind
        position*             : Vec3
        direction*            : Vec3
        up*                   : Vec3
        attenuation_constant* : float32
        attenuation_linea*    : float32
        attenuation_quadratic*: float32
        colour_diffuse*       : Colour3
        colour_specular*      : Colour3
        colour_ambient*       : Colour3
        angle_inner_cone*     : float32
        angle_outer_cone*     : float32
        size*                 : Vec2

type Scene* = object
    flags*          : SceneFlag
    root_node*      : ptr Node
    mesh_count*     : uint32
    meshes*         : ptr UncheckedArray[ptr Mesh]
    material_count* : uint32
    materials*      : ptr UncheckedArray[ptr Material]
    animation_count*: uint32
    animations*     : ptr UncheckedArray[ptr Animation]
    texture_count*  : uint32
    textures*       : ptr UncheckedArray[ptr Texture]
    light_count*    : uint32
    lights*         : ptr UncheckedArray[ptr Light]
    camera_count*   : uint32
    cameras*        : ptr UncheckedArray[ptr Camera]
    meta_data*      : ptr MetaData
    name*           : AIString
    skeleton_count* : uint32
    skeletons*      : ptr UncheckedArray[ptr Skeleton]
    private         : pointer

# TODO: !! Statically link Assimp
# TODO: import_file interface for memory load
#       property imports
# proc import_file*(buffer: ptr byte; length: uint32; flags: uint32; hint: cstring): ptr Scene {.importc: "aiImportFileFromMemory", dynlib: AIPath.}
{.push dynlib: AIPath.}
proc get_error*(): cstring                                     {.importc: "aiGetErrorString"      .}
proc is_extension_supported*(ext: cstring): bool               {.importc: "aiIsExtensionSupported".}
proc get_extension_list(lst: ptr AIString)                     {.importc: "aiGetExtensionList"    .}
proc import_file(path: cstring; flags: uint32): ptr Scene      {.importc: "aiImportFile"          .}
proc process*(scene: ptr Scene; flags: ProcessFlag): ptr Scene {.importc: "aiApplyPostProcessing" .}
proc free_scene*(scene: ptr Scene)                             {.importc: "aiReleaseImport"       .}
{.pop.}

proc import_file*(path: string; flags: ProcessFlag): ptr Scene =
    result = import_file(path.cstring, flags.uint32)
    if result == nil:
        echo fmt"Error: failed to load '{path}'"
        quit 1

proc get_extension_list*(): seq[string] =
    var lst: AIString
    get_extension_list lst.addr
    result = split($lst, ';')

#[ -------------------------------------------------------------------- ]#

macro build_vertex() =
    let pack_pragma = newNimNode(nnkPragma)
    let type_name   = newNimNode nnkPragmaExpr
    pack_pragma.add(ident "packed")
    type_name.add(ident "Vertex", pack_pragma)

    var
        type_sec = newNimNode nnkTypeSection
        type_def = newNimNode nnkTypeDef
        obj_def  = newNimNode nnkObjectTy
        fields   = newNimNode nnkRecList
        def : NimNode
        name: string
        kind: string
    for flag in vertex_flags:
        case flag
        of VertexPosition  : name = "pos"      ; kind = "Vec3"
        of VertexNormal    : name = "normal"   ; kind = "Vec3"
        of VertexTangent   : name = "tangent"  ; kind = "Vec3"
        of VertexBitangent : name = "bitangent"; kind = "Vec3"
        of VertexColourRGBA: name = "colour"   ; kind = "Colour"
        of VertexColourRGB : name = "colour"   ; kind = "Colour3"
        of VertexUV        : name = "uv"       ; kind = "Vec2"
        of VertexUV3       : name = "uv"       ; kind = "Vec3"

        def = newNimNode(nnkPostFix)
        def.add(ident "*")
        def.add(ident name)
        fields.add newIdentDefs(def, ident kind)

    obj_def.add(newEmptyNode(), newEmptyNode(), fields)
    type_def.add(type_name, newEmptyNode(), obj_def)
    type_sec.add type_def

    result = newNimNode nnkStmtList
    result.add type_sec

build_vertex()

proc validate*(scene: ptr Scene; output_errs: bool): int =
    proc check(val: uint; name: string): int =
        result = if val != 0: 1 else: 0
        if val != 0 and output_errs:
            echo yellow fmt"Warning: scene contains {val} {name} which are not supported"

    result =
        check(scene.texture_count  , "textures")   +
        check(scene.material_count , "materials")  +
        check(scene.animation_count, "animations") +
        check(scene.skeleton_count , "skeletons")  +
        check(scene.light_count    , "lights")     +
        check(scene.camera_count   , "cameras")

# TODO: ensure flags don't overlap/have invalid pairs
proc write_header*(scene: ptr Scene; file: Stream) =
    var header = Header(
        magic          : [78, 65, 73, 126],
        version        : [0, 0],
        output_flags   : output_flags,
        vertex_flags   : vertex_flags,
        mesh_count     : uint16 scene.mesh_count,
        material_count : uint16 scene.material_count,
        animation_count: uint16 scene.animation_count,
        texture_count  : uint16 scene.texture_count,
        skeleton_count : uint16 scene.skeleton_count,
    )
    file.write_data(header.addr, sizeof header)

template iter(count: int; a, b, c: ptr UncheckedArray[untyped]): untyped =
    iterator iter_impl(n: int; s1: typeof a; s2: typeof b; s3: typeof c): (typeof a[0], typeof b[0], typeof c[0]) =
        for i in 0..<n:
            yield (s1[i], s2[i], s3[i])

    iter_impl(count, a, b, c)

proc write_meshes*(scene: ptr Scene; file: Stream; verbose: bool) =
    template to_oa(arr, c): untyped = to_open_array(arr, 0, int (c - 1))
    template write(flags, dst, src) =
        when flags * vertex_flags != {}:
            dst = src

    if scene.mesh_count != 1:
        assert(false, "Need to implement multiple meshes")
    for mesh in to_oa(scene.meshes, scene.mesh_count):
        var index_count = 0
        for face in to_oa(mesh.faces, mesh.face_count):
            index_count += int face.index_count

        if verbose:
            echo fmt"Mesh '{mesh.name}' (material index: {mesh.material_index}) {vertex_flags}"
            echo fmt"    {mesh.vertex_count} vertices ({index_count} indices making {mesh.face_count} faces)"
            echo fmt"    UV components -> {mesh.uv_component_count}"
            echo fmt"    {mesh.bone_count} bones"
            echo fmt"    {mesh.anim_mesh_count} animation meshes (morphing method: {mesh.morph_method})"
            echo fmt"    AABB: {mesh.aabb}"

        if mesh.primitive_kinds != PrimitiveTriangle:
            echo "Error: mesh contains non-triangle primitives"
            return

        let vc = mesh.vertex_count.int - 1
        when VerticesInterleaved in output_flags:
            file.write_data(mesh.vertex_count.addr, sizeof header.Vertices.vert_count)
            file.write_data(index_count.addr      , sizeof header.Vertices.index_count)

            var vertex: Vertex
            for (pos, normal, uv) in iter(vc, mesh.vertices, mesh.normals, mesh.texture_coords[0]):
                write({VertexPosition}                   , vertex.pos      , pos)
                write({VertexNormal}                     , vertex.normal   , normal)
                write({VertexTangent}                    , vertex.tangent  , tangent)
                write({VertexBitangent}                  , vertex.bitangent, bitangent)
                write({VertexColourRGBA, VertexColourRGB}, vertex.colour   , colour)
                write({VertexUV, VertexUV3}              , vertex.uv       , uv)
                file.write_data(vertex.addr, sizeof vertex)
                # if vc < 2000:
                    # echo vertex

            for face in to_oa(mesh.faces, mesh.face_count):
                for index in to_oa(face.indices, face.index_count):
                    let index32 = uint32 index
                    file.write_data(index32.addr, sizeof index32)

        elif VerticesSeparated in output_flags:
            assert false
