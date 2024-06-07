import std/[strformat, strutils, sequtils]

const
    Bin = to_exe "naic"

    SrcDir  = "./src"
    LibDir  = "./lib"
    TestDir = "./tests"

    LinkerFlags = &"\"{LibDir}/libassimp.a {LibDir}/libzlibstatic.a\""
    AssimpFlags = "-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF -DUSE_STATIC_CRT=ON -DBUILD_SHARED_LIBS=OFF " &
                  "-DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF -DASSIMP_BUILD_ZLIB=ON"

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
        exec &"cmake -B . -S . {AssimpFlags}"
        exec &"cmake --build . --config release -j8"
    exec &"cp {LibDir}/assimp/lib/*.a {LibDir}/"

task restore, "Fetch and build dependencies":
    exec "git submodule update --init --remote --merge --recursive -j 8"
    build_libs_task()

task test, "Run tests":
    build_task()

    let files = (list_files TestDir).filter(proc (path: string): bool = not path.endswith(".nai"))
    for file in files:
        let fname = basename file
        exec &"./{Bin} --ignore --verbose -o:{TestDir}/{fname}.nai {file}"
