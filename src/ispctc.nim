import common
from std/math import ceil_div

type
    ProfileKind* = enum
        UltraFast
        VeryFast
        Fast
        Basic
        Slow

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

    CompressionProfile* = object
        case kind: CompressionKind
        of BC6H: bc6h: BC6HEncSettings
        of BC7 : bc7 : BC7EncSettings
        else: discard

    CompressedTexture* = object
        data*: ptr uint8
        size*: int

# struct etc_enc_settings
# {
#     int fastSkipTreshold;
# };

# struct astc_enc_settings
# {
#     int block_width;
#     int block_height;
#     int channels;

#     int fastSkipTreshold;
#     int refineIterations;
# };

#[ -------------------------------------------------------------------- ]#

proc get_profile_ultra_fast*(settings: ptr BC7EncSettings) {.importc: "GetProfile_ultrafast".}

proc compress_blocks_bc1*(src: ptr RGBASurface; dst: ptr uint8)                               {.importc: "CompressBlocksBC1".}
proc compress_blocks_bc7*(src: ptr RGBASurface; dst: ptr uint8; settings: ptr BC7EncSettings) {.importc: "CompressBlocksBC7".}

proc replicate_borders*(dst_slice, src_tex: ptr RGBASurface; x, y, bpp: cint) {.importc: "ReplicateBorders".}

#[ -------------------------------------------------------------------- ]#

proc get_profile*(kind: CompressionKind; mode: ProfileKind): CompressionProfile =
    result.kind = kind
    case kind
    of BC1: discard
    of BC7:
        case mode
        of UltraFast: get_profile_ultra_fast result.bc7.addr
        else: assert false
    else: assert false

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

    let bpp = 32
    let raw_img   = RGBASurface(data: src, width: w, height: h, stride: stride)
    var edged_img = alloc_img(bw, bh)
    replicate_borders(edged_img.addr, raw_img.addr, cint bw, cint bh, cint bpp)

    result.size = int(8 * bw * bh)
    result.data = cast[ptr uint8](alloc result.size)
    case profile.kind
    of BC1: compress_blocks_bc1(edged_img.addr, result.data)
    of BC7: compress_blocks_bc7(edged_img.addr, result.data, profile.bc7.addr)
    else: assert false

# /*
# Notes:
#     - input width and height need to be a multiple of block size
#     - LDR input is 32 bit/pixel (sRGB), HDR is 64 bit/pixel (half float)
#         - for BC4 input is 8bit/pixel (R8), for BC5 input is 16bit/pixel (RG8)
#     - dst buffer must be allocated with enough space for the compressed texture:
#         - 8 bytes/block for BC1/BC4/ETC1,
#         - 16 bytes/block for BC3/BC5/BC6H/BC7/ASTC
#     - the blocks are stored in raster scan order (natural CPU texture layout)
#     - use the GetProfile_* functions to select various speed/quality tradeoffs
#     - the RGB profiles are slightly faster as they ignore the alpha channel
# */

# // profiles for RGB data (alpha channel will be ignored)
# extern "C" void GetProfile_veryfast(bc7_enc_settings* settings);
# extern "C" void GetProfile_fast(bc7_enc_settings* settings);
# extern "C" void GetProfile_basic(bc7_enc_settings* settings);
# extern "C" void GetProfile_slow(bc7_enc_settings* settings);

# // profiles for RGBA inputs
# extern "C" void GetProfile_alpha_ultrafast(bc7_enc_settings* settings);
# extern "C" void GetProfile_alpha_veryfast(bc7_enc_settings* settings);
# extern "C" void GetProfile_alpha_fast(bc7_enc_settings* settings);
# extern "C" void GetProfile_alpha_basic(bc7_enc_settings* settings);
# extern "C" void GetProfile_alpha_slow(bc7_enc_settings* settings);

# // profiles for BC6H (RGB HDR)
# extern "C" void GetProfile_bc6h_veryfast(bc6h_enc_settings* settings);
# extern "C" void GetProfile_bc6h_fast(bc6h_enc_settings* settings);
# extern "C" void GetProfile_bc6h_basic(bc6h_enc_settings* settings);
# extern "C" void GetProfile_bc6h_slow(bc6h_enc_settings* settings);
# extern "C" void GetProfile_bc6h_veryslow(bc6h_enc_settings* settings);

# // profiles for ETC
# extern "C" void GetProfile_etc_slow(etc_enc_settings* settings);

# // profiles for ASTC
# extern "C" void GetProfile_astc_fast(astc_enc_settings* settings, int block_width, int block_height);
# extern "C" void GetProfile_astc_alpha_fast(astc_enc_settings* settings, int block_width, int block_height);
# extern "C" void GetProfile_astc_alpha_slow(astc_enc_settings* settings, int block_width, int block_height);

# /*
# Notes:
#     - input width and height need to be a multiple of block size
#     - LDR input is 32 bit/pixel (sRGB), HDR is 64 bit/pixel (half float)
#         - for BC4 input is 8bit/pixel (R8), for BC5 input is 16bit/pixel (RG8)
#     - dst buffer must be allocated with enough space for the compressed texture:
#         - 8 bytes/block for BC1/BC4/ETC1,
#         - 16 bytes/block for BC3/BC5/BC6H/BC7/ASTC
#     - the blocks are stored in raster scan order (natural CPU texture layout)
#     - use the GetProfile_* functions to select various speed/quality tradeoffs
#     - the RGB profiles are slightly faster as they ignore the alpha channel
# */

# extern "C" void CompressBlocksBC3(const rgba_surface* src, uint8_t* dst);
# extern "C" void CompressBlocksBC4(const rgba_surface* src, uint8_t* dst);
# extern "C" void CompressBlocksBC5(const rgba_surface* src, uint8_t* dst);
# extern "C" void CompressBlocksBC6H(const rgba_surface* src, uint8_t* dst, bc6h_enc_settings* settings);
# extern "C" void CompressBlocksETC1(const rgba_surface* src, uint8_t* dst, etc_enc_settings* settings);
# extern "C" void CompressBlocksASTC(const rgba_surface* src, uint8_t* dst, astc_enc_settings* settings);
