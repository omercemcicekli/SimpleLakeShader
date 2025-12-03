shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_lambert, specular_schlick_ggx;

group_uniforms Normals;
uniform sampler2D texture_normal: hint_normal;
uniform vec2 first_normal_speed = vec2(-0.01, 0.03);
uniform vec2 second_normal_speed = vec2(0.025, -0.02);
uniform float first_normal_strength : hint_range(-2.0, 2.0, 0.1)= 0.3;
uniform float second_normal_strength : hint_range(-2.0, 2.0, 0.1) = 0.4;

group_uniforms Colors;
uniform vec3 deep_color: source_color = vec3(0.02, 0.15, 0.3);
uniform vec3 shallow_color: source_color = vec3(0.2, 0.5, 0.6);

group_uniforms Misc;
uniform float refraction_strength: hint_range(0.0, 0.1, 0.01) = 0.05;
uniform float roughness: hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float metallic: hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float specular: hint_range(0.0, 1.0, 0.1) = 0.3;
uniform float depth_distance: hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float beers_law: hint_range(1.0, 32.0, 0.1) = 24.0;
uniform float fresnel_strength: hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float edge_fade: hint_range(0.0, 0.2, 0.01) = 0.01;

uniform sampler2D texture_screen: hint_screen_texture, filter_linear_mipmap;
uniform sampler2D texture_depth: hint_depth_texture, filter_linear_mipmap;

varying vec3 vertex_world_pos;
varying vec2 first_uv;
varying vec2 second_uv;

float fresnel_schlick(float cosTheta, float F0) {
    float m = clamp(1.0 - cosTheta, 0.0, 1.0);
    float m2 = m * m;
    float m5 = m2 * m2 * m;
    return F0 + (1.0 - F0) * m5;
}

// OPTIMIZATION: Cheaper normal blending method (UDN / Whiteout)
// Visually similar to RNM but much faster
vec3 blend_normals(vec3 n1, vec3 n2) {
    return normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
}

void vertex() {
    vertex_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    first_uv = (vertex_world_pos.xz * 0.2) + (TIME * first_normal_speed);
    second_uv = (vertex_world_pos.xz * 0.6) + (TIME * second_normal_speed);
}

void fragment() {
    // 1. Normals
    vec3 first_normal = texture(texture_normal, first_uv).rgb * 2.0 - 1.0;
    vec3 second_normal = texture(texture_normal, second_uv).rgb * 2.0 - 1.0;

    first_normal.xy *= first_normal_strength;
    second_normal.xy *= second_normal_strength;

    // Use optimized blend
    vec3 blended_normal = blend_normals(first_normal, second_normal);

    // 2. Refraction Offset
    vec2 refraction_offset = blended_normal.xy * refraction_strength;

    // Edge fade calculation
    vec2 edge_factor = smoothstep(0.0, edge_fade, SCREEN_UV) * smoothstep(0.0, edge_fade, vec2(1.0) - SCREEN_UV);
    refraction_offset *= (edge_factor.x * edge_factor.y);

    // 3. Clamped UVs
    vec2 refracted_uv = SCREEN_UV + refraction_offset;
    // Keep this clamp to prevent green edge artifacts
    refracted_uv = clamp(refracted_uv, vec2(0.001), vec2(0.999));

    // 4. Depth Reconstruction
    float depth = texture(texture_depth, refracted_uv).r;
    vec3 ndc = vec3(refracted_uv * 2.0 - 1.0, depth);
    vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float depth_y = world.y / world.w;

    vec2 final_uv = refracted_uv;

    // FIX: Add small offset (+0.05) to prevent Z-fighting noise on surface
    float water_depth = vertex_world_pos.y - depth_y;

    // 5. Refraction Fallback Check
    // If the refracted ray hits something ABOVE the water (water_depth < 0),
    // or hits the sky, revert to standard screen UV.
    if (water_depth < 0.0 || depth >= 0.999) {
        final_uv = SCREEN_UV;
        depth = texture(texture_depth, SCREEN_UV).r;

        if (depth < 0.999) {
            ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
            world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
            depth_y = world.y / world.w;
            water_depth = vertex_world_pos.y - depth_y;
        } else {
            water_depth = depth_distance;
        }
    }

    water_depth = max(water_depth, 0.0);
    float depth_blend = clamp(water_depth / depth_distance, 0.0, 1.0);
    depth_blend = exp2(-depth_blend * beers_law);

    vec3 screen_color = texture(texture_screen, final_uv).rgb;
    vec3 water_color = mix(deep_color, shallow_color, depth_blend);

    // Fresnel
    vec3 view_normal = normalize(mat3(TANGENT, BINORMAL, NORMAL) * blended_normal);
    float cosTheta = max(dot(view_normal, VIEW), 0.0);
    float fresnel = fresnel_schlick(cosTheta, 0.02);

    vec3 final_color = mix(water_color, screen_color, depth_blend);
    final_color = final_color + (fresnel * fresnel_strength);

    ALBEDO = final_color;
    ALPHA = clamp(1.0 - depth_blend, 0.0, 1.0);
    NORMAL_MAP = blended_normal * 0.5 + 0.5;
    ROUGHNESS = roughness;
    SPECULAR = specular;
    METALLIC = metallic;
}