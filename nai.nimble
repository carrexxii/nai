version     = "0.0.1"
author      = "carrexxii"
description = "Nim asset importer for game development"
license     = "AGPLv3"
bin         = @["src/main"]

import std/strformat

const
    AssimpTag = "v5.4.1"
    IspctcTag = "691513b4fb406eccfc2f7d7f8213c8505ff5b897"
    ZLibTag   = "v1.3.1"
    StbTag    = "5c205738c191bcb0abc65c4febfa9bd25ff35234"

    AssimpFlags = """-DASSIMP_INSTALL=OFF -DASSIMP_BUILD_TESTS=OFF -DASSIMP_WARNINGS_AS_ERRORS=OFF
                     -DASSIMP_BUILD_ALL_EXPORTERS_BY_DEFAULT=OFF -DASSIMP_INSTALL_PDB=OFF -DASSIMP_BUILD_ZLIB=OFF"""

task restore, "Fetch and build libraries":
    exec &"git submodule update --init --remote --merge --recursive -j 8"

    with_dir "lib/assimp":
        exec &"git checkout {AssimpTag}"
        exec &"""cmake -S . -B ./build {AssimpFlags};
                 cmake --build ./build --config release -j8;
                 mv ./build/bin/libassimp.so* ../"""

    with_dir "lib/ispctc":
        exec &"git checkout {IspctcTag}"
        exec &"""git apply ../../ispctc.patch;
                 make -f Makefile.linux -j8;
                 mv build/* ../"""

    with_dir "lib/zlib":
        exec &"git checkout {ZLibTag}"
        exec &"""./configure;
                 make;
                 mv libz.so* ../"""

    with_dir "lib/stb":
        exec &"git checkout {StbTag}"
        exec &"mv stb_image.h ../"
        exec &"mv stb_image_write.h ../"

after build:
    exec "mv ./src/main ./nai"
