extends Node

# Example patterns for FW_StateMachine

class GuardState:
	func on_enter(prev, data):
		# check preconditions carried in `data`
		if data and data.get("ok", false):
			print("guard passed")
		else:
			print("guard failed")

class EventedState:
	func on_event(ev):
		if ev == "doit":
			print("event handled")

func example(sm):
	sm.add_state(&"guard", GuardState.new())
	sm.add_state(&"evented", EventedState.new())
	sm.start(&"guard", {"ok": true})
	sm.transition_to(&"evented")
	sm.send_event("doit")
