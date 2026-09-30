shader_type spatial;
// material_overlay for anything Vampiric Sense reveals. Drawn without depth test so it
// shows through walls. Pulses at the target's heart rate.
//  - a known person burns steady in the colour of their blood; a stranger is paler, hollow and
//    flickers like something half-heard
//  - `flash` is the scan wave passing over them
//  - `focus` dims everyone but the one you are attending to; `near` makes a close heart throb harder
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_add;

uniform vec4 color : source_color = vec4(0.9, 0.05, 0.1, 1.0);
uniform float intensity = 1.0;
uniform float beat_hz = 1.1;
uniform float phase = 0.0;
uniform float unknown = 0.0;
uniform float flash = 0.0;
uniform float focus = 1.0;
uniform float near = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float t = TIME * beat_hz + phase;
	float b1 = pow(max(0.0, sin(TAU * t)), 8.0);
	float b2 = 0.55 * pow(max(0.0, sin(TAU * (t - 0.14))), 10.0);
	float beat = (b1 + b2) * (1.0 + near * 1.6);
	vec3 base = color.rgb;
	// A stranger: washed toward cold white, hollow in the middle, flickering.
	base = mix(base, vec3(0.78, 0.84, 1.0) * length(base), unknown * 0.5);
	float flick = mix(1.0, 0.55 + 0.45 * step(0.4, fract(sin(floor(TIME * 11.0) * 12.9898 + phase * 40.0) * 43758.5453)), unknown * 0.7);
	float body = mix(0.4, 0.16, unknown);
	vec3 c = base * (body + fres * 1.5 + beat * 1.8 + flash * 1.6) * flick;
	ALBEDO = c * intensity * focus;
	ALPHA = clamp(mix(0.4, 0.22, unknown) + fres + flash * 0.4, 0.0, 1.0);
}
