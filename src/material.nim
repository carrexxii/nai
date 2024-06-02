import common

type
    TextureOp* = enum
        Multiply
        Add
        Subtract
        Divide
        SmoothAdd
        SignedAdd

    TextureMapOp* = enum
        Wrap
        Clamp
        Mirror
        Decal

    TextureMapping* = enum
        UV
        Sphere
        Cylinder
        Box
        Plane
        Other

    TextureKind* = enum
        None
        Diffuse
        Specular
        Ambient
        Emissive
        Height
        Normals
        Shininess
        Opacity
        Displacement
        Lightmap
        Reflection
        BaseColour
        NormalCamera
        EmissionColour
        Metalness
        DiffuseRoughness
        AmbientOcclusion
        Unknown
        Sheen
        Clearcoat
        Transmission

    ShadingMode* = enum
        Flat
        Gouraud
        Phong
        Blinn
        Toon
        OrenNayar
        Minnaert
        CookTorrance
        NoShading
        Fresnel
        PBRBRDF

    BlendMode* = enum
        Default
        Additive

    PropertyKindInfo* = enum
        Float
        Double
        String
        Integer
        Buffer

const Unlit* = NoShading

type TextureFlag {.size: sizeof(cint).} = enum
    Invert      = 0x1
    UseAlpha    = 0x2
    IgnoreAlpha = 0x4
func `or`(a, b: TextureFlag): TextureFlag =
    TextureFlag ((cint a) or (cint b))

type
    Material* = object
        properties      : ptr UncheckedArray[ptr MaterialProperty]
        properties_count: uint32
        allocated_count : uint32

    MaterialProperty* = object
        key        : AIString
        semantic   : uint32
        index      : uint32
        data_length: uint32
        kind       : PropertyKindInfo
        data       : ptr byte

    UVTransform* = object
        translation: Vec2
        scaling    : Vec2
        rotation   : Real

proc texture_kind_to_string*(kind: TextureKind): cstring {.importc: "aiTextureTypeToString", dynlib: AIPath.}
proc `$`*(kind: TextureKind): string = $(texture_kind_to_string kind)
