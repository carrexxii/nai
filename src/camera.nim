import common

type Camera* = object
    name*       : AIString
    position*   : Vec3
    up*         : Vec3
    look_at*    : Vec3
    hfov*       : float32
    clip_near*  : float32
    clip_far*   : float32
    aspect*     : float32
    ortho_width*: float32
