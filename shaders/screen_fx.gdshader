shader_type canvas_item;
// Single full-screen pass carrying every screen-space cue: sunlight glare, sense tint, feeding
// tunnel, transformation, blood pulse / hunger / Bloodrush, Blood Memory looks, hurt, flash, fade.
// Every effect is driven by one uniform that is 0 when off, and the heavier ones are skipped then.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float sun_strength = 0.0;
uniform float sense_strength = 0.0;
uniform float feed_strength = 0.0;
uniform float memory_strength = 0.0;
uniform vec3 memory_tint = vec3(0.95, 0.72, 0.42);
uniform float memory_fragmentation = 0.0;
uniform float memory_dim = 0.0;
uniform float morph = 0.0;
uniform vec3 morph_color = vec3(0.3, 0.0, 0.05);
uniform float morph_ring = -1.0;
uniform float morph_ring_strength = 0.0;
uniform float chroma = 0.0;
uniform float vamp_look = 0.0;
uniform float hunger = 0.0;
uniform float surge = 0.0;
uniform float pulse_env = 0.0;
uniform float pulse_strength = 0.0;
uniform float hurt_strength = 0.0;
uniform float flash_strength = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float fade = 0.0;
uniform float aspect = 1.78;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(aspect * 0.6, 1.0)) * 1.25;
	float vig = smoothstep(0.35, 1.0, r);

	uv.x += sin(uv.y * 45.0 + TIME * 7.0) * 0.003 * sun_strength * (0.3 + vig);
	uv += c * -0.06 * feed_strength * vig;

	// Transformation: a shockwave ring bends the picture outward as it passes.
	if (morph_ring_strength > 0.001) {
		float ring = smoothstep(0.12, 0.0, abs(r - morph_ring)) * morph_ring_strength;
		uv += normalize(c + vec2(0.0001)) * ring * 0.035;
	}
	// Blood Memory, fragmented: the picture tears in horizontal slices.
	if (memory_fragmentation > 0.001 && memory_strength > 0.01) {
		float tick = floor(TIME * 9.0);
		float slice = floor(uv.y * 26.0);
		float h = hash(slice + tick * 3.7);
		float tear = step(0.86, h) * (h - 0.86) * 7.0;
		uv.x += (tear * 0.10 + (h - 0.5) * 0.004) * memory_fragmentation * memory_strength;
	}

	vec3 col;
	float ca = chroma + morph * 0.6;
	if (ca > 0.002) {
		vec2 off = c * ca * 0.022 * (0.25 + vig);
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));

	// Being a vampire: a cold, slightly darkened rim to the world.
	col = mix(col, col * vec3(0.8, 0.8, 0.95), vamp_look * vig * 0.55);
	col *= 1.0 - vamp_look * vig * 0.22;

	// Hunger: colour drains, the edges close in.
	col = mix(col, vec3(lum) * vec3(1.0, 0.85, 0.85), hunger * 0.45);
	col *= 1.0 - hunger * vig * 0.45;

	// Vampiric Sense: drained colour, cold dark-red rim.
	col = mix(col, vec3(lum) * vec3(1.1, 0.62, 0.66), sense_strength * 0.45);
	col = mix(col, col * vec3(0.5, 0.08, 0.12), sense_strength * vig * 0.7);

	// Feeding: red tunnel, pulsing with a heartbeat.
	float beat = pow(max(0.0, sin(TIME * 7.5)), 6.0);
	col = mix(col, vec3(lum) * vec3(0.95, 0.15, 0.15), feed_strength * 0.5);
	col = mix(col, vec3(0.32, 0.0, 0.02), clamp(feed_strength * vig * (1.1 + beat * 0.5), 0.0, 1.0));

	// Bloodrush: warm crimson in the veins of the picture.
	col = mix(col, col * vec3(1.12, 0.94, 0.94), surge * 0.6);
	col += vec3(0.22, 0.025, 0.035) * surge * (0.18 + vig * 0.7) * (0.75 + 0.25 * pulse_env);

	// Transformation: the world narrows to a red-black tunnel, then snaps open.
	float tunnel = smoothstep(1.05 - morph * 0.85, 1.3 - morph * 0.85, r);
	col = mix(col, vec3(lum) * 0.7, morph * 0.55);
	col = mix(col, morph_color, clamp(tunnel * morph * 1.05, 0.0, 1.0));

	// Blood Memory: the world drains into the victim's colour and dims so the words can be read.
	if (memory_strength > 0.001) {
		float mvig = smoothstep(0.25, 1.0, r);
		float lift = pow(max(lum, 0.0001), 0.6);   // raise the shadows: a dark night must stay readable as a scene
		col = mix(col, vec3(lift) * memory_tint * 1.9, memory_strength * 0.82);
		col = mix(col, col * memory_tint * 0.55, memory_strength * mvig * 0.9);
		col *= 1.0 - memory_dim * 0.45;
		float flick = step(0.93, hash(floor(TIME * 12.0) + 1.3));
		col *= 1.0 - memory_fragmentation * memory_strength * 0.28 * flick;
	}

	// Sunlight: bleaching glare that grows from the edges.
	vec3 glare = vec3(1.0, 0.8, 0.5);
	col += glare * sun_strength * (0.08 + vig * 0.75);
	col = mix(col, vec3(lum + 0.4) * glare, sun_strength * 0.25);

	// The heart, felt at the edges of the eyes.
	col = mix(col, vec3(0.5, 0.0, 0.03), pulse_env * pulse_strength * smoothstep(0.4, 1.05, r) * 0.7);

	col = mix(col, vec3(0.75, 0.0, 0.0), hurt_strength * (0.25 + vig * 0.6));
	col = mix(col, flash_color.rgb, flash_strength);
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
