shader_type canvas_item;

uniform vec4 tint: source_color = vec4(1.0, 0.25, 0.02, 1.0);
uniform float brightness = 20.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec2 centered = UV - vec2(0.5);
    float d = length(centered);
    float halo = 1.0 - smoothstep(0.02, 0.65, d);
    float core = 1.0 - smoothstep(0.0, 0.16, d);
    float alpha = max(halo * 0.4, core);
    alpha *= tex.a;
    vec3 color = tint.rgb * brightness;
    COLOR = vec4(color, alpha);
}