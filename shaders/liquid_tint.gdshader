shader_type canvas_item;
// Recolors the grey liquid in the cup sprites to `tint`, keeping the art's shading.
// Grey pixels (no saturation) darker than the glass get tinted; the brown outline
// and the white glass/rim are left alone. Lighter greys (highlights, ice) become
// lighter shades of the tint.

uniform vec4 tint : source_color = vec4(0.41, 0.41, 0.41, 1.0);
// Brightness of the main liquid grey in the art (#696a6a).
uniform float base_value = 0.415;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float max_c = max(c.r, max(c.g, c.b));
	float min_c = min(c.r, min(c.g, c.b));
	float sat = max_c > 0.0 ? (max_c - min_c) / max_c : 0.0;
	if (c.a > 0.99 && sat < 0.06 && max_c > 0.25 && max_c < 0.9) {
		vec3 col;
		if (max_c <= base_value) {
			col = tint.rgb * (max_c / base_value);
		} else {
			col = mix(tint.rgb, vec3(1.0), (max_c - base_value) / (1.0 - base_value) * 0.85);
		}
		COLOR = vec4(col, c.a);
	} else {
		COLOR = c;
	}
}
