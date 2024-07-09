# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, nai

type
    CompressionLevel* = enum
        clvlNone
        clvlDefault
        clvlSpeed
        clvlSize

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
    of clvlNone   : zlNoCompression
    of clvlDefault: zlDefaultCompression
    of clvlSpeed  : zlBestSpeed
    of clvlSize   : zlBestCompression

#[ -------------------------------------------------------------------- ]#

using
    src: ptr byte
    dst: ptr byte

proc zlib_version(): cstring                                                                                {.importc: "zlibVersion"  .}
proc zlib_compress(dst; dst_len: ptr culong; src; src_len: culong; level: ZLibCompressionLevel): ZLibReturn {.importc: "compress2"    .}
proc zlib_compress_bound(src_len: culong): culong                                                           {.importc: "compressBound".}

#[ -------------------------------------------------------------------- ]#

proc get_versions*(): seq[tuple[name, version: string]] =
    @[("zlib", $zlib_version())]

proc compress*(kind: CompressionKind; level: CompressionLevel; data: openArray[byte]): tuple[data: ptr byte, size: uint] =
    case kind
    of cmpNone: result = (data: cast[ptr byte](data[0].addr), size: uint data.len)
    of cmpZLib:
        result.size = zlib_compress_bound (culong data.len)
        result.data = cast[ptr byte](alloc result.size)
        let res = zlib_compress(result.data , result.size.addr,
                                data[0].addr, culong data.len,
                                level)
        if res != zlOk:
            error &"Error compression data ({data}) using ZLib: '{res}'"
            quit 1

