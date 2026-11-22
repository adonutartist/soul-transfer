shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 mouse_uv = vec2(0.5, 0.5);
uniform float darkness = 0.58;
uniform float radius = 0.2;
uniform vec3 flashlight_color : source_color = vec3(0.62, 0.78, 1.0);

void fragment() {
    vec4 scene = texture(screen_texture, SCREEN_UV);
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 delta = (SCREEN_UV - mouse_uv) * vec2(aspect, 1.0);
    float distance_to_mouse = length(delta);
    float spread = radius * 0.85;
    float light = exp(-0.5 * pow(distance_to_mouse / spread, 2.0));
    float brightness = 1.0 - darkness + light * (darkness + 0.12);
    vec3 result = scene.rgb * brightness;
    result += flashlight_color * light * 0.045;
    COLOR = vec4(result, scene.a);
}