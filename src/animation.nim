import common

type AnimBehaviour = enum
    Default
    Constant
    Linear
    Repeat

type
    Animation* = object
        name               : AIString
        duration           : float64
        ticks_per_second   : float64
        channels_count     : uint32
        channels           : ptr UncheckedArray[ptr NodeAnim]
        mesh_channel_count : uint32
        mesh_channels      : ptr UncheckedArray[ptr MeshAnim]
        morph_mesh_channels: ptr UncheckedArray[ptr MeshMorphAnim]

    MeshMorphAnim* = object
        name      : AIString
        keys_count: uint32
        keys      : ptr UncheckedArray[MeshMorphKey]
    MeshMorphKey* = object
        time   : float64
        values : ptr UncheckedArray[uint32]
        weights: ptr UncheckedArray[float64]
        count  : uint32

    MeshAnim* = object
        name      : AIString
        keys_count: uint32
        keys      : ptr UncheckedArray[MeshKey]
    MeshKey* = object
        time : float64
        value: uint32

    NodeAnim* = object
        name               : AIString
        position_keys_count: uint32
        position_keys      : ptr UncheckedArray[VecKey]
        rotation_keys_count: uint32
        rotation_keys      : ptr UncheckedArray[QuatKey]
        scaling_keys_count : uint32
        scaling_keys       : ptr UncheckedArray[VecKey]
        pre_state          : AnimBehaviour
        post_state         : AnimBehaviour
    VecKey* = object
        time : float64
        value: Vec3
    QuatKey* = object
        time : float64
        value: Quat
