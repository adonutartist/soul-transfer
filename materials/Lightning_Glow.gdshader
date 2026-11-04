shader_type canvas_item;

uniform vec4 hdr_color : source_color = vec4(0.12907735, 0.62275136, 0.7653253, 1.0);
uniform float brightness = 15.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = tex.a;
	COLOR = vec4(
		hdr_color.rgb * brightness * mask,
		mask
	);
}