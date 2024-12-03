# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common

type AiCamera* = object
    name*     : AiString
    pos*      : AiVec3
    up*       : AiVec3
    look_at*  : AiVec3
    fov*      : float32
    clip_near*: float32
    clip_far* : float32
    aspect*   : float32
    ortho_w*  : float32

func `$`*(cam: AiCamera | ptr AiCamera): string = &"""
AiCamera '{cam.name}' with horizontal fov of {cam.fov:.2f}, aspect ratio {cam.aspect} and orthogonal width of {cam.ortho_w}
    Position      {cam.pos}
    Up            {cam.up}
    Look At       {cam.look_at}
    Clip Near/Far {cam.clip_near}/{cam.clip_far}
"""
