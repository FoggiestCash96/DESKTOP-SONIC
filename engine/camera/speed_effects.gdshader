// Speed effects drawn over the 3D view: a radial motion blur that streaks the scene away from the
// screen's centre, and white speed lines flowing outward near the edges. The player camera sets
// the two amounts from the player's speed; at 0 it hides the effect entirely.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 2.0) = 0.0;
uniform float lines_amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur_reach = 0.07; // Share of the distance to the centre the blur smears across at full strength.
uniform float line_density = 90.0; // Rays around the screen; only some of them carry a line.
uniform float line_flow = 3.5; // How fast the lines flow outward.

const int BLUR_SAMPLES = 10;

float random(float seed) {
	return fract(sin(seed * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 from_centre = SCREEN_UV - vec2(0.5);
	float distance = length(from_centre);
	vec3 colour = texture(screen, SCREEN_UV).rgb;

	if (blur_amount > 0.001) {
		// Average samples toward the centre: none at the middle, most at the edges.
		float smear = blur_amount * blur_reach * smoothstep(0.08, 0.6, distance);
		vec3 sum = vec3(0.0);
		for (int i = 0; i < BLUR_SAMPLES; i++) {
			float t = float(i) / float(BLUR_SAMPLES - 1);
			sum += texture(screen, SCREEN_UV - from_centre * smear * t).rgb;
		}
		colour = sum / float(BLUR_SAMPLES);
	}

	if (lines_amount > 0.001) {
		// Thin streaks along random rays from the centre, flowing outward, only near the edges.
		float ray = floor((atan(from_centre.y, from_centre.x) / TAU + 0.5) * line_density);
		float chosen = step(0.86, random(ray));
		float flow = fract(distance * 2.5 - TIME * line_flow + random(ray + 7.0));
		float streak = smoothstep(0.0, 0.25, flow) * (1.0 - smoothstep(0.35, 0.8, flow));
		float edge = smoothstep(0.32, 0.7, distance);
		colour = mix(colour, vec3(1.0), chosen * streak * edge * lines_amount * 0.55);
	}

	COLOR = vec4(colour, 1.0);
}
