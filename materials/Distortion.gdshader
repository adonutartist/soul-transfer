shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float distortion_strength : hint_range(-0.2, 0.2) = 0.04;

void fragment() {
    float mask = texture(TEXTURE, UV).a;
    vec2 centered = UV - vec2(0.5);
    float distance_from_center = length(centered) * 2.0;
    float falloff = 1.0 - smoothstep(
        0.0,
        1.0,
        distance_from_center
    );
    vec2 direction = normalize(centered + vec2(0.00001));
    vec2 offset = direction * distortion_strength * falloff;
    vec2 screen_uv = SCREEN_UV - offset;
    vec4 scene = texture(screen_texture, screen_uv);
    COLOR = vec4(scene.rgb, mask);
}