// Cartoon water for a sea or lake drawn as one flat surface: light over the shallows, darker where
// it's deep, a band of white foam wherever it meets something standing in it, and drifting ripple
// lines that fade out with distance. It reads the depth buffer to tell how deep the water is.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_toon, specular_toon;

uniform vec4 shallow_colour : source_color = vec4(0.30, 0.88, 0.86, 0.72);
uniform vec4 deep_colour : source_color = vec4(0.06, 0.38, 0.78, 0.93);
uniform vec4 foam_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ripple_colour : source_color = vec4(0.78, 0.96, 1.0, 1.0);
uniform float depth_fade : hint_range(0.1, 100.0) = 8.0; // m of water for shallow to turn deep
uniform float foam_width : hint_range(0.0, 10.0) = 0.9; // m
uniform float ripple_size : hint_range(0.1, 100.0) = 5.0; // m between ripple cells
uniform float ripple_width : hint_range(0.0, 1.0) = 0.07; // fraction of a cell
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.55;
uniform float ripple_speed : hint_range(0.0, 5.0) = 0.35;
uniform float ripple_patches : hint_range(0.0, 1.0) = 0.5; // how much of the surface has no ripples
uniform float ripple_fade : hint_range(1.0, 2000.0) = 150.0; // m from the camera where ripples have gone
uniform float roughness : hint_range(0.0, 1.0) = 0.25;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 world_position;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

// How far `p` is from the border between two cells of a Voronoi pattern whose points drift in
// small circles over time (the second-nearest point's distance minus the nearest's).
float cell_border(vec2 p, float time) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 point = 0.5 + 0.4 * sin(time + 6.2831 * hash2(cell + offset));
			float d = length(offset + point - f);
			if (d < nearest) {
				second = nearest;
				nearest = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - nearest;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// How much water there is between this point of the surface and whatever is behind it.
	float behind = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 behind_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, behind, 1.0);
	behind_view.xyz /= behind_view.w;
	float water = max(VERTEX.z - behind_view.z, 0.0);

	vec4 colour = mix(shallow_colour, deep_colour, clamp(water / depth_fade, 0.0, 1.0));

	float fade = 1.0 - clamp(length(VERTEX) / ripple_fade, 0.0, 1.0);
	float ripples = 1.0 - step(ripple_width, cell_border(world_position.xz / ripple_size, TIME * ripple_speed));
	ripples *= step(ripple_patches, value_noise(world_position.xz / (ripple_size * 4.0) + vec2(TIME * 0.05, 0.0)));
	colour.rgb = mix(colour.rgb, ripple_colour.rgb, ripples * fade * ripple_strength);

	float foam_edge = foam_width * (0.7 + 0.6 * value_noise(world_position.xz * 0.7 + vec2(TIME * 0.3, 0.0)));
	if (water < foam_edge) {
		colour = foam_colour;
	}

	ALBEDO = colour.rgb;
	ALPHA = colour.a;
	ROUGHNESS = roughness;
}
