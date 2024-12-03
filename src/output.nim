# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import
    std/[streams, sequtils, strutils],
    common, assimp/assimp, stbi, ispctc, dds, nai, util

# TODO: ensure flags don't overlap/have invalid pairs
proc write_header*(header: var Header; scene: ptr AiScene; file: Stream) =
    with header:
        magic        = nai.Magic
        version      = nai.Version
        mesh_cnt     = uint16 scene.mesh_cnt
        mtl_cnt      = uint16 scene.mtl_cnt
        tex_cnt      = uint16 scene.tex_cnt
        anim_cnt     = uint16 scene.anim_cnt
        skeleton_cnt = uint16 scene.skeleton_cnt
    file.write header

proc write_meshes*(header: Header; scene: ptr AiScene; file: Stream) =
    if scene.mesh_cnt != 1:
        assert false, "Need to implement multiple meshes"

    for mesh in scene.meshes.to_open_array(0, int scene.mesh_cnt - 1):
        var idx_cnt = 0
        for face in to_open_array(mesh.faces, 0, int mesh.face_cnt - 1):
            idx_cnt += int face.idx_cnt

        let vtx_lst = to_seq header.vtx_kinds
        let vtx_sz  = vtx_lst.foldl(a + b, 0)

        info &"Mesh '{mesh.name}' (material index: {mesh.mtl_idx}) {header.vtx_kinds}"
        info &"    {mesh.vtx_cnt} vertices of {0}B ({idx_cnt} indices making {mesh.face_cnt} faces)"
        info &"    UV components: {mesh.uv_comp_cnt}"
        info &"    {mesh.bone_cnt} bones"
        info &"    {mesh.anim_mesh_cnt} animation meshes (morphing method: {mesh.morph_method})"
        info &"    AABB: {mesh.aabb}"

        if mesh.prim_kinds != primTriangle:
            error "Mesh contains non-triangle primitives"
            return

        # Header
        let mesh_header = MeshHeader(
            mtl_idx: uint16 mesh.mtl_idx,
            idx_sz : is32Bit, # TODO: index size option
            vtx_cnt: mesh.vtx_cnt,
            idx_cnt: uint32 idx_cnt,
        )
        file.write mesh_header

        # TODO
        if lfVerticesSeparated in header.layout_mask:
            assert false

        # Vertices
        func confirm_vert_kind(mesh: ptr AiMesh; kind: VertexKind): bool =
            case kind
            of vkNone: false
            of vkPosition, vkNormal, vkTangent, vkBitangent:
                mesh.vtx_cnt > 0
            of vkColourRgba, vkColourRgb:
                mesh.colours.foldl(a + (if b == nil: 0 else: 1), 0) > 0
            of vkUv, vkUv3:
                mesh.tex_coords.foldl(a + (if b == nil: 0 else: 1), 0) > 0

        let vtx_kinds  = header.vtx_kinds.filter_it: it != vkNone
        let interleave = lfVerticesInterleaved in header.layout_mask # TODO: implement separated vertices
        var offset = 0
        for (i, kind) in enumerate vtx_kinds:
            if not mesh.confirm_vert_kind kind:
                warning &"Mesh '{mesh.name}' does not contain {kind} vertices"

        for v in 0..<mesh.vtx_cnt:
            for (i, kind) in enumerate vtx_kinds:
                case kind
                of vkPosition  : file.write mesh.vtxs[v]
                of vkNormal    : file.write mesh.normals[v]
                of vkTangent   : file.write mesh.tangents[v]
                of vkBitangent : file.write mesh.bitangents[v]
                of vkColourRgba: file.write mesh.colours[v]
                of vkColourRgb : file.write mesh.colours[v]
                of vkUv        : file.write mesh.tex_coords[0][v].xy
                of vkUv3       : file.write mesh.tex_coords[0][v]
                of vkNone:
                    assert false

        # TODO: deal with different index sizes
        for face in mesh.faces.to_open_array(0, int mesh.face_cnt - 1):
            for idx in face.idxs.to_open_array(0, int face.idx_cnt - 1):
                let index32 = uint32 idx
                file.write index32

proc write_materials*(header: Header; scene: ptr AiScene; file: Stream; tex_descrips: seq[TextureDescriptor]; output_name: string) =
    if {lfTexturesInternal, lfTexturesExternal} * header.layout_mask == {}:
        return

    proc check_tex(mtl: ptr AiMaterial; kind: AiTextureKind): bool =
        result = true
        let count = mtl.texture_count kind
        if count == 0:
            warning &"Material does not have any '{kind}' texture"
            result = false
        elif count > 1:
            warning &"Material has {count} {kind} textures, but only 1 is supported"
    proc get_tex(mtl: ptr AiMaterial; kind: AiTextureKind): AiTextureData =
        let data = mtl.texture kind
        if data.is_none:
            error &"Could not get material's '{kind}' texture '{get_assimp_error()}'"
            quit 1
        get data

    for mtl in scene.mtls.to_open_array(0, int scene.mtl_cnt - 1):
        info $mtl[]

        # Fetch the Ai data
        var tex_datas = tex_descrips
        for data in mitems tex_datas:
            let kind = cast[AiTextureKind](data.kind)
            if mtl.check_tex kind:
                data.tex = mtl.get_tex kind

        # Header
        let mtl_header = MaterialHeader(tex_cnt: uint16 tex_datas.len)
        file.write mtl_header

        # Material data
        for val in header.mtl_vals:
            if val == mvNone:
                continue

            let buf = mtl.get_value val
            case buf.kind
            of tvkBoolean: file.write_data buf.bln.addr, 4
            of tvkInteger: file.write_data buf.num.addr, 4
            of tvkFloat  : file.write_data buf.flt.addr, 4
            of tvkString : assert false, "TODO"# file.write_data buf.str.addr, 4
            of tvkVector : file.write_data buf.vec.addr, 16

        # Textures
        for tex_data in tex_datas:
            let path = tex_data.tex.path
            if path == "":
                continue
            elif path.starts_with "*":
                let index = parse_int path[1..^1] # TODO: Fix for external textures
                let tex   = scene.texs[index][]

                # Header
                let
                    raw_tex = load_image(tex.data, tex.w, 4)
                    w = raw_tex.w
                    h = raw_tex.h
                    tex_header = TextureHeader(
                        kind: tex_data.kind,
                        fmt : tex_data.fmt,
                        w   : uint16 w,
                        h   : uint16 h,
                    )
                file.write tex_header

                # TODO: mipmaps
                let mip_cnt = 1

                # Compression
                var final_tex: ptr UncheckedArray[byte]
                var final_sz : int
                if tex_header.fmt notin [tckNoneRgb, tckNoneRgba]:
                    let profile = get_profile tex_header.fmt
                    let cmp_tex = profile.compress(cast[ptr byte](raw_tex.data), w, h, raw_tex.channels)
                    final_tex = cast[ptr UncheckedArray[byte]](cmp_tex.data)
                    final_sz  = cmp_tex.sz
                else:
                    final_tex = cast[ptr UncheckedArray[byte]](raw_tex.data)
                    final_sz  = (raw_tex.w * raw_tex.h * tex_header.fmt.bpp) div 8

                # Output
                let dst_file =
                    if lfTexturesInternal in header.layout_mask:
                        file
                    else:
                        let ext = to_lower_ascii (if tex_data.container != ckNone: $tex_data.container else: $tex_data.fmt)
                        var file_name = output_name
                        file_name.remove_suffix ".nai"
                        file_name &= &"-{to_lower_ascii $tex_data.kind}.{ext}"
                        open_file_stream file_name, fmWrite

                case tex_data.container
                of ckNone: dst_file.write_data final_tex, final_sz
                of ckPng : dst_file.write_image ifPng, int tex_header.w, int tex_header.h, tex_header.fmt.bpp div 8, final_tex
                of ckDds:
                    dst_file.write dds.encode(
                        tex_data.fmt,
                        final_tex.to_open_array(0, final_sz - 1),
                        w, h, mip_cnt,
                    )
            else:
                assert false

# proc write_header*(header: Header) =
