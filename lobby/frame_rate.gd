extends Label

const TIMER_LIMIT = 1.0
var timer = 0.0

func _process(delta):
	timer += delta
	if timer > TIMER_LIMIT:
		timer = 0.0
		text = str(Engine.get_frames_per_second()) + "FPS"
