/* zlib License
 *
 * (C) 2024 carrexxii
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
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
#define NAI_VERSION_MAJOR 0
#define NAI_VERSION_MINOR 0

#ifdef __cplusplus
extern "C" {
#endif

/* This enum is used for describing what is included and how it it included in the file.
 * - Each group of flags is exclusive (ie, `VERTICES_INTERLEAVED | VERTICES_SEPARATED` is invalid)
 */
typedef enum NaiLayoutFlag {
    NAI_VERTICES_INTERLEAVED = 1 << 0, // [xyz][nnn][uv][xyz][nnn][uv]
    NAI_VERTICES_SEPARATED   = 1 << 1, // [xyz][xyz][nnn][nnn][uv][uv]

    NAI_TEXTURES_INTERNAL = 1 << 2, // Embed the textures in the file
    NAI_TEXTURES_EXTERNAL = 1 << 3, // Write the textures to an external file. Format will be `output-kind.ext`
                                    // For example if the output file is 'model' and you specify diffuse and normals
                                    // textures as DDS, you'll get 'model-diffuse.dds' and 'model-normals.dds'.
} NaiLayoutFlag;

typedef enum NaiCompressionType {
    NAI_COMPRESSION_NONE,
    NAI_COMPRESSION_ZLIB,
} NaiCompressionType;

typedef enum NaiContainerType {
    NAI_CONTAINER_NONE,
    NAI_CONTAINER_DDS,
    NAI_CONTAINER_PNG,
} NaiContainerType;

typedef enum NaiIndexSize {
    NAI_INDEX_SIZE_NONE,
    NAI_INDEX_SIZE_8,
    NAI_INDEX_SIZE_16,
    NAI_INDEX_SIZE_32,
    NAI_INDEX_SIZE_64,
} NaiIndexSize;

typedef enum NaiVertexType {
    NAI_VERTEX_None,
    NAI_VERTEX_POSITION,
    NAI_VERTEX_NORMAL,
    NAI_VERTEX_TANGENT,
    NAI_VERTEX_BITANGENT,
    NAI_VERTEX_COLOUR_RGBA,
    NAI_VERTEX_COLOUR_RGB,
    NAI_VERTEX_UV,
    NAI_VERTEX_UV3,
} NaiVertexType;

typedef enum NaiTextureType {
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
    NAI_TEXTURE_BASE_COLOUR,
    NAI_TEXTURE_NORMAL_CAMERA,
    NAI_TEXTURE_EMISSION_COLOUR,
    NAI_TEXTURE_METALNESS,
    NAI_TEXTURE_DIFFUSE_ROUGHNESS,
    NAI_TEXTURE_AMBIENT_OCCLUSION,
    NAI_TEXTURE_UNKNOWN,
    NAI_TEXTURE_SHEEN,
    NAI_TEXTURE_CLEARCOAT,
    NAI_TEXTURE_TRANSMISSION,
} NaiTextureType;

typedef enum NaiTextureFormat {
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
} NaiTextureFormat;

typedef enum NaiMaterialValueType {
    NAI_MATERIAL_NONE,
    NAI_MATERIAL_NAME,
    NAI_MATERIAL_TWO_SIDED,
    NAI_MATERIAL_BASE_COLOUR,
    NAI_MATERIAL_METALLIC_FACTOR,
    NAI_MATERIAL_ROUGHNESS_FACTOR,
    NAI_MATERIAL_SPECULAR_FACTOR,
    NAI_MATERIAL_GLOSSINESS_FACTOR,
    NAI_MATERIAL_ANISOTROPY_FACTOR,
    NAI_MATERIAL_SHEEN_COLOUR_FACTOR,
    NAI_MATERIAL_SHEEN_ROUGHNESS_FACTOR,
    NAI_MATERIAL_CLEARCOAT_FACTOR,
    NAI_MATERIAL_CLEARCOAT_ROUGHNESS_FACTOR,
    NAI_MATERIAL_OPACITY,
    NAI_MATERIAL_BUMP_SCALING,
    NAI_MATERIAL_SHININESS,
    NAI_MATERIAL_REFLECTIVITY,
    NAI_MATERIAL_REFRACTIVE_INDEX,
    NAI_MATERIAL_COLOUR_DIFFUSE,
    NAI_MATERIAL_COLOUR_AMBIENT,
    NAI_MATERIAL_COLOUR_SPECULAR,
    NAI_MATERIAL_COLOUR_EMISSIVE,
    NAI_MATERIAL_COLOUR_TRANSPARENT,
    NAI_MATERIAL_COLOUR_REFLECTIVE,
    NAI_MATERIAL_TRANSMISSION_FACTOR,
    NAI_MATERIAL_VOLUME_THICKNESS_FACTOR,
    NAI_MATERIAL_VOLUME_ATTENUATION_DISTANCE,
    NAI_MATERIAL_VOLUME_ATTENUATION_COLOUR,
    NAI_MATERIAL_EMISSIVE_INTENSITY,
} NaiMaterialValueType;

/* -------------------------------------------------------------------- */

typedef struct NaiHeader {
    uint8_t  magic[4];
    uint8_t  version[2];
    uint16_t layout_mask;        // NaiLayoutFlag
    uint8_t  vertex_types[8];    // NaiVertexType
    uint8_t  material_values[8]; // NaiMaterialValue
    uint16_t compression;        // NaiCompressionType
    uint16_t mesh_count;
    uint16_t material_count;
    uint16_t texture_count;
    uint16_t animation_count;
    uint16_t skeleton_count;
} NaiHeader;

/* Indices follow vertices such that `inds = verts + vert_count` */
typedef struct NaiMeshHeader {
    uint16_t material_index;
    uint16_t index_size;     // NaiIndexSize
    uint32_t vert_count;
    uint32_t index_count;
    float    verts[];
} NaiMeshHeader;

typedef struct NaiMaterialHeader {
    uint16_t texture_count;
    uint16_t _;
    // Material data here depending on `header.material_values`
    // NaiTextureHeader textures[];
} NaiMaterial;

typedef struct NaiTextureHeader {
    uint16_t type;   // NAITextureType
    uint16_t format; // NAITextureFormat
    uint16_t w, h;
    uint8_t  data[/* <format_size> * w * h */];
} NaiTexture;

#ifdef __cplusplus
} // extern "C"
#endif

static_assert(sizeof(NaiHeader)         == 36);
static_assert(sizeof(NaiMeshHeader)     == 12);
static_assert(sizeof(NaiMaterialHeader) == 4);
static_assert(sizeof(NaiTextureHeader)  == 8);

#endif

