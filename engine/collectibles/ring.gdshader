// Ring look: a shiny ring that stands upright and spins about the vertical axis. Every ring using
// this shader spins in step, as in the classic games, with no script running per ring. Made for
// TorusMesh, which lies flat in the XZ plane; give the MeshInstance3D a custom_aabb that covers
// the ring standing up.
shader_type spatial;

uniform vec3 color : source_color = vec3(1.0, 0.78, 0.18);
uniform float spin_speed = 4.0; // Radians per second.
uniform float glow = 0.25; // Share of the color added as emission, so rings read in the shade.

void vertex() {
	// Stand the torus up (a quarter turn about X), then spin it about Y.
	vec3 standing = vec3(VERTEX.x, -VERTEX.z, VERTEX.y);
	vec3 standing_normal = vec3(NORMAL.x, -NORMAL.z, NORMAL.y);
	float angle = TIME * spin_speed;
	mat3 spin = mat3(vec3(cos(angle), 0.0, -sin(angle)), vec3(0.0, 1.0, 0.0), vec3(sin(angle), 0.0, cos(angle)));
	VERTEX = spin * standing;
	NORMAL = spin * standing_normal;
}

void fragment() {
	ALBEDO = color;
	METALLIC = 0.8;
	ROUGHNESS = 0.3;
	EMISSION = color * glow;
}
