shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, diffuse_lambert, specular_schlick_ggx;

group_uniforms Normals;
uniform sampler2D texture_normal: hint_normal;
uniform vec2 first_normal_speed = vec2(-0.01, 0.03);
uniform vec2 second_normal_speed = vec2(0.025, -0.02);
uniform float first_normal_strength : hint_range(-2.0, 2.0, 0.1)= 0.3;
uniform float second_normal_strength : hint_range(-2.0, 2.0, 0.1) = 0.4;

group_uniforms Colors;
uniform vec3 deep_color: source_color = vec3(0.02, 0.15, 0.3);
uniform vec3 shallow_color: source_color = vec3(0.2, 0.5, 0.6);

group_uniforms Foam;
uniform float foam_distance: hint_range(0.0, 2.0, 0.01) = 0.03;
uniform float foam_cutoff: hint_range(0.0, 1.0, 0.01) = 0.6;
uniform vec3 foam_color: source_color = vec3(1.0, 1.0, 1.0);

group_uniforms Misc;
uniform float refraction_strength: hint_range(0.0, 0.1, 0.01) = 0.075;
uniform float roughness: hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float metallic: hint_range(0.0, 1.0, 0.1) = 0.2;
uniform float specular: hint_range(0.0, 1.0, 0.1) = 0.3;
uniform float depth_distance: hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float beers_law: hint_range(1.0, 32.0, 0.1) = 16.0;

uniform sampler2D texture_screen: hint_screen_texture;
uniform sampler2D texture_depth: hint_depth_texture;

varying vec3 vertex_world_pos;

float fresnel_schlick(float cosTheta, float F0) {
    float m = clamp(1.0 - cosTheta, 0.0, 1.0);
    float m2 = m*m; float m5 = m2*m2*m;
    return F0 + (1.0 - F0) * m5;
}

vec3 blend_normals_rnm(vec3 base, vec3 detail) {
    base   = normalize(base);
    detail = normalize(detail);
    vec3 t = base + vec3(0.0, 0.0, 1.0);
    vec3 u = detail * vec3(-1.0, -1.0, 1.0);
    return normalize(t * dot(t, u) - u * t.z);
}

void vertex() {
	vertex_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 first_uv = (vertex_world_pos.xz * 0.2) + (TIME * first_normal_speed);
    vec2 second_uv = (vertex_world_pos.xz * 0.6) + (TIME * second_normal_speed);
    vec3 first_normal = texture(texture_normal, first_uv).rgb * 2.0 - 1.0;
    vec3 second_normal = texture(texture_normal, second_uv).rgb * 2.0 - 1.0;
    first_normal.xy *= first_normal_strength;
    first_normal = normalize(first_normal);
    second_normal.xy *= second_normal_strength;
    second_normal = normalize(second_normal);

	vec3 blended_normal = blend_normals_rnm(first_normal, second_normal) * 0.5 + 0.5;

    vec2 refraction_offset = (blended_normal.xy - 0.5) * refraction_strength;
	vec2 refracted_uv = SCREEN_UV + refraction_offset;
    refracted_uv = clamp(refracted_uv, 0.0, 1.0);

    float depth = texture(texture_depth, refracted_uv).r;
    vec3 ndc = vec3(refracted_uv * 2.0 - 1.0, depth);
    vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float depth_y = world.y / world.w;

    vec2 final_uv = refracted_uv;

    if (depth_y >= vertex_world_pos.y) {
        final_uv = SCREEN_UV;
        depth = texture(texture_depth, SCREEN_UV).r;
        ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
        world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
        depth_y = world.y / world.w;
    }

    float depth_blend = clamp((vertex_world_pos.y - depth_y) / depth_distance, 0.0, 1.0);
    depth_blend = exp(-depth_blend * beers_law);

    vec3 screen_color = texture(texture_screen, final_uv).rgb;
    vec3 water_color = mix(deep_color, shallow_color, depth_blend);

	float cosTheta = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
    float fresnel = fresnel_schlick(cosTheta, 0.02);

	float foam_depth = clamp((vertex_world_pos.y - depth_y) / foam_distance, 0.0, 1.0);
	float foam = 1.0 - smoothstep(foam_cutoff, 1.0, foam_depth);

    ALBEDO = mix(water_color, screen_color, depth_blend) + fresnel * 0.25;
	ALBEDO = mix(ALBEDO, foam_color, foam);
    ALPHA = clamp(1.0 - depth_blend, 0.0, 1.0);
    NORMAL_MAP = blended_normal;
    ROUGHNESS = clamp(roughness * (1.0 - fresnel), 0.0, 1.0);
	SPECULAR = specular;
	METALLIC = metallic;
}