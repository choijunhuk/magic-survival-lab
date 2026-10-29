shader_type canvas_item;

uniform vec4 ink_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_art = 0.0;

void fragment() {
    vec4 source = texture(TEXTURE, UV);
    float strength = max(max(source.r, source.g), source.b);
    float detail = clamp((strength - 0.025) * 2.0, 0.0, 1.0);
    float edge = clamp(fwidth(strength) * 8.0, 0.0, 1.0);
    float shape = mix(1.0, 0.20 + 0.80 * edge, line_art);
    COLOR = vec4(ink_color.rgb, source.a * detail * shape * ink_color.a);
}
