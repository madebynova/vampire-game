shader_type canvas_item;
// Single full-screen pass carrying every screen-space cue: sunlight glare, sense tint,
// feeding tunnel, hurt flash, transformation flash, fade to black.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float sun_strength = 0.0;
uniform float sense_strength = 0.0;
uniform float feed_strength = 0.0;
uniform float memory_strength = 0.0;
uniform float hurt_strength = 0.0;
uniform float flash_strength = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float fade = 0.0;
uniform float aspect = 1.78;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(aspect * 0.6, 1.0)) * 1.25;
	float vig = smoothstep(0.35, 1.0, r);

	uv.x += sin(uv.y * 45.0 + TIME * 7.0) * 0.003 * sun_strength * (0.3 + vig);
	uv += c * -0.06 * feed_strength * vig;

	vec3 col = texture(screen_tex, uv).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));

	// Vampiric Sense: drained colour, cold dark-red rim.
	col = mix(col, vec3(lum) * vec3(1.1, 0.62, 0.66), sense_strength * 0.45);
	col = mix(col, col * vec3(0.5, 0.08, 0.12), sense_strength * vig * 0.7);

	// Feeding: red tunnel, pulsing with a heartbeat.
	float beat = pow(max(0.0, sin(TIME * 7.5)), 6.0);
	col = mix(col, vec3(lum) * vec3(0.95, 0.15, 0.15), feed_strength * 0.5);
	col = mix(col, vec3(0.32, 0.0, 0.02), clamp(feed_strength * vig * (1.1 + beat * 0.5), 0.0, 1.0));

	// Blood memory: a faded, sepia flashback with dark edges.
	col = mix(col, vec3(lum) * vec3(1.18, 0.95, 0.72), memory_strength * 0.75);
	col = mix(col, col * vec3(0.4, 0.28, 0.22), memory_strength * vig * 0.9);

	// Sunlight: bleaching glare that grows from the edges.
	vec3 glare = vec3(1.0, 0.8, 0.5);
	col += glare * sun_strength * (0.08 + vig * 0.75);
	col = mix(col, vec3(lum + 0.4) * glare, sun_strength * 0.25);

	col = mix(col, vec3(0.75, 0.0, 0.0), hurt_strength * (0.25 + vig * 0.6));
	col = mix(col, flash_color.rgb, flash_strength);
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
