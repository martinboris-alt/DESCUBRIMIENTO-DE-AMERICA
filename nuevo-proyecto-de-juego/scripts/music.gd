extends Node
## Autoload "Music": reproduce la pista del nivel en loop y expone la fase
## de beat para sincronizar visuales tipo Geometry Dash.

const TRACKS := {
	"level1": {"stream": "res://assets/audio/music_level1.wav", "bpm": 122.0},
	"level2": {"stream": "res://assets/audio/music_level2.wav", "bpm": 138.0},
	"level3": {"stream": "res://assets/audio/music_level3.wav", "bpm": 128.0},
	"boss": {"stream": "res://assets/audio/music_boss.wav", "bpm": 144.0},
}

signal beat(index: int)

var bpm := 120.0

var _player: AudioStreamPlayer
var _beats := 0.0
var _last_beat := -1
var _pulse := 0.0
var _cur := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -8.0
	add_child(_player)
	process_mode = Node.PROCESS_MODE_ALWAYS


func play_track(key: String) -> void:
	if key == _cur or key not in TRACKS:
		return
	_cur = key
	var info: Dictionary = TRACKS[key]
	bpm = info.bpm
	var stream: AudioStreamWAV = load(info.stream)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	_player.stream = stream
	_player.play()
	_last_beat = -1


func stop() -> void:
	_cur = ""
	_player.stop()


func _process(delta: float) -> void:
	if not _player.playing:
		_pulse = maxf(_pulse - delta * 3.0, 0.0)
		return
	var pos := _player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix()
	_beats = pos * bpm / 60.0
	var bi := int(_beats)
	if bi != _last_beat:
		_last_beat = bi
		_pulse = 1.0
		beat.emit(bi)
	_pulse = maxf(_pulse - delta * (bpm / 60.0) * 2.2, 0.0)


## 0..1 que salta a 1 en cada beat y decae: ideal para escalar/pulsar.
func pulse() -> float:
	return _pulse


## Onda suave continua sincronizada al beat (-1..1) para balanceos lentos.
func wave() -> float:
	return sin(_beats * PI)


func beats() -> float:
	return _beats
