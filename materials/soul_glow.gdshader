shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brightness = 10.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float mask = max(tex.r, max(tex.g, tex.b));

    COLOR = vec4(
        tex.rgb * tint.rgb * brightness,
        tex.a * tint.a
    );
}