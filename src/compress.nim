import common, nai

const ZLibPath = "lib/libz.so"

type
    CompressionLevel* = enum
        None
        Default
        Speed
        Size

    ZLibReturn = enum
        zlOk           = 0
        zlStreamEnd    = 1
        zlNeedDict     = 2
        zlErrNo        = -1
        zlStreamError  = -2
        zlDataError    = -3
        zlMemError     = -4
        zlBufError     = -5
        zlVersionError = -6

    ZLibCompressionLevel = enum
        zlNoCompression      = 0
        zlBestSpeed          = 1
        zlBestCompression    = 9
        zlDefaultCompression = -1

converter level_to_zlib_level(level: CompressionLevel): ZLibCompressionLevel =
    case level
    of None   : zlNoCompression
    of Default: zlDefaultCompression
    of Speed  : zlBestSpeed
    of Size   : zlBestCompression

#[ -------------------------------------------------------------------- ]#

using
    src: ptr byte
    dst: ptr byte

{.push dynlib: ZLibPath.}
proc zlib_version(): cstring                                                                                {.importc: "zlibVersion"  .}
proc zlib_compress(dst; dst_len: ptr culong; src; src_len: culong; level: ZLibCompressionLevel): ZLibReturn {.importc: "compress2"    .}
proc zlib_compress_bound(src_len: culong): culong                                                           {.importc: "compressBound".}
{.pop.}

proc get_versions*(): seq[tuple[name, version: string]] =
    @[("zlib", $zlib_version())]

proc compress*(kind: CompressionKind; level: CompressionLevel; data: openArray[byte]): tuple[data: ptr byte, size: uint] =
    case kind
    of None: result = (data: cast[ptr byte](data[0].addr), size: uint data.len)
    of ZLib:
        result.size = zlib_compress_bound (culong data.len)
        result.data = cast[ptr byte](alloc result.size)
        let res = zlib_compress(result.data , result.size.addr,
                                data[0].addr, culong data.len,
                                level)
        if res != zlOk:
            error &"Error compression data ({data}) using ZLib: '{res}'"
            quit 1
    else:
        error &"Compression not implemented for {kind}"
        quit 1

