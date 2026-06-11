extends Node
## Autoload "Sfx": reproductor central de efectos con pool de players.

const SOUNDS := {
	"coin": preload("res://assets/audio/coin.wav"),
	"crate": preload("res://assets/audio/crate.wav"),
	"jump": preload("res://assets/audio/jump.wav"),
	"bounce": preload("res://assets/audio/bounce.wav"),
	"land": preload("res://assets/audio/land.wav"),
	"spin": preload("res://assets/audio/spin.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"enemy_die": preload("res://assets/audio/enemy_die.wav"),
	"checkpoint": preload("res://assets/audio/checkpoint.wav"),
	"idol": preload("res://assets/audio/idol.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"lose": preload("res://assets/audio/lose.wav"),
	"tnt_tick": preload("res://assets/audio/tnt_tick.wav"),
	"tnt_boom": preload("res://assets/audio/tnt_boom.wav"),
	"step": preload("res://assets/audio/step.wav"),
}

const POOL_SIZE := 10

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

	_ambient = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/ambient.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		_ambient.stream = stream
		_ambient.volume_db = -10.0
	add_child(_ambient)
	_ambient.play()


func play(name_: String, vol_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if name_ not in SOUNDS:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = SOUNDS[name_]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
