class_name MusicPlayerWidget
extends PanelContainer
## The soundtrack in the top-right corner: what is playing, a switch to silence it, and a button for
## the next one. It sits above the wave chip in the fight and in the same place in every menu, so it
## is one row the player learns once.
##
## **It reads the jukebox and never owns anything.** What is playing, whether it is muted and what
## happens next are all `AudioManager`'s; this draws them. Two of these on screen at once — the
## title behind the options overlay, say — therefore agree rather than fighting.
##
## **It disappears when there is no soundtrack.** An empty playlist is the shipped state until the
## music is delivered, and a player showing nothing with two dead buttons is worse than no player:
## it reads as broken rather than as absent.

## What the buttons say. Words rather than glyphs: these are real buttons in a chip the size of the
## wave chip, and the mute one names what pressing it does rather than the state it is already in.
const MUTE_KEY: String = "MUSIC_MUTE"
const UNMUTE_KEY: String = "MUSIC_UNMUTE"
const NEXT_KEY: String = "MUSIC_NEXT"

@onready var title: Label = $Row/Title
@onready var mute: Button = $Row/Mute
@onready var next: Button = $Row/Next


func _ready() -> void:
	mute.pressed.connect(_on_mute_pressed)
	next.pressed.connect(_on_next_pressed)
	next.text = tr(NEXT_KEY)
	EventBus.music_track_changed.connect(_on_track_changed)
	EventBus.music_muted.connect(_on_muted)
	_refresh()


## Pulls the row back in line with the jukebox. Called on arrival as well as on every change, so a
## widget that appears mid-track shows that track rather than waiting for the next one.
func _refresh() -> void:
	var box := AudioManager.jukebox()
	if box == null or not box.has_music():
		visible = false
		return
	visible = true
	mute.text = tr(UNMUTE_KEY) if box.is_muted() else tr(MUTE_KEY)
	next.disabled = box.is_muted()
	var track := box.now_playing()
	# Muted is not "nothing is playing": the player asked for silence and the row says so, rather
	# than going blank as though the soundtrack had run out.
	if box.is_muted():
		title.text = tr("MUSIC_MUTED")
		return
	title.text = track.billing() if track != null else tr("MUSIC_NONE")


func _on_mute_pressed() -> void:
	var box := AudioManager.jukebox()
	if box != null:
		box.toggle_mute()


func _on_next_pressed() -> void:
	var box := AudioManager.jukebox()
	if box != null:
		box.skip()


func _on_track_changed(_track: MusicTrack) -> void:
	_refresh()


func _on_muted(_muted: bool) -> void:
	_refresh()
