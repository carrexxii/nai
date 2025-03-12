# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, terminal, strutils, sequtils],
    common, assimp/assimp, ispctc, nai, util
from std/os import get_file_size

const ShadeChars  = ["▓", "▒", "░"]

const StartColour = bgRed
proc `++`(colour: var BackgroundColor): BackgroundColor =
    if colour == bgCyan:
        colour = StartColour
    else:
        inc colour
    result = colour

func fourcc_to_string(arr: array[4, char | byte]): string =
    result = new_string_of_cap 4
    for c in arr:
        result.add(char c)

func bytes_to_string(bytes: int): string =
    if bytes >= 1024*1024:
        &"{bytes / 1024 / 1024:.1f}MB"
    elif bytes >= 1024:
        &"{bytes / 1024:.1f}kB"
    else:
        &"{bytes}B"

func layout_to_string(layout: set[LayoutFlag]): string =
    var flags: seq[string]
    for flag in layout:
        flags.add case flag
        of lfVerticesInterleaved: "VInt"
        of lfVerticesSeparated  : "VSep"
        of lfTexturesInternal   : "TInt"
        of lfTexturesExternal   : "TExt"

    if "VInt" notin flags and "VSep" notin flags:
        flags.insert("VInt", 0)
    if "TInt" notin flags and "TExt" notin flags:
        flags.insert("TInt", 1)

    result = flags.join "|"

func verts_to_string(flags: array[8, VertexKind]): string =
    flags.foldl(
        if b != vkNone:
            a & &"[{to_lower_ascii ($b)[3..^1]}]"
        else:
            a,
        "")

proc write(str: string; size, scale: int; colour: var BackgroundColor) =
    var wstr = str
    if wstr.len >= size * scale:
        wstr.set_len size * scale
    else:
        wstr = wstr.center (scale * size)
    stdout.styled_write fgBlack, ++colour, wstr

let scale  = min(16, terminal_width() div 8)
var colour = StartColour
proc write(str: string; size: int) =
    write str, size, scale, colour

proc write_header(header: Header; file_name: string) =
    let scale  = min(16, terminal_width() div 8)
    var colour = StartColour
    proc write(str: string; size: int) =
        write str, size, scale, colour

    let file_size = get_file_size file_name
    let head = &"Nai File '{file_name}' ({bytes_to_string file_size})"
    stdout.styled_write bgWhite, fgBlack, head.center(8 * scale, '-'), bgDefault, "\n"

    write fourcc_to_string header.magic              , sizeof Header.magic
    write &"V{header.version[0]}.{header.version[1]}", sizeof Header.version
    write layout_to_string header.layout_mask        , sizeof Header.layout_mask
    stdout.write "\n"

    write verts_to_string header.vtx_kinds, sizeof Header.vtx_kinds
    stdout.write "\n"

    let cmp_str = if header.cmp_kind == ckNone: "No Compression" else: ($header.cmp_kind)[3..^1]
    write cmp_str                      , sizeof Header.cmp_kind
    write &"{header.mesh_cnt} Meshes"  , sizeof Header.mesh_cnt
    write &"{header.mtl_cnt} Materials", sizeof Header.mtl_cnt
    write &"{header.tex_cnt} Textures" , sizeof Header.tex_cnt
    stdout.write "\n"
    write &"{header.anim_cnt} Animations", sizeof Header.anim_cnt
    write &"{header.anim_cnt} Skeletons" , sizeof Header.skeleton_cnt
    stdout.write "\n"

proc write_meshes(header: Header; file: FileStream; file_name: string) =
    let vtx_sz = header.vtx_kinds.foldl(a + b, 0)
    var mesh: MeshHeader
    for i in 0..<int header.mesh_cnt:
        file.read mesh
        let name = &"Mesh {i}"
        let vtx_msg = &"Vertex data... ({vtx_sz * int mesh.vtx_cnt}B / " &
                      &"{vtx_sz * (int mesh.vtx_cnt) / 1024:.2f}kB / "   &
                      &"{vtx_sz * (int mesh.vtx_cnt) / 1024 / 1024:.2f}MB)"
        stdout.styled_write bgWhite, fgBlack, name.center 8 * scale, bgDefault, "\n"
        write &"Index {mesh.mtl_idx}"    , sizeof mesh.mtl_idx
        write &"Index size {mesh.idx_sz}", sizeof mesh.idx_sz
        write &"{mesh.vtx_cnt} Vertices" , sizeof mesh.vtx_cnt
        stdout.write "\n"
        write &"{mesh.idx_cnt} Indices", sizeof mesh.idx_cnt
        write vtx_msg                  , sizeof mesh.idx_cnt
        stdout.write "\n"

        # TODO: add data preview for empty rows
        var rows  = ShadeChars.len
        var cnt = 8 * scale
        while cnt > 0:
            colour = StartColour
            for flag in header.vtx_kinds:
                if flag == vkNone:
                    continue

                # TODO: fix partial writes when terminal width is multiple of output size
                let sz = min(cnt, flag)
                if rows == ShadeChars.len:
                    let str = flag.abbrev.foldl(a & ($b).align_left(scale div 4, '.'), "")
                    stdout.styled_write ++colour, fgBlack, str.center(sz, ' ')
                else:
                    stdout.styled_write ++colour, fgBlack, ShadeChars[rows - 1].repeat sz
                cnt -= sz

            if rows > 1 and cnt <= 0:
                dec rows
                cnt = 8 * scale
                stdout.write "\n"
        stdout.write "\n"

        # Skip that vertex and index data in the stream
        let idx_sz  = (int mesh.idx_cnt) * mesh.idx_sz
        let mtl_pos = file.get_position() + vtx_sz*(int mesh.vtx_cnt) + idx_sz
        file.set_position mtl_pos

proc write_materials(header: Header; file: FileStream; file_name: string; mtl_data: seq[TextureDescriptor]) =
    var mtl: MaterialHeader
    for i in 0..<int header.mtl_cnt:
        # Header
        file.read mtl
        let name = &"Material {i}"
        stdout.styled_write bgWhite, fgBlack, name.center 8 * scale, bgDefault, "\n"

        # Material Data
        var buf: array[4, float32]
        for val in header.mtl_vals:
            if val == mvNone:
                continue

            if file.read_data(buf.addr, val) != val:
                error &"Error reading material data for '{val}'"
            let msg = &"{val} {buf}"
            write msg.center msg.len, scale div 8
        stdout.write "\n"

        # Textures
        var tex: TextureHeader
        for j in 0..<int mtl.tex_cnt:
            file.read tex
            write &"{tex.kind}"    , sizeof tex.kind
            write &"{tex.fmt}"     , sizeof tex.fmt
            write &"Width {tex.w}" , sizeof tex.w
            write &"Height {tex.h}", sizeof tex.h
            stdout.write "\n"

            let tex_sz = tex.fmt.size(int tex.w, int tex.h)
            write &"Texture Data... ({bytes_to_string tex_sz})", 8
            stdout.write "\n"
            for k in 0..<ShadeChars.len:
                stdout.styled_write styleDim, fgBlue, ShadeChars[k].repeat 8 * scale, bgDefault, "\n"

            # Skip the texture data
            file.set_position (file.get_position() + tex_sz)

proc analyze*(file_name: string; mtl_data: seq[TextureDescriptor]) =
    var file: FileStream
    try: file = file_name.open_file_stream fmRead
    except IoError:
        error &"Failed to open '{file_name}'"
        quit 1

    var header: Header
    if file.read_data(header.addr, sizeof Header) != sizeof Header:
        error &"Failed to read header for '{file_name}'"
        quit 1

    if header.magic != Magic:
        const magic = fourcc_to_string Magic
        let   mstr  = fourcc_to_string header.magic
        warning &"File '{file_name}' does not have a correct magic value ({magic}), got: {mstr}"

    try: header.write_header file_name
    except ValueError:
        error &"Invalid header, file '{file_name}' does not appear to be a valid Nai file"
        quit 1

    if header.cmp_kind == ckNone:
        header.write_meshes    file, file_name
        header.write_materials file, file_name, mtl_data
        assert file.at_end
    close file
