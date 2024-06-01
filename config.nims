import std/[strformat, strutils, sequtils]

const
    Bin = "naic"

    SrcDir   = "./src"
    BuildDir = "./build"
    LibDir   = "./lib"
    TestDir  = "./tests"

    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF " &
                  "-DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF"

func basename(path: string; with_ext = false): string =
    let start = (path.rfind '/') + 1
    let stop  = path.rfind '.'
    if with_ext:
        result = path[start..^1]
    else:
        result = path[start..<stop]

task build, "Build Nai~":
    exec &"nim c --nimCache:{BuildDir} -o:{Bin} {SrcDir}/nai.nim"

task build_libs, "Build libraries":
    # Assimp
    with_dir &"{LibDir}/assimp":
        exec &"cmake -B . -S . {AssimpFlags} -DCMAKE_BUILD_TYPE=release"
        exec &"cmake --build . -j8"
    exec &"cp {LibDir}/assimp/bin/*.so* {LibDir}/"

task restore, "Fetch and build dependencies":
    exec "git submodule update --init --remote --merge --recursive -j 8"
    build_libs_task()

task test, "Run tests":
    build_task()

    let files = (list_files TestDir).filter(proc (path: string): bool = not path.endswith(".nai"))
    for file in files:
        let fname = basename file
        exec &"./{Bin} --ignore --verbose -o:{TestDir}/{fname}.nai {file}"
