shader_type canvas_item;
uniform float emission_strength = 8.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb * emission_strength, tex.a);
}