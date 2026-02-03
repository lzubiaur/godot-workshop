extends Label

func _ready():
	global.get_game().connect("player_step", Callable(self, "_on_player_step"))
	# BMFont has to be load from code for now (should be fixed in 3.1)
	#get_font("font").create_from_fnt('res://assets/fonts/BoxyBold_16px.fnt')
	update_score()
	
func update_score():
	text = String.num(global.score)

func _on_player_step(step_count):
	update_score()
