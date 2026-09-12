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
// the palm fronds have to agree with the trunk they sit on to the centimetre.

uniform vec3 tint : source_color = vec3(0.36, 0.52, 0.27);
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

	// INSTANCE_CUSTOM carries where this instance's plant meets the ground, relative to the
	// instance itself: .r how far above the ground the instance sits, .gb the ground's offset in
	// the plane. Both are zero for anything planted directly — which is what an instance with no
	// custom data reads as, so only the fronds have to carry any.
	vec2 anchor = root.xz + INSTANCE_CUSTOM.gb;
	float above_ground = max(INSTANCE_CUSTOM.r + (VERTEX.y - root.y), 0.0);

	float along = dot(anchor, heading);
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
	ALBEDO = tint;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.15;
}
