import
    std/[terminal, strutils, sequtils],
    common, header, mesh

var verbose* = false

template write(args: varargs[untyped]) =
    if verbose:
        stdout.styled_write args

proc info*(   msg: string) = write(fgWhite ,              msg, "\n")
proc warning*(msg: string) = write(fgYellow, "Warning: ", msg, "\n")
proc error*(  msg: string) = write(fgRed   , "Error: "  , msg, "\n")

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
        rows = terminal_height() - 1
        cols = terminal_width()
        size = float(rows * cols)
    var sections: seq[(BackgroundColor, string, int)]
    var colour = bgRed
    for (name, size) in parts:
        sections.add (colour, name, size)
        inc colour
    let total = sections.foldl(a + b[2], 0)

    write "\n"
    for (bg, name, len) in sections:
        let name = &"{name} ({bytes_to_string len})"
        let len = max(1, int(len / total * size))
        if len < name.len:
            write(fgBlack, bg, " ")
        else:
            write(fgBlack, bg, center(name, len))
    write "\n"
