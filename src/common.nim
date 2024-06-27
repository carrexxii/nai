# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/[sugar, enumerate, options, terminal], nai
from std/strformat import `&`
export sugar, enumerate, options, `&`, nai

var verbose* = false
var quiet*   = false

proc info*(msg: string) =
    if verbose:
        stdout.styled_write(fgWhite, msg, "\n")

proc warning*(msg: string) =
    if not quiet:
        stderr.styled_write(fgYellow, "Warning: ", msg, "\n")

proc error*(msg: string) =
    stderr.styled_write(fgRed, "Error: ", msg, "\n")

template to_oa*(arr, c): untyped =
    to_open_array(arr, 0, int c - 1)
