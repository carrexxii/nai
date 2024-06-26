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
