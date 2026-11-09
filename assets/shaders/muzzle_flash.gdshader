shader_type canvas_item;
render_mode blend_add;

// A star-shaped glow, used for muzzle flashes and explosion cores.
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);

void fragment() {
	vec2 offset = UV - vec2(0.5);
	float distance_from_centre = length(offset) * 2.0;
	float star = 0.75 + 0.25 * cos(atan(offset.y, offset.x) * 8.0);
	float glow = 1.0 - smoothstep(0.0, star, distance_from_centre);
	COLOR = vec4(mix(edge_color.rgb, core_color.rgb, glow), glow);
}
