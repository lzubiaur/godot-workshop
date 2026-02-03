# Player.gd
extends CharacterBody2D

func _on_gameover():
	$AnimatedSprite2D.modulate = Color(1.0, 0.2, 0.2)

func jump():
	$AnimationPlayer.stop(true)
	$AnimationPlayer.play("PlayerJump")
	$AnimationPlayer.queue("PlayerIdle")

func player_look_at(direction: Vector2):
	var delta = position.x - direction.x
	if abs(delta):
		$AnimatedSprite2D.flip_h = delta > 0
