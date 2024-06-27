# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[terminal, strutils, sequtils],
    common, assimp/assimp

func bytes_to_string(bytes: int): string =
    if bytes >= 1024*1024:
        &"{bytes / 1024 / 1024:.1f}MB"
    elif bytes >= 1024:
        &"{bytes / 1024:.1f}kB"
    else:
        &"{bytes}B"

proc output_descrip*(parts: openArray[(string, int)]) =
    verbose = true
    let
        # rows = terminal_height() - 1
        rows = 20
        cols = terminal_width()
        size = float(rows * cols)
    var sections: seq[(BackgroundColor, string, int)]
    var colour = bgRed
    for (name, size) in parts:
        sections.add (colour, name, size)
        inc colour
    let total = sections.foldl(a + b[2], 0)

    stdout.styled_write "\n"
    for (bg, name, len) in sections:
        let name = &"{name} ({bytes_to_string len})"
        let len = max(1, int(len / total * size))
        if len < name.len:
            stdout.styled_write(fgBlack, bg, " ")
        else:
            stdout.styled_write(fgBlack, bg, center(name, len))
    stdout.styled_write "\n"
