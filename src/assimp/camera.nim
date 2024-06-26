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
