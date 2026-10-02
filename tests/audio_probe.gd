extends Node
## Dev tool: builds the procedural sounds and reports build time, length and peak level.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var sfx: Node = load("res://scripts/core/sfx.gd").new()
	sfx._ready()
	print("Sfx build time: %d ms" % (Time.get_ticks_msec() - t0))
	for lazy_name in sfx._lazy.keys():
		sfx._stream(lazy_name)   # the sounds built on first use
	var names: Array = sfx._streams.keys()
	names.sort()
	for n in names:
		var wav: AudioStreamWAV = sfx._streams[n]
		var d := wav.data
		var peak := 0
		var sum_sq := 0.0
		for i in range(0, d.size(), 2):
			var v := d.decode_s16(i)
			peak = maxi(peak, absi(v))
			sum_sq += float(v) * float(v)
		var count := d.size() / 2
		print("%-20s %.2fs  peak %.2f  rms %.3f  %s" % [n, count / float(wav.mix_rate), peak / 32768.0, sqrt(sum_sq / count) / 32768.0, "loop" if wav.loop_mode != 0 else ""])
	get_tree().quit()
