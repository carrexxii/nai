# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common

type
    AILightSourceKind* = enum
        Undefined
        Directional
        Point
        Spot
        Ambient
        Area
    AILight* = object
        name*                 : AIString
        kind*                 : AILightSourceKind
        position*             : AIVec3
        direction*            : AIVec3
        up*                   : AIVec3
        attenuation_constant* : float32
        attenuation_linea*    : float32
        attenuation_quadratic*: float32
        colour_diffuse*       : AIColour3
        colour_specular*      : AIColour3
        colour_ambient*       : AIColour3
        angle_inner_cone*     : float32
        angle_outer_cone*     : float32
        size*                 : AIVec2
