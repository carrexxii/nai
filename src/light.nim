import common

type
    LightSourceKind* = enum
        Undefined
        Directional
        Point
        Spot
        Ambient
        Area
    Light* = object
        name*                 : AIString
        kind*                 : LightSourceKind
        position*             : Vec3
        direction*            : Vec3
        up*                   : Vec3
        attenuation_constant* : float32
        attenuation_linea*    : float32
        attenuation_quadratic*: float32
        colour_diffuse*       : Colour3
        colour_specular*      : Colour3
        colour_ambient*       : Colour3
        angle_inner_cone*     : float32
        angle_outer_cone*     : float32
        size*                 : Vec2
