# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, sequtils, strutils],
    common, assimp/assimp, stbi, ispctc, dds, nai, util

# TODO: ensure flags don't overlap/have invalid pairs
proc write_header*(header: var Header; scene: ptr AIScene; file: Stream) =
    with header:
        magic           = NAIMagic
        version         = NAIVersion
        mesh_count      = uint16 scene.mesh_count
        material_count  = uint16 scene.material_count
        texture_count   = uint16 scene.texture_count
        animation_count = uint16 scene.animation_count
        skeleton_count  = uint16 scene.skeleton_count
    file.write header

proc write_meshes*(header: Header; scene: ptr AIScene; file: Stream) =
    if scene.mesh_count != 1:
        assert false, "Need to implement multiple meshes"

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
            index_size    : isz32Bit, # TODO: index size option
            vert_count    : mesh.vertex_count,
            index_count   : uint32 index_count,
        )
        file.write mesh_header

        # TODO
        if lfVerticesSeparated in header.layout_mask:
            assert false

        # Vertices
        func confirm_vert_kind(mesh: ptr AIMesh; kind: VertexKind): bool =
            case kind
            of vtxNone: false
            of vtxPosition, vtxNormal, vtxTangent, vtxBitangent:
                mesh.vertex_count > 0
            of vtxColourRGBA, vtxColourRGB:
                mesh.colours.foldl(a + (if b == nil: 0 else: 1), 0) > 0
            of vtxUV, vtxUV3:
                mesh.texture_coords.foldl(a + (if b == nil: 0 else: 1), 0) > 0

        let vert_kinds = header.vertex_kinds.filter_it: it != vtxNone
        let interleave = lfVerticesInterleaved in header.layout_mask # TODO: implement separated vertices
        var offset = 0
        for (i, kind) in enumerate vert_kinds:
            if not mesh.confirm_vert_kind kind:
                warning &"Mesh '{mesh.name}' does not contain {kind} vertices"

        for v in 0..<mesh.vertex_count:
            for (i, kind) in enumerate vert_kinds:
                case kind
                of vtxPosition  : file.write mesh.vertices[v]
                of vtxNormal    : file.write mesh.normals[v]
                of vtxTangent   : file.write mesh.tangents[v]
                of vtxBitangent : file.write mesh.bitangents[v]
                of vtxColourRGBA: file.write mesh.colours[v]
                of vtxColourRGB : file.write mesh.colours[v]
                of vtxUV        : file.write mesh.texture_coords[0][v].xy
                of vtxUV3       : file.write mesh.texture_coords[0][v]
                of vtxNone:
                    assert false

        # TODO: deal with different index sizes
        for face in mesh.faces.to_oa mesh.face_count:
            for index in face.indices.to_oa face.index_count:
                let index32 = uint32 index
                file.write index32

proc write_materials*(header: Header; scene: ptr AIScene; file: Stream; tex_descrips: seq[TextureDescriptor]; output_name: string) =
    if {lfTexturesInternal, lfTexturesExternal} * header.layout_mask == {}:
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
            if val == mtlNone:
                continue

            let buf = mtl.get_value val
            case buf.kind
            of tvBoolean: file.write_data buf.bln.addr, 4
            of tvInteger: file.write_data buf.num.addr, 4
            of tvFloat  : file.write_data buf.flt.addr, 4
            of tvString : assert false, "TODO"# file.write_data buf.str.addr, 4
            of tvVector : file.write_data buf.vec.addr, 16

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
                if tex_header.format notin [cmpNoneRGB, cmpNoneRGBA]:
                    let profile = get_profile tex_header.format
                    let cmp_tex = profile.compress(cast[ptr byte](raw_tex.data), w, h, raw_tex.channels)
                    final_tex  = cast[ptr UncheckedArray[byte]](cmp_tex.data)
                    final_size = cmp_tex.size
                else:
                    final_tex  = cast[ptr UncheckedArray[byte]](raw_tex.data)
                    final_size = (raw_tex.w * raw_tex.h * tex_header.format.bpp) div 8

                # Output
                let dst_file =
                    if lfTexturesInternal in header.layout_mask:
                        file
                    else:
                        let ext = to_lower_ascii (if tex_data.container != cntNone: $tex_data.container else: $tex_data.format)
                        var file_name = output_name
                        file_name.remove_suffix ".nai"
                        file_name &= &"-{to_lower_ascii $tex_data.kind}.{ext}"
                        open_file_stream file_name, fmWrite

                case tex_data.container
                of cntNone: dst_file.write_data final_tex, final_size
                of cntPNG : dst_file.write_image stbPNG, int tex_header.w, int tex_header.h, tex_header.format.bpp div 8, final_tex
                of cntDDS:
                    dst_file.write encode_dds(
                        tex_data.format,
                        final_tex.to_oa final_size,
                        w, h, mip_count,
                    )
            else:
                assert false

# proc write_header*(header: Header) =


