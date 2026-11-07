extends Node
## 短音效在启动时合成，不依赖外部音频文件。

const MIX_RATE := 22050
var muted := false
var streams: Dictionary = {}

func _ready() -> void:
	streams["stamp"] = _make_stream("stamp")
	streams["ok"] = _make_stream("ok")
	streams["bad"] = _make_stream("bad")
	streams["done"] = _make_stream("done")

func play(sound_name: String) -> void:
	if muted or not streams.has(sound_name):
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[sound_name]
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func _make_stream(kind: String) -> AudioStreamWAV:
	var duration := 0.16
	match kind:
		"bad": duration = 0.42
		"done": duration = 0.65
	var count := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	for i in range(count):
		var t := float(i) / MIX_RATE
		var k := t / duration
		var sample := 0.0
		match kind:
			"stamp":
				var frequency := lerpf(170.0, 90.0, k)
				sample = sin(TAU * frequency * t) * 0.42 * exp(-k * 5.0)
				if t < 0.055:
					sample += rng.randf_range(-1.0, 1.0) * 0.24 * (1.0 - t / 0.055)
			"ok":
				sample = sin(TAU * 784.0 * t) * 0.18 * sin(PI * k)
			"bad":
				var frequency := lerpf(220.0, 140.0, k)
				sample = (1.0 if sin(TAU * frequency * t) > 0 else -1.0) * 0.12 * (1.0 - k)
			"done":
				var notes := [784.0, 988.0, 1319.0]
				for note in range(3):
					var local := t - note * 0.12
					if local >= 0.0:
						sample += sin(TAU * notes[note] * local) * 0.11 * exp(-local * 7.0)
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
