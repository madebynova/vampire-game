shader_type spatial;
// material_overlay for anything Vampiric Sense reveals. Drawn without depth test so it
// shows through walls. Pulses at the target's heart rate.
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_add;

uniform vec4 color : source_color = vec4(0.9, 0.05, 0.1, 1.0);
uniform float intensity = 1.0;
uniform float beat_hz = 1.1;
uniform float phase = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float t = TIME * beat_hz + phase;
	float b1 = pow(max(0.0, sin(TAU * t)), 8.0);
	float b2 = 0.55 * pow(max(0.0, sin(TAU * (t - 0.14))), 10.0);
	float beat = b1 + b2;
	vec3 c = color.rgb * (0.4 + fres * 1.5 + beat * 1.8);
	ALBEDO = c * intensity;
	ALPHA = clamp(0.4 + fres, 0.0, 1.0);
}
