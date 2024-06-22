####### File Layout #######
# Magic - uint32 ("DDS ")
# DDSHeader
# [DDSHeaderDXT10]        (if pf.flags == FourCC and pf.fourcc == "DX10")
# data    - ptr byte
# [data2] - ptr byte      (for texture/cubemap/volume texture)

import
    std/tables,
    common
from ispctc import CompressionKind

converter make_fourcc(fcc: array[4, char]): uint32 =
    ((uint32 fcc[0])       ) or
    ((uint32 fcc[1]) shl 8 ) or
    ((uint32 fcc[2]) shl 16) or
    ((uint32 fcc[3]) shl 24)

const
    DDSMagic*: uint32 = ['D', 'D', 'S', ' ']
    DDSHeaderSize      = 124
    DDSPixelFormatSize = 32

type
    DDSFlag* {.size: sizeof(uint32).} = enum
        Caps        = 0x0000_0001
        Height      = 0x0000_0002
        Width       = 0x0000_0004
        Pitch       = 0x0000_0008
        PixelFormat = 0x0000_1000
        MipmapCount = 0x0002_0000
        LinearSize  = 0x0008_0000
        Depth       = 0x0080_0000

    DDSPixelFormatFlag* {.size: sizeof(uint32).} = enum
        AlphaPixels = 0x0000_0001
        Alpha       = 0x0000_0002
        Palette8    = 0x0000_0020
        Palette8A   = 0x0000_0021
        FourCC      = 0x0000_0004
        RGB         = 0x0000_0040
        RGBA        = 0x0000_0041
        YUV         = 0x0000_0200
        Luminance   = 0x0002_0000
        LuminanceA  = 0x0002_0001

    DDSSurfaceFlag* {.size: sizeof(uint32).} = enum
        Cubemap = 0x0000_0008
        Texture = 0x0000_1000
        Mipmap  = 0x0040_0000

    DDSCubemapFlag* {.size: sizeof(uint32).} = enum
        Cubemap          = 0x0000_0200
        CubemapPositiveX = 0x0000_0400
        CubemapNegativeX = 0x0000_0800
        CubemapPositiveY = 0x0000_1000
        CubemapNegativeY = 0x0000_2000
        CubemapPositiveZ = 0x0000_4000
        CubemapNegativeZ = 0x0000_8000
        Volume           = 0x0020_0000

    DXGIFormat* {.size: sizeof(uint32).} = enum
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

    D3DMiscFlag {.size: sizeof(uint32).} = enum
        GenerateMips                 = 0x0000_0001
        Shared                       = 0x0000_0002
        TextureCube                  = 0x0000_0004
        DrawIndirectArgs             = 0x0000_0010
        BufferAllowRawViews          = 0x0000_0020
        BufferStructured             = 0x0000_0040
        ResourceClamp                = 0x0000_0080
        SharedKeyedMutex             = 0x0000_0100
        GDICompatible                = 0x0000_0200
        SharedNthHandle              = 0x0000_0800
        RestrictedContent            = 0x0000_1000
        RestrictSharedResource       = 0x0000_2000
        RestrictSharedResourceDriver = 0x0000_4000
        Guarded                      = 0x0000_8000
        TilePool                     = 0x0002_0000
        Tiled                        = 0x0004_0000
        HWProtected                  = 0x0008_0000
        SharedDisplayable
        SharedExclusiveWriter

    DDSAlphaMode {.size: sizeof(uint32).} = enum
        Unknown
        Straight
        Premultiplied
        Opaque
        Custom


template flag_or(flag) =
    func `or`*(a, b: `flag`): `flag` {.warning[HoleEnumConv]: off.} =
        `flag` ((uint a) or (uint b))
flag_or DDSFlag
flag_or DDSPixelFormatFlag
flag_or DDSSurfaceFlag
flag_or DDSCubemapFlag
flag_or D3DMiscFlag

const CubemapAllFaces* =
    CubemapPositiveX or CubemapNegativeX or
    CubemapPositiveY or CubemapNegativeY or
    CubemapPositiveZ or CubemapNegativeZ

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
        data*, data2*: CArray[byte]

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

const PixelFormats = {
    NoneRGB : pixel_format(RGB , ['\0', '\0', '\0', '\0'], 24, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0),
    NoneRGBA: pixel_format(RGBA, ['\0', '\0', '\0', '\0'], 32, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0xFF00_0000'u32),
    BC1 : pixel_format(FourCC, ['D', 'X', 'T', '1' ], 0, 0, 0, 0, 0),
    BC3 : pixel_format(FourCC, ['D', 'X', 'T', '4' ], 0, 0, 0, 0, 0), # DXT5 without alpha
    BC4 : pixel_format(FourCC, ['B', 'C', '4', 'U' ], 0, 0, 0, 0, 0),
    BC5 : pixel_format(FourCC, ['B', 'C', '5', 'U' ], 0, 0, 0, 0, 0),
    BC6H: pixel_format(FourCC, ['B', 'C', '6', 'H' ], 0, 0, 0, 0, 0),
    BC7 : pixel_format(FourCC, ['B', 'C', '7', '\0'], 0, 0, 0, 0, 0), # Also "BC7L"?
    ETC1: pixel_format(FourCC, ['E', 'T', 'C', '1' ], 0, 0, 0, 0, 0), # No standard FOURCC
    ASTC: pixel_format(FourCC, ['A', 'S', 'T', 'C' ], 0, 0, 0, 0, 0), # No standard FOURCC
}.to_table

converter compression_kind_to_pixel_format(kind: CompressionKind): DXGIFormat =
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

proc encode_dds*(kind: CompressionKind; data: openArray[byte]; w, h, mip_count: int): DDSFile =
    var
        pitch = 0'u32
        flags = Caps or Height or Width or PixelFormat
    if kind == NoneRGB or kind == NoneRGBA:
        flags = flags or Pitch or LinearSize
    if mip_count > 1:
        flags = flags or MipmapCount

    result.header = DDSHeader(
        flags               : flags,
        width               : uint32 w,
        height              : uint32 h,
        pitch_or_linear_size: pitch,
        mipmap_count        : uint32 mip_count,
        pf                  : PixelFormats[kind],
        surface_flags       : if mip_count > 1: Mipmap else: Texture,
    )

static:
    assert (sizeof DDSHeader)      == DDSHeaderSize
    assert (sizeof DDSPixelFormat) == DDSPixelFormatSize
