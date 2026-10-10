shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.062, 0.733, 0.871, 1.0);
uniform float brightness = 1.0;
uniform float dissolve_position = -1.0;
uniform float dissolve_feather = 0.08;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float particle_position = COLOR.g;
	float dissolve_alpha = 1.0;
	if (dissolve_position >= 0.0) {
		float fade_start = 1.0 - dissolve_position;
		float fade_end = fade_start - dissolve_feather;
		dissolve_alpha = smoothstep(
			fade_end,
			fade_start,
			particle_position
		);
	}
	COLOR = vec4(
		tex.rgb * tint.rgb * brightness,
		tex.a * tint.a * dissolve_alpha
	);
}