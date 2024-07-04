# This file is a part of Nai. Copyright (C) 2024 carrexxii.
# It is distributed under the terms of the GNU General Public License version 3 only.
# For a copy, see the LICENSE file or <https://www.gnu.org/licenses/>.

import std/[os, strformat, strutils, sequtils, enumerate]

const
    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF -DASSIMP_WARNINGS_AS_ERRORS=OFF " &
                  "-DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF -DASSIMP_BUILD_ZLIB=OFF"

let
    bin_path  = get_current_dir() / "nai"
    src_dir   = "./src"
    lib_dir   = "./lib"
    build_dir = "./build"
    tests_dir = "./tests"
    entry     = src_dir / "main.nim"
    deps: seq[tuple[src, dst, tag: string; cmds: seq[string]]] = @[
        (src  : "https://github.com/assimp/assimp",
         dst  : lib_dir / "assimp",
         tag  : "v5.4.1",
         cmds : @[&"cmake -B . -S . {AssimpFlags}",
                   "cmake --build . --config release -j8",
                   "mv bin/libassimp.so* ../"]),
        (src  : "https://github.com/GameTechDev/ISPCTextureCompressor/",
         dst  : lib_dir / "ispctc",
         tag  : "691513b4fb406eccfc2f7d7f8213c8505ff5b897",
         cmds : @["git apply ../../ispctc.patch",
                  "make -f Makefile.linux -j8",
                  "mv build/* ../"]),
        (src  : "https://github.com/madler/zlib/",
         dst  : lib_dir / "zlib",
         tag  : "v1.3.1",
         cmds : @["./configure",
                  "make",
                  "mv libz.so* ../"]),
        (src  : "https://raw.githubusercontent.com/nothings/stb/master/stb_image.h",
         dst  : lib_dir,
         tag  : "",
         cmds : @[]),
        (src  : "https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h",
         dst  : lib_dir,
         tag  : "",
         cmds : @[]),
    ]

    linker_flags = &"-L{lib_dir} -Wl,-rpath,'\\$ORIGIN/{lib_dir}' -lassimp -lispc_texcomp -lz"
    debug_flags = &"--cc:tcc --passL:\"{linker_flags}\" --nimCache:{build_dir} -o:{bin_path} " &
                  &"--passL:\"-ldl -lm\" --tlsEmulation:on -d:useMalloc"
    release_flags = &"--cc:gcc --passL:\"{linker_flags}\" --nimCache:{build_dir} -o:{bin_path} -d:release -d:danger --opt:speed"
    post_release = @[""]

#[ -------------------------------------------------------------------- ]#

proc red    (s: string): string = &"\e[31m{s}\e[0m"
proc green  (s: string): string = &"\e[32m{s}\e[0m"
proc yellow (s: string): string = &"\e[33m{s}\e[0m"
proc blue   (s: string): string = &"\e[34m{s}\e[0m"
proc magenta(s: string): string = &"\e[35m{s}\e[0m"
proc cyan   (s: string): string = &"\e[36m{s}\e[0m"

proc error(s: string)   = echo red    &"Error: {s}"
proc warning(s: string) = echo yellow &"Warning: {s}"

var cmd_count = 0
proc run(cmd: string) =
    if defined `dry-run`:
        echo blue &"[{cmd_count}] ", cmd
        cmd_count += 1
    else:
        exec cmd

func is_git_repo(url: string): bool =
    (gorge_ex &"git ls-remote -q {url}")[1] == 0

#[ -------------------------------------------------------------------- ]#

task restore, "Fetch and build dependencies":
    run &"rm -rf {lib_dir}/*"
    run &"git submodule update --init --remote --merge -j 8"
    for dep in deps:
        if is_git_repo dep.src:
            with_dir dep.dst:
                run &"git checkout {dep.tag}"
        else:
            run &"curl -o {lib_dir / (dep.src.split '/')[^1]} {dep.src}"

        with_dir dep.dst:
            for cmd in dep.cmds:
                run cmd

task build, "Build the project (debug build)":
    run &"nim c {debug_flags} {entry}"

task release, "Build the project (release build)":
    run &"nim c {release_flags} {entry}"
    for cmd in post_release:
        run cmd

task run, "Build and run with debug build":
    build_task()
    run &"./{bin_path}"

task test, "Run the project's tests":
    build_task()
    let files = (list_files tests_dir).filter(proc (path: string): bool =
        not (path.endswith ".nai") and
        not (path.endswith ".dds") and
        not (path.endswith ".png")
    )
    for file in files:
        let fname = file.split('/')[^1]
                        .split('.')[^2]
        run &"{bin_path} --ignore --verbose -o:{tests_dir}/{fname}.nai {file}"

task info, "Print out information about the project":
    echo green &"Nai '{yellow bin_path}'"
    if deps.len > 0:
        echo &"{deps.len} Dependencies:"
    for (i, dep) in enumerate deps:
        let is_git = is_git_repo dep.src
        let tag =
            if is_git and dep.tag != "":
                "@" & dep.tag
            elif is_git: "@HEAD"
            else       : ""
        echo &"    [{i + 1}] {dep.dst:<24}{cyan dep.src}{yellow tag}"

    echo ""
    run "cloc --vcs=git"

