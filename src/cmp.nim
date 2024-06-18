const CMPVersion*: tuple[major, minor: int] = (4, 3)

const
    MSFlagDefault*           = 0
    MSFlagAlphaPremult*      = 1
    MSFlagDisableMIPMapping* = 2

    AMDMaxCmds*     = 20
    AMDMaxCmdStr*   = 32
    AMDMaxCmdParam* = 16

    BRLGFileIdentifier* = ['B', 'R', 'L', 'G']

    BCComponentCount = 4
    BCBlockBytes     = 4 * 4
    BCBlockPixels    = BCBlockBytes

type
    CMPFormat* {.size: sizeof(cint).} = enum
        Unknown             = 0x0000
        RGBA8888S           = 0x0010
        ARGB8888S           = 0x0020
        ARGB8888            = 0x0030
        ABGR8888            = 0x0040
        RGBA8888            = 0x0050
        BGRA8888            = 0x0060
        RGB888              = 0x0070
        RGB888S             = 0x0080
        BGR888              = 0x0090
        RG8S                = 0x00A0
        RG8                 = 0x00B0
        R8S                 = 0x00C0
        R8                  = 0x00D0
        ARGB2101010         = 0x00E0
        RGBA1010102         = 0x00F0
        ARGB16              = 0x0100
        ABGR16              = 0x0110
        RGBA16              = 0x0120
        BGRA16              = 0x0130
        RG16                = 0x0140
        R16                 = 0x0150
        RGBE32F             = 0x1000
        ARGB16F             = 0x1010
        ABGR16F             = 0x1020
        RGBA16F             = 0x1030
        BGRA16F             = 0x1040
        RG16F               = 0x1050
        R16F                = 0x1060
        ARGB32F             = 0x1070
        ABGR32F             = 0x1080
        RGBA32F             = 0x1090
        BGRA32F             = 0x10A0
        RGB32F              = 0x10B0
        BGR32F              = 0x10C0
        RG32F               = 0x10D0
        R32F                = 0x10E0
        Brotlig             = 0x2000
        BC1                 = 0x0011
        BC2                 = 0x0021
        BC3                 = 0x0031
        BC4                 = 0x0041
        BC4S                = 0x1041
        BC5                 = 0x0051
        BC5S                = 0x1051
        BC6H                = 0x0061
        BC6HSF              = 0x1061
        BC7                 = 0x0071
        ATI1N               = 0x0141
        ATI2N               = 0x0151
        ATI2N_XY            = 0x0152
        ATI2N_DXT5          = 0x0153
        DXT1                = 0x0211
        DXT3                = 0x0221
        DXT5                = 0x0231
        DXT5xGBR            = 0x0252
        DXT5RxBG            = 0x0253
        DXT5RBxG            = 0x0254
        DXT5xRBG            = 0x0255
        DXT5RGxB            = 0x0256
        DXT5xGxR            = 0x0257
        ATCGB               = 0x0301
        ATCRGBAExplicit     = 0x0302
        ATCRGBAInterpolated = 0x0303
        ASTC                = 0x0A01
        APC                 = 0x0A02
        PVRTC               = 0x0A03
        ETCRGB              = 0x0E01
        ETC2RGB             = 0x0E02
        ETC2SRGB            = 0x0E03
        ETC2RGBA            = 0x0E04
        ETC2RGBA1           = 0x0E05
        ETC2SRGBA           = 0x0E06
        ETC2SRGBA1          = 0x0E07
        Binary              = 0x0B01
        GTC                 = 0x0B02
        Basis               = 0x0B03

    CMPError* {.size: sizeof(cint).} = enum
        OK
        Aborted
        InvalidSourceTexture
        InvalidDestTexture
        UnsupportedSourceFormat
        UnsupportedDestFormat
        UnsupportedGPUASTCDecode
        UnsupportedGPUBasisDecode
        SizeMismatch
        UnableToInitCodec
        UnableToInitDecompresslib
        UnableToInitComputelib
        CMP_Destination
        MemAllocForMipset
        UnknownDestinationFormat
        FailedHostSetup
        PluginFileNotFound
        UnableToLoadFile
        UnableToCreateEncoder
        UnableToLoadEncoder
        NoShaderCodeDefined
        GPUDoesNotSupportCompute
        NoPerfStats
        GPUDoesNotSupportCMPExt
        GammaOutOfRange
        PluginSharedIONotSet
        UnableToInitD3DX
        FrameworkNotInitialized
        Generic

    CMPComputeKind* {.size: sizeof(cint).} = enum
        Unknown
        CPU
        HPC
        GPUOCL
        GPUDXC
        GPUVLK
        GPUHW

    CMPSpeed* {.size: sizeof(cint).} = enum
        Normal
        Fast
        SuperFast

    CMPGPUDecode* {.size: sizeof(cint).} = enum
        OpenGL
        DirectX
        Vulkan
        Invalid

    CMPChannelFormat* {.size: sizeof(cint).} = enum
        N8Bit
        Float16
        Float32
        Compressed
        N16Bit
        N2101010
        N32Bit
        Float9995E
        YUV420
        YUV422
        YUV444
        YUV4444
        N1010102

    CMPTextureDataKind* {.size: sizeof(cint).} = enum
        XRGB
        ARGB
        NormalMap
        R
        RG
        YUVSD
        YUVHD
        RGB
        N8
        N16

    CMPTextureKind* {.size: sizeof(cint).} = enum
        N2D
        CubeMap
        VolumeTexture
        N2DBlock
        N1D
        Unknown

    CMPD3DXFilter* {.size: sizeof(cint).} = enum
        None     = 1
        Point    = 2
        Linear   = 3
        Triangle = 4
        Box      = 5
        Dither   = 1 shl 19
        SRGB     = 3 shl 21
        Mirror   = 7 shl 16

    CMPVisionProcess* {.size: sizeof(cint).} = enum
        Default
        LStd

    BCComponent* {.size: sizeof(cint).} = enum
        Red
        Green
        Blue
        Alpha

    BCError* {.size: sizeof(cint).} = enum
        None
        LibraryNotInitialized
        LibraryAlreadyInitialized
        InvalidParameters
        OutOfMemory

    CMPAnalysisMode* {.size: sizeof(cint).} = enum
        MSEPSNR

type
    Vec8* {.importcpp: "std::vector<uint8_t>", header: "<vector>".} = object

    CMPComputeExtensions* {.size: sizeof(cint).} = enum
        FP16 = 0x0001
    CMPComputeOptions* = object
        force_rebuild*: bool
        plugin_compute: pointer

    CMPKernelPerformanceStats* = object
        elapsed_ms* : cfloat
        block_count*: cint
        mtx_per_sec*: cfloat

    CMPKernelDeviceInfo* = object
        device_name*: array[256, char]
        version*    : array[128, char]
        max_ucores* : cint

    CMPKernelOptionsEncoderOptions* = object
        use_channel_weights* : bool
        channel_weights*     : cfloat
        use_adaptive_weights*: bool
        use_alpha_threshold* : bool
        alpha_threshold*     : cint
        use_refinement_steps*: bool
        refinement_steps*    : cint
    CMPKernelOptionsUnion* {.union.} = object
        _   : array[32, byte]
        opt*: CMPKernelOptionsEncoderOptions
    CMPKernelOptions* = object
        extensions*      : CMPComputeExtensions
        height*          : uint32
        width*           : uint32
        fquality*        : cfloat
        format*          : CMPFormat
        src_format*      : CMPFormat
        encode_with*     : CMPComputeKind
        threads*         : cint
        get_perf_stats*  : bool
        perf_stats*      : CMPKernelPerformanceStats
        get_device_info* : bool
        device_info*     : CMPKernelDeviceInfo
        gen_gpu_mip_maps*: bool
        mip_levels*      : cint
        use_srgb_frames* : bool
        bc15*            : CMPKernelOptionsUnion
        size    : cuint
        data    : pointer
        data_svm: pointer
        src_file: cstring

    AMDCmdSet* = object
        str_cmd*  : array[AMDMaxCmdStr  , char]
        str_param*: array[AMDMaxCmdParam, char]

    CMPPrintInfoStr*      = proc(info_str: cstring)                                {.cdecl.}
    CMPFeedbackProc*      = proc(progress: cfloat; user1, user2: ptr uint32): bool {.cdecl.}
    CMPMIPFeedbackProc*   = proc(progress: CMPMIPProgressParam): bool              {.cdecl.}
    CMPCodecFeedbackProc* = proc(progress: cfloat; user1, user2: ptr uint32): bool {.cdecl.}

    CMPCompressionOptions* = object
        size*                  : uint32
        do_precondition_brgl*  : bool
        do_delta_encode_brgl*  : bool
        do_swizzle_brgl*       : bool
        page_size*             : uint32
        use_refinement_steps*  : bool
        refinement_steps*      : cint
        use_channel_weighting* : bool
        weighting_red*         : cfloat
        weighting_green*       : cfloat
        weighting_blue*        : cfloat
        use_adaptive_weighting*: bool
        dxt1_use_alpha*        : bool
        use_gpu_decompress*    : bool
        use_cg_compress*       : bool
        alpha_threshold*       : byte
        disable_multithreading*: bool
        compression_speed*     : CMPSpeed
        gpu_decode*            : CMPGPUDecode
        encode_with*           : CMPComputeKind
        num_threads*           : uint32
        quality*               : cfloat
        restrict_colour*       : bool
        restrict_alpha*        : bool
        mode_mask*             : uint32
        num_cmds*              : cint
        cmd_set*               : AMDCmdSet
        input_defog*           : cfloat
        input_exposure*        : cfloat
        input_knee_low*        : cfloat
        input_knee_high*       : cfloat
        input_gamma*           : cfloat
        input_filter_gamma*    : cfloat
        cmp_level*             : cint
        pos_bits*              : cint
        tex_cbits*             : cint
        normal_bits*           : cint
        generic_bits*          : cint
        when defined Use3DMeshOptimize:
            vcache_size*     : cint
            vcache_fifo_size*: cint
            overdraw_acmr*   : cfloat
            simplify_lod*    : cint
            vertex_fetch*    : bool
        source_format*              : CMPFormat
        dest_format*                : CMPFormat
        format_support_host_encoder*: bool
        print_info_str*             : CMPPrintInfoStr
        get_perf_stats*             : bool
        perf_stats*                 : CMPKernelPerformanceStats
        get_device_info*            : bool
        device_info*                : CMPKernelDeviceInfo
        gen_gpu_mip_maps*           : bool
        use_srgb_frames*            : bool
        mip_levels*                 : cint

    CMPColour* {.union.} = object
        rgba*   : array[4, byte]
        as_word*: uint32

    CMPCFilterParams* = object
        filter_kind*       : cint
        mip_filter_options*: culong
        min_size*          : cint
        gamma_correction*  : cfloat
        sharpness*         : cfloat
        dest_width*        : cint
        dest_height*       : cint
        use_srgb*          : bool

    CMPCVisionProcessOptions* = object
        process_kind*: CMPVisionProcess
        auto*        : bool
        align_images*: bool
        show_images* : bool
        save_match*  : bool
        save_images* : bool
        ssim*        : bool
        psnr*        : bool
        image_diff*  : bool
        crop_images* : bool
        crop*        : cint

    CMPCVisionProcessResults* = object
        result*    : cint
        image_size*: cint
        src_lstd*  : cfloat
        tst_lstd*  : cfloat
        norm_lstd* : cfloat
        ssim*      : cfloat
        psnr*      : cfloat

    CMPMIPLevelUnion* {.union.} = object
        psb*  : ptr int8
        pb*   : ptr byte
        pw*   : ptr uint16
        pc*   : ptr CMPColour
        pf*   : ptr cfloat
        phfs* : ptr int16
        pdw*  : ptr uint32
        pvec8*: ptr Vec8
    CMPMIPLevel* = object
        width*      : cint
        height*     : cint
        linear_size*: uint32
        data*       : CMPMIPLevelUnion

    CMPMIPLevelTable* = ptr CMPMIPLevel

    CMPMIPSet* = object
        width*            : cint
        height*           : cint
        depth*            : cint
        format*           : CMPFormat
        channel_format*   : CMPChannelFormat
        texture_data_kind*: CMPTextureDataKind
        texture_kind*     : CMPTextureKind
        flags*            : cuint
        cube_face_mask*   : byte
        four_cc*          : uint32
        four_cc2*         : uint32
        max_mip_levels*   : cint
        mip_levels*       : cint
        transcode_format* : CMPFormat
        compressed*       : bool
        is_decompressed*  : CMPFormat
        swizzle*          : bool
        block_width*      : byte
        block_height*     : byte
        block_depth*      : byte
        channels*         : byte
        is_signed*        : byte
        curr_width*       : uint32
        curr_height*      : uint32
        curr_data_size*   : uint32
        curr_data*        : ptr UncheckedArray[byte]
        mip_level_table*  : ptr CMPMIPLevelTable
        reserved_data*    : pointer
        iterations*       : cint
        at_mip_level*     : cint
        at_face_or_slice* : cint

    CMPTexture* = object
        size*            : uint32
        width*           : uint32
        height*          : uint32
        pitch*           : uint32
        format*          : CMPFormat
        transcode_format*: CMPFormat
        block_height*    : byte
        block_width*     : byte
        block_depth*     : byte
        data_size*       : uint32
        data*            : ptr UncheckedArray[byte]
        mip_set*         : pointer

    BRLGExtraInfo* = object
        file_name*: cstring
        num_chars*: uint32

    BRLGFileHeader* = object
        file_kind*           : array[4, byte]
        major_version*       : byte
        header_size*         : cuint
        compressed_data_size*: uint32

    BRLGBlockHeader* = object
        original_width*            : uint32
        original_height*           : cuint
        original_format*           : CMPFormat
        original_texture_kind*     : CMPTextureKind
        original_texture_data_kind*: CMPTextureDataKind
        extra_data_size*           : cuint
        compressed_block_size*     : cuint

    BC6HBlockParameters* = object
        mask*           : int16
        exposure*       : cfloat
        is_signed*      : bool
        quality*        : cfloat
        use_pattern_rec*: bool

    CMPMIPProgressParam* = object
        mip_progress*: cfloat
        mip_level*   : cint
        cube_face*   : cint

    CMPEncoderSetting* = object
        width*  : cuint
        height* : cuint
        pitch*  : cuint
        quality*: cfloat
        format* : cuint

    CMPAnalysisData* = object
        analysis_mode*  : culong
        channel_bitmap* : cuint
        input_defog*    : cfloat
        input_exposure* : cfloat
        input_knee_low* : cfloat
        input_knee_high*: cfloat
        input_gamma*    : cfloat
        mse*            : cfloat
        mse_r*          : cfloat
        mse_g*          : cfloat
        mse_b*          : cfloat
        mse_a*          : cfloat
        psnr*           : cfloat
        psnr_r*         : cfloat
        psnr_g*         : cfloat
        psnr_b*         : cfloat
        psnr_a*         : cfloat

    BC6HBlockEncoder* = object
    BC7BlockEncoder*  = object

func make_fourcc*(ch0, ch1, ch2, ch3: uint32): uint32 =
    ch0 or
    (ch1 shl 8 ) or
    (ch2 shl 16) or
    (ch3 shl 24)

#[ -------------------------------------------------------------------- ]#

using
    ppbc6h_enc : ptr ptr BC6HBlockEncoder
    pbc6h_enc  : ptr     BC6HBlockEncoder
    ppbc7_enc  : ptr ptr BC7BlockEncoder
    pbc7_enc   : ptr     BC7BlockEncoder
    pbc7_block : ptr array[BCBlockPixels, array[BCComponentCount, cdouble]]
    pbc6h_block: ptr array[BCBlockPixels, array[BCComponentCount, cfloat]]
    pbytes     : ptr UncheckedArray[byte]
    pmips      : ptr CMPMIPSet
    mode_mask  : uint32
    qual, perf : cdouble
    feedback   : CMPFeedbackProc
    restr_rgb, restr_a: bool
    dst_tex, src_tex  : ptr CMPTexture
    panalysis_data    : ptr CMPAnalysisData
    encoder           : ptr pointer

proc init_framework*() {.importc: "CMP_InitFramework".}
proc max_faces_or_slices*(mip_set: ptr CMPMIPSet; mip_level: cint): cint {.importc: "CMP_MaxFacesOrSlices".}

proc initialize_bc_library*(): BCError {.importc: "CMP_InitializeBCLibrary".}
proc shutdown_bc_library*(): BCError   {.importc: "CMP_ShutdownBCLibrary"  .}

proc create_bc7_encoder*(qual; restr_rgb, restr_a; mode_mask; perf; ppbc7_enc): BCError {.importc: "CMP_CreateBC7Encoder" .}
proc encode_bc7_block*(pbc7_enc; pbc7_block; pbytes): BCError                           {.importc: "CMP_EncodeBC7Block"   .}
proc decode_bc7_block*(pbytes; pbc7_block): BCError                                     {.importc: "CMP_DecodeBC7Block"   .}
proc destroy_bc7_encoder*(pbc7_enc): BCError                                            {.importc: "CMP_DestroyBC7Encoder".}

proc create_bc6h_encoder*(user_settings: BC6HBlockParameters; ppbc6h_enc): BCError {.importc: "CMP_CreateBC6HEncoder" .}
proc encode_bc6h_block*(pbc6h_enc; pbc6h_block; pbytes): BCError                   {.importc: "CMP_EncodeBC6HBlock"   .}
proc decode_bc6h_block*(pbytes; pbc6h_block): BCError                              {.importc: "CMP_DecodeBC6HBlock"   .}
proc destroy_bc6h_encoder*(pbc6h_enc): BCError                                     {.importc: "CMP_DestroyBC6HEncoder".}

proc calculate_buffer_size*(tex: ptr CMPTexture): uint32                                     {.importc: "CMP_CalculateBufferSize".}
proc convert_texture*(src_tex, dst_tex; opts: ptr CMPCompressionOptions; feedback): CMPError {.importc: "CMP_ConvertTexture"     .}

proc calc_max_mip_level*(height, width: cint; for_gpu: bool): cint                                {.importc: "CMP_CalcMaxMipLevel"     .}
proc calc_min_mip_size*(height, width, mips_level: cint): cint                                    {.importc: "CMP_CalcMinMipSize"      .}
proc generate_mip_levels_ex*(pmips; params: ptr CMPCFilterParams): cint                           {.importc: "CMP_GenerateMIPLevelsEx" .}
proc generate_mip_levels*(pmips; min_size: cint): cint                                            {.importc: "CMP_GenerateMIPLevels"   .}
proc create_compress_mip_set*(mips_cmp, mips_src: ptr CMPMIPSet): CMPError                        {.importc: "CMP_CreateCompressMipSet".}
proc create_mip_set*(pmips; w, h, d: cint; fmt: CMPChannelFormat; kind: CMPTextureKind): CMPError {.importc: "CMP_CreateMipSet"        .}

proc get_format_num_channels*(fmt: CMPFormat): cuint                                                            {.importc: "CMP_getFormat_nChannels".}
proc mip_set_analysis*(src1, src2: ptr CMPMIPSet; level, face_or_slice: cint; panalysis_data): CMPError         {.importc: "CMP_MipSetAnlaysis"     .}
proc convert_mip_texture*(mips_in, mips_out: ptr CMPMIPSet; opt: ptr CMPCompressionOptions; feedback): CMPError {.importc: "CMP_ConvertMipTexture"  .}

proc load_texture*(src_file: cstring; pmips): CMPError                                                   {.importc: "CMP_LoadTexture"        .}
proc save_texture*(dst_file: cstring; pmips): CMPError                                                   {.importc: "CMP_SaveTexture"        .}
proc process_texture*(src_mips, dst_mips: ptr CMPMIPSet; opt: CMPKernelOptions; feedback): CMPError      {.importc: "CMP_ProcessTexture"     .}
proc compress_texture*(opt: ptr CMPKernelOptions; src_mips, dst_mips: ptr CMPMIPSet; feedback): CMPError {.importc: "CMP_CompressTexture"    .}
proc format_to_fourcc*(fmt: CMPFormat; pmips)                                                            {.importc: "CMP_Format2FourCC"      .}
proc parse_format*(fmt: cstring): CMPFormat                                                              {.importc: "CMP_ParseFormat"        .}
proc number_of_processors*(): cint                                                                       {.importc: "CMP_NumberOfProcessors" .}
proc free_mip_set*(pmips)                                                                                {.importc: "CMP_FreeMipSet"         .}
proc get_mip_level*(data: ptr ptr CMPMIPLevel; pmips; mip_lvl, face_or_slice: cint)                      {.importc: "CMP_GetMipLevel"        .}
proc get_performance_stats*(stats: ptr CMPKernelPerformanceStats): CMPError                              {.importc: "CMP_GetPerformanceStats".}
proc get_device_info*(info: ptr CMPKernelDeviceInfo): CMPError                                           {.importc: "CMP_GetDeviceInfo"      .}
proc is_compressed_format*(fmt: CMPFormat): bool                                                         {.importc: "CMP_IsCompressedFormat" .}
proc is_float_format*(fmt: CMPFormat): bool                                                              {.importc: "CMP_IsFloatFormat"      .}

proc create_compute_library*(pmips; opt: ptr CMPKernelOptions; reserved: pointer): CMPError {.importc: "CMP_CreateComputeLibrary" .}
proc destroy_compute_library*(force_close: bool): CMPError                                  {.importc: "CMP_DestroyComputeLibrary".}
proc set_compute_options*(opt: ptr CMPComputeOptions): CMPError                             {.importc: "CMP_SetComputeOptions"    .}

proc create_block_encoder*(encoder; settings: CMPEncoderSetting): CMPError                                {.importc: "CMP_CreateBlockEncoder" .}
proc compress_block*(encoder; src: pointer; src_stride: cuint; dst: pointer; dst_stride: cuint): CMPError {.importc: "CMP_CompressBlock"      .}
proc destroy_block_encoder*(encoder): CMPError                                                            {.importc: "CMP_DestroyBlockEncoder".}
proc compress_block_xy*(encoder; x, y: cuint; img_src: pointer; src_stride: cuint;
                                              cmp_dst: pointer; dst_stride: cuint): CMPError {.importc: "CMP_CompressBlockXY".}
