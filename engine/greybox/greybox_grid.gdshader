shader_type spatial;
// World-space grid for blockout geometry. Lines stay 1 m apart however a mesh is scaled,
// so distances and slope angles can be read at a glance while playtesting.

uniform vec3 base_color : source_color = vec3(0.36, 0.39, 0.43);
uniform vec3 line_color : source_color = vec3(0.62, 0.66, 0.70);
uniform float cell_size = 1.0;
uniform float major_every = 5.0; // Every Nth line is drawn thicker.
uniform float line_width = 0.02;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 on a grid line, 0.0 elsewhere, antialiased with screen-space derivatives.
float grid(vec2 p, float size, float width) {
	vec2 distance_to_line = abs(fract(p / size - 0.5) - 0.5) * size;
	vec2 aa = fwidth(p);
	vec2 line = 1.0 - smoothstep(vec2(width) - aa, vec2(width) + aa, distance_to_line);
	return max(line.x, line.y);
}

// Projects the grid from the three world axes and blends by the surface normal.
float triplanar_grid(float size, float width) {
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	return grid(world_position.zy, size, width) * weights.x
		+ grid(world_position.xz, size, width) * weights.y
		+ grid(world_position.xy, size, width) * weights.z;
}

void fragment() {
	float minor = triplanar_grid(cell_size, line_width);
	float major = triplanar_grid(cell_size * major_every, line_width * 2.0);
	ALBEDO = mix(base_color, line_color, max(minor * 0.6, major));
	ROUGHNESS = roughness;
}
