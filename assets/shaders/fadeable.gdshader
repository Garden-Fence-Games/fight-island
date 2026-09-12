shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Stone that gets out of the camera's way. The camera is fixed on purpose — see `CameraRig` — so
// the answer to something standing in front of the player is to fade it, never to move the
// viewpoint.
//
// Plain transparency, which is only affordable because there are six of these. The palms are a
// MultiMesh of several hundred and could not have used it; they are also not faded at all, because
// a thinned-out tree reads as stranger than the tree did.

uniform vec3 tint : source_color = vec3(0.33, 0.31, 0.29);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;
// Driven per node by the occlusion fader. Zero is solid, which is what an untouched material is.
uniform float faded : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = tint;
	ALPHA = 1.0 - faded;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.15;
}
