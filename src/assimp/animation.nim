# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common

type AiAnimBehaviour* {.size: sizeof(cint).} = enum
    abDefault
    abConstant
    abLinear
    abRepeat

type
    AiAnimation* = object
        name               : AiString
        duration           : float64
        ticks_per_second   : float64
        channel_count      : uint32
        channels           : ptr UncheckedArray[ptr AiNodeAnim]
        mesh_channel_count : uint32
        mesh_channels      : ptr UncheckedArray[ptr AiMeshAnim]
        morph_mesh_channels: ptr UncheckedArray[ptr AiMeshMorphAnim]

    AiMeshMorphAnim* = object
        name      : AiString
        keys_count: uint32
        keys      : ptr UncheckedArray[AiMeshMorphKey]

    AiMeshMorphKey* = object
        time   : float64
        values : ptr UncheckedArray[uint32]
        weights: ptr UncheckedArray[float64]
        count  : uint32

    AiMeshAnim* = object
        name      : AiString
        keys_count: uint32
        keys      : ptr UncheckedArray[AiMeshKey]

    AiMeshKey* = object
        time : float64
        value: uint32

    AiNodeAnim* = object
        name               : AiString
        position_keys_count: uint32
        position_keys      : ptr UncheckedArray[AiVecKey]
        rotation_keys_count: uint32
        rotation_keys      : ptr UncheckedArray[AiQuatKey]
        scaling_keys_count : uint32
        scaling_keys       : ptr UncheckedArray[AiVecKey]
        pre_state          : AiAnimBehaviour
        post_state         : AiAnimBehaviour

    AiVecKey* = object
        time : float64
        value: AiVec3

    AiQuatKey* = object
        time : float64
        value: AiQuat

func `$`*(anim: AiAnimation | ptr AiAnimation): string = &"""
AiAnimation '{anim.name}'
    {anim.duration} Duration
    {anim.ticks_per_second} Ticks per second
    {anim.channel_count} Channel
    {anim.mesh_channel_count} Mesh channels
"""
