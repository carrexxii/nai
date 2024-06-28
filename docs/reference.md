# Material Options

All `r`, `g`, `b` and `a` values can be either normalized `0.0` to `1.0` values, or
integer values of `0` to `255`. The first (`r`) value is checked for a decimal place
to determine which interpretation to use.

| Material Value            | Valid Values              |
| ------------------------- | ------------------------- |
| DoubleSided               | `true` or `false`         |
| BaseColour                | `[r, g, b, a]`            |
| MetallicFactor            | `[0.0, 1.0]`              |
| RoughnessFactor           | `[0.0, 1.0]`              |
| SpecularFactor            | `[0.0, 1.0]`              |
| GlossinessFactor          | `[0.0, 1.0]`              |
| AnisotropyFactor          | `[0.0, 1.0]`              |
| SheenColourFactor         | `[0.0, 1.0]`              |
| SheenRoughnessFactor      | `[0.0, 1.0]`              |
| ClearcoatFactor           | `[0.0, 1.0]`              |
| ClearcoatRoughnessFactor  | `[0.0, 1.0]`              |
| Opacity                   | `[0.0, 1.0]`              |
| BumpScaling               | any float                 |
| Shininess                 |                           |
| Reflectivity              |                           |
| RefractiveIndex           |                           |
| ColourDiffuse             |                           |
| ColourAmbient             |                           |
| ColourSpecular            |                           |
| ColourEmissive            |                           |
| ColourTransparent         |                           |
| ColourReflective          |                           |
| TransmissionFactor        |                           |
| VolumeThicknessFactor     |                           |
| VolumeAttenuationDistance |                           |
| VolumeAttenuationColour   |                           |
| EmissiveIntensity         |                           |

<table>
    <th colspan = 5> Valid Texture Maps </th>
    <tr>
        <td> Diffuse </td>
        <td> Specular </td>
        <td> Ambient </td>
        <td> Emissive </td>
        <td> Height </td>
    </tr>
    <tr>
        <td> Normals </td>
        <td> Shininess </td>
        <td> Opacity </td>
        <td> Displacement </td>
        <td> Lightmap </td>
    </tr>
    <tr>
        <td> Reflection </td>
        <td> EmissionColour </td>
        <td> Metalness </td>
        <td> DiffuseRoughness </td>
        <td> Sheen </td>
    </tr>
    <tr>
        <td> Clearcoat </td>
        <td> Transmission </td>
    </tr>
</table>
