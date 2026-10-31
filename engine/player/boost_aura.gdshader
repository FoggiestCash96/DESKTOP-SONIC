shader_type spatial;
// The boost aura: a shell of light around the player, bright at its edges and clear in the middle,
// flickering slightly, so it reads as rushing air rather than a bubble like the shield.

render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.4, 0.75, 1.0, 1.0);
uniform float edge_power = 2.2;  // Higher keeps the glow nearer the edges.
uniform float strength = 1.3;
uniform float flicker = 0.15;  // How much the glow flickers.
uniform float flicker_rate = 30.0;  // Flickers per second, roughly.

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), edge_power);
	float wobble = 1.0 - flicker + flicker * sin(TIME * flicker_rate);
	ALBEDO = color.rgb;
	ALPHA = clamp(rim * strength * wobble, 0.0, 1.0) * color.a;
}
