import std/compilesettings, common
from std/strutils  import contains
from assimp/assimp import AITexel

const
    STBImage      = "../lib/stb_image.h"
    STBImageWrite = "../lib/stb_image_write.h"

# For tcc compat
when query_setting(commandLine).contains "--cc:tcc":
    {.emit: "#define STBI_NO_SIMD".}

{.emit: &"""
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "{STBImage}"
#include "{STBImageWrite}"
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
{.pop.}

#[ -------------------------------------------------------------------- ]#

type Image* = object
    data*    : ptr uint8
    w*, h*   : int
    size*    : int
    channels*: int

converter texels_to_uint8ptr*(x: ptr UncheckedArray[AITexel]): ptr uint8 =
    cast[ptr uint8](x)

proc `=destroy`*(img: Image) =
    if img.data != nil:
        free_image(img.data)

proc load_image*(data: ptr uint8; len: SomeInteger; bpp = 4): Image =
    var w, h, chan: cint
    let data = load_image(data, cint len, w.addr, h.addr, chan.addr, cint bpp)
    Image(data: data, w: w, h: h, size: 4*w*h, channels: chan)
