# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common
from std/math import ceil_div

type
    ProfileKind* = enum
        pkUltraFast
        pkVeryFast
        pkFast
        pkBasic
        pkSlow
        pkVerySlow

    TextureCompressionKind* = enum
        tckNoneRgb
        tckNoneRgba
        tckBc1
        tckBc3
        tckBc4
        tckBc5
        tckBc6H
        tckBc7
        tckEtc1
        tckAstc

type
    RgbaSurface = object
        data  : ptr byte
        w, h  : uint32
        stride: uint32

    Bc7EncSettings = object
        mode_selection           : array[4, bool]
        refine_iterations        : array[8, cint]
        skip_mode2               : bool
        fast_skip_threshold_mode1: cint
        fast_skip_threshold_mode3: cint
        fast_skip_threshold_mode7: cint
        mode45_channel0          : cint
        refine_iterations_channel: cint
        channels                 : cint

    Bc6HEncSettings = object
        slow_mode           : bool
        fast_mode           : bool
        refine_iterations_1p: cint
        refine_iterations_2p: cint
        fast_skip_threshold : cint

    EtcEncSettings = object
        fast_skip_threshold: cint

    AstcEncSettings = object
        block_w            : cint
        block_h            : cint
        channels           : cint
        fast_skip_threshold: cint
        refine_iterations  : cint

    CompressionProfile* = object
        case kind*: TextureCompressionKind
        of tckBc6H: bc6h: Bc6HEncSettings
        of tckBc7 : bc7 : Bc7EncSettings
        of tckEtc1: etc1: EtcEncSettings
        of tckAstc: astc: AstcEncSettings
        else: discard

    CompressedTexture* = object
        data*: ptr byte
        sz*  : int

#[ -------------------------------------------------------------------- ]#

# BC7 with ignored alpha
proc get_profile_ultra_fast*(settings: ptr Bc7EncSettings) {.importc: "GetProfile_ultrafast".}
proc get_profile_very_fast* (settings: ptr Bc7EncSettings) {.importc: "GetProfile_veryfast" .}
proc get_profile_fast*      (settings: ptr Bc7EncSettings) {.importc: "GetProfile_fast"     .}
proc get_profile_basic*     (settings: ptr Bc7EncSettings) {.importc: "GetProfile_basic"    .}
proc get_profile_slow*      (settings: ptr Bc7EncSettings) {.importc: "GetProfile_slow"     .}

proc get_profile_alpha_ultra_fast*(settings: ptr Bc7EncSettings) {.importc: "GetProfile_alpha_ultrafast".}
proc get_profile_alpha_very_fast* (settings: ptr Bc7EncSettings) {.importc: "GetProfile_alpha_veryfast" .}
proc get_profile_alpha_fast*      (settings: ptr Bc7EncSettings) {.importc: "GetProfile_alpha_fast"     .}
proc get_profile_alpha_basic*     (settings: ptr Bc7EncSettings) {.importc: "GetProfile_alpha_basic"    .}
proc get_profile_alpha_slow*      (settings: ptr Bc7EncSettings) {.importc: "GetProfile_alpha_slow"     .}

proc get_profile_bc6h_very_fast*(settings: ptr Bc6HEncSettings) {.importc: "GetProfile_bc6h_veryfast".}
proc get_profile_bc6h_fast*     (settings: ptr Bc6HEncSettings) {.importc: "GetProfile_bc6h_fast"    .}
proc get_profile_bc6h_basic*    (settings: ptr Bc6HEncSettings) {.importc: "GetProfile_bc6h_basic"   .}
proc get_profile_bc6h_slow*     (settings: ptr Bc6HEncSettings) {.importc: "GetProfile_bc6h_slow"    .}
proc get_profile_bc6h_very_slow*(settings: ptr Bc6HEncSettings) {.importc: "GetProfile_bc6h_veryslow".}

proc get_profile_etc_slow*(settings: ptr EtcEncSettings) {.importc: "GetProfile_etc_slow".}

proc get_profile_astc_fast*      (settings: ptr AstcEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_fast"      .}
proc get_profile_astc_alpha_fast*(settings: ptr AstcEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_alpha_fast".}
proc get_profile_astc_alpha_slow*(settings: ptr AstcEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_alpha_slow".}

# Notes:
#  - input width and height need to be a multiple of block size
#  - LDR input is 32 bit/pixel (sRGB), HDR is 64 bit/pixel (half float)
#      - for BC4 input is 8bit/pixel (R8), for BC5 input is 16bit/pixel (RG8)
#  - dst buffer must be allocated with enough space for the compressed texture:
#      - 8 bytes/block for BC1/BC4/ETC1,
#      - 16 bytes/block for BC3/BC5/BC6H/BC7/ASTC
#  - the blocks are stored in raster scan order (natural CPU texture layout)
#  - use the GetProfile_* functions to select various speed/quality tradeoffs
#  - the RGB profiles are slightly faster as they ignore the alpha channel
proc compress_blocks_bc1* (src: ptr RgbaSurface; dst: ptr byte)                                {.importc: "CompressBlocksBC1" .}
proc compress_blocks_bc3* (src: ptr RgbaSurface; dst: ptr byte)                                {.importc: "CompressBlocksBC3" .}
proc compress_blocks_bc4* (src: ptr RgbaSurface; dst: ptr byte)                                {.importc: "CompressBlocksBC4" .}
proc compress_blocks_bc5* (src: ptr RgbaSurface; dst: ptr byte)                                {.importc: "CompressBlocksBC5" .}
proc compress_blocks_bc6h*(src: ptr RgbaSurface; dst: ptr byte; settings: ptr Bc6HEncSettings) {.importc: "CompressBlocksBC6H".}
proc compress_blocks_bc7* (src: ptr RgbaSurface; dst: ptr byte; settings: ptr Bc7EncSettings)  {.importc: "CompressBlocksBC7" .}
proc compress_blocks_etc1*(src: ptr RgbaSurface; dst: ptr byte; settings: ptr EtcEncSettings)  {.importc: "CompressBlocksETC1".}
proc compress_blocks_astc*(src: ptr RgbaSurface; dst: ptr byte; settings: ptr AstcEncSettings) {.importc: "CompressBlocksASTC".}

proc replicate_borders*(dst_slice, src_tex: ptr RgbaSurface; x, y, bpp: cint) {.importc: "ReplicateBorders".}

#[ -------------------------------------------------------------------- ]#

func bytes_per_block(kind: TextureCompressionKind): int =
    case kind
    of tckBc1, tckBc4, tckEtc1: 8
    of tckBc3, tckBc5, tckBc6H, tckBc7, tckAstc: 16
    of tckNoneRgb : 48
    of tckNoneRgba: 64

func sz*(kind: TextureCompressionKind; w, h: int): int =
    let block_count = (w div 4) * (h div 4)
    result = kind.bytes_per_block * block_count

proc get_profile*(kind: TextureCompressionKind; mode = pkBasic; with_alpha = true; block_size = (4, 4)): CompressionProfile =
    result = CompressionProfile(kind: kind)
    case kind
    of tckBc6H:
        if mode == pkUltraFast:
            warning &"No mode '{mode}' available, using '{pkVeryFast}'"
        case mode
        of pkUltraFast,
           pkVeryFast: get_profile_bc6h_very_fast result.bc6h.addr
        of pkFast    : get_profile_bc6h_fast      result.bc6h.addr
        of pkBasic   : get_profile_bc6h_basic     result.bc6h.addr
        of pkSlow    : get_profile_bc6h_slow      result.bc6h.addr
        of pkVerySlow: get_profile_bc6h_very_slow result.bc6h.addr
    of tckBc7:
        if mode == pkVerySlow:
            warning &"No mode '{mode}' available, using '{pkSlow}'"
        if with_alpha:
            case mode
            of pkUltraFast: get_profile_alpha_ultra_fast result.bc7.addr
            of pkVeryFast : get_profile_alpha_very_fast  result.bc7.addr
            of pkFast     : get_profile_alpha_fast       result.bc7.addr
            of pkBasic    : get_profile_alpha_basic      result.bc7.addr
            of pkSlow,
               pkVerySlow: get_profile_alpha_slow result.bc7.addr
        else:
            case mode
            of pkUltraFast: get_profile_ultra_fast result.bc7.addr
            of pkVeryFast : get_profile_very_fast  result.bc7.addr
            of pkFast     : get_profile_fast       result.bc7.addr
            of pkBasic    : get_profile_basic      result.bc7.addr
            of pkSlow,
               pkVerySlow: get_profile_slow result.bc7.addr
    of tckEtc1:
        if mode != pkSlow:
            warning &"The only mode available for ETC1 is '{pkSlow}' (got '{mode}')"
        get_profile_etc_slow result.etc1.addr
    of tckAstc:
        if mode != pkFast or (with_alpha and mode != pkFast):
            let alpha_msg = if with_alpha: "with alpha" else: "without alpha"
            warning &"No mode '{mode}' available {alpha_msg}"
        if with_alpha:
            case mode
            of pkUltraFast, pkVeryFast, pkFast:
                get_profile_astc_alpha_fast(result.astc.addr, cint block_size[0], cint block_size[1])
            of pkBasic, pkSlow, pkVerySlow:
                get_profile_astc_alpha_slow(result.astc.addr, cint block_size[0], cint block_size[1])
        else:
            get_profile_astc_fast(result.astc.addr, cint block_size[0], cint block_size[1])
    else:
        discard

proc alloc_img(w, h, bpp: int): RgbaSurface =
    result.w      = uint32 w
    result.h      = uint32 h
    result.stride = uint32 (bpp * w)
    result.data   = cast[ptr byte](alloc(result.h * result.stride))

proc compress*(profile: CompressionProfile; src: ptr byte; w, h, bpp: int): CompressedTexture =
    const BlockWidth  = 4
    const BlockHeight = 4
    let bw = BlockWidth  * ceil_div(w, BlockWidth)
    let bh = BlockHeight * ceil_div(h, BlockHeight)
    let block_count = int (bw div BlockWidth) * (bw div BlockHeight)

    # let raw_img   = RgbaSurface(data: src, width: uint32 w, height: uint32 h, stride: uint32 (bpp * w))
    var edged_img = alloc_img(bw, bh, bpp) # TODO: fix the edging for non power-of-two
    copy_mem(edged_img.data, src, int(edged_img.stride * edged_img.h))
    # replicate_borders(edged_img.addr, raw_img.addr, cint bw, cint bh, 32)

    result.sz   = profile.kind.bytes_per_block * block_count
    result.data = cast[ptr byte](alloc result.sz)
    case profile.kind
    of tckBc1 : compress_blocks_bc1  edged_img.addr, result.data
    of tckBc3 : compress_blocks_bc3  edged_img.addr, result.data
    of tckBc4 : compress_blocks_bc4  edged_img.addr, result.data
    of tckBc5 : compress_blocks_bc5  edged_img.addr, result.data
    of tckBc6H: compress_blocks_bc6h edged_img.addr, result.data, profile.bc6h.addr
    of tckBc7 : compress_blocks_bc7  edged_img.addr, result.data, profile.bc7.addr
    of tckEtc1: compress_blocks_etc1 edged_img.addr, result.data, profile.etc1.addr
    of tckAstc: compress_blocks_astc edged_img.addr, result.data, profile.astc.addr
    of tckNoneRgb, tckNoneRgba:
        assert false, &"Should not call compress with '{profile.kind}'"
