shader_type canvas_item;

uniform float brightness = 2.5;
uniform float saturation = 1.25;
uniform float glow_alpha = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float mask = max(tex.r, max(tex.g, tex.b));
    float luminance = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 color = mix(vec3(luminance), tex.rgb, saturation);
    color *= brightness;
    COLOR = vec4(color, mask * glow_alpha);
}