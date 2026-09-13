shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, specular_schlick_ggx;

// Wind, as a vertex program rather than an animation.
//
// Every plant on the island is one instance of a MultiMeshInstance3D: one mesh, one material,
// thousands of transforms. Instances cannot play separate animations, so the only place motion can
// come from is here — driven by TIME and by where in the world each instance stands.
//
// Phase comes from the distance along the wind, so the gust travels across the island and no two
// plants are in step unless they are neighbours. Nothing is hashed: a hash is discontinuous, and
// two plants a metre apart must not jump to opposite ends of the cycle.

uniform vec3 tint : source_color = vec3(0.36, 0.52, 0.27);
// A plant that carries its own painted colours supplies this; every other one leaves it alone.
// `hint_default_white` is what makes the two live in one shader: an unset sampler reads as white,
// so `tint * white` is the flat colour the island's palette has always produced, unchanged.
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;

uniform vec2 wind_heading = vec2(0.86, 0.51);
// Metres the top of a fully bent plant travels.
uniform float wind_strength : hint_range(0.0, 1.5) = 0.3;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.1;
// Metres between one crest of the wind and the next.
uniform float wave_length : hint_range(1.0, 120.0) = 26.0;
// Height at which a plant is bending as far as it will bend.
uniform float bend_height : hint_range(0.1, 16.0) = 5.2;
// Above 1.0 the base stays planted and the motion collects in the top, which is what a stem does.
uniform float bend_power : hint_range(1.0, 4.0) = 2.2;
uniform float gust_length : hint_range(10.0, 400.0) = 95.0;
uniform float gust_depth : hint_range(0.0, 1.0) = 0.55;
// Sideways flex along a leaf's own length, measured from the instance origin so a frond twists
// without ever leaving the trunk it is attached to.
uniform float flutter : hint_range(0.0, 0.6) = 0.0;
uniform float flutter_speed : hint_range(0.0, 16.0) = 4.5;

void vertex() {
	vec2 heading = normalize(wind_heading);
	vec3 root = MODEL_MATRIX[3].xyz;

	// Every plant is one instance standing on its own origin, so height above the ground is simply
	// height above that origin. A palm arrives as one piece — trunk and crown in the same mesh — so
	// the crown reads its real height and bends with the wood it sits on, for free.
	float above_ground = max(VERTEX.y - root.y, 0.0);

	float along = dot(root.xz, heading);
	float gust = 1.0 - gust_depth * (0.5 + 0.5 * sin(along / gust_length * TAU - TIME * 0.19));
	float phase = along / wave_length * TAU - TIME * wind_speed;
	float wave = sin(phase) * 0.72 + sin(phase * 2.3 + 1.7) * 0.28;

	float bend = pow(min(above_ground / bend_height, 1.0), bend_power);
	vec2 push = heading * wave * gust * wind_strength * bend;

	float reach = length(VERTEX.xz - root.xz);
	vec2 across = vec2(-heading.y, heading.x);
	push += across * sin(phase * 3.1 + above_ground * 2.0 + TIME * flutter_speed) * flutter * reach;

	VERTEX.xz += push;
	// A stem bends through an arc, it does not slide: without the sag a palm grows taller the harder
	// the wind blows. Half the travel squared over the length is the arc's drop to first order.
	VERTEX.y -= dot(push, push) / (2.0 * max(above_ground, 0.25));
}

void fragment() {
	// Cut out rather than blended: a painted leaf's alpha is where the leaf ends, and a MultiMesh of
	// blended cards would have to be sorted against itself every frame. An unset texture reads white
	// and fully opaque, so nothing without a cut-out changes.
	vec4 painted = texture(albedo_texture, UV);
	ALBEDO = tint * painted.rgb;
	ALPHA = painted.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.15;
}
