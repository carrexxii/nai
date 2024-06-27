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
