# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common, nai

type
    CompressionLevel* = enum
        clNone
        clDefault
        clSpeed
        clSize

    ZLibReturn = enum
        zlrOk           = 0
        zlrStreamEnd    = 1
        zlrNeedDict     = 2
        zlrErrNo        = -1
        zlrStreamError  = -2
        zlrDataError    = -3
        zlrMemError     = -4
        zlrBufError     = -5
        zlrVersionError = -6

    ZLibCompressionLevel = enum
        zlclNoCompression      = 0
        zlclBestSpeed          = 1
        zlclBestCompression    = 9
        zlclDefaultCompression = -1

converter level_to_zlib_level(level: CompressionLevel): ZLibCompressionLevel =
    case level
    of clNone   : zlclNoCompression
    of clDefault: zlclDefaultCompression
    of clSpeed  : zlclBestSpeed
    of clSize   : zlclBestCompression

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

proc compress*(kind: CompressionKind; lvl: CompressionLevel; data: openArray[byte]): tuple[data: ptr byte, sz: uint] =
    case kind
    of ckNone: result = (data: cast[ptr byte](data[0].addr), sz: uint data.len)
    of ckZLib:
        result.sz   = zlib_compress_bound (culong data.len)
        result.data = cast[ptr byte](alloc result.sz)
        let res = zlib_compress(result.data , result.sz.addr,
                                data[0].addr, culong data.len,
                                lvl)
        if res != zlrOk:
            error &"Error compression data ({data}) using ZLib: '{res}'"
            quit 1
