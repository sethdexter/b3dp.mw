extends Node
class_name StateMachine

@export var currentCharacter: BaseCharacter

enum State {
	IDLE,
	MOVING,
	JUMPING
	}

var current_state: State = State.IDLE

func _ready():
	set_state(State.IDLE)

func _process(delta):                                    
	match current_state:
		State.IDLE:
			_handle_idle_state(delta)
		State.MOVING:
			_handle_moving_state(delta)
		State.JUMPING:
			_handle_jumping_state(delta)
			
	# Check for transitions (example)
	if Input.is_action_pressed("ui_right") || Input.is_action_pressed("ui_up") || Input.is_action_pressed("ui_down") || Input.is_action_pressed("ui_left"):
		set_state(State.MOVING)
	elif Input.is_action_just_pressed("ui_accept"):
		set_state(State.JUMPING)
	else:
		set_state(State.IDLE)

# Method to change state
func set_state(new_state: State):
	if current_state != new_state:
		exit_state(current_state)
		current_state = new_state
		enter_state(current_state)

# Method called when entering a state
func enter_state(state: State):
	match state:
		State.IDLE:
			print("Entering Idle State")
		State.MOVING:
			print("Entering Moving State")
		State.JUMPING:
			print("Entering Jumping State")

# Method called when exiting a state
func exit_state(state: State):
	match state:
		State.IDLE:
			print("Exiting Idle State")
		State.MOVING:
			print("Exiting Moving State")
		State.JUMPING:
			print("Exiting Jumping State")

# State-specific logic
func _handle_idle_state(delta):
	# Idle state behavior
	pass

func _handle_moving_state(delta):
	# Moving state behavior
	pass

func _handle_jumping_state(delta):
	# Jumping state behavior
	pass
