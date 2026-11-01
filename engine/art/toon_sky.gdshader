// A cartoon sky: a gradient from the horizon up, a round sun with a soft halo, and flat-shaded
// clouds that thin out toward the horizon. For a storm, turn the cover up and the colours down;
// `flash` lights everything up for a moment of lightning (a script animates it).
shader_type sky;

uniform vec4 top_colour : source_color = vec4(0.16, 0.45, 0.92, 1.0);
uniform vec4 horizon_colour : source_color = vec4(0.70, 0.88, 1.0, 1.0);
uniform vec4 below_colour : source_color = vec4(0.40, 0.65, 0.88, 1.0); // under the horizon, past the sea's edge
uniform float gradient_curve : hint_range(0.1, 4.0) = 0.55;
uniform vec4 sun_colour : source_color = vec4(1.0, 0.98, 0.88, 1.0);
uniform float sun_size : hint_range(0.0, 0.5) = 0.05; // radians
uniform float sun_halo : hint_range(0.0, 1.0) = 0.25;
uniform vec4 cloud_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shade_colour : source_color = vec4(0.80, 0.87, 0.96, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_scale : hint_range(0.01, 10.0) = 1.1;
uniform vec2 cloud_offset = vec2(0.0, 0.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	// Each layer is turned against the last, so the noise's square grid never lines up into streaks.
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float total = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		total += weight * value_noise(p);
		p = turn * p * 2.03 + vec2(17.1, 9.3);
		weight *= 0.5;
	}
	return total;
}

void sky() {
	vec3 direction = EYEDIR;
	vec3 colour;
	if (direction.y >= 0.0) {
		colour = mix(horizon_colour.rgb, top_colour.rgb, pow(direction.y, gradient_curve));
	} else {
		colour = mix(horizon_colour.rgb, below_colour.rgb, clamp(-direction.y * 6.0, 0.0, 1.0));
	}

	if (LIGHT0_ENABLED) {
		float angle = acos(clamp(dot(direction, LIGHT0_DIRECTION), -1.0, 1.0));
		colour += sun_colour.rgb * sun_halo * (1.0 - smoothstep(sun_size, sun_size * 6.0, angle));
		if (angle < sun_size) {
			colour = sun_colour.rgb;
		}
	}

	if (direction.y > 0.0) {
		// Clouds on a flat layer overhead, seen in perspective.
		vec2 layer = direction.xz / (direction.y + 0.08) * cloud_scale + cloud_offset;
		float density = fbm(layer);
		float edge = 1.0 - cloud_cover;
		float cloud = smoothstep(edge, edge + 0.03, density);
		// The side away from the sun is shaded: denser cloud between this point and the sun.
		vec2 toward_sun = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.12 : vec2(0.0);
		float shaded = smoothstep(density + 0.01, density + 0.09, fbm(layer + toward_sun));
		vec3 cloud_rgb = mix(cloud_colour.rgb, cloud_shade_colour.rgb, shaded);
		float thin = smoothstep(0.0, 0.3, direction.y);
		colour = mix(colour, cloud_rgb, cloud * thin);
	}

	COLOR = mix(colour, vec3(1.0), flash * 0.65);
}
