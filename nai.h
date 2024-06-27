/* zlib License
 *
 * (C) 2024 carrexxii
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

#ifndef NAI_H
#define NAI_H

#include <stdint.h>

#define NAI_MAGIC "NAI~"

#ifdef __cplusplus
extern "C" {
#endif

/* This enum is used for describing what is included and how it it included in the file.
 * - Each group of flags is exclusive (ie, `VERTICES_INTERLEAVED | VERTICES_SEPARATED` is invalid)
 */
typedef enum NAILayoutFlag {
    NAI_VERTICES_NONE        = 1 << 0, // Exclude the vertices
    NAI_VERTICES_INTERLEAVED = 1 << 1, // [xyz][nnn][uv][xyz][nnn][uv]
    NAI_VERTICES_SEPARATED   = 1 << 2, // [xyz][xyz][nnn][nnn][uv][uv]

    NAI_TEXTURES_NONE     = 1 << 3, // Exclude the textures
    NAI_TEXTURES_INTERNAL = 1 << 4, // Embed the textures in the file
    NAI_TEXTURES_EXTERNAL = 1 << 5, // Write the textures to an external file. Format will be `output-kind.ext`
                                    // For example if the output file is 'model' and you specify diffuse and normals
                                    // textures as DDS, you'll get 'model-diffuse.dds' and 'model-normals.dds'.
} NAILayoutFlag;

typedef enum NAICompressionType {
    NAI_COMPRESSION_NONE,
    NAI_COMPRESSION_ZLIB,
} NAICompressionType;

typedef enum NAIIndexSize {
    NAI_INDEX_SIZE_NONE,
    NAI_INDEX_SIZE_8,
    NAI_INDEX_SIZE_16,
    NAI_INDEX_SIZE_32,
} NAIIndexSize;

typedef enum NAIVertexFlag {
    NAI_VERTEX_POSITION    = 1 << 0,
    NAI_VERTEX_NORMAL      = 1 << 1,
    NAI_VERTEX_TANGENT     = 1 << 2,
    NAI_VERTEX_BITANGENT   = 1 << 3,
    NAI_VERTEX_COLOUR_RGBA = 1 << 4,
    NAI_VERTEX_COLOUR_RGB  = 1 << 5,
    NAI_VERTEX_UV          = 1 << 6,
    NAI_VERTEX_UV3         = 1 << 7,
} NAIVertexFlag;

typedef enum NAITextureType {
    NAI_TEXTURE_NONE,
    NAI_TEXTURE_DIFFUSE,
    NAI_TEXTURE_SPECULAR,
    NAI_TEXTURE_AMBIENT,
    NAI_TEXTURE_EMISSIVE,
    NAI_TEXTURE_HEIGHT,
    NAI_TEXTURE_NORMALS,
    NAI_TEXTURE_SHININESS,
    NAI_TEXTURE_OPACITY,
    NAI_TEXTURE_DISPLACEMENT,
    NAI_TEXTURE_LIGHTMAP,
    NAI_TEXTURE_REFLECTION,
    NAI_TEXTURE_EMISSION_COLOUR,
    NAI_TEXTURE_METALNESS,
    NAI_TEXTURE_DIFFUSE_ROUGHNESS,
    NAI_TEXTURE_SHEEN,
    NAI_TEXTURE_CLEARCOAT,
    NAI_TEXTURE_TRANSMISSION,
} NAITextureType;

typedef enum NAITextureFormat {
    NAI_TEXTURE_FORMAT_NONE,

    NAI_TEXTURE_FORMAT_R,
    NAI_TEXTURE_FORMAT_RG,
    NAI_TEXTURE_FORMAT_RGB,
    NAI_TEXTURE_FORMAT_RGBA,

    NAI_TEXTURE_FORMAT_BC1 = 100,
    NAI_TEXTURE_FORMAT_BC3,
    NAI_TEXTURE_FORMAT_BC4,
    NAI_TEXTURE_FORMAT_BC5,
    NAI_TEXTURE_FORMAT_BC6H,
    NAI_TEXTURE_FORMAT_BC7,

    NAI_TEXTURE_FORMAT_ETC1 = 200,

    NAI_TEXTURE_FORMAT_ASTC4x4 = 300,
} NAITextureFormat;

typedef struct NAIHeader {
    uint8_t            magic[4];
    uint8_t            version[2];
    NAICompressionType compression: 16;
    NAILayoutFlag      layout_mask;
    uint8_t            vertex_mask[8]; // Of NAIVertexFlag
    uint16_t           mesh_count;
    uint16_t           material_count;
    uint16_t           texture_count;
    uint16_t           animation_count;
    uint16_t           skeleton_count;
} NAIHeader;

/* Indices follow vertices such that `inds = verts + vert_count` */
typedef struct NAIMeshHeader {
    uint16_t     material_index;
    NAIIndexSize index_size: 16;
    uint32_t     vert_count;
    uint32_t     index_count;
    float        verts[];
} NAIMeshHeader;

typedef struct NAIMaterialHeader {
    float   base_colour[4];
    float   metallic_factor;
    float   roughness_factor;
    uint8_t texture_count;
    uint8_t texture_inds[];
} NAIMaterial;

typedef struct NAITextureHeader {
    NAITextureType   type;
    NAITextureFormat format;
    uint16_t         w;
    uint16_t         h;
    uint8_t          data[];
} NAITexture;

#ifdef __cplusplus
} // extern "C"
#endif

static_assert(sizeof(NAIHeader)         == 32);
static_assert(sizeof(NAIMeshHeader)     == 12);
static_assert(sizeof(NAIMaterialHeader) == 28);
static_assert(sizeof(NAITextureHeader)  == 12);

#endif
