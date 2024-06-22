import
    std/streams,
    common, header

const
    STBImage      = "../lib/stb_image.h"
    STBImageWrite = "../lib/stb_image_write.h"

    MaxTextureHintLen* = 9

type
    Texture* = object
        width*      : uint32
        height*     : uint32
        format_hint*: array[MaxTextureHintLen, byte]
        data*       : ptr UncheckedArray[Texel]
        filename*   : AIString

    Texel* = object
        b, g, r, a: uint8

proc `$`*(texture: Texture): string =
    var fmt_hint = new_string MaxTextureHintLen
    copy_mem(fmt_hint[0].addr, texture.format_hint[0].addr, MaxTextureHintLen)
    result = &"""
Texture '{texture.filename}' ({texture.width}x{texture.height}):
    Format hint      -> {fmt_hint}
    Data is internal -> {texture.data != nil}
"""

#[ -------------------------------------------------------------------- ]#

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

converter texels_to_uint8ptr*(x: ptr UncheckedArray[Texel]): ptr uint8 =
    cast[ptr uint8](x)

proc `=destroy`*(img: Image) =
    if img.data != nil:
        free_image(img.data)

proc load_image*(data: ptr uint8; len: SomeInteger): Image =
    var w, h, chan: cint
    let data = load_image(data, cint len, w.addr, h.addr, chan.addr, 4)
    Image(data: data, w: w, h: h, size: 4*w*h, channels: chan)
