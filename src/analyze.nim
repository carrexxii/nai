# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, terminal, strutils, sequtils],
    common, assimp/assimp, nai

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

proc write_header(header: Header; file_name: string) =
    let scale  = min(8, terminal_width() div 8)
    var colour = StartColour
    proc write(str: string; size: int) =
        write str, size, scale, colour

    let name = &"Nai File '{file_name}'"
    stdout.styled_write bgWhite, fgBlack, name.center(8 * scale, '-'), bgDefault, "\n"

    write fourcc_to_string header.magic              , sizeof Header.magic
    write &"V{header.version[0]}.{header.version[1]}", sizeof Header.version
    write layout_to_string header.layout_flags       , sizeof Header.layout_flags
    stdout.write "\n"

    write verts_to_string header.vertex_flags, sizeof Header.vertex_flags
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

proc analyze*(file_name: string) =
    var file = open_file_stream(file_name, fmRead)

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

    let scale  = min(16, terminal_width() div 8)
    var colour = StartColour
    proc write(str: string; size: int) =
        write str, size, scale, colour

    var mesh: MeshHeader
    for i in 0..<int header.mesh_count:
        if file.read_data(mesh.addr, sizeof MeshHeader) != sizeof MeshHeader:
            error &"Failed to read mesh {i} header for file '{file_name}'"
            quit 1

        let name = &"Mesh {i}"
        stdout.styled_write bgWhite, fgBlack, name.center 8 * scale, bgDefault, "\n"
        write &"Index {mesh.material_index}" , sizeof mesh.material_index
        write &"Index size {mesh.index_size}", sizeof mesh.index_size
        write &"{mesh.vert_count} Vertices"  , sizeof mesh.vert_count
        stdout.write "\n"
        write &"{mesh.index_count} Indices", sizeof mesh.index_count
        write "Vertex data..."             , sizeof mesh.index_count
        stdout.write "\n"

        var count = 8 * scale
        while count > 0:
            for flag in header.vertex_flags:
                if flag == None:
                    continue

                let size = min(count, flag.size)
                let str  = flag.abbrev.foldl(a & ($b).align_left(scale div 4, '.'), "")
                stdout.styled_write ++colour, fgBlack, str.center(size, ' ')
                count -= size
        stdout.write "\n"

    close file
