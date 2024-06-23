import std/[os, strformat, strutils, sequtils, enumerate]

const
    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF -DUSE_STATIC_CRT=ON -DBUILD_SHARED_LIBS=OFF " &
                  "-DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF -DASSIMP_BUILD_ZLIB=ON " &
                  "-DASSIMP_WARNINGS_AS_ERRORS=OFF"
    CompressonatorFlags = "-DOPTION_ENABLE_ALL_APPS=OFF -DOPTION_BUILD_CMP_SDK=ON -DOPTION_BUILD_EXR=OFF"

let
    target = "cpp"
    cwd    = get_current_dir()

    bin_path   = &"./{(to_exe cwd.split('/')[^1])}"
    src_path   = "./src"
    lib_path   = "./lib"
    tools_path = "./tools"
    build_path = "./build"
    tests_path = "./tests"
    deps: seq[tuple[src, dst, tag, patch: string; cmds: seq[string]]] = @[
        (src  : "https://github.com/assimp/assimp",
         dst  : lib_path / "assimp",
         tag  : "v5.4.1",
         patch: "",
         cmds : @[&"cmake -B . -S . {AssimpFlags}",
                  &"cmake --build . --config release -j8",
                  &"cp lib/*.a ../",
                  &"cp contrib/zlib/*.a ../",]),
        (src  : "https://github.com/GPUOpen-Tools/compressonator",
         dst  : lib_path / "compressonator",
         tag  : "V4.5.52",
         patch: "compressonator.patch",
         cmds : @[&"cmake -B . -S . {CompressonatorFlags}",
                  &"cmake --build . --config release -j8",
                  &"cp lib/*.a ../",])
    ]
    entry =
        if file_exists &"{src_path}/main.nim":
            src_path / "main.nim"
        else:
            src_path / &"{cwd.split('/')[^1]}.nim"
    linker_libs = @[
        "libassimp.a",
        "libzlibstatic.a",
        "libispc_texcomp.so",
    ]

    debug_flags   = &"--nimCache:{build_path} -o:{bin_path}"
    release_flags = &"--cc:gcc --nimCache:{build_path} -o:{bin_path} -d:release -d:danger"
    post_release = @[""]

#[ -------------------------------------------------------------------- ]#

--hints:off

proc red    (s: string): string = "\e[31m" & s & "\e[0m"
proc green  (s: string): string = "\e[32m" & s & "\e[0m"
proc yellow (s: string): string = "\e[33m" & s & "\e[0m"
proc blue   (s: string): string = "\e[34m" & s & "\e[0m"
proc magenta(s: string): string = "\e[35m" & s & "\e[0m"
proc cyan   (s: string): string = "\e[36m" & s & "\e[0m"

proc error(s: string)   = echo red    ("Error: "   & s)
proc warning(s: string) = echo yellow ("Warning: " & s)

var cmd_count = 0
proc run(cmd: string) =
    if defined `dry-run`:
        echo blue &"[{cmd_count}] ", cmd
        cmd_count += 1
    else:
        exec cmd

func is_git_repo(url: string): bool =
    (gorge_ex &"git ls-remote -q {url}")[1] == 0

import std/algorithm
proc get_libs(): string =
    var libs: seq[string] = linker_libs
    if libs == @[]:
        for file in list_files lib_path:
            if (file.ends_with ".so") or (file.ends_with ".a"):
                libs.add file
    else:
        libs = linker_libs.map_it(lib_path / it)

    result = libs.join " "

#[ -------------------------------------------------------------------- ]#

task restore, "Fetch and build dependencies":
    run &"git submodule update --init --remote --merge --recursive -j 8"
    for dep in deps:
        if is_git_repo dep.src:
            if not (dir_exists dep.dst):
                run &"git submodule add {dep.src} {dep.dst}"
            with_dir dep.dst:
                run &"git checkout {dep.tag}"
                if dep.patch != "":
                    run &"git apply --check --reverse {cwd / dep.patch}"

        with_dir dep.dst:
            for cmd in dep.cmds:
                run cmd

task build, "Build the project (debug build)":
    run &"nim {target} --passL:\"{get_libs()}\" {debug_flags} {entry}"

task release, "Build the project (release build)":
    run &"nim {target} --passL:\"{get_libs()}\" {release_flags} {entry}"
    for cmd in post_release:
        run cmd

task run, "Build and run with debug build":
    build_task()
    run &"./{bin_path}"

task test, "Run the project's tests":
    build_task()

    let files = (list_files tests_path).filter(proc (path: string): bool =
        not (path.endswith ".nai") and
        not (path.endswith ".dds") and
        not (path.endswith ".png")
    )
    for file in files:
        let fname = file.split('/')[^1]
                        .split('.')[^2]
        exec &"{bin_path} --ignore --verbose -o:{tests_path}/{fname}.nai {file}"

task info, "Print out information about the project":
    echo green &"Bou Project '{yellow bin_path}'"
    echo &"    Source dir : {yellow src_path}"
    echo &"    Library dir: {yellow lib_path}"
    echo &"    Tools dir  : {yellow tools_path}"
    echo &"    Tests dir  : {yellow tests_path}"
    if deps.len > 0:
        echo &"    {deps.len} Dependencies:"
    for (i, dep) in enumerate deps:
        echo &"        [{i + 1}] {cyan dep.src} ({yellow dep.tag})"
