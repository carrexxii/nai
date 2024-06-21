import common
from std/math import ceil_div

type
    ProfileKind* = enum
        UltraFast
        VeryFast
        Fast
        Basic
        Slow
        VerySlow

    CompressionKind* = enum
        BC1
        BC3
        BC4
        BC5
        BC6H
        BC7
        ETC1
        ASTC

type
    RGBASurface = object
        data  : ptr uint8
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
        case kind: CompressionKind
        of BC6H: bc6h: BC6HEncSettings
        of BC7 : bc7 : BC7EncSettings
        of ETC1: etc : ETCEncSettings
        of ASTC: astc: ASTCEncSettings
        else: discard

    CompressedTexture* = object
        data*: ptr uint8
        size*: int

#[ -------------------------------------------------------------------- ]#

# BC7 with ignored alpha
proc get_profile_ultra_fast*(settings: ptr BC7EncSettings) {.importc: "GetProfile_ultrafast".}
proc get_profile_very_fast*(settings: ptr BC7EncSettings)  {.importc: "GetProfile_veryfast" .}
proc get_profile_fast*(settings: ptr BC7EncSettings)       {.importc: "GetProfile_fast"     .}
proc get_profile_basic*(settings: ptr BC7EncSettings)      {.importc: "GetProfile_basic"    .}
proc get_profile_slow*(settings: ptr BC7EncSettings)       {.importc: "GetProfile_slow"     .}

proc get_profile_alpha_ultra_fast*(settings: ptr BC7EncSettings) {.importc: "GetProfile_alpha_ultrafast".}
proc get_profile_alpha_very_fast*(settings: ptr BC7EncSettings)  {.importc: "GetProfile_alpha_veryfast" .}
proc get_profile_alpha_fast*(settings: ptr BC7EncSettings)       {.importc: "GetProfile_alpha_fast"     .}
proc get_profile_alpha_basic*(settings: ptr BC7EncSettings)      {.importc: "GetProfile_alpha_basic"    .}
proc get_profile_alpha_slow*(settings: ptr BC7EncSettings)       {.importc: "GetProfile_alpha_slow"     .}

proc get_profile_bc6h_very_fast*(settings: ptr BC6HEncSettings) {.importc: "GetProfile_bc6h_veryfast".}
proc get_profile_bc6h_fast*(settings: ptr BC6HEncSettings)      {.importc: "GetProfile_bc6h_fast"    .}
proc get_profile_bc6h_basic*(settings: ptr BC6HEncSettings)     {.importc: "GetProfile_bc6h_basic"   .}
proc get_profile_bc6h_slow*(settings: ptr BC6HEncSettings)      {.importc: "GetProfile_bc6h_slow"    .}
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
proc compress_blocks_bc1*(src: ptr RGBASurface; dst: ptr uint8)                                 {.importc: "CompressBlocksBC1" .}
proc compress_blocks_bc3*(src: ptr RGBASurface; dst: ptr uint8)                                 {.importc: "CompressBlocksBC3" .}
proc compress_blocks_bc4*(src: ptr RGBASurface; dst: ptr uint8)                                 {.importc: "CompressBlocksBC4" .}
proc compress_blocks_bc5*(src: ptr RGBASurface; dst: ptr uint8)                                 {.importc: "CompressBlocksBC5" .}
proc compress_blocks_bc6h*(src: ptr RGBASurface; dst: ptr uint8; settings: ptr BC6HEncSettings) {.importc: "CompressBlocksBC6H".}
proc compress_blocks_bc7*( src: ptr RGBASurface; dst: ptr uint8; settings: ptr BC7EncSettings)  {.importc: "CompressBlocksBC7" .}
proc compress_blocks_etc1*(src: ptr RGBASurface; dst: ptr uint8; settings: ptr ETCEncSettings)  {.importc: "CompressBlocksETC1".}
proc compress_blocks_astc*(src: ptr RGBASurface; dst: ptr uint8; settings: ptr ASTCEncSettings) {.importc: "CompressBlocksASTC".}

proc replicate_borders*(dst_slice, src_tex: ptr RGBASurface; x, y, bpp: cint) {.importc: "ReplicateBorders".}

#[ -------------------------------------------------------------------- ]#

func bytes_per_block(kind: CompressionKind): int =
    case kind
    of BC1, BC4, ETC1: 8
    of BC3, BC5, BC6H, BC7, ASTC: 16

proc get_profile*(kind: CompressionKind; mode = Basic; with_alpha = true; block_size = (4, 4)): CompressionProfile =
    result = CompressionProfile(kind: kind)
    case kind
    of BC6H:
        if mode == UltraFast:
            warning &"No mode '{mode}' available, using '{VeryFast}'"
        case mode
        of UltraFast,
           VeryFast: get_profile_bc6h_very_fast result.bc6h.addr
        of Fast    : get_profile_bc6h_fast      result.bc6h.addr
        of Basic   : get_profile_bc6h_basic     result.bc6h.addr
        of Slow    : get_profile_bc6h_slow      result.bc6h.addr
        of VerySlow: get_profile_bc6h_very_slow result.bc6h.addr
    of BC7:
        if mode == VerySlow:
            warning &"No mode '{mode}' available, using '{Slow}'"
        if with_alpha:
            case mode
            of UltraFast: get_profile_alpha_ultra_fast result.bc7.addr
            of VeryFast : get_profile_alpha_very_fast  result.bc7.addr
            of Fast     : get_profile_alpha_fast       result.bc7.addr
            of Basic    : get_profile_alpha_basic      result.bc7.addr
            of Slow,
               VerySlow: get_profile_alpha_slow result.bc7.addr
        else:
            case mode
            of UltraFast: get_profile_ultra_fast result.bc7.addr
            of VeryFast : get_profile_very_fast  result.bc7.addr
            of Fast     : get_profile_fast       result.bc7.addr
            of Basic    : get_profile_basic      result.bc7.addr
            of Slow,
               VerySlow: get_profile_slow result.bc7.addr
    of ETC1:
        if mode != Slow:
            warning &"The only mode available for ETC1 is '{Slow}' (got '{mode}')"
        get_profile_etc_slow result.etc.addr
    of ASTC:
        if mode != Fast or (with_alpha and mode != Fast):
            let alpha_msg = if with_alpha: "with alpha" else: "without alpha"
            warning &"No mode '{mode}' available {alpha_msg}"
        if with_alpha:
            case mode
            of UltraFast, VeryFast, Fast:
                get_profile_astc_alpha_fast(result.astc.addr, cint block_size[0], cint block_size[1])
            of Basic, Slow, VerySlow:
                get_profile_astc_alpha_slow(result.astc.addr, cint block_size[0], cint block_size[1])
        else:
            get_profile_astc_fast(result.astc.addr, cint block_size[0], cint block_size[1])
    else:
        discard

proc alloc_img(w, h: SomeUnsignedInt): RGBASurface =
    result.width  = w
    result.height = h
    result.stride = 4 * w
    result.data   = cast[ptr uint8](alloc(result.height * result.stride))

proc compress*(profile: CompressionProfile; src: ptr uint8; w, h, stride: SomeUnsignedInt): CompressedTexture =
    const BlockWidth  = 4
    const BlockHeight = 4
    let bw = BlockWidth  * ceil_div(w, BlockWidth)
    let bh = BlockHeight * ceil_div(h, BlockHeight)
    let block_count = int (bw div BlockWidth) * (bw div BlockHeight)

    const bpp = 32
    let raw_img   = RGBASurface(data: src, width: w, height: h, stride: stride)
    var edged_img = alloc_img(bw, bh)
    replicate_borders(edged_img.addr, raw_img.addr, cint bw, cint bh, cint bpp)

    result.size = (bytes_per_block profile.kind) * block_count
    echo result.size, " ", (bytes_per_block profile.kind), " ", block_count
    result.data = cast[ptr uint8](alloc result.size)
    case profile.kind
    of BC1: compress_blocks_bc1(edged_img.addr, result.data)
    of BC7: compress_blocks_bc7(edged_img.addr, result.data, profile.bc7.addr)
    else: assert false
