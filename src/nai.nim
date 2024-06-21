import
    std/[streams, parseopt, parsecfg, paths, tables, strutils, enumerate],
    common, ispctc, mesh, texture, material, animation, light, camera, header
from std/os       import get_app_dir
from std/files    import file_exists
from std/sequtils import foldl, to_seq
from std/setutils import full_set

const ConfigFileName = "nai.ini"

type
    ProcessFlag {.size: sizeof(cuint).} = enum
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

    SceneFlag {.size: sizeof(cuint)} = enum
        Incomplete        = 0x0000_0001
        Validated         = 0x0000_0002
        ValidationWarning = 0x0000_0004
        NonVerboseFormat  = 0x0000_0008
        Terrain           = 0x0000_0010
        AllowShared       = 0x0000_0020

# Cast to avoid buggy bounds checking
# https://github.com/nim-lang/Nim/issues/20024
template `or`(a, b: ProcessFlag): ProcessFlag =
    cast[ProcessFlag]((cuint a) or (cuint b))
    #ProcessFlag ((cuint a) or (cuint b))
template `or`(a, b: SceneFlag): SceneFlag =
    SceneFlag ((cuint a) or (cuint b))

type Scene = object
    flags          : SceneFlag
    root_node      : ptr Node
    mesh_count     : uint32
    meshes         : ptr UncheckedArray[ptr Mesh]
    material_count : uint32
    materials      : ptr UncheckedArray[ptr Material]
    animation_count: uint32
    animations     : ptr UncheckedArray[ptr Animation]
    texture_count  : uint32
    textures       : ptr UncheckedArray[ptr Texture]
    light_count    : uint32
    lights         : ptr UncheckedArray[ptr Light]
    camera_count   : uint32
    cameras        : ptr UncheckedArray[ptr Camera]
    meta_data      : ptr MetaData
    name           : AIString
    skeleton_count : uint32
    skeletons      : ptr UncheckedArray[ptr Skeleton]
    private        : pointer

#[ -------------------------------------------------------------------- ]#

# TODO: variable index size with an 'auto` option that detects size needed
# TODO: import_file interface for memory load
#       property imports
proc is_extension_supported(ext: cstring): bool               {.importc: "aiIsExtensionSupported".}
proc get_extension_list(lst: ptr AIString)                    {.importc: "aiGetExtensionList"    .}
proc import_file(path: cstring; flags: uint32): ptr Scene     {.importc: "aiImportFile"          .}
proc process(scene: ptr Scene; flags: ProcessFlag): ptr Scene {.importc: "aiApplyPostProcessing" .}
proc free_scene(scene: ptr Scene)                             {.importc: "aiReleaseImport"       .}

proc import_file(path: string; flags: ProcessFlag): ptr Scene =
    result = import_file(path.cstring, flags.uint32)
    if result == nil:
        error &"Error: failed to load '{path}'"
        quit 1

proc get_extension_list(): seq[string] =
    var lst: AIString
    get_extension_list lst.addr
    result = split($lst, ';')

# TODO: ensure flags don't overlap/have invalid pairs
proc write_header(scene: ptr Scene; file: Stream) =
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

proc validate(scene: ptr Scene; output_errs: bool): int =
    proc check(val: uint; name: string): int =
        result = if val != 0: 1 else: 0
        if val != 0 and output_errs:
            discard
            warning &"scene contains {val} {name} which are not supported"

    result =
        check(scene.texture_count  , "textures")   +
        check(scene.material_count , "materials")  +
        check(scene.animation_count, "animations") +
        check(scene.skeleton_count , "skeletons")  +
        check(scene.light_count    , "lights")     +
        check(scene.camera_count   , "cameras")

    let texture_flags = {TexturesNone, TexturesInternal, TexturesExternal}
    if scene.texture_count > 0 and output_flags * texture_flags != {}:
        error &"File has {scene.texture_count} textures but no texture flags were specified"
        inc result

#[ -------------------------------------------------------------------- ]#

converter vec3_to_vec2(v: Vec3): Vec2 = Vec2(x: v.x, y: v.y)

proc write_meshes(scene: ptr Scene; file: Stream; verbose: bool) =
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

        let vert_list = to_seq vertex_flags
        let vert_size = vert_list.foldl(a + b.size, 0)

        if verbose:
            info &"Mesh '{mesh.name}' (material index: {mesh.material_index}) {vertex_flags}"
            info &"    {mesh.vertex_count} vertices of {0}B ({index_count} indices making {mesh.face_count} faces)"
            info &"    UV components: {mesh.uv_component_count}"
            info &"    {mesh.bone_count} bones"
            info &"    {mesh.anim_mesh_count} animation meshes (morphing method: {mesh.morph_method})"
            info &"    AABB: {mesh.aabb}"

        if mesh.primitive_kinds != PrimitiveTriangle:
            error "Error: mesh contains non-triangle primitives"
            return

        if VerticesInterleaved in output_flags:
            file.write_data(mesh.vertex_count.addr, sizeof header.MeshHeader.vert_count)
            file.write_data(index_count.addr      , sizeof header.MeshHeader.index_count)

            var vert_mem  = cast[ptr UncheckedArray[uint8]](alloc (vert_size * (int mesh.vertex_count)))
            for (i, pair) in enumerate [(Position, mesh.vertices),
                                        (Normal  , mesh.normals),
                                        (UV      , mesh.texture_coords[0])]: # TODO: deal with other texture_coords
                let (kind, data) = pair
                var offset = 0
                for flag in vertex_flags:
                    if flag == kind:
                        break
                    offset += flag.size

                var p = offset
                for v in 0 .. mesh.vertex_count:
                    copy_mem(vert_mem[p].addr, data[v].addr, kind.size)
                    p += vert_size

            file.write_data(vert_mem, vert_size * (int mesh.vertex_count))
            dealloc vert_mem

            for face in to_oa(mesh.faces, mesh.face_count):
                for index in to_oa(face.indices, face.index_count):
                    let index32 = uint32 index
                    file.write_data(index32.addr, sizeof index32)

        elif VerticesSeparated in output_flags:
            assert false

proc write_materials(scene: ptr Scene; file: Stream; output_name: string; verbose: bool) =
    proc get_tex(mtl: ptr Material; kind: TextureKind): TextureData =
        let count = mtl.texture_count kind
        if count == 0:
            error &"Material does not have any '{kind}' texture"
            quit 1
        elif count > 1:
            warning &"Material has {count} {kind} textures, but only 1 is supported"

        let data = mtl.texture kind
        if is_none data:
            error &"Could not get material's '{kind}' texture '{get_assimp_error()}'"
            quit 1
        get data

    if verbose:
        discard

    for mtl in to_oa(scene.materials, scene.material_count):
        if verbose:
            echo $mtl[]

        echo mtl.get_tex Diffuse
        echo mtl.get_tex Normals
        echo mtl.get_tex Metalness
        echo "==========================="

        let tex_datas = @[mtl.get_tex Diffuse, mtl.get_tex Normals, mtl.get_tex Metalness]
        for tex_data in tex_datas:
            if tex_data.path.starts_with "*":
                let tex       = scene.textures[parse_int tex_data.path[1..^1]][]
                var file_name = output_name
                file_name.remove_suffix ".nai"
                file_name &= &"-{to_lower_ascii $tex_data.kind}.png"

                let raw_tex = load_image(tex.data, tex.width)
                let w = uint32 raw_tex.w
                let h = uint32 raw_tex.h

                # var file = open_file_stream(file_name, fmWrite)
                # file.write_data(tex.data[0].addr, int tex.width)
                # close file

                let profile = BC1.get_profile()
                let cmp_tex = profile.compress(cast[ptr uint8](raw_tex.data), w, h, 4*w)

                var file = open_file_stream(file_name, fmWrite)
                file.write_data(cmp_tex.data, cmp_tex.size)
                close file
            else:
                assert false

    quit 0

# proc write_textures*(scene: ptr Scene; file: Stream; output_name: string; verbose: bool) =
    # discard
    # for texture in to_oa(scene.textures, scene.texture_count):
    #     if verbose:
    #         echo $texture[]
    #     var fmt_hint = new_string MaxTextureHintLen
    #     copy_mem(fmt_hint[0].addr, texture.format_hint[0].addr, MaxTextureHintLen)
        # if TexturesExternal in output_flags:
        #     let texture_name = &"{output_name[0 ..^ 5]}-{}.{fmt_hint}"
        #     var file = open_file_stream(texture_name, fmWrite)
        #     file.write_data(texture.data[0].addr, int texture.width)
        #     close file

#[ -------------------------------------------------------------------- ]#

let cwd = get_current_dir()

func `~`(path: string): Path =
    Path path

proc write_help() =
    info "Usage:"
    info "    naic file [options]\n"

    info "Options: (opt:VAL or opt=VAL)"
    info "    -i, --input:PATH        Explicitly define an input file"
    info "    -o, --output:PATH       Define the output path (defaults to current directory)"
    info "    -c, --config:FILE       Specify a configuration file (defaults to nai.ini)"
    info "    -f, --force             Ignore warnings for unsupported components"
    info "    -v, --verbose           Output extra information about the file being compiled"
    info "    -q, --quiet             Don't output warnings"
    info ""
    info "    --ignore    Alias for --force"

    info "\nSupported formats:"
    info &"""{foldl(get_extension_list(), a & " " & b, "    ")}"""

    quit 0

proc check_duplicate(val, kind: string | Path) =
    if val != default (typeof val):
        error &"Error: duplicate inputs provided for '{kind}'"
        quit 1

proc check_present(val, opt: string): string =
    if val == "":
        error &"No value provided for '{opt}'"
        quit 1
    result = val

proc bool_opt(key, val: string): bool =
    const truthy = ["true" , "t", "yes", "y", "on", ""]
    const falsy  = ["false", "f", "no" , "n", "off"]
    case to_lower val
    of truthy: true
    of falsy : false
    else:
        error &"Invalid value for '{key}'. Expected a boolean value:"
        error &"\tTruth-y: {truthy.join \", \"}"
        error &"\tFalse-y: {falsy.join \", \"},"
        quit 1

proc parse_config(cfg_file: Path) =
    func string_of_output_flags(): string {.compileTime.} =
        result = "\t"
        const set_str = $(full_set OutputFlag)
        for (i, c) in enumerate set_str:
            if c == ',':
                result.add "\n\t"
                continue
            elif c in [' ', ',', '{', '}']:
                continue
            elif (is_upper_ascii c) and (is_alpha_ascii set_str[i - 1]):
                result.add ": "
            result.add c

    var path = cfg_file
    if path == default Path:
        let cwd_ini_path = ~get_app_dir() / ~ConfigFileName
        let bin_ini_path = cwd / ~ConfigFileName
        if file_exists cwd_ini_path:
            path = cwd_ini_path
        elif file_exists bin_ini_path:
            path = bin_ini_path
        else:
            error "Error: no configuration file specified and could not find 'nai.ini' (use --config/-c to specify)"
            quit 1

    let config = load_config $path
    for key in config.keys:
        template push_flags(section, kind) =
            for val in config[key].keys:
                section.incl (parse_enum[kind] val)

        case to_lower key
        of "vertex" : push_flags(vertex_flags , VertexFlag)
        of "texture": push_flags(texture_flags, TextureFlag)
        of "":
            for (k, v) in pairs config[""]:
                try: output_flags.incl (parse_enum[OutputFlag] &"{capitalize_ascii k}{capitalize_ascii v}")
                except ValueError:
                    error &"Error: Invalid output flag '{k}: {v}'"
                    error &"Valid values:\n{string_of_output_flags()})"
                    quit 1
        else:
            warning &"Error: unrecognized configuration section '{key}'"
            continue

    block validate_flags:
        proc check(flags: OutputMask): bool =
            let intersection = flags * output_flags
            if intersection.len > 1:
                error &"Incompatible flags '{intersection}'"
                result = true

        if (check {TexturesNone, TexturesInternal, TexturesExternal}) or
           (check {VerticesNone, VerticesInterleaved, VerticesSeparated}):
            quit 1

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
            of "force", "ignore", "f": ignore = key.bool_opt val
            else:
                error &"Unrecognized option: '{key}'"
                quit 1
        of cmdArgument:
            in_file.check_duplicate "input"
            in_file = ~(if key == "": val else: key)
        of cmdEnd:
            discard

    if in_file == ~"":
        error "No input file provided"
        write_help()

    if out_file == cwd:
        out_file = cwd / extract_filename in_file

    parse_config cfg_file

    var scene = import_file($in_file, GenBoundingBoxes or RemoveRedundantMaterials)
    if verbose:
        info &"Scene '{scene.name}' ('{in_file}' -> '{out_file}')"
        info &"\tMeshes     -> {scene.mesh_count}"
        info &"\tMaterials  -> {scene.material_count}"
        info &"\tAnimations -> {scene.animation_count}"
        info &"\tTextures   -> {scene.texture_count}"
        info &"\tLights     -> {scene.light_count}"
        info &"\tCameras    -> {scene.camera_count}"
        info &"\tSkeletons  -> {scene.skeleton_count}"

    if validate(scene, not quiet) != 0 and not ignore:
        error &"File '{in_file}' contains unsupported components (use -f/--force/--ignore to continue regardless)"
        quit 1

    var file = open_file_stream($out_file, fmWrite)
    write_header(scene, file)
    write_meshes(scene, file, verbose)
    write_materials(scene, file, $out_file, verbose)
    close file

    free_scene scene
