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
        cmpNoneRGB
        cmpNoneRGBA
        cmpBC1
        cmpBC3
        cmpBC4
        cmpBC5
        cmpBC6H
        cmpBC7
        cmpETC1
        cmpASTC

type
    RGBASurface = object
        data  : ptr byte
        width : uint32
        height: uint32
        stride: uint32

    BC7EncSettings = object
        mode_selection           : array[4, bool]
        refine_iterations        : array[8, cint]
        skip_mode2               : bool
        fast_skip_threshold_mode1: cint
        fast_skip_threshold_mode3: cint
        fast_skip_threshold_mode7: cint
        mode45_channel0          : cint
        refine_iterations_channel: cint
        channels                 : cint

    BC6HEncSettings = object
        slow_mode           : bool
        fast_mode           : bool
        refine_iterations_1p: cint
        refine_iterations_2p: cint
        fast_skip_threshold : cint

    ETCEncSettings = object
        fast_skip_threshold: cint

    ASTCEncSettings = object
        block_width        : cint
        block_height       : cint
        channels           : cint
        fast_skip_threshold: cint
        refine_iterations  : cint

    CompressionProfile* = object
        case kind*: TextureCompressionKind
        of cmpBC6H: bc6h: BC6HEncSettings
        of cmpBC7 : bc7 : BC7EncSettings
        of cmpETC1: etc1: ETCEncSettings
        of cmpASTC: astc: ASTCEncSettings
        else: discard

    CompressedTexture* = object
        data*: ptr byte
        size*: int

#[ -------------------------------------------------------------------- ]#

# BC7 with ignored alpha
proc get_profile_ultra_fast*(settings: ptr BC7EncSettings) {.importc: "GetProfile_ultrafast".}
proc get_profile_very_fast*( settings: ptr BC7EncSettings) {.importc: "GetProfile_veryfast" .}
proc get_profile_fast*(      settings: ptr BC7EncSettings) {.importc: "GetProfile_fast"     .}
proc get_profile_basic*(     settings: ptr BC7EncSettings) {.importc: "GetProfile_basic"    .}
proc get_profile_slow*(      settings: ptr BC7EncSettings) {.importc: "GetProfile_slow"     .}

proc get_profile_alpha_ultra_fast*(settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_ultrafast".}
proc get_profile_alpha_very_fast*( settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_veryfast" .}
proc get_profile_alpha_fast*(      settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_fast"     .}
proc get_profile_alpha_basic*(     settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_basic"    .}
proc get_profile_alpha_slow*(      settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_slow"     .}

proc get_profile_bc6h_very_fast*(settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_veryfast".}
proc get_profile_bc6h_fast*(     settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_fast"    .}
proc get_profile_bc6h_basic*(    settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_basic"   .}
proc get_profile_bc6h_slow*(     settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_slow"    .}
proc get_profile_bc6h_very_slow*(settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_veryslow".}

proc get_profile_etc_slow*(settings: ptr ETCEncSettings) {.importc: "GetProfile_etc_slow".}

proc get_profile_astc_fast*(      settings: ptr ASTCEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_fast"      .}
proc get_profile_astc_alpha_fast*(settings: ptr ASTCEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_alpha_fast".}
proc get_profile_astc_alpha_slow*(settings: ptr ASTCEncSettings; bw, bh: cint) {.importc: "GetProfile_astc_alpha_slow".}

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
proc compress_blocks_bc1*( src: ptr RGBASurface; dst: ptr byte)                                {.importc: "CompressBlocksBC1" .}
proc compress_blocks_bc3*( src: ptr RGBASurface; dst: ptr byte)                                {.importc: "CompressBlocksBC3" .}
proc compress_blocks_bc4*( src: ptr RGBASurface; dst: ptr byte)                                {.importc: "CompressBlocksBC4" .}
proc compress_blocks_bc5*( src: ptr RGBASurface; dst: ptr byte)                                {.importc: "CompressBlocksBC5" .}
proc compress_blocks_bc6h*(src: ptr RGBASurface; dst: ptr byte; settings: ptr BC6HEncSettings) {.importc: "CompressBlocksBC6H".}
proc compress_blocks_bc7*( src: ptr RGBASurface; dst: ptr byte; settings: ptr BC7EncSettings)  {.importc: "CompressBlocksBC7" .}
proc compress_blocks_etc1*(src: ptr RGBASurface; dst: ptr byte; settings: ptr ETCEncSettings)  {.importc: "CompressBlocksETC1".}
proc compress_blocks_astc*(src: ptr RGBASurface; dst: ptr byte; settings: ptr ASTCEncSettings) {.importc: "CompressBlocksASTC".}

proc replicate_borders*(dst_slice, src_tex: ptr RGBASurface; x, y, bpp: cint) {.importc: "ReplicateBorders".}

#[ -------------------------------------------------------------------- ]#

func bytes_per_block(kind: TextureCompressionKind): int =
    case kind
    of cmpBC1, cmpBC4, cmpETC1: 8
    of cmpBC3, cmpBC5, cmpBC6H, cmpBC7, cmpASTC: 16
    of cmpNoneRGB : 48
    of cmpNoneRGBA: 64

func size*(kind: TextureCompressionKind; w, h: int): int =
    let block_count = (w div 4) * (h div 4)
    result = kind.bytes_per_block * block_count

proc get_profile*(kind: TextureCompressionKind; mode = pkBasic; with_alpha = true; block_size = (4, 4)): CompressionProfile =
    result = CompressionProfile(kind: kind)
    case kind
    of cmpBC6H:
        if mode == pkUltraFast:
            warning &"No mode '{mode}' available, using '{pkVeryFast}'"
        case mode
        of pkUltraFast,
           pkVeryFast: get_profile_bc6h_very_fast result.bc6h.addr
        of pkFast    : get_profile_bc6h_fast      result.bc6h.addr
        of pkBasic   : get_profile_bc6h_basic     result.bc6h.addr
        of pkSlow    : get_profile_bc6h_slow      result.bc6h.addr
        of pkVerySlow: get_profile_bc6h_very_slow result.bc6h.addr
    of cmpBC7:
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
    of cmpETC1:
        if mode != pkSlow:
            warning &"The only mode available for ETC1 is '{pkSlow}' (got '{mode}')"
        get_profile_etc_slow result.etc1.addr
    of cmpASTC:
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

proc alloc_img(w, h, bpp: int): RGBASurface =
    result.width  = uint32 w
    result.height = uint32 h
    result.stride = uint32 (bpp * w)
    result.data   = cast[ptr byte](alloc(result.height * result.stride))

proc compress*(profile: CompressionProfile; src: ptr byte; w, h, bpp: int): CompressedTexture =
    const BlockWidth  = 4
    const BlockHeight = 4
    let bw = BlockWidth  * ceil_div(w, BlockWidth)
    let bh = BlockHeight * ceil_div(h, BlockHeight)
    let block_count = int (bw div BlockWidth) * (bw div BlockHeight)

    # let raw_img   = RGBASurface(data: src, width: uint32 w, height: uint32 h, stride: uint32 (bpp * w))
    var edged_img = alloc_img(bw, bh, bpp) # TODO: fix the edging for non power-of-two
    copy_mem(edged_img.data, src, int(edged_img.stride * edged_img.height))
    # replicate_borders(edged_img.addr, raw_img.addr, cint bw, cint bh, 32)

    result.size = (bytes_per_block profile.kind) * block_count
    result.data = cast[ptr byte](alloc result.size)
    case profile.kind
    of cmpBC1 : compress_blocks_bc1  edged_img.addr, result.data
    of cmpBC3 : compress_blocks_bc3  edged_img.addr, result.data
    of cmpBC4 : compress_blocks_bc4  edged_img.addr, result.data
    of cmpBC5 : compress_blocks_bc5  edged_img.addr, result.data
    of cmpBC6H: compress_blocks_bc6h edged_img.addr, result.data, profile.bc6h.addr
    of cmpBC7 : compress_blocks_bc7  edged_img.addr, result.data, profile.bc7.addr
    of cmpETC1: compress_blocks_etc1 edged_img.addr, result.data, profile.etc1.addr
    of cmpASTC: compress_blocks_astc edged_img.addr, result.data, profile.astc.addr
    of cmpNoneRGB, cmpNoneRGBA:
        assert false, &"Should not call compress with '{profile.kind}'"

