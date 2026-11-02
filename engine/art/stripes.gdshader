// Flat colour in stripes across a surface, like mown grass or the planks of a deck. The stripes
// change along UV.x, which the art scripts measure in metres along the way the player runs, so
// they stream past at speed. An optional line marks the start of each stripe (the gap between
// planks), and optional soft blotches break up large flat areas such as sand.
// Vertex colours tint the result.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 colour_1 : source_color = vec4(0.42, 0.80, 0.25, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.36, 0.72, 0.21, 1.0);
uniform vec4 line_colour : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float stripe_length : hint_range(0.05, 50.0) = 2.0; // m per stripe
uniform float line_width : hint_range(0.0, 1.0) = 0.0; // fraction of a stripe
uniform float speckle : hint_range(0.0, 1.0) = 0.0; // how much the blotches darken
uniform float speckle_size : hint_range(0.01, 20.0) = 1.5; // m
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float level = UV.x / stripe_length;
	vec3 colour = mod(floor(level), 2.0) < 1.0 ? colour_1.rgb : colour_2.rgb;
	if (fract(level) < line_width) {
		colour = line_colour.rgb;
	}
	if (speckle > 0.0) {
		colour *= 1.0 - speckle * value_noise(world_position.xz / speckle_size);
	}
	ALBEDO = colour * COLOR.rgb;
	ROUGHNESS = roughness;
}
