class_name UiSounds
extends RefCounted
## Gives every button under a menu the same press, without every menu having to remember to.
##
## **A walker rather than a line in each button's script.** The menus are built from four different
## button classes and a handful of plain `Button`s made in code — the options tabs, the reset rows,
## the player in the corner. Teaching each of them to click would have missed the ones nobody
## thought of, which is exactly the set a player finds.
##
## Stateless and static, for the reason `SaveManager` is: there is nothing to own.


## Connects every button under `root`, including ones added since the last call. Safe to call twice
## — a button already armed is left alone rather than clicking twice.
static func arm(root: Node) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null or button.pressed.is_connected(_on_pressed):
			continue
		button.pressed.connect(_on_pressed)


static func _on_pressed() -> void:
	AudioManager.click()
