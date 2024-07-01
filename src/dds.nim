# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

####### File Layout #######
# Magic - uint32 ("DDS ")
# DDSHeader
# [DDSHeaderDXT10]        (if pf.flags == FourCC and pf.fourcc == "DX10")
# data    - ptr byte
# [data2] - ptr byte      (for texture/cubemap/volume texture)

import
    std/[streams, tables],
    common, bitgen
from ispctc import TextureCompressionKind

converter make_fourcc(fcc: array[4, char]): uint32 =
    ((uint32 fcc[0])       ) or
    ((uint32 fcc[1]) shl 8 ) or
    ((uint32 fcc[2]) shl 16) or
    ((uint32 fcc[3]) shl 24)

const
    DDSMagic: uint32 = ['D', 'D', 'S', ' ']
    DDSHeaderSize      = 124
    DDSPixelFormatSize = 32

type DDSFlag = distinct uint32
DDSFlag.gen_bit_ops(
    ddsCaps, ddsHeight, ddsWidth, ddsPitch,
    _, _, _, _,
    _, _, _, _,
    _, _, _, ddsPixelFormat,
    _, ddsMipmapCount, _, ddsLinearSize,
    _, _, _, ddsDepth,
)

type DDSPixelFormatFlag = distinct uint32
DDSPixelFormatFlag.gen_bit_ops(
    pfAlphaPixels, pfAlpha, pfFourCC, _,
    _, pfPalette8, pfRGB, _,
    _, pfYUV, _, _,
    _, _, _, _,
    _, pfLuminance,
)
const pfPalette8A*  = pfPalette8  or pfAlphaPixels
const pfLuminanceA* = pfLuminance or pfAlphaPixels
const pfRGBA*       = pfRGB       or pfAlphaPixels

type DDSSurfaceFlag = distinct uint32
DDSSurfaceFlag.gen_bit_ops(
    _, _, _, sfCubemap,
    _, _, _, _,
    _, _, _, _,
    sfTexture, _, _, _,
    _, _, _, _,
    _, _, sfMipmap,
)

type DDSCubemapFlag = distinct uint32
DDSCubemapFlag.gen_bit_ops(
    _, _, _, _,
    _, _, _, _,
    _, cfCubemap, cfPositiveX, cfNegativeX,
    cfPositiveY, cfNegativeY, cfPositiveZ, cfNegativeZ,
    _, _, _, _,
    _, cfVolume,
)
const cfAllFaces* =
    cfPositiveX or cfNegativeX or
    cfPositiveY or cfNegativeY or
    cfPositiveZ or cfNegativeZ

type D3DMiscFlag = distinct uint32
D3DMiscFlag.gen_bit_ops(
    d3GenerateMips, d3Shared, d3TextureCube, _,
    d3DrawIndirectArgs, d3dBufferAllowRawViews, d3BufferStructured, d3ResourceClamp,
    d3SharedKeyedMutex, d3GDICompatible, _, d3SharedNthHandle,
    d3RestrictedContent, d3RestrictSharedResource, d3RestrictSharedResourceDriver, d3Guarded,
    _, d3TilePool, d3Tiled, d3HWProtected,
)
const SharedDisplayable     = D3DMiscFlag (1 + int d3HWProtected)
const SharedExclusiveWriter = D3DMiscFlag (2 + int d3HWProtected)

type
    DXGIFormat {.size: sizeof(uint32).} = enum
        Unknown       = 0
        R8G8B8A8UNorm = 28
        BC1UNorm      = 71
        BC3UNorm      = 77
        BC4UNorm      = 80
        BC5UNorm      = 83
        BC6HUF16      = 95
        BC7UNorm      = 98

    D3DResourceDimension {.size: sizeof(uint32).} = enum
        Unknown
        Buffer
        Texture1D
        Texture2D
        Texture3D

    DDSAlphaMode {.size: sizeof(uint32).} = enum
        Unknown
        Straight
        Premultiplied
        Opaque
        Custom

type
    DDSPixelFormat = object
        size         : uint32 = DDSPixelFormatSize
        flags        : DDSPixelFormatFlag
        fourcc       : uint32
        rgb_bit_count: uint32
        rbit_mask    : uint32
        gbit_mask    : uint32
        bbit_mask    : uint32
        abit_mask    : uint32

    DDSHeader = object
        size                : uint32 = DDSHeaderSize
        flags               : DDSFlag
        height              : uint32
        width               : uint32
        pitch_or_linear_size: uint32
        depth               : uint32 # Only for volume textures
        mipmap_count        : uint32
        reserved1           : array[11, uint32]
        pf                  : DDSPixelFormat
        surface_flags       : DDSSurfaceFlag # caps1
        cubemap_flags       : DDSCubemapFlag # caps2
        caps3               : uint32 # Unused
        caps4               : uint32 # Unused
        reserved2           : uint32

    DDSHeaderDXT10 = object
        dxgi_format       : DXGIFormat
        resource_dimension: D3DResourceDimension
        misc_flag         : D3DMiscFlag
        array_size        : uint32
        misc_flags2       : DDSAlphaMode

    DDSFile* = object
        magic*       : uint32 = DDSMagic
        header*      : DDSHeader
        dxt10_header*: DDSHeaderDXT10
        data*, data2*: ptr byte
        data_size*   : int
        data_size2*  : int

func pixel_format(flags: DDSPixelFormatFlag; fourcc, cbc, rm, gm, bm, am: uint32): DDSPixelFormat =
    DDSPixelFormat(
        flags        : flags,
        fourcc       : fourcc,
        rgb_bit_count: cbc,
        rbit_mask    : rm,
        gbit_mask    : gm,
        bbit_mask    : bm,
        abit_mask    : am,
    )

const PixelFormats = to_table {
    NoneRGB : pixel_format(pfRGB , ['\0', '\0', '\0', '\0'], 24, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0),
    NoneRGBA: pixel_format(pfRGBA, ['\0', '\0', '\0', '\0'], 32, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0xFF00_0000'u32),
    BC1 : pixel_format(pfFourCC, ['D', 'X', 'T', '1'], 0, 0, 0, 0, 0),
    BC3 : pixel_format(pfFourCC, ['D', 'X', 'T', '4'], 0, 0, 0, 0, 0), # DXT5 without alpha
    BC4 : pixel_format(pfFourCC, ['A', 'T', 'I', '1'], 0, 0, 0, 0, 0),
    BC5 : pixel_format(pfFourCC, ['A', 'T', 'I', '2'], 0, 0, 0, 0, 0),
    BC6H: pixel_format(pfFourCC, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    BC7 : pixel_format(pfFourCC, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    ETC1: pixel_format(pfFourCC, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    ASTC: pixel_format(pfFourCC, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
}

func compression_to_format(kind: TextureCompressionKind): DXGIFormat =
    case kind
    of NoneRGB, NoneRGBA: R8G8B8A8UNorm
    of BC1 : BC1UNorm
    of BC3 : BC3UNorm
    of BC4 : BC4UNorm
    of BC5 : BC5UNorm
    of BC6H: BC6HUF16
    of BC7 : BC7UNorm
    of ETC1: Unknown
    of ASTC: Unknown

# block_size = 8 for DXT1 or 16 for DXT2-5
func calc_mip_size(w, h, block_size: uint32): uint32 =
    result = max(1'u32, (w + 3) div 4) * max(1'u32, (h + 3) div 4)
    result *= block_size

func get_bpp(kind: TextureCompressionKind): int =
    case kind
    of BC1, BC4, ETC1: 4
    of BC3, BC5, BC6H, BC7, ASTC: 8
    of NoneRGB : 24
    of NoneRGBA: 32

proc encode_dds*(kind: TextureCompressionKind; data: openArray[byte]; w, h, mip_count: int): DDSFile =
    let bpp = get_bpp kind
    let pixel_format = PixelFormats[kind]

    var pitch: int
    var flags = ddsCaps or ddsHeight or ddsWidth or ddsPixelFormat
    if kind == NoneRGB or kind == NoneRGBA:
        flags = flags or ddsPitch
        pitch = (w * bpp) div 8
    else:
        flags = flags or ddsLinearSize
        pitch = (w * h * bpp) div 8

    if mip_count > 1:
        flags = flags or ddsMipmapCount

    result = DDSFile(
        data: data[0].addr,
        data_size: data.len,
        header: DDSHeader(
            flags               : flags,
            width               : uint32 w,
            height              : uint32 h,
            pitch_or_linear_size: uint32 pitch,
            mipmap_count        : uint32 mip_count,
            pf                  : pixel_format,
            surface_flags       : if mip_count > 1: sfMipmap else: sfTexture,
        ),
        dxt10_header: DDSHeaderDXT10(
            dxgi_format       : compression_to_format kind,
            resource_dimension: Texture2D,
            array_size        : 1,
        ),
    )

proc write*(file: FileStream; dds_file: DDSFile) =
    assert dds_file.header.size == DDSHeaderSize

    file.write DDSMagic
    file.write dds_file.header
    if dds_file.header.pf.fourcc == ['D', 'X', '1', '0']:
        file.write dds_file.dxt10_header
    file.write_data dds_file.data, dds_file.data_size

static:
    assert (sizeof DDSHeader)      == DDSHeaderSize
    assert (sizeof DDSPixelFormat) == DDSPixelFormatSize

