// Rock in horizontal bands, like layered sandstone. The colour depends on the height in the
// world, so the bands line up across every cliff whatever its shape and however it was built.
// They wander up and down a little along a cliff, and a thin line marks the bottom of each band.
// Vertex colours tint the result (the art scripts use them to darken cliff bottoms).
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 colour_1 : source_color = vec4(0.97, 0.78, 0.50, 1.0);
uniform vec4 colour_2 : source_color = vec4(0.92, 0.62, 0.36, 1.0);
uniform vec4 colour_3 : source_color = vec4(0.82, 0.46, 0.27, 1.0);
uniform vec4 colour_4 : source_color = vec4(0.92, 0.62, 0.36, 1.0);
uniform vec4 line_colour : source_color = vec4(0.66, 0.34, 0.21, 1.0);
uniform float band_height : hint_range(0.1, 20.0) = 1.4; // m
uniform float line_width : hint_range(0.0, 1.0) = 0.1; // fraction of a band
uniform float wobble : hint_range(0.0, 5.0) = 0.35; // how far the bands wander up and down (m)
uniform float wobble_length : hint_range(0.5, 100.0) = 7.0; // m between wobbles along a cliff
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise in 0..1.
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float wander = (value_noise(world_position.xz / wobble_length) - 0.5) * 2.0 * wobble;
	float level = (world_position.y + wander) / band_height;
	float band = mod(floor(level), 4.0);
	vec3 colour = band < 1.0 ? colour_1.rgb : band < 2.0 ? colour_2.rgb : band < 3.0 ? colour_3.rgb : colour_4.rgb;
	if (fract(level) < line_width) {
		colour = line_colour.rgb;
	}
	ALBEDO = colour * COLOR.rgb;
	ROUGHNESS = roughness;
}
