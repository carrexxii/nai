# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import common

type
    AiLightSourceKind* = enum
        lskUndefined
        lskDirectional
        lskPoint
        lskSpot
        lskAmbient
        lskArea

    AiLight* = object
        name*            : AiString
        kind*            : AiLightSourceKind
        pos*             : AiVec3
        dir*             : AiVec3
        up*              : AiVec3
        atten_constant*  : float32
        atten_linear*    : float32
        atten_quadratic* : float32
        colour_diffuse*  : AiColour3
        colour_specular* : AiColour3
        colour_ambient*  : AiColour3
        angle_inner_cone*: float32
        angle_outer_cone*: float32
        sz*              : AiVec2

func `$`*(light: AiLight | ptr AiLight): string = &"""
AiLight '{light.name}' is {light.kind} with size {light.sz}
    Position/Direction/Up                  {light.pos}/{light.dir}/{light.up}
    Attentuation Constant/Linear/Quadratic {light.atten_constant}/{light.atten_linear}/{light.atten_quadratic}
    Colour Diffuse/Specular/Ambient        {light.colour_diffuse}/{light.colour_specular}/{light.colour_ambient}
    Angle Outer Cone/Inner Cone            {light.angle_inner_cone}/{light.angle_outer_cone}
"""
