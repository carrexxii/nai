import std/[strformat, strutils, sequtils]

const
    Bin = "naic"

    SrcDir   = "./src"
    BuildDir = "./build"
    LibDir   = "./lib"
    TestDir  = "./tests"

    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_NO_EXPORT=ON -DASSIMP_BUILD_TESTS=OFF " &
                  "-DASSIMP_INSTALL_PDB=OFF -DBUILD_SHARED_LIBS=OFF"

func basename(path: string; with_ext = false): string =
    let start = (path.rfind '/') + 1
    let stop  = path.rfind '.'
    if with_ext:
        result = path[start..^1]
    else:
        result = path[start..<stop]

task build, "Build Nai~":
    exec &"nim c --nimCache:{BuildDir} -o:{Bin} {SrcDir}/main.nim"

task build_libs, "Build libraries":
    # Assimp
    with_dir &"{LibDir}/assimp":
        exec &"cmake -B . -S . {AssimpFlags}"
        exec &"cmake --build . -j"
    exec &"cp {LibDir}/assimp/build/bin/*.so* {LibDir}/"

task restore, "Fetch and build dependencies":
    exec "git submodule update --init --remote --merge --recursive -j 8"
    build_libs_task()

task test, "Run tests":
    build_task()

    let files = (list_files TestDir).filter(proc (path: string): bool = not path.endswith(".nai"))
    for file in files:
        let fname = basename file
        exec &"./{Bin} --ignore --verbose -o:{TestDir}/{fname}.nai {file}"
