class_name PixelLookData
extends Resource
## What the pixel look is tuned to. See `PixelLook` for what each figure does to the frame.

## How many rows of fat pixels the frame is cut into, whatever the window's resolution: 270 is a
## fat pixel four screen pixels across at 1080p and three at 720p, so the look is the same size on
## every screen rather than getting finer as the screen grows.
@export var rows: float = 270.0
## How much further a neighbour must be, as a share of a block's own distance, before the block is
## outlined. A share rather than metres so a silhouette reads the same close in and zoomed out; big
## enough that a blade of grass against the ground it stands in does not draw one.
@export_range(0.0, 1.0, 0.005) var depth_edge: float = 0.06
## How much of its colour an outlined block loses.
@export_range(0.0, 1.0, 0.01) var outline: float = 0.65
## How much brighter a block on a crease gets, and how sharply two faces must turn for one: the
## cosine of the angle between their normals.
@export_range(0.0, 1.0, 0.01) var highlight: float = 0.25
@export_range(-1.0, 1.0, 0.01) var crease: float = 0.8
## Steps per colour channel, in perceptual space. Nought leaves the palette alone.
@export var levels: float = 24.0
