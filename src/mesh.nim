import
    std/macros,
    common, header

type
    Mesh* = object
        primitive_kinds*    : PrimitiveFlag
        vertex_count*       : uint32
        face_count*         : uint32
        vertices*           : ptr UncheckedArray[Vec3]
        normals*            : ptr UncheckedArray[Vec3]
        tangents*           : ptr UncheckedArray[Vec3]
        bitangents*         : ptr UncheckedArray[Vec3]
        colours*            : array[MaxColourSets, ptr UncheckedArray[Colour]]
        texture_coords*     : array[MaxTextureCoords, ptr UncheckedArray[Vec3]]
        uv_component_count* : array[MaxTextureCoords, uint32]
        faces*              : ptr UncheckedArray[Face]
        bone_count*         : uint32
        bones*              : ptr UncheckedArray[ptr Bone]
        material_index*     : uint32
        name*               : AIString
        anim_mesh_count*    : uint32
        anim_meshes*        : ptr UncheckedArray[ptr AnimMesh]
        morph_method*       : MorphMethod
        aabb*               : AABB
        texture_coord_names*: ptr UncheckedArray[ptr AIString]

    AnimMesh* = object
        name*          : AIString
        vertices*      : ptr UncheckedArray[Vec3]
        normals*       : ptr UncheckedArray[Vec3]
        tangents*      : ptr UncheckedArray[Vec3]
        bitangents*    : ptr UncheckedArray[Vec3]
        colours*       : array[MaxColourSets, ptr UncheckedArray[Colour]]
        texture_coords*: array[MaxTextureCoords, ptr UncheckedArray[Vec3]]
        vertex_count*  : uint32
        weight*        : float32

    MorphMethod* = enum
        MorphUnknown
        MorphVertexBlend
        MorphNormalized
        MorphRelative

    VertexWeight* = object
        id*    : uint32
        weight*: Real

    Bone* = object
        parent*: int32
        when NoArmaturePopulateProcess:
            armature*: ptr Node
            node*    : ptr Node
        weight_count*: uint32
        mesh_index*  : ptr Mesh
        weights*     : ptr UncheckedArray[VertexWeight]
        offset_mat*  : Mat4x4
        local_mat*   : Mat4x4

    Skeleton* = object
        name*       : AIString
        bones_count*: uint32
        bones*      : ptr UncheckedArray[ptr Bone]

    Face* = object
        index_count*: uint32
        indices*    : ptr UncheckedArray[uint32]

macro build_vertex() =
    var fields = newNimNode nnkRecList
    for flag in vertex_flags:
        let (fn, fk) = case flag
        of Position  : ("pos"      , "Vec3"   )
        of Normal    : ("normal"   , "Vec3"   )
        of Tangent   : ("tangent"  , "Vec3"   )
        of Bitangent : ("bitangent", "Vec3"   )
        of ColourRGBA: ("colour"   , "Colour" )
        of ColourRGB : ("colour"   , "Colour3")
        of UV        : ("uv"       , "Vec2"   )
        of UV3       : ("uv"       , "Vec3"   )

        let def = nnkPostFix.newTree(
            ident "*",
            ident fn,
        )
        fields.add newIdentDefs(def, ident fk)

    # Put it all together into a type section+def
    nnkTypeSection.newTree(
        nnkTypeDef.newTree(
            nnkPragmaExpr.newTree(
                nnkPostFix.newTree(
                    ident "*",
                    ident "Vertex",
                ),
                nnkPragma.newTree(
                    ident "packed",
                ),
            ),
            newEmptyNode(),
            nnkObjectTy.newTree(
                newEmptyNode(),
                newEmptyNode(),
                fields,
            )
        )
    )

build_vertex()
