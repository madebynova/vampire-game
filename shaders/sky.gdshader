shader_type sky;
// Time-of-day sky: gradient, sun and moon discs, stars. All inputs come from WorldAtmosphere.

uniform vec3 sky_top : source_color = vec3(0.2, 0.42, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.8, 0.9);
uniform vec3 ground_color : source_color = vec3(0.12, 0.09, 0.1);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float star_strength = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.45));
	col = mix(col, ground_color, smoothstep(0.0, -0.25, h));

	// Sun: bright disc + warm halo that hugs the horizon at sunset.
	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	float sun_up = smoothstep(-0.12, 0.05, sun_dir.y);
	col += sun_color * (smoothstep(0.9994, 0.9998, sd) * 5.0 + pow(sd, 48.0) * 0.6 + pow(sd, 6.0) * 0.12) * sun_up;

	// Moon.
	float md = max(dot(dir, normalize(moon_dir)), 0.0);
	float moon_up = smoothstep(-0.12, 0.05, moon_dir.y);
	col += vec3(0.75, 0.8, 0.95) * (smoothstep(0.9993, 0.9996, md) * 2.2 + pow(md, 80.0) * 0.25) * moon_up;

	// Stars (fade near the horizon and where the moon glows).
	vec3 cell = floor(dir * 260.0);
	float r = hash(cell);
	float twinkle = 0.6 + 0.4 * sin(TIME * 2.0 + r * 60.0);
	float star = step(0.9975, r) * twinkle;
	col += vec3(star) * star_strength * smoothstep(0.02, 0.25, h) * (1.0 - pow(md, 30.0));

	COLOR = col;
}
