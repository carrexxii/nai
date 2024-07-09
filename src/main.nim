# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, parseopt, parsecfg, paths, tables, strutils],
    common, assimp/assimp, ispctc, stbi, compress, nai, output, analyze, dds
from std/os       import get_app_dir
from std/files    import file_exists
from std/sequtils import foldl, to_seq, map_it
from std/setutils import full_set

const ConfigFileName = "nai.ini"
let cwd = get_current_dir()

# TODO: texture format + container validation
proc validate(scene: ptr AIScene; output_errs: bool): int =
    proc check(val: uint; name: string): int =
        result = if val != 0: 1 else: 0
        if val != 0 and output_errs:
            discard
            warning &"Scene contains {val} {name} which are not supported"

    result =
        check(scene.texture_count  , "textures")   +
        check(scene.material_count , "materials")  +
        check(scene.animation_count, "animations") +
        check(scene.skeleton_count , "skeletons")  +
        check(scene.light_count    , "lights")     +
        check(scene.camera_count   , "cameras")

    # let texture_flags = {TexturesInternal, TexturesExternal}
    # if scene.texture_count > 0 and layout_mask * texture_flags != {}:
    #     error &"File has {scene.texture_count} textures but no texture flags were specified"
    #     inc result

func `~/`(path: string): Path =
    Path path

proc write_help() =
    verbose = true

    info "Nai - Copyright (C) 2024 carrexxii. All rights reserved."
    info "    This program comes with ABSOLUTELY NO WARRANTY and is licensed under the terms"
    info "    of the GNU General Public License version 3 only."
    info "    For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.\n"

    info "Usage:"
    info "    nai [command] <file> [options]\n"

    info "Commands:"
    info "    convert, c              Converts input into a Nai file (Default)"
    info "    analyze, a              Analyze and output data contained in a Nai file\n"

    info "Options: (opt:VAL or opt=VAL)"
    info "    -i, --input:PATH        Explicitly define an input file"
    info "    -o, --output:PATH       Define the output path (defaults to current directory)"
    info "    -c, --config:FILE       Specify a configuration file (defaults to nai.ini)"
    info "    -f, --force             Ignore warnings for unsupported components"
    info "    -v, --verbose           Output extra information about the file being compiled"
    info "    -q, --quiet             Don't output warnings"
    info ""
    info "    --ignore    Alias for --force"

    info  "\nSupported formats:"
    info &"""{foldl(get_extension_list(), a & " " & b, "    ")}"""

    info "Compression:"
    for lib in compress.get_versions():
        info &"    {lib.name} {lib.version}"

    quit 0

proc check_duplicate(val, kind: string | Path) =
    if val != default (typeof val):
        error &"Duplicate inputs provided for '{kind}'"
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
        error &"\tFalse-y: {falsy.join  \", \"},"
        quit 1

proc parse_config(cfg_file: Path): tuple[header: Header; tex_descrips: seq[TextureDescriptor]] =
    var path = cfg_file
    if path == default Path:
        let cwd_ini_path = ~/get_app_dir() / ~/ConfigFileName
        let bin_ini_path = cwd / ~/ConfigFileName
        if file_exists cwd_ini_path:
            path = cwd_ini_path
        elif file_exists bin_ini_path:
            path = bin_ini_path
        else:
            error "No configuration file specified and could not find 'nai.ini' (use --config/-c to specify)"
            quit 1

    let config = load_config $path
    for key in config.keys:
        case to_lower key
        of "vertex":
            var vc = 0
            for val in config[key].keys:
                try:
                    result.header.vertex_kinds[vc] = parse_enum[VertexKind] &"vtx{val}"
                    inc vc
                except ValueError:
                    let kinds = ($(full_set VertexKind)).multireplace(("vtx", ""), ("{", ""), ("}", ""))
                    error &"Invalid vertex kind '{val}': {kinds}"
                    quit 1
        of "materials":
            var mc = 0
            for (k, v) in pairs config[key]:
                if v == "":
                    try:
                        result.header.material_values[mc] = parse_enum[MaterialValue] &"mtl{k}"
                        inc mc
                    except ValueError:
                        let kinds = ($(full_set MaterialValue)).multireplace(("mtl", ""), ("{", ""), ("}", ""))
                        error &"Invalid material value '{k}': {kinds}"
                        quit 1
                else:
                    try:
                        let dst = if '.' in v: v.split '.' else: @[v, ""]
                        result.tex_descrips.add TextureDescriptor(
                            kind     : parse_enum[TextureKind]   &"tex{k}",
                            format   : parse_enum[TextureFormat] &"tf{dst[0]}",
                            container: (if dst[1] == "":
                                            cntNone
                                        else:
                                            parse_enum[ContainerKind] &"cnt{dst[1]}"),
                        )
                    except ValueError:
                        error &"Invalid values for material: '{k}', '{v}'"
                        quit 1
        of "":
            for (k, v) in pairs config[""]:
                case k
                of "Compression":
                    try: result.header.compression_kind = parse_enum[CompressionKind](&"cmp{to_upper_ascii v}")
                    except ValueError:
                        let kinds = ($(full_set CompressionKind)).multireplace(("cmp", ""), ("{", ""), ("}", ""))
                        error &"Invalid compression kind '{v}': {kinds}"
                        quit 1
                else:
                    try: result.header.layout_mask.incl (parse_enum[LayoutFlag] &"lf{capitalize_ascii k}{capitalize_ascii v}")
                    except ValueError:
                        error &"Invalid output flag '{k}: {v}'"
                        quit 1
        else:
            warning &"Unrecognized configuration section '{key}'"
            continue

    block validate_flags:
        let header = result.header
        proc check(flags: LayoutMask): bool =
            let intersection = flags * header.layout_mask
            if intersection.len > 1:
                error &"Incompatible flags '{intersection}'"
                result = true

        if (check {lfTexturesInternal, lfTexturesExternal}) or
           (check {lfVerticesInterleaved, lfVerticesSeparated}):
            quit 1

when is_main_module:
    var
        options = init_opt_parser()
        command = "convert"
        out_file: Path = cwd
        in_file : Path
        cfg_file: Path
        ignore  : bool = false
        quiet   : bool = false
    for kind, key, val in get_opt options:
        case kind
        of cmdLongOption, cmdShortOption:
            case key
            of "help"   , "h": write_help()
            of "verbose", "v": verbose  = key.bool_opt val
            of "quiet"  , "q": quiet    = key.bool_opt val
            of "config" , "c": cfg_file = ~/key
            of "output" , "o": out_file = ~/(val.check_present key)
            of "input"  , "i":
                in_file.check_duplicate ~/"input"
                in_file = ~/val
            of "force", "ignore", "f": ignore = key.bool_opt val
            else:
                error &"Unrecognized option: '{key}'"
                quit 1
        of cmdArgument:
            case key
            of "convert", "c": command = "convert"
            of "analyze", "a": command = "analyze"
            else:
                in_file.check_duplicate "input"
                in_file = ~/(if key == "": val else: key)
        of cmdEnd:
            discard

    if in_file == ~/"":
        error "No input file provided"
        write_help()

    if out_file == cwd:
        out_file = cwd / extract_filename in_file

    var (header, mtl_data) = parse_config cfg_file

    case command
    of "convert":
        var flags = pfGenBoundingBoxes or pfRemoveRedundantMaterials
        if vtxTangent in header.vertex_kinds:
            flags = flags or pfCalcTangentSpace

        let scene = import_file($in_file, flags)
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

        var buffer = new_string_stream ""
        header.write_header    scene, buffer
        header.write_meshes    scene, buffer
        header.write_materials scene, buffer, mtl_data, $out_file

        var file = open_file_stream($out_file, fmWrite)
        if header.compression_kind != cmpNone:
            # The header must not be compressed
            let data      = cast[ptr UncheckedArray[byte]](buffer.data[sizeof Header].addr)
            let data_size = buffer.data.len - sizeof Header
            let cmp_data = compress(header.compression_kind, clvlSize, data.to_oa data_size)

            file.write_data buffer.data[0].addr, sizeof Header
            file.write_data cmp_data.data      , int cmp_data.size
        else:
            file.write_data buffer.data[0].addr, buffer.data.len
        close file

        close buffer
        free_scene scene
    of "analyze":
        if ($in_file).ends_with ".nai":
            analyze $in_file, mtl_data
        else:
            let scene = import_file($in_file, pfGenBoundingBoxes)
            dump scene, $in_file

