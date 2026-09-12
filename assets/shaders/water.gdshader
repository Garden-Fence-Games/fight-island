shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

// A translucent blue plane reads as a sheet of plastic. Four things separate water from glass, and
// all four are here: the sea floor bends as it is seen through the surface, the deep closes over it
// entirely, the surface is a mirror at a grazing angle and clear from above, and the light breaks
// into sparks on ripples far finer than the mesh could carry.
//
// The shoreline still comes out of the depth buffer — the foam band and the shallow tint follow the
// coast wherever it goes, and nothing about either is authored.

uniform vec3 shallow_colour : source_color = vec3(0.21, 0.60, 0.63);
uniform vec3 deep_colour : source_color = vec3(0.02, 0.11, 0.24);
uniform vec3 horizon_colour : source_color = vec3(0.62, 0.78, 0.92);
// Metres of water after which the floor's colour has gone.
uniform float depth_fade : hint_range(0.5, 20.0) = 3.6;
// Metres of water after which the floor itself has gone. Shorter than a real sea because the island
// shelf is shallow: past this the water has to be a surface, not a window.
uniform float clarity_depth : hint_range(0.2, 12.0) = 2.4;
uniform vec3 foam_colour : source_color = vec3(0.92, 0.96, 0.97);
uniform float foam_width : hint_range(0.05, 4.0) = 1.1;

uniform float wave_height : hint_range(0.0, 0.6) = 0.11;
uniform float wave_scale : hint_range(0.02, 2.0) = 0.22;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
// The fine skin between the swells. It never reaches the vertex stage — see surface_normal below.
uniform float ripple_height : hint_range(0.0, 0.2) = 0.018;
uniform float ripple_scale : hint_range(0.1, 6.0) = 1.5;
uniform float ripple_speed : hint_range(0.0, 6.0) = 1.9;

uniform float refraction : hint_range(0.0, 0.2) = 0.045;
uniform float fresnel_power : hint_range(1.0, 8.0) = 4.5;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.75;

uniform sampler2D screen_colour : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D screen_depth : hint_depth_texture, filter_linear_mipmap;

// Two crossing wave trains. Cheaper than a normal map and it needs no texture to author.
float swell(vec2 at, float time) {
	float first = sin(dot(at, vec2(1.0, 0.35)) * wave_scale + time * wave_speed);
	float second = sin(dot(at, vec2(-0.4, 1.0)) * wave_scale * 1.7 - time * wave_speed * 0.8);
	return first * 0.6 + second * 0.4;
}

float ripple(vec2 at, float time) {
	float first = sin(dot(at, vec2(0.91, 0.42)) * ripple_scale + time * ripple_speed);
	float second = sin(dot(at, vec2(-0.52, 0.85)) * ripple_scale * 1.9 - time * ripple_speed * 1.4);
	float third = sin(dot(at, vec2(0.18, -0.98)) * ripple_scale * 3.7 + time * ripple_speed * 2.1);
	return first * 0.5 + second * 0.32 + third * 0.18;
}

float surface_height(vec2 at, float time) {
	return swell(at, time) * wave_height + ripple(at, time) * ripple_height;
}

// Built per pixel rather than per vertex. The plane carries a vertex every nine metres, which is
// coarse enough that a per-vertex normal facets the whole sea and loses every ripple between two of
// them — and the ripples are where the sparkle comes from.
vec3 surface_normal(vec2 at, float time) {
	float step_size = 0.3;
	float here = surface_height(at, time);
	float along = surface_height(at + vec2(step_size, 0.0), time) - here;
	float across = surface_height(at + vec2(0.0, step_size), time) - here;
	return normalize(vec3(-along, step_size, -across));
}

// How far in front of the camera whatever was drawn at this pixel sits, in metres.
float distance_at(vec2 uv, mat4 inverse_projection) {
	vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, texture(screen_depth, uv).r, 1.0);
	return -view.z / view.w;
}

void vertex() {
	// Swell only. The ripples are finer than the gap between two vertices, so putting them here
	// would sample them at random and read as noise rather than as water.
	VERTEX.y += swell(VERTEX.xz + NODE_POSITION_WORLD.xz, TIME) * wave_height;
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 surface = surface_normal(world.xz, TIME);
	NORMAL = normalize((VIEW_MATRIX * vec4(surface, 0.0)).xyz);

	float here = -VERTEX.z;
	float thickness = max(0.0, distance_at(SCREEN_UV, INV_PROJECTION_MATRIX) - here);

	// Bending what is behind the surface is the single strongest thing that says liquid. Divided by
	// the distance to the water so a swell forty metres out does not smear as hard as one underfoot.
	vec2 bent_uv = SCREEN_UV + surface.xz * refraction / max(here * 0.1, 1.0);
	bent_uv = clamp(bent_uv, vec2(0.001), vec2(0.999));
	// A refracted sample may land on something standing in front of the water — a body wading in the
	// shallows — and drag it under the surface. When it does, take the pixel straight on instead.
	float bent_thickness = distance_at(bent_uv, INV_PROJECTION_MATRIX) - here;
	if (bent_thickness < 0.0) {
		bent_uv = SCREEN_UV;
		bent_thickness = thickness;
	}

	vec3 behind = texture(screen_colour, bent_uv).rgb;
	float shallowness = 1.0 - exp(-bent_thickness / depth_fade);
	vec3 body = mix(shallow_colour, deep_colour, shallowness);
	// What is left of the floor after the water in front of it. Past a couple of metres, nothing.
	float clarity = exp(-bent_thickness / clarity_depth);
	ALBEDO = mix(body, behind * mix(shallow_colour, deep_colour, shallowness * 0.5) * 2.0, clarity);

	// Near-mirror edge-on, near-clear looking down. Without it the whole sheet has one look from
	// every distance, which no water has.
	float facing = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
	float grazing = pow(1.0 - facing, fresnel_power);
	ALBEDO = mix(ALBEDO, horizon_colour, grazing * fresnel_strength);

	// Foam where the water is thin, which is exactly the waterline.
	float foam = 1.0 - smoothstep(0.0, foam_width, thickness);
	foam *= 0.55 + 0.45 * sin(thickness * 6.0 + TIME * 1.6);
	ALBEDO = mix(ALBEDO, foam_colour, clamp(foam, 0.0, 1.0));

	// The screen behind is composited here rather than left to the blender, so the refraction is
	// the thing that shows through and the deep can close completely.
	ALPHA = 1.0;
	ROUGHNESS = mix(0.02, 0.12, grazing);
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
