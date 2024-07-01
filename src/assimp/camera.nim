# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common

type AICamera* = object
    name*       : AIString
    position*   : AIVec3
    up*         : AIVec3
    look_at*    : AIVec3
    hfov*       : float32
    clip_near*  : float32
    clip_far*   : float32
    aspect*     : float32
    ortho_width*: float32

func `$`*(cam: AICamera | ptr AICamera): string = &"""
AICamera '{cam.name}' with horizontal fov of {cam.hfov:.2f}, aspect ratio {cam.aspect} and orthogonal width of {cam.ortho_width}
    Position      {cam.position}
    Up            {cam.up}
    Look At       {cam.look_at}
    Clip Near/Far {cam.clip_near}/{cam.clip_far}
"""

