# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, sequtils, strutils],
    common, assimp/assimp, stbi, ispctc, dds, nai

# TODO: ensure flags don't overlap/have invalid pairs
proc write_header*(header: var Header; scene: ptr AIScene; file: Stream) =
    header.magic           = NAIMagic
    header.version         = NAIVersion
    header.mesh_count      = uint16 scene.mesh_count
    header.material_count  = uint16 scene.material_count
    header.texture_count   = uint16 scene.texture_count
    header.animation_count = uint16 scene.animation_count
    header.skeleton_count  = uint16 scene.skeleton_count
    file.write header

proc write_meshes*(header: Header; scene: ptr AIScene; file: Stream) =
    template write(kind: VertexKind; dst, src) =
        when flags in vertex_flags:
            dst = src

    template iter(count: int; a, b, c: ptr UncheckedArray[untyped]): untyped =
        iterator iter_impl(n: int; s1: typeof a; s2: typeof b; s3: typeof c): (typeof a[0], typeof b[0], typeof c[0]) =
            for i in 0..<n:
                yield (s1[i], s2[i], s3[i])

        iter_impl(count, a, b, c)

    if scene.mesh_count != 1:
        assert(false, "Need to implement multiple meshes")
    for mesh in to_oa(scene.meshes, scene.mesh_count):
        var index_count = 0
        for face in to_oa(mesh.faces, mesh.face_count):
            index_count += int face.index_count

        let vert_list = to_seq header.vertex_kinds
        let vert_size = vert_list.foldl(a + b.size, 0)

        info &"Mesh '{mesh.name}' (material index: {mesh.material_index}) {header.vertex_kinds}"
        info &"    {mesh.vertex_count} vertices of {0}B ({index_count} indices making {mesh.face_count} faces)"
        info &"    UV components: {mesh.uv_component_count}"
        info &"    {mesh.bone_count} bones"
        info &"    {mesh.anim_mesh_count} animation meshes (morphing method: {mesh.morph_method})"
        info &"    AABB: {mesh.aabb}"

        if mesh.primitive_kinds != Triangle:
            error "Mesh contains non-triangle primitives"
            return

        # Header
        let mesh_header = MeshHeader(
            material_index: uint16 mesh.material_index,
            index_size    : Index32,
            vert_count    : mesh.vertex_count,
            index_count   : uint32 index_count,
        )
        file.write mesh_header

        # TODO
        if VerticesSeparated in header.layout_mask:
            assert false

        # Vertices
        func confirm_vert_kind(mesh: ptr AIMesh; kind: VertexKind): bool =
            case kind
            of None: false
            of Position, Normal, Tangent , Bitangent:
                mesh.vertex_count > 0
            of ColourRGBA, ColourRGB:
                mesh.colours.foldl(a + (if b == nil: 0 else: 1), 0) > 0
            of UV, UV3:
                mesh.texture_coords.foldl(a + (if b == nil: 0 else: 1), 0) > 0

        let vert_kinds = header.vertex_kinds.filter_it: it != None
        let interleave = VerticesInterleaved in header.layout_mask
        var vert_mem  = cast[ptr UncheckedArray[uint8]](alloc vert_size * int mesh.vertex_count)
        var offset = 0
        for (i, kind) in enumerate vert_kinds:
            if not mesh.confirm_vert_kind kind:
                warning &"Mesh '{mesh.name}' does not contain {kind} vertices"
                continue

            var p = offset
            for v in 0..<mesh.vertex_count:
                let dst = vert_mem[p].addr
                var src: pointer
                case kind
                of Position  : src = mesh.vertices[i].addr
                of Normal    : src = mesh.normals[i].addr
                of Tangent   : src = mesh.tangents[i].addr
                of Bitangent : src = mesh.bitangents[i].addr
                of ColourRGBA: src = mesh.colours[i].addr
                of ColourRGB : src = mesh.colours[i].addr
                of UV        : src = mesh.texture_coords[0][i].addr
                of UV3       : src = mesh.texture_coords[0][i].addr
                else: assert false

                copy_mem dst, src, kind.size
                p += vert_size

            offset += kind.size

        file.write_data vert_mem, vert_size * int mesh.vertex_count
        dealloc vert_mem

        for face in mesh.faces.to_oa mesh.face_count:
            for index in face.indices.to_oa face.index_count:
                let index32 = uint32 index
                file.write_data index32.addr, sizeof index32

proc write_materials*(header: Header; scene: ptr AIScene; file: Stream; tex_descrips: seq[TextureDescriptor]; output_name: string) =
    if {TexturesInternal, TexturesExternal} * header.layout_mask == {}:
        return

    proc check_tex(mtl: ptr AIMaterial; kind: AITextureKind): bool =
        result = true
        let count = mtl.texture_count kind
        if count == 0:
            warning &"Material does not have any '{kind}' texture"
            result = false
        elif count > 1:
            warning &"Material has {count} {kind} textures, but only 1 is supported"
    proc get_tex(mtl: ptr AIMaterial; kind: AITextureKind): AITextureData =
        let data = mtl.texture kind
        if data.is_none:
            error &"Could not get material's '{kind}' texture '{get_assimp_error()}'"
            quit 1
        get data

    for mtl in scene.materials.to_oa scene.material_count:
        info $mtl[]

        # Fetch the AI data
        var tex_datas = tex_descrips
        for data in mitems tex_datas:
            let kind = cast[AITextureKind](data.kind)
            if mtl.check_tex kind:
                data.texture = mtl.get_tex kind

        # Header
        let mtl_header = MaterialHeader(texture_count: uint16 tex_datas.len)
        file.write mtl_header

        # Material data
        for val in header.material_values:
            if val == None:
                continue

            let buf = mtl.get_value val
            case buf.kind
            of Boolean: file.write_data buf.bln.addr, 4
            of Integer: file.write_data buf.num.addr, 4
            of Float  : file.write_data buf.flt.addr, 4
            of String : assert false, "TODO"# file.write_data buf.str.addr, 4
            of Vector : file.write_data buf.vec.addr, 16

        # Textures
        for tex_data in tex_datas:
            let path = tex_data.texture.path
            if path == "":
                continue
            elif path.starts_with "*":
                let index = parse_int path[1..^1] # TODO: Fix for external textures
                let tex   = scene.textures[index][]

                # Header
                let
                    raw_tex = load_image(tex.data, tex.width, 4)
                    w = raw_tex.w
                    h = raw_tex.h
                    tex_header = TextureHeader(
                        kind  : tex_data.kind,
                        format: tex_data.format,
                        w     : uint16 w,
                        h     : uint16 h,
                    )
                file.write tex_header

                # TODO: mipmaps
                let mip_count = 1

                # Compression
                var final_tex : ptr UncheckedArray[byte]
                var final_size: int
                if tex_header.format notin [NoneRGB, NoneRGBA]:
                    let profile = get_profile tex_header.format
                    let cmp_tex = profile.compress(cast[ptr byte](raw_tex.data), w, h, raw_tex.channels)
                    final_tex  = cast[ptr UncheckedArray[byte]](cmp_tex.data)
                    final_size = cmp_tex.size
                else:
                    final_tex  = cast[ptr UncheckedArray[byte]](raw_tex.data)
                    final_size = (raw_tex.w * raw_tex.h * tex_header.format.bpp) div 8

                # Output
                let dst_file =
                    if TexturesInternal in header.layout_mask:
                        file
                    else:
                        let ext = to_lower_ascii (if tex_data.container != None: $tex_data.container else: $tex_data.format)
                        var file_name = output_name
                        file_name.remove_suffix ".nai"
                        file_name &= &"-{to_lower_ascii $tex_data.kind}.{ext}"
                        open_file_stream file_name, fmWrite

                case tex_data.container
                of None: dst_file.write_data final_tex, final_size
                of PNG : dst_file.write_image PNG, int tex_header.w, int tex_header.h, tex_header.format.bpp div 8, final_tex
                of DDS:
                    dst_file.write encode_dds(
                        tex_data.format,
                        final_tex.to_oa final_size,
                        w, h, mip_count,
                    )
            else:
                assert false

