shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// The enemy wind-up, drawn on the ground under whoever is committing.
//
// **It has to read in greyscale**, which is the whole reason it is a shape and not a colour. A ring
// that fills as the telegraph runs is geometry: it survives a colourblind player, a screenshot with
// no saturation, and a camera twenty metres up. A tint that went from green to red would fail all
// three and look fine to whoever wrote it.
//
// Drawn rather than animated, because the fill has to match the wind-up exactly — and the wind-up
// shortens with the waves and with the hour.

uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint: source_color = vec4(0.9, 0.2, 0.2, 1.0);
// What `access_colourblind_telegraphs` turns on: the ring thickens and goes to full black-and-white
// rather than the archetype's own colour. Redundancy on top of a cue that already works, for a
// player who wants the shape to shout.
uniform float high_contrast: hint_range(0.0, 1.0) = 0.0;
uniform float inner: hint_range(0.0, 1.0) = 0.62;
uniform float outer: hint_range(0.0, 1.0) = 0.94;
// How much of the ring is drawn before anything has filled. Without it the telegraph appears out of
// nothing, and the player has no frame to read the fill against.
uniform float rail: hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec2 from_centre = UV * 2.0 - 1.0;
	float radius = length(from_centre);
	float thicken = mix(0.0, 0.1, high_contrast);
	float edge = fwidth(radius) * 1.5;
	float ring = smoothstep(inner - thicken - edge, inner - thicken, radius)
		* (1.0 - smoothstep(outer + thicken, outer + thicken + edge, radius));
	if (ring < 0.01) {
		discard;
	}
	// Clockwise from the top, so it reads the way every other filling dial does.
	float turn = fract(atan(from_centre.x, from_centre.y) / 6.2831853 + 0.5);
	float filled = step(turn, progress);
	vec3 colour = mix(tint.rgb, vec3(1.0), high_contrast);
	ALBEDO = colour;
	ALPHA = ring * mix(rail, 1.0, filled) * mix(0.85, 1.0, high_contrast);
}
