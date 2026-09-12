shader_type canvas_item;

// The frozen world behind a pause menu, softened so the menu is what the eye lands on. Reading the
// screen's own mipmaps is the cheap blur: one sample, no kernel, and the cost does not grow with
// the radius.

uniform float radius : hint_range(0.0, 6.0) = 3.0;
uniform float darken : hint_range(0.0, 1.0) = 0.25;

uniform sampler2D screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec3 blurred = textureLod(screen, SCREEN_UV, radius).rgb;
	COLOR = vec4(blurred * (1.0 - darken), 1.0);
}
