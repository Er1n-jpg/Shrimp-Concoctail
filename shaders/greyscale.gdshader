shader_type canvas_item;
// Full-screen desaturate (Dumped Guy). Tween `amount` from 0 to 1.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(grey), amount), 1.0);
}
