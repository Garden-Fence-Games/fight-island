shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// A translucent blue plane reads as a sheet of plastic. What says "water" is the shoreline: the
// depth fade and the foam band come from comparing the sea floor behind the surface with the
// surface itself, so both follow the coast wherever it goes without anything being authored.

uniform vec3 shallow_colour : source_color = vec3(0.24, 0.58, 0.62);
uniform vec3 deep_colour : source_color = vec3(0.04, 0.16, 0.30);
uniform float depth_fade : hint_range(0.5, 20.0) = 5.5;
uniform vec3 foam_colour : source_color = vec3(0.92, 0.96, 0.97);
uniform float foam_width : hint_range(0.05, 4.0) = 1.1;
uniform float wave_height : hint_range(0.0, 0.6) = 0.10;
uniform float wave_scale : hint_range(0.02, 2.0) = 0.22;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform sampler2D screen_depth : hint_depth_texture, filter_linear_mipmap;

// Two crossing wave trains. Cheaper than a normal map and it needs no texture to author.
float waves(vec2 at, float time) {
	float first = sin(dot(at, vec2(1.0, 0.35)) * wave_scale + time * wave_speed);
	float second = sin(dot(at, vec2(-0.4, 1.0)) * wave_scale * 1.7 - time * wave_speed * 0.8);
	return first * 0.6 + second * 0.4;
}

void vertex() {
	float lift = waves(VERTEX.xz + NODE_POSITION_WORLD.xz, TIME) * wave_height;
	VERTEX.y += lift;
	// Tilt the normal with the slope of the wave so the light catches it.
	float step_size = 1.5;
	float along = waves(VERTEX.xz + vec2(step_size, 0.0), TIME) * wave_height - lift;
	float across = waves(VERTEX.xz + vec2(0.0, step_size), TIME) * wave_height - lift;
	NORMAL = normalize(vec3(-along, step_size, -across));
}

void fragment() {
	// How much water the view passes through before it reaches the sea floor.
	float floor_depth = texture(screen_depth, SCREEN_UV).r;
	vec4 floor_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, floor_depth, 1.0);
	floor_view.xyz /= floor_view.w;
	float thickness = max(0.0, -floor_view.z + VERTEX.z);

	float shallowness = 1.0 - exp(-thickness / depth_fade);
	ALBEDO = mix(shallow_colour, deep_colour, shallowness);
	ALPHA = mix(0.45, 0.96, shallowness);

	// Foam where the water is thin, which is exactly the waterline.
	float foam = 1.0 - smoothstep(0.0, foam_width, thickness);
	foam *= 0.55 + 0.45 * sin(thickness * 6.0 + TIME * 1.6);
	ALBEDO = mix(ALBEDO, foam_colour, clamp(foam, 0.0, 1.0));
	ALPHA = clamp(ALPHA + foam * 0.5, 0.0, 1.0);

	ROUGHNESS = 0.06;
	METALLIC = 0.2;
	SPECULAR = 0.7;
}
