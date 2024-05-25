import common

const MaxTextureLenHint = 9

type
    Texture* = object
        width      : uint32
        height     : uint32
        format_hint: array[MaxTextureLenHint, byte]
        data       : ptr UncheckedArray[Texel]
        filename   : AIString

    Texel* = object
        b, g, r, a: byte
