shader_type spatial;
// The island's ground, which remembers where blood fell.
//
// Everything the terrain's own material did, and one thing more. The colour is still the vertex
// colour the generator bakes — sand, grass and the mix between — and roughness is still the sand's.
// On top, a mask the size of the island says how soaked each spot is, and the ground goes that far
// towards red and that much wetter.
//
// Sampled by world position rather than by UV, so the mask belongs to the island and not to the
// mesh: a terrain rebuilt with a different grid keeps every stain where it fell.

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Alpha is coverage: nought is dry ground, one is soaked through.
uniform sampler2D blood_mask : filter_linear, repeat_disable, hint_default_transparent;
uniform vec4 blood_colour : source_color = vec4(0.78, 0.02, 0.04, 1.0);
// The world XZ of the mask's corner, and the metres its side covers.
uniform vec2 mask_origin = vec2(-90.0, -90.0);
uniform float mask_extent = 180.0;
uniform float dry_roughness : hint_range(0.0, 1.0) = 0.95;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.45;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_position.xz - mask_origin) / mask_extent;
	float soaked = texture(blood_mask, uv).a;
	ALBEDO = mix(COLOR.rgb, blood_colour.rgb, soaked);
	ROUGHNESS = mix(dry_roughness, wet_roughness, soaked);
}
