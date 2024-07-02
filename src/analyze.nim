# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, terminal, strutils, sequtils],
    common, assimp/assimp, ispctc, nai
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

func layout_to_string(layout: LayoutMask): string =
    var flags: seq[string]
    for flag in layout:
        flags.add case flag
        of VerticesInterleaved: "VInt"
        of VerticesSeparated  : "VSep"
        of TexturesInternal   : "TInt"
        of TexturesExternal   : "TExt"

    if "VInt" notin flags and "VSep" notin flags:
        flags.insert("VInt", 0)
    if "TInt" notin flags and "TExt" notin flags:
        flags.insert("TInt", 1)

    result = flags.join "|"

func verts_to_string(flags: array[8, VertexKind]): string =
    flags.foldl(
        if b != None:
            a & &"[{to_lower_ascii $b}]"
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

    write verts_to_string header.vertex_kinds, sizeof Header.vertex_kinds
    stdout.write "\n"

    let cmp_str = if header.compression_kind == None: "No Compression" else: $header.compression_kind
    write cmp_str                             , sizeof Header.compression_kind
    write &"{header.mesh_count} Meshes"       , sizeof Header.mesh_count
    write &"{header.material_count} Materials", sizeof Header.material_count
    write &"{header.texture_count} Textures"  , sizeof Header.texture_count
    stdout.write "\n"
    write &"{header.animation_count} Animations", sizeof Header.animation_count
    write &"{header.animation_count} Skeletons" , sizeof Header.skeleton_count
    stdout.write "\n"

proc write_meshes(header: Header; file: FileStream; file_name: string) =
    let vert_size = header.vertex_kinds.foldl(a + b.size, 0)
    var mesh: MeshHeader
    for i in 0..<int header.mesh_count:
        file.read mesh
        let name = &"Mesh {i}"
        let vert_msg = &"Vertex data... ({vert_size * int mesh.vert_count}B / " &
                       &"{vert_size * (int mesh.vert_count) / 1024:.2f}kB / "   &
                       &"{vert_size * (int mesh.vert_count) / 1024 / 1024:.2f}MB)"
        stdout.styled_write bgWhite, fgBlack, name.center 8 * scale, bgDefault, "\n"
        write &"Index {mesh.material_index}" , sizeof mesh.material_index
        write &"Index size {mesh.index_size}", sizeof mesh.index_size
        write &"{mesh.vert_count} Vertices"  , sizeof mesh.vert_count
        stdout.write "\n"
        write &"{mesh.index_count} Indices", sizeof mesh.index_count
        write vert_msg                     , sizeof mesh.index_count
        stdout.write "\n"

        # TODO: add data preview for empty rows
        var rows  = ShadeChars.len
        var count = 8 * scale
        while count > 0:
            colour = StartColour
            for flag in header.vertex_kinds:
                if flag == None:
                    continue

                # TODO: fix partial writes when terminal width is multiple of output size
                let size = min(count, flag.size)
                if rows == ShadeChars.len:
                    let str = flag.abbrev.foldl(a & ($b).align_left(scale div 4, '.'), "")
                    stdout.styled_write ++colour, fgBlack, str.center(size, ' ')
                else:
                    stdout.styled_write ++colour, fgBlack, ShadeChars[rows - 1].repeat size
                count -= size

            if rows > 1 and count <= 0:
                dec rows
                count = 8 * scale
                stdout.write "\n"
        stdout.write "\n"

        # Skip that vertex and index data in the stream
        let inds_size = (int mesh.index_count) * mesh.index_size
        let mtl_pos   = file.get_position() + vert_size*(int mesh.vert_count) + inds_size
        file.set_position mtl_pos

proc write_materials(header: Header; file: FileStream; file_name: string; mtl_data: seq[TextureDescriptor]) =
    var material: MaterialHeader
    for i in 0..<int header.material_count:
        # Header
        file.read material
        let name = &"Material {i}"
        stdout.styled_write bgWhite, fgBlack, name.center 8 * scale, bgDefault, "\n"

        # Material Data
        var buf: array[4, float32]
        for val in header.material_values:
            if val == None:
                continue

            if file.read_data(buf.addr, val.size) != val.size:
                error &"Error reading material data for '{val}'"
            let msg = &"{val} {buf}"
            write msg.center msg.len, scale div 8
            # echo val, ": ", val.size
            # echo buf
        stdout.write "\n"

        # Textures
        var tex: TextureHeader
        for j in 0..<int material.texture_count:
            file.read tex
            write &"{tex.kind}"    , sizeof tex.kind
            write &"{tex.format}"  , sizeof tex.format
            write &"Width {tex.w}" , sizeof tex.w
            write &"Height {tex.h}", sizeof tex.h
            stdout.write "\n"

            let tex_size = tex.format.size(int tex.w, int tex.h)
            write &"Texture Data... ({bytes_to_string tex_size})", 8
            stdout.write "\n"
            for k in 0..<ShadeChars.len:
                stdout.styled_write styleDim, fgBlue, ShadeChars[k].repeat 8 * scale, bgDefault, "\n"

            # Skip the texture data
            file.set_position (file.get_position() + tex_size)

proc analyze*(file_name: string; mtl_data: seq[TextureDescriptor]) =
    var file: FileStream
    try: file = file_name.open_file_stream fmRead
    except IOError:
        error &"Failed to open '{file_name}'"
        quit 1

    var header: Header
    if file.read_data(header.addr, sizeof Header) != sizeof Header:
        error &"Failed to read header for '{file_name}'"
        quit 1

    if header.magic != NAIMagic:
        const magic = fourcc_to_string NAIMagic
        let   mstr  = fourcc_to_string header.magic
        warning &"File '{file_name}' does not have a correct magic value ({magic}), got: {mstr}"

    try: header.write_header file_name
    except ValueError:
        error &"Invalid header, file '{file_name}' does not appear to be a valid Nai file"
        quit 1

    if header.compression_kind == None:
        header.write_meshes    file, file_name
        header.write_materials file, file_name, mtl_data
        assert file.at_end
    close file

