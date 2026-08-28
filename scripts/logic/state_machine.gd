class_name CharacterStateMachine
extends RefCounted
## Phase 1 最简状态机：IDLE <-> WALK_TO。
## 后续可扩展 INTERACT / TALK。

enum State {
	IDLE,
	WALK_TO,
	INTERACT,
	TALK,
}

var state: State = State.IDLE


func change_state(new_state: State) -> void:
	state = new_state


func is_state(s: State) -> bool:
	return state == s
