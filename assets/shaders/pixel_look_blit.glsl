#[compute]
#version 450

// The pixel look, second pass: the stylised frame copied back over the scene's own colour, which the
// tonemap and everything after it read.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D stylised;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D scene_colour;

layout(push_constant, std430) uniform Params {
	vec2 size;
	vec2 unused;
} params;

void main() {
	ivec2 here = ivec2(gl_GlobalInvocationID.xy);
	if (here.x >= int(params.size.x) || here.y >= int(params.size.y)) {
		return;
	}
	imageStore(scene_colour, here, imageLoad(stylised, here));
}
