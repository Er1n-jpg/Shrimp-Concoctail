shader_type canvas_item;
// Draws a solid outline around the opaque parts of a sprite (e.g. to make a dark-outlined
// sprite readable on a dark background). `width` is in the sprite's own pixels.

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float width = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		vec2 p = TEXTURE_PIXEL_SIZE * width;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(p.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-p.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, p.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, -p.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(p.x, p.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-p.x, p.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(p.x, -p.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-p.x, -p.y)).a);
		if (a > 0.5) {
			c = outline_color;
		}
	}
	COLOR = c;
}
