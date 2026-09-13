#[compute]
#version 450

// The pixel look, first pass: the finished 3D frame, read one fat pixel at a time.
//
// Every block of `pixel` screen pixels takes the colour, depth and normal of its own centre, so an
// edge is decided once per block and lands exactly on the block grid — an outline one fat pixel
// wide, never a smear of half-covered screen pixels. Written to a texture of our own, because the
// frame is still being read while it is written, and the second pass copies it back.
//
// Two lines are drawn, the way hand-made pixel art draws them:
// - a dark one where a block is nearer than its neighbour by a share of its own distance — the
//   silhouette of whatever stands in front, at any zoom;
// - a light one along a crease, where two faces at the same depth turn away from each other and the
//   block faces the sky more than its neighbour does — the top edge of a rock, a roof, a shoulder.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D scene_colour;
layout(set = 0, binding = 1) uniform sampler2D scene_depth;
layout(set = 0, binding = 2) uniform sampler2D scene_normal;
layout(rgba16f, set = 0, binding = 3) uniform restrict writeonly image2D result;

layout(push_constant, std430) uniform Params {
	vec2 size;
	float pixel;
	float depth_edge;
	float outline;
	float highlight;
	float crease;
	float levels;
	mat4 inverse_projection;
} params;

float distance_at(vec2 uv) {
	float depth = texture(scene_depth, uv).r;
	vec4 view = params.inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}

vec3 normal_at(vec2 uv) {
	return normalize(texture(scene_normal, uv).xyz * 2.0 - 1.0);
}

void main() {
	ivec2 here = ivec2(gl_GlobalInvocationID.xy);
	if (here.x >= int(params.size.x) || here.y >= int(params.size.y)) {
		return;
	}
	vec2 texel = 1.0 / params.size;
	vec2 block = floor(vec2(here) / params.pixel);
	vec2 centre = clamp((block + 0.5) * params.pixel * texel, texel * 0.5, 1.0 - texel * 0.5);
	vec2 reach = params.pixel * texel;

	// The colour is the block's average, from four points inside it, rather than its centre alone:
	// grass is finer than a fat pixel, and one sample of it per block is a different blade every few
	// frames — a field of flickering specks rather than a green.
	vec2 quarter = reach * 0.25;
	vec3 colour = (
		texture(scene_colour, clamp(centre + vec2(-quarter.x, -quarter.y), 0.0, 1.0)).rgb
		+ texture(scene_colour, clamp(centre + vec2(quarter.x, -quarter.y), 0.0, 1.0)).rgb
		+ texture(scene_colour, clamp(centre + vec2(-quarter.x, quarter.y), 0.0, 1.0)).rgb
		+ texture(scene_colour, clamp(centre + vec2(quarter.x, quarter.y), 0.0, 1.0)).rgb
	) * 0.25;
	float distance = distance_at(centre);
	vec3 normal = normal_at(centre);

	float silhouette = 0.0;
	float ridge = 0.0;
	const vec2 around[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 4; i++) {
		vec2 there = clamp(centre + around[i] * reach, texel * 0.5, 1.0 - texel * 0.5);
		float beyond = distance_at(there) - distance;
		if (beyond > distance * params.depth_edge) {
			silhouette = 1.0;
		} else if (abs(beyond) < distance * params.depth_edge) {
			vec3 other = normal_at(there);
			if (dot(normal, other) < params.crease && normal.y > other.y) {
				ridge = 1.0;
			}
		}
	}

	colour *= 1.0 - params.outline * silhouette;
	colour *= 1.0 + params.highlight * ridge * (1.0 - silhouette);

	// A slightly smaller palette, stepped in a perceptual space so the darks keep their steps.
	if (params.levels > 0.0) {
		vec3 perceived = pow(max(colour, vec3(0.0)), vec3(1.0 / 2.2));
		perceived = floor(perceived * params.levels + 0.5) / params.levels;
		colour = pow(perceived, vec3(2.2));
	}

	imageStore(result, here, vec4(colour, 1.0));
}
