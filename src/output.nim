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
    file.write_data(header.addr, sizeof header)

proc write_meshes*(header: Header; scene: ptr AIScene; file: Stream; verbose: bool) =
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

        let vert_list = to_seq header.vertex_flags
        let vert_size = vert_list.foldl(a + b.size, 0)

        info &"Mesh '{mesh.name}' (material index: {mesh.material_index}) {header.vertex_flags}"
        info &"    {mesh.vertex_count} vertices of {0}B ({index_count} indices making {mesh.face_count} faces)"
        info &"    UV components: {mesh.uv_component_count}"
        info &"    {mesh.bone_count} bones"
        info &"    {mesh.anim_mesh_count} animation meshes (morphing method: {mesh.morph_method})"
        info &"    AABB: {mesh.aabb}"

        if mesh.primitive_kinds != Triangle:
            error "Mesh contains non-triangle primitives"
            return

        let mesh_header = MeshHeader(
            material_index: uint16 mesh.material_index,
            index_size    : Index32,
            vert_count    : mesh.vertex_count,
            index_count   : uint32 index_count,
        )
        file.write mesh_header

        if VerticesInterleaved in header.layout_flags:
            file.write_data(mesh.vertex_count.addr, sizeof MeshHeader.vert_count)
            file.write_data(index_count.addr      , sizeof MeshHeader.index_count)

            var vert_mem  = cast[ptr UncheckedArray[uint8]](alloc (vert_size * (int mesh.vertex_count)))
            for (i, pair) in enumerate [(Position, mesh.vertices),
                                        (Normal  , mesh.normals),
                                        (UV      , mesh.texture_coords[0])]: # TODO: deal with other texture_coords
                let (kind, data) = pair
                var offset = 0
                for flag in header.vertex_flags:
                    if flag == kind:
                        break
                    offset += flag.size

                var p = offset
                for v in 0 .. mesh.vertex_count:
                    copy_mem(vert_mem[p].addr, data[v].addr, kind.size)
                    p += vert_size

            file.write_data(vert_mem, vert_size * (int mesh.vertex_count))
            dealloc vert_mem

            for face in to_oa(mesh.faces, mesh.face_count):
                for index in to_oa(face.indices, face.index_count):
                    let index32 = uint32 index
                    file.write_data(index32.addr, sizeof index32)

        elif VerticesSeparated in header.layout_flags:
            assert false

proc write_materials*(header: Header; scene: ptr AIScene; file: Stream; output_name: string; verbose: bool) =
    proc get_tex(mtl: ptr AIMaterial; kind: AITextureKind): AITextureData =
        echo kind
        let count = mtl.texture_count kind
        if count == 0:
            error &"Material does not have any '{kind}' texture"
            quit 1
        elif count > 1:
            warning &"Material has {count} {kind} textures, but only 1 is supported"

        let data = mtl.texture kind
        if is_none data:
            error &"Could not get material's '{kind}' texture '{get_assimp_error()}'"
            quit 1
        get data

    if verbose:
        discard

    for mtl in to_oa(scene.materials, scene.material_count):
        if verbose:
            echo $mtl[]

        let tex_datas = @[mtl.get_tex Diffuse, mtl.get_tex Normals, mtl.get_tex Metalness]
        for tex_data in tex_datas:
            if tex_data.path.starts_with "*":
                let index     = parse_int tex_data.path[1..^1]
                let tex       = scene.textures[index][]
                var file_name = output_name
                file_name.remove_suffix ".nai"
                file_name &= &"-{to_lower_ascii $tex_data.kind}.dds"

                let
                    raw_tex = load_image(tex.data, tex.width, 4)
                    w = raw_tex.w
                    h = raw_tex.h

                # var file = open_file_stream(file_name, fmWrite)
                # file.write_data(tex.data[0].addr, int tex.width)
                # close file

                let profile = BC1.get_profile()
                let cmp_tex = profile.compress(cast[ptr byte](raw_tex.data), w, h, raw_tex.channels)

                # file.write_data(mesh_header, sizeof mesh_header)
                file.write_data(cmp_tex.data, cmp_tex.size)

                # let dds_file = encode_dds(profile.kind, to_open_array(cast[ptr UncheckedArray[byte]](cmp_tex.data), 0, cmp_tex.size - 1), w, h, 1)
                # let sz = 4 + (sizeof dds_file.header) + dds_file.data_size
                # info &"Writing '{tex_data.kind}' texture to '{file_name}' ({sz}/{sz/1024:.2f}kB/{sz/1024/1024:.2f}MB)"
            else:
                assert false

# proc write_textures*(scene: ptr Scene; file: Stream; output_name: string; verbose: bool) =
    # discard
    # for texture in to_oa(scene.textures, scene.texture_count):
    #     if verbose:
    #         echo $texture[]
    #     var fmt_hint = new_string MaxTextureHintLen
    #     copy_mem(fmt_hint[0].addr, texture.format_hint[0].addr, MaxTextureHintLen)
        # if TexturesExternal in output_flags:
        #     let texture_name = &"{output_name[0 ..^ 5]}-{}.{fmt_hint}"
        #     var file = open_file_stream(texture_name, fmWrite)
        #     file.write_data(texture.data[0].addr, int texture.width)
        #     close file
