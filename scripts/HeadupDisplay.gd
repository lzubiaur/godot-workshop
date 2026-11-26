# HeadupDisplay.gd
# Displays the game state: level, remaining time, level-up popup and game over panel.
# It only displays things: the game rules (timer, levels...) live in Game.gd
extends CanvasLayer

@onready var game = global.get_game()
@onready var time_bar = $TextureProgressBar
@onready var level_label = $LevelLabel
@onready var level_up_label = $LevelUpLabel
@onready var level_up_sound = $LevelUpSound
@onready var game_over_panel = $GameOverPanel
@onready var touch_controls = $CanvasLayer

var level_up_tween: Tween

func _ready():
	game.gameover.connect(_on_gameover)
	game.level_up.connect(_on_level_up)
	level_up_label.hide()
	game_over_panel.hide()
	update_level_label(game.level)

func _process(_delta):
	time_bar.value = game.time_left / game.max_time * 100.0

func update_level_label(level):
	level_label.text = "LEVEL %d" % level

func _on_level_up(level):
	update_level_label(level)

	# Show "LEVEL X" in the middle of the screen, then fade it out
	level_up_label.text = "LEVEL %d" % level
	level_up_label.modulate.a = 1.0
	level_up_label.show()
	if level_up_tween:
		level_up_tween.kill()
	level_up_tween = create_tween()
	level_up_tween.tween_interval(0.6)
	level_up_tween.tween_property(level_up_label, "modulate:a", 0.0, 0.4)
	level_up_tween.tween_callback(level_up_label.hide)

	# No sound asset yet: set the stream of LevelUpSound in HUD.tscn
	if level_up_sound.stream:
		level_up_sound.play()

func _on_gameover():
	touch_controls.hide()

func show_game_over(score, best):
	$GameOverPanel/GameOverLabel.text = "SCORE %d\nBEST %d\n\nTAP TO RETRY" % [score, best]
	game_over_panel.show()

func _on_game_over_panel_pressed() -> void:
	game.retry()

func _on_right_button_down() -> void:
	Input.action_press("Jump")

func _on_right_button_up() -> void:
	Input.action_release("Jump")

func _on_button_left_down() -> void:
	Input.action_press("Dash")

func _on_button_left_up() -> void:
	Input.action_release("Dash")
