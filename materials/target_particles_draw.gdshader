shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.062, 0.733, 0.871, 1.0);
uniform float brightness = 1.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    COLOR = vec4(
        tex.rgb * tint.rgb * brightness,
        tex.a * tint.a
    );
}