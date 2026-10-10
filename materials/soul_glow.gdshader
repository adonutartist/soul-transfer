shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float brightness = 10.0;
uniform float dissolve_position : hint_range(-1.0, 1.0) = -0.2;
uniform float dissolve_softness : hint_range(0.001, 0.5) = 0.08;
varying float particle_position;

void vertex() {
	particle_position = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = max(tex.r, max(tex.g, tex.b));
	float fade = smoothstep(
		dissolve_position,
		dissolve_position + dissolve_softness,
		particle_position
	);
	COLOR = vec4(
		tex.rgb * tint.rgb * brightness,
		mask * tint.a * fade
	);
}