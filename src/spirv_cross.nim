{.push importc.}
proc spvc_get_version*(major, minor, patch: ptr cuint)
{.pop.}

{.push inline.}

proc version*(): tuple[major, minor, patch: cuint] =
    spvc_get_version result.major.addr, result.minor.addr, result.patch.addr

{.pop.}
