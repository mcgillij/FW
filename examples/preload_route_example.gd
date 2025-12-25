extends Node

# Example: Preload a list of resources then route to the main scene.

func start_example(preload_queue, scene_router):
	preload_queue.connect("completed", Callable(self, "_on_preload_done"))
	preload_queue.start(["res://scenes/level1.tscn", "res://scenes/common.tres"])
	self._scene_router = scene_router

func _on_preload_done():
	# After all resources are ready, route
	_scene_router.change_scene("res://scenes/level1.tscn")
