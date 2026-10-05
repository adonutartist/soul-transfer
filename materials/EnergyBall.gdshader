shader_type canvas_item;
uniform float emission_strength = 15.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = max(tex.r, max(tex.g, tex.b));
	COLOR = vec4(vec3(emission_strength), alpha);
}