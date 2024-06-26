import common

type AIAnimBehaviour* {.size: sizeof(cint).} = enum
    Default
    Constant
    Linear
    Repeat

type
    AIAnimation* = object
        name               : AIString
        duration           : float64
        ticks_per_second   : float64
        channels_count     : uint32
        channels           : ptr UncheckedArray[ptr AINodeAnim]
        mesh_channel_count : uint32
        mesh_channels      : ptr UncheckedArray[ptr AIMeshAnim]
        morph_mesh_channels: ptr UncheckedArray[ptr AIMeshMorphAnim]

    AIMeshMorphAnim* = object
        name      : AIString
        keys_count: uint32
        keys      : ptr UncheckedArray[AIMeshMorphKey]
    AIMeshMorphKey* = object
        time   : float64
        values : ptr UncheckedArray[uint32]
        weights: ptr UncheckedArray[float64]
        count  : uint32

    AIMeshAnim* = object
        name      : AIString
        keys_count: uint32
        keys      : ptr UncheckedArray[AIMeshKey]
    AIMeshKey* = object
        time : float64
        value: uint32

    AINodeAnim* = object
        name               : AIString
        position_keys_count: uint32
        position_keys      : ptr UncheckedArray[AIVecKey]
        rotation_keys_count: uint32
        rotation_keys      : ptr UncheckedArray[AIQuatKey]
        scaling_keys_count : uint32
        scaling_keys       : ptr UncheckedArray[AIVecKey]
        pre_state          : AIAnimBehaviour
        post_state         : AIAnimBehaviour
    AIVecKey* = object
        time : float64
        value: AIVec3
    AIQuatKey* = object
        time : float64
        value: AIQuat
