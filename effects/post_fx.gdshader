shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_start : hint_range(0.0, 1.0) = 0.35;
uniform float ca_strength : hint_range(0.0, 0.01) = 0.0018;
uniform float edge_blur : hint_range(0.0, 4.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.04, 1.0, 0.94);
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float r = length(d);
	float lod = edge_blur * smoothstep(0.25, 0.75, r);
	vec3 c;
	c.r = textureLod(screen_tex, SCREEN_UV + d * ca_strength * r * 4.0, lod).r;
	c.g = textureLod(screen_tex, SCREEN_UV, lod).g;
	c.b = textureLod(screen_tex, SCREEN_UV - d * ca_strength * r * 4.0, lod).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	c *= 1.0 - vignette * smoothstep(vignette_start, 0.85, r);
	COLOR = vec4(c, 1.0);
}