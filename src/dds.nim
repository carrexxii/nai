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
    Magic: uint32 = ['D', 'D', 'S', ' ']
    HeaderSize      = 124
    PixelFormatSize = 32

type Flag = distinct uint32
Flag.gen_bit_ops(
    ddsCaps, ddsHeight, ddsWidth, ddsPitch,
    _, _, _, _,
    _, _, _, _,
    _, _, _, ddsPixelFormat,
    _, ddsMipmapCount, _, ddsLinearSize,
    _, _, _, ddsDepth,
)

type PixelFormatFlag = distinct uint32
PixelFormatFlag.gen_bit_ops(
    pxFmtAlphaPixels, pxFmtAlpha, pxFmtFourCc, _,
    _, pxFmtPalette8, pxFmtRgb, _,
    _, pxFmtYUV, _, _,
    _, _, _, _,
    _, pxFmtLuminance,
)
const pxFmtPalette8A*  = pxFmtPalette8  or pxFmtAlphaPixels
const pxFmtLuminanceA* = pxFmtLuminance or pxFmtAlphaPixels
const pxFmtRGBA*       = pxFmtRgb       or pxFmtAlphaPixels

type SurfaceFlag = distinct uint32
SurfaceFlag.gen_bit_ops(
    _, _, _, surfCubemap,
    _, _, _, _,
    _, _, _, _,
    surfTexture, _, _, _,
    _, _, _, _,
    _, _, surfMipMap,
)

type CubemapFlag = distinct uint32
CubemapFlag.gen_bit_ops(
    _, _, _, _,
    _, _, _, _,
    _, cubemapCubemap, cubemapPositiveX, cubemapNegativeX,
    cubemapPositiveY, cubemapNegativeY, cubemapPositiveZ, cubemapNegativeZ,
    _, _, _, _,
    _, cubemapVolume,
)
const cubemapAllFaces* = cubemapPositiveX or cubemapNegativeX or
                         cubemapPositiveY or cubemapNegativeY or
                         cubemapPositiveZ or cubemapNegativeZ

type D3dMiscFlag = distinct uint32
D3dMiscFlag.gen_bit_ops(
    d3dGenerateMips     , d3dShared                , d3dTextureCube                 , _,
    d3dDrawIndirectArgs , d3dBufferAllowRawViews   , d3dBufferStructured            , d3dResourceClamp,
    d3dSharedKeyedMutex , d3dGdiCompatible         , _                              , d3dSharedNthHandle,
    d3dRestrictedContent, d3dRestrictSharedResource, d3dRestrictSharedResourceDriver, d3dGuarded,
    _                   , d3dTilePool              , d3dTiled                       , d3dHwProtected,
)
const d3dSharedDisplayable*     = D3dMiscFlag (1 + int d3dHwProtected)
const d3dSharedExclusiveWriter* = D3dMiscFlag (2 + int d3dHwProtected)

type
    DxGiFormat {.size: sizeof(cint).} = enum
        dgfUnknown       = 0
        dgfR8G8B8A8UNorm = 28
        dgfBC1UNorm      = 71
        dgfBC3UNorm      = 77
        dgfBC4UNorm      = 80
        dgfBC5UNorm      = 83
        dgfBC6HUF16      = 95
        dgfBC7UNorm      = 98

    D3dResourceDimension {.size: sizeof(cint).} = enum
        rdUnknown
        rdBuffer
        rdTexture1D
        rdTexture2D
        rdTexture3D

    AlphaMode {.size: sizeof(cint).} = enum
        amUnknown
        amStraight
        amPremultiplied
        amOpaque
        amCustom

type
    PixelFormat = object
        sz           : uint32 = PixelFormatSize
        flags        : PixelFormatFlag
        fourcc       : uint32
        rgb_bit_count: uint32
        rbit_mask    : uint32
        gbit_mask    : uint32
        bbit_mask    : uint32
        abit_mask    : uint32

    Header = object
        sz                : uint32 = HeaderSize
        flags             : Flag
        h, w              : uint32
        pitch_or_linear_sz: uint32
        d                 : uint32 # Only for volume textures
        mip_map_count     : uint32
        reserved1         : array[11, uint32]
        px_fmt            : PixelFormat
        surf_flags        : SurfaceFlag # caps1
        cubemap_flags     : CubemapFlag # caps2
        caps3             : uint32 # Unused
        caps4             : uint32 # Unused
        reserved2         : uint32

    HeaderDxt10 = object
        dxgi_fmt   : DxGiFormat
        res_dim    : D3dResourceDimension
        misc_flag  : D3dMiscFlag
        arr_sz     : uint32
        misc_flags2: AlphaMode

    File* = object
        magic*       : uint32 = Magic
        header*      : Header
        dxt10_header*: HeaderDxt10
        data*, data2*: ptr byte
        data_sz*     : int
        data_sz2*    : int

func pixel_format(flags: PixelFormatFlag; fourcc, cbc, rm, gm, bm, am: uint32): PixelFormat =
    PixelFormat(
        flags        : flags,
        fourcc       : fourcc,
        rgb_bit_count: cbc,
        rbit_mask    : rm,
        gbit_mask    : gm,
        bbit_mask    : bm,
        abit_mask    : am,
    )

const PixelFormats = to_table {
    tckNoneRgb : pixel_format(pxFmtRgb , ['\0', '\0', '\0', '\0'], 24, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0),
    tckNoneRgba: pixel_format(pxFmtRgba, ['\0', '\0', '\0', '\0'], 32, 0x0000_00FF, 0x0000_FF00, 0x00FF_0000, 0xFF00_0000'u32),
    tckBc1 : pixel_format(pxFmtFourCc, ['D', 'X', 'T', '1'], 0, 0, 0, 0, 0),
    tckBc3 : pixel_format(pxFmtFourCc, ['D', 'X', 'T', '4'], 0, 0, 0, 0, 0), # DXT5 without alpha
    tckBc4 : pixel_format(pxFmtFourCc, ['A', 'T', 'I', '1'], 0, 0, 0, 0, 0),
    tckBc5 : pixel_format(pxFmtFourCc, ['A', 'T', 'I', '2'], 0, 0, 0, 0, 0),
    tckBc6H: pixel_format(pxFmtFourCc, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    tckBc7 : pixel_format(pxFmtFourCc, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    tckEtc1: pixel_format(pxFmtFourCc, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
    tckAstc: pixel_format(pxFmtFourCc, ['D', 'X', '1', '0'], 0, 0, 0, 0, 0),
}

converter `TextureCompressionKind -> DxGiFormat`(kind: TextureCompressionKind): DxGiFormat =
    case kind
    of tckNoneRgb, tckNoneRgba: dgfR8G8B8A8UNorm
    of tckBc1 : dgfBc1UNorm
    of tckBc3 : dgfBc3UNorm
    of tckBc4 : dgfBc4UNorm
    of tckBc5 : dgfBc5UNorm
    of tckBc6H: dgfBc6HUF16
    of tckBc7 : dgfBc7UNorm
    of tckEtc1: dgfUnknown
    of tckAstc: dgfUnknown

# block_size = 8 for DXT1 or 16 for DXT2-5
func calc_mip_size(w, h, block_size: uint32): uint32 =
    result = max(1'u32, (w + 3) div 4) * max(1'u32, (h + 3) div 4)
    result *= block_size

func bpp(kind: TextureCompressionKind): int =
    case kind
    of tckBc1, tckBc4, tckEtc1: 4
    of tckBc3, tckBc5, tckBc6H, tckBc7, tckAstc: 8
    of tckNoneRgb : 24
    of tckNoneRgba: 32

proc encode*(kind: TextureCompressionKind; data: openArray[byte]; w, h, mip_count: int): File =
    let bpp    = kind.bpp
    let px_fmt = PixelFormats[kind]

    var pitch: int
    var flags = ddsCaps or ddsHeight or ddsWidth or ddsPixelFormat
    if kind == tckNoneRgb or kind == tckNoneRgba:
        flags = flags or ddsPitch
        pitch = (w * bpp) div 8
    else:
        flags = flags or ddsLinearSize
        pitch = (w * h * bpp) div 8

    if mip_count > 1:
        flags = flags or ddsMipMapCount

    result = File(
        data   : data[0].addr,
        data_sz: data.len,
        header: Header(
            flags             : flags,
            w                 : uint32 w,
            h                 : uint32 h,
            pitch_or_linear_sz: uint32 pitch,
            mip_map_count     : uint32 mip_count,
            px_fmt            : px_fmt,
            surf_flags        : if mip_count > 1: surfMipMap else: surfTexture,
        ),
        dxt10_header: HeaderDxt10(
            dxgi_fmt: kind,
            res_dim : rdTexture2D,
            arr_sz  : 1,
        ),
    )

proc write*(dst: FileStream; file: File) =
    assert file.header.sz == HeaderSize

    dst.write Magic
    dst.write file.header
    if file.header.px_fmt.fourcc == ['D', 'X', '1', '0']:
        dst.write file.dxt10_header
    dst.write_data file.data, file.data_sz

static:
    assert (sizeof Header)      == HeaderSize
    assert (sizeof PixelFormat) == PixelFormatSize
