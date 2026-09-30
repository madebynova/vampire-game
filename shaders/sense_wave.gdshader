shader_type spatial;
// Full-screen post effect (quad parented to the camera): an expanding world-space ring that
// "scans" the environment for Vampiric Sense. Reconstructs world position from the depth buffer.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 origin = vec3(0.0);
uniform float radius = 0.0;
uniform float strength = 0.0;
uniform float thickness = 1.1;
uniform vec4 ring_color : source_color = vec4(1.0, 0.08, 0.14, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	float d = distance(world, origin);
	float ring = smoothstep(thickness, 0.0, abs(d - radius));
	float wake = smoothstep(radius - 9.0, radius, d) * step(d, radius) * 0.10;
	float not_sky = step(0.00001, depth);
	ALBEDO = ring_color.rgb * (1.0 + ring * 1.5);
	ALPHA = clamp((ring * 0.85 + wake) * strength * not_sky, 0.0, 1.0);
}
