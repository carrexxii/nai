import
    std/[streams, parseopt, parsecfg, paths, tables, strutils],
    common, mesh, texture, material, animation, light, camera, header
from std/os       import get_app_dir
from std/files    import file_exists
from std/sequtils import foldl

const ConfigFileName = "nai.ini"

type
    ProcessFlag* {.size: sizeof(cint).} = enum
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

    SceneFlag* {.size: sizeof(cint)} = enum
        Incomplete        = 0x0000_0001
        Validated         = 0x0000_0002
        ValidationWarning = 0x0000_0004
        NonVerboseFormat  = 0x0000_0008
        Terrain           = 0x0000_0010
        AllowShared       = 0x0000_0020

func `or`*(a, b: ProcessFlag): ProcessFlag = ProcessFlag ((cint a) or (cint b))
func `or`*(a, b: SceneFlag)  : SceneFlag   = SceneFlag ((cint a) or (cint b))

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

#[ -------------------------------------------------------------------- ]#

# TODO: variable index size with an 'auto` option that detects size needed
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
        echo &"Error: failed to load '{path}'"
        quit 1

proc get_extension_list*(): seq[string] =
    var lst: AIString
    get_extension_list lst.addr
    result = split($lst, ';')

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

proc validate*(scene: ptr Scene; output_errs: bool): int =
    proc error(msg: string)   = echo red    &"Error: {msg}"
    proc warning(msg: string) = echo yellow &"Warning: {msg}"

    block ImplementationCheck:
        proc check(val: uint; name: string): int =
            result = if val != 0: 1 else: 0
            if val != 0 and output_errs:
                warning &"scene contains {val} {name} which are not supported"

        result =
            check(scene.texture_count  , "textures")   +
            check(scene.material_count , "materials")  +
            check(scene.animation_count, "animations") +
            check(scene.skeleton_count , "skeletons")  +
            check(scene.light_count    , "lights")     +
            check(scene.camera_count   , "cameras")

    # TODO: continue prompt
    if scene.texture_count > 0 and not (TexturesNone in output_flags):
        error &"File has {scene.texture_count} textures but '{TexturesNone}' was not specified"

#[ -------------------------------------------------------------------- ]#

converter vec3_to_vec2(v: Vec3): Vec2 = Vec2(x: v.x, y: v.y)

template to_oa(arr, c): untyped =
    to_open_array(arr, 0, int (c - 1))

proc write_meshes*(scene: ptr Scene; file: Stream; verbose: bool) =
    template write(flags: VertexMask; dst, src) =
        when flags * vertex_flags != {}:
            dst = src

    template iter(count: int; a, b, c: ptr UncheckedArray[untyped]): untyped =
        iterator iter_impl(n: int; s1: typeof a; s2: typeof b; s3: typeof c): (typeof a[0], typeof b[0], typeof c[0]) =
            for i in 0..<n:
                yield (s1[i], s2[i], s3[i])

        iter_impl(count, a, b, c)

    if scene.mesh_count != 1:
        assert(false, "Need to implement multiple meshes")
    for mesh in to_oa(scene.meshes, scene.mesh_count):
        var index_count = 0
        for face in to_oa(mesh.faces, mesh.face_count):
            index_count += int face.index_count

        if verbose:
            echo &"Mesh '{mesh.name}' (material index: {mesh.material_index}) {vertex_flags}"
            echo &"\t{mesh.vertex_count} vertices of {0}B ({index_count} indices making {mesh.face_count} faces)"
            echo &"\tUV components -> {mesh.uv_component_count}"
            echo &"\t{mesh.bone_count} bones"
            echo &"\t{mesh.anim_mesh_count} animation meshes (morphing method: {mesh.morph_method})"
            echo &"\tAABB: {mesh.aabb}"

        if mesh.primitive_kinds != PrimitiveTriangle:
            echo "Error: mesh contains non-triangle primitives"
            return

        if VerticesInterleaved in output_flags:
            file.write_data(mesh.vertex_count.addr, sizeof header.Vertices.vert_count)
            file.write_data(index_count.addr      , sizeof header.Vertices.index_count)

            # var vertex: Vertex
            # for (pos, normal, uv) in iter(int mesh.vertex_count, mesh.vertices, mesh.normals, mesh.texture_coords[0]):
            #     write({Position}             , vertex.pos      , pos)
            #     write({Normal}               , vertex.normal   , normal)
            #     write({Tangent}              , vertex.tangent  , tangent)
            #     write({Bitangent}            , vertex.bitangent, bitangent)
            #     write({ColourRGBA, ColourRGB}, vertex.colour   , colour)
            #     write({UV3, UV}              , vertex.uv       , uv) # TODO: need to check if the file actually has these before reading
            #     file.write_data(vertex.addr, sizeof vertex)
                # if mesh.vertex_count < 2000:
                    # echo vertex

            for face in to_oa(mesh.faces, mesh.face_count):
                for index in to_oa(face.indices, face.index_count):
                    let index32 = uint32 index
                    file.write_data(index32.addr, sizeof index32)

        elif VerticesSeparated in output_flags:
            assert false

proc write_textures*(scene: ptr Scene; file: Stream; verbose: bool) =
    for texture in to_oa(scene.textures, scene.texture_count):
        var fmt_hint = new_string MaxTextureHintLen
        copy_mem(fmt_hint[0].addr, texture.format_hint[0].addr, MaxTextureHintLen)
        if verbose:
            echo &"Texture '{texture.filename}' ({texture.width}x{texture.height}):"
            echo &"\tFormat hint      -> {fmt_hint}"
            echo &"\tData is internal -> {texture.data != nil}"

        if TexturesExternal in output_flags:
            var file = open_file_stream("" & fmt_hint, fmWrite)
            defer: close file

            file.write_data(texture.data[0].addr, int texture.width)

#[ -------------------------------------------------------------------- ]#

let cwd = get_current_dir()

func `~`(path: string): Path =
    Path path

proc write_help() =
    echo "Usage:"
    echo "    naic file [options]\n"

    echo "Options: (opt:VAL or opt=VAL)"
    echo "    -i, --input:PATH        Explicitly define an input file"
    echo "    -o, --output:PATH       Define the output path (defaults to current directory)"
    echo "    -c, --config:FILE       Specify a configuration file (defaults to nai.ini)"
    echo "    -f, --force             Ignore warnings for unsupported components"
    echo "    -v, --verbose           Output extra information about the file being compiled"
    echo "    -q, --quiet             Don't output warnings"
    echo ""
    echo "    --ignore    Alias for --force"

    echo "\nSupported formats:"
    echo &"""{foldl(get_extension_list(), a & " " & b, "    ")}"""

    quit 0

proc check_duplicate(val, kind: string | Path) =
    if val != default (typeof val):
        echo red &"Error: duplicate inputs provided for '{kind}'"
        quit 1

proc check_present(val, opt: string): string =
    if val == "":
        echo red &"No value provided for '{opt}'"
        quit 1
    result = val

proc bool_opt(key, val: string): bool =
    case to_lower val
    of "", "true" , "t", "yes", "y", "on" : true
    of     "false", "f", "no" , "n", "off": false
    else:
        echo red &"Invalid value for '{key}'. Expected a boolean value."
        quit 1

from std/setutils import full_set
import std/enumerate
proc string_of_output_flags(): string =
    let set_str = $full_set OutputFlag
    result = "\t"
    for (i, c) in enumerate set_str:
        if c == ',':
            result.add '\n'
            result.add '\t'
            continue
        elif c in [' ', ',', '{', '}']:
            continue
        elif (is_upper_ascii c) and (is_alpha_ascii set_str[i - 1]):
            result.add ": "

        result.add c

when is_main_module:
    var
        options = init_opt_parser()
        out_file: Path = cwd
        in_file : Path
        cfg_file: Path
        verbose : bool = false
        ignore  : bool = false
        quiet   : bool = false
    for kind, key, val in get_opt options:
        case kind
        of cmdLongOption, cmdShortOption:
            case key
            of "help"   , "h": write_help()
            of "verbose", "v": verbose  = key.bool_opt val
            of "quiet"  , "q": quiet    = key.bool_opt val
            of "config" , "c": cfg_file = ~key
            of "output" , "o": out_file = ~(val.check_present key)
            of "input"  , "i":
                in_file.check_duplicate ~"input"
                in_file = ~val
            of "force", "ignore", "f": ignore = true
            else:
                echo red &"Unrecognized option: '{key}'"
                quit 1
        of cmdArgument:
            in_file.check_duplicate "input"
            in_file = ~(if key == "": val else: key)
        of cmdEnd:
            discard

    if in_file == ~"":
        echo red "Error: no input file provided"
        write_help()

    if out_file == cwd:
        out_file = cwd / extract_filename in_file

    if cfg_file == default Path:
        let cwd_ini_path = ~get_app_dir() / ~ConfigFileName
        let bin_ini_path = cwd / ~ConfigFileName
        if file_exists cwd_ini_path:
            cfg_file = cwd_ini_path
        elif file_exists bin_ini_path:
            cfg_file = bin_ini_path
        else:
            echo red "Error: no configuration file specified and could not find 'nai.ini' (use --config/-c to specify)"
            quit 1

    let config = load_config $cfg_file
    for key in config.keys:
        template push_flags(section, kind) =
            for val in config[key].keys:
                section.incl (parse_enum[kind] val)

        case to_lower key
        of "vertex" : push_flags(vertex_flags , VertexFlag)
        of "texture": push_flags(texture_flags, TextureFlag)
        of "":
            for (k, v) in pairs config[""]:
                try:
                    let en = parse_enum[OutputFlag] &"{capitalize_ascii k}{capitalize_ascii v}"
                    output_flags.incl en
                except ValueError:
                    echo red &"Error: Invalid output flag '{k}: {v}' \nValid values:\n{string_of_output_flags()})"
                    quit 1
        else:
            echo yellow &"Error: unrecognized configuration section '{key}'"
            continue

    proc check_incompatible(flags: OutputMask): bool =
        let intersection = flags * output_flags
        if intersection.len > 1:
            echo red &"Incompatible flags '{intersection}'"
            result = true

    if (check_incompatible {TexturesNone, TexturesInternal, TexturesExternal}) or
       (check_incompatible {VerticesNone, VerticesInterleaved, VerticesSeparated}):
        quit 1

    var scene = import_file($in_file, GenBoundingBoxes)
    if verbose:
        echo &"Scene '{scene.name}' ('{in_file}' -> '{out_file}')"
        echo &"\tMeshes     -> {scene.mesh_count}"
        echo &"\tMaterials  -> {scene.material_count}"
        echo &"\tAnimations -> {scene.animation_count}"
        echo &"\tTextures   -> {scene.texture_count}"
        echo &"\tLights     -> {scene.light_count}"
        echo &"\tCameras    -> {scene.camera_count}"
        echo &"\tSkeletons  -> {scene.skeleton_count}"

    if validate(scene, not quiet) != 0 and not ignore:
        echo red &"Error: File '{in_file}' contains unsupported components (use -f/--force/--ignore to continue regardless)"
        quit 1

        var file = open_file_stream($out_file, fmWrite)
        write_header(scene, file)
        write_meshes(scene, file, verbose)
        write_textures(scene, file, verbose)
        close file

        free_scene scene
