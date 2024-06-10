import std/[os, strformat, strutils, sequtils]

const
    Bin = to_exe "naic"

    SrcDir  = "./src"
    LibDir  = "./lib"
    TestDir = "./tests"

    LinkerFlags = &"\"{LibDir}/libassimp.a {LibDir}/libzlibstatic.a\""
    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF -DUSE_STATIC_CRT=ON -DBUILD_SHARED_LIBS=OFF " &
                  "-DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF -DASSIMP_BUILD_ZLIB=ON " &
                  "-DASSIMP_WARNINGS_AS_ERRORS=OFF"

    AssimpTag = "v5.4.1"
    STBPaths = ["https://raw.githubusercontent.com/nothings/stb/master/stb_image.h",
                "https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h"]

--nimCache:"./build"

func basename(path: string; with_ext = false): string =
    let start = (path.rfind '/') + 1
    let stop  = path.rfind '.'
    if with_ext:
        result = path[start..^1]
    else:
        result = path[start..<stop]

task build, "Build Nai~":
    self_exec &"cpp --passL:{LinkerFlags} -o:{Bin} {SrcDir}/nai.nim"

task build_libs, "Build libraries":
    # Assimp
    with_dir &"{LibDir}/assimp":
        exec &"git checkout {AssimpTag}"
        exec &"cmake -B . -S . {AssimpFlags}"
        exec &"cmake --build . --config release -j8"
    exec &"cp {LibDir}/assimp/lib/*.a {LibDir}/"
    exec &"cp {LibDir}/assimp/contrib/zlib/*.a {LibDir}/"

task restore, "Fetch and build dependencies":
    exec "git submodule update --init --remote --merge --recursive -j 8"
    for link in STBPaths:
        let path = LibDir / link.basename(with_ext = true)
        if not (file_exists path):
            exec &"curl -o {path} {link}"
    build_libs_task()

task test, "Run tests":
    build_task()

    let files = (list_files TestDir).filter(proc (path: string): bool =
        not (path.endswith ".nai") and
        not (path.endswith ".png")
    )
    for file in files:
        let fname = basename file
        exec &"./{Bin} --ignore --verbose -o:{TestDir}/{fname}.nai {file}"
