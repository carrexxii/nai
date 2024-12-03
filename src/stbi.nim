# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/[compilesettings, streams], common
from std/strutils  import contains
from assimp/assimp import AiTexel

const
    StbImageHeader      = "../lib/stb_image.h"
    StbImageWriteHeader = "../lib/stb_image_write.h"

type ImageFormat* = enum
    ifPng
    ifBmp
    ifTga
    ifJpg
    ifHdr

type
    WriteFunction = proc(ctx, data: pointer; size: cint) {.cdecl.}

    Image* = object
        data*    : ptr uint8
        w*, h*   : int
        sz*      : int
        channels*: int

# For tcc compat
when query_setting(commandLine).contains "--cc:tcc":
    {.emit: "#define STBI_NO_SIMD".}

{.emit: &"""
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "{StbImageHeader}"
#include "{StbImageWriteHeader}"
""".}
{.push nodecl.}
proc load_image*(buffer: ptr uint8; len: cint; x, y, chan: ptr cint; want_chan: cint): ptr uint8 {.importc: "stbi_load_from_memory".}
proc stbi_failure_reason*(data: pointer): cstring                                                {.importc: "stbi_failure_reason"  .}
proc free_image*(data: pointer)                                                                  {.importc: "stbi_image_free"      .}

proc write_png*(fname: cstring; w, h, comp: cint; data: pointer; stride: cint): cint  {.importc: "stbi_write_png".}
proc write_bmp*(fname: cstring; w, h, comp: cint; data: pointer): cint                {.importc: "stbi_write_bmp".}
proc write_tga*(fname: cstring; w, h, comp: cint; data: pointer): cint                {.importc: "stbi_write_tga".}
proc write_jpg*(fname: cstring; w, h, comp: cint; data: pointer; quality: cint): cint {.importc: "stbi_write_jpg".}
proc write_hdr*(fname: cstring; w, h, comp: cint; data: ptr cfloat): cint             {.importc: "stbi_write_hdr".}

proc write_png*(fn: WriteFunction; ctx: pointer; w, h, comp: cint; data: pointer; stride: cint): cint  {.importc: "stbi_write_png_to_func".}
proc write_bmp*(fn: WriteFunction; ctx: pointer; w, h, comp: cint; data: pointer): cint                {.importc: "stbi_write_bmp_to_func".}
proc write_tga*(fn: WriteFunction; ctx: pointer; w, h, comp: cint; data: pointer): cint                {.importc: "stbi_write_tga_to_func".}
proc write_jpg*(fn: WriteFunction; ctx: pointer; w, h, comp: cint; data: pointer; quality: cint): cint {.importc: "stbi_write_hdr_to_func".}
proc write_hdr*(fn: WriteFunction; ctx: pointer; w, h, comp: cint; data: ptr cfloat): cint             {.importc: "stbi_write_jpg_to_func".}
{.pop.}

#[ -------------------------------------------------------------------- ]#

converter `ptr UncheckedArray[AiTexel] -> ptr uint8`*(x: ptr UncheckedArray[AiTexel]): ptr uint8 = cast[ptr uint8](x)

proc `=destroy`*(img: Image) =
    if img.data != nil:
        free_image(img.data)

proc load_image*(data: ptr uint8; len: SomeInteger; bpp = 4): Image =
    var w, h, chan: cint
    let data = load_image(data, cint len, w.addr, h.addr, chan.addr, cint bpp)
    result = Image(data: data, w: w, h: h, sz: 4*w*h, channels: bpp)

    info &"[STBI] Loaded image from memory w/{bpp}Bpp ({w}x{h} with {chan} channels)"

proc writer(ctx, data: pointer; sz: cint) {.cdecl.} =
    let file = cast[ptr Stream](ctx)[]
    file.write_data data, sz
proc write_image*(file: Stream; fmt: ImageFormat; w, h, comp: int; data: pointer) =
    let fn: WriteFunction = writer
    let res = case fmt
    of ifPng: fn.write_png file.addr, cint w, cint h, cint comp, data, 0
    else: 0

    if res == 0: # wtf?
        error &"Error writing {fmt} image ({w}x{h} w/{comp} channels)"
        quit 1
    info &"[STBI] Wrote image to memory as {fmt} ({w}x{h} w/{comp} components)"
