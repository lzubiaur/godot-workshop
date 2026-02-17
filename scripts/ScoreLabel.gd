extends Label

func _ready():
	global.get_game().connect("player_step", Callable(self, "_on_player_step"))
	# BMFont has to be load from code for now (should be fixed in 3.1)
	#get_font("font").create_from_fnt('res://assets/fonts/BoxyBold_16px.fnt')
	update_score()
	
func update_score():
	text = String.num(global.score)
	bounce()

func bounce():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
func _on_player_step(step_count):
	update_score()
