// A cartoon waterfall: a curtain of water with white streaks pouring down it and white water
// where it lands. The mesh's UVs are in metres (x across, y down from the top), and its vertex
// colour's red marks the white water (1 at the foot of the fall).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, diffuse_toon, specular_toon;

uniform vec4 water_colour : source_color = vec4(0.55, 0.88, 0.98, 0.82);
uniform vec4 streak_colour : source_color = vec4(0.95, 1.0, 1.0, 0.95);
uniform float fall_speed : hint_range(0.0, 30.0) = 7.0; // m/s the streaks pour down at
uniform float streak_spacing : hint_range(0.05, 5.0) = 0.55; // m between streaks across the fall
uniform float streak_length : hint_range(0.1, 20.0) = 2.6; // m from one streak to the next down a column
uniform float streak_amount : hint_range(0.0, 1.0) = 0.75;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float column = floor(UV.x / streak_spacing);
	float offset = hash(column) * streak_length;
	float along = fract((UV.y - TIME * fall_speed * (0.8 + 0.4 * hash(column + 3.1)) + offset) / streak_length);
	float streak = smoothstep(0.0, 0.12, along) * (1.0 - smoothstep(0.3, 0.55, along));
	streak *= step(0.35, hash(column + 7.7));
	vec4 colour = mix(water_colour, streak_colour, streak * streak_amount);
	colour = mix(colour, vec4(1.0, 1.0, 1.0, 0.95), clamp(COLOR.r, 0.0, 1.0));
	ALBEDO = colour.rgb;
	ALPHA = colour.a;
	ROUGHNESS = roughness;
}
