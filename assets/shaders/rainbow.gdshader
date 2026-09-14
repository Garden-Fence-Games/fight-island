shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

// The rainbow bird's light, and the player's while its power is on. A `material_overlay`, drawn on
// top of whatever the body already wears: the painted rig stays itself, and the colours run over
// it. An override would have flattened the texture to a block of paint.
//
// Additive, so it can only ever brighten. Bands of hue flow across the body in world space, a rim
// makes the silhouette glow, and a scatter of glints pinned to the body's own surface twinkle on
// and off — the glitter. `glitter` is a switch rather than a strength, because the reduced-flashing
// setting asks for no twinkle at all, not a quieter one.

// Everything together, so the effect can be faded in and out and blinked as it runs down.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// How many bands a metre, and how fast they move.
uniform float bands = 1.4;
uniform float flow = 0.35;
// How bright the colour sits on the body, and how much brighter it gets at the silhouette's edge.
uniform float glow = 0.45;
uniform float rim = 1.1;
// Glints a metre along each axis, the share of cells that carry one, and how fast each one blinks.
uniform float glitter_density = 22.0;
uniform float glitter_share = 0.12;
uniform float glitter_rate = 5.0;
uniform float glitter = 1.0;

varying vec3 world_position;
varying vec3 body_position;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

float hash(vec3 cell) {
	return fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	body_position = VERTEX;
}

void fragment() {
	float h = fract(dot(world_position, vec3(0.55, 1.0, 0.35)) * bands - TIME * flow);
	vec3 colour = hue(h);
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float seed = hash(floor(body_position * glitter_density));
	float lit = step(1.0 - glitter_share, seed);
	float blink = pow(max(sin(TIME * glitter_rate + seed * TAU * 8.0), 0.0), 12.0);
	vec3 glint = vec3(lit * blink * glitter * 2.5);
	ALBEDO = (colour * glow * (1.0 + edge * rim) + glint) * strength;
}
