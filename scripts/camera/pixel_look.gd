@tool
class_name PixelLook
extends CompositorEffect
## The frame as pixel art: the finished 3D image cut into fat pixels, outlined along silhouettes and
## lit along creases, with a slightly smaller palette. The interface is drawn after it and stays
## sharp.
##
## **A compositor effect, not a screen-space quad and not a low-resolution viewport.** A quad that
## reads the screen texture reads it before the transparent pass — the sea, the blood decals and
## every particle would be drawn over the pixel art, unstyled. A small `SubViewport` would put the
## whole world one viewport away from the input that aims into it and from every check that asks a
## camera where something is. After the transparent pass, with the depth and normal buffers in hand,
## is the one place where the frame is both finished and still three-dimensional.
##
## It does nothing without a rendering device, which is what the headless checks run on, so the game
## they check is the same game minus a look.

const SHADER: String = "res://assets/shaders/pixel_look.glsl"
const BLIT: String = "res://assets/shaders/pixel_look_blit.glsl"
const GROUP: int = 8
## The option that switches the look off, in Video.
const SETTING: StringName = &"video_pixel_look"

var look: PixelLookData = preload("res://data/fx/pixel_look.tres")

var _device: RenderingDevice = null
var _shader: RID
var _pipeline: RID
var _blit_shader: RID
var _blit_pipeline: RID
var _sampler: RID
var _stylised: RID
var _stylised_size: Vector2i = Vector2i.ZERO


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_normal_roughness = true
	_device = RenderingServer.get_rendering_device()
	if _device != null:
		RenderingServer.call_on_render_thread(_build)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _device == null:
		return
	for rid: RID in [_stylised, _sampler, _pipeline, _shader, _blit_pipeline, _blit_shader]:
		if rid.is_valid():
			_device.free_rid(rid)


## Puts the look on a camera. On the camera rather than on the world's environment, because the
## environment belongs to the sky and the hour, and the look belongs to how the game is framed.
static func attach(camera: Camera3D) -> void:
	if camera == null:
		return
	var compositor := Compositor.new()
	compositor.compositor_effects = [PixelLook.new()]
	camera.compositor = compositor


func _render_callback(_type: int, render_data: RenderData) -> void:
	if _device == null or not _pipeline.is_valid() or look == null:
		return
	# Asked every frame rather than told, the way every setting is read: switching it off in the
	# options leaves the effect on the camera doing nothing, and switching it back on needs nothing.
	var wanted := bool(Settings.get_value(SETTING))
	# **And the buffer goes with it.** Returning here spares the two dispatches and nothing else:
	# the renderer has already run its depth prepass in normal-roughness mode and allocated a
	# full-screen target for a callback that never reads it, at 1080p, whether one farmer is on
	# screen or thirty. The renderer reads this when it prepares a frame, so the change lands on the
	# next one — one frame of a buffer nobody wanted, against a menu toggle nobody is watching.
	if needs_normal_roughness != wanted:
		needs_normal_roughness = wanted
	if not wanted:
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene := render_data.get_render_scene_data() as RenderSceneDataRD
	if buffers == null or scene == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	_ensure_stylised(size)
	var pixel := maxf(roundf(float(size.y) / look.rows), 1.0)
	var groups := Vector2i(ceili(size.x / float(GROUP)), ceili(size.y / float(GROUP)))
	for view: int in buffers.get_view_count():
		var colour := buffers.get_color_layer(view)
		var depth := buffers.get_depth_layer(view)
		var normal := buffers.get_texture("forward_clustered", "normal_roughness")
		var inverse := Projection(scene.get_view_projection(view)).inverse()
		_stylise(colour, depth, normal, size, pixel, inverse, groups)
		_copy_back(colour, size, groups)


func _build() -> void:
	_shader = _compile(SHADER)
	_blit_shader = _compile(BLIT)
	if not _shader.is_valid() or not _blit_shader.is_valid():
		return
	_pipeline = _device.compute_pipeline_create(_shader)
	_blit_pipeline = _device.compute_pipeline_create(_blit_shader)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _device.sampler_create(state)


func _compile(path: String) -> RID:
	var file := load(path) as RDShaderFile
	if file == null:
		return RID()
	return _device.shader_create_from_spirv(file.get_spirv())


func _ensure_stylised(size: Vector2i) -> void:
	if _stylised.is_valid() and _stylised_size == size:
		return
	if _stylised.is_valid():
		_device.free_rid(_stylised)
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)
	_stylised = _device.texture_create(format, RDTextureView.new())
	_stylised_size = size


func _stylise(
	colour: RID,
	depth: RID,
	normal: RID,
	size: Vector2i,
	pixel: float,
	inverse: Projection,
	groups: Vector2i
) -> void:
	var constants := PackedFloat32Array(
		[
			size.x,
			size.y,
			pixel,
			look.depth_edge,
			look.outline,
			look.highlight,
			look.crease,
			look.levels,
		]
	)
	for column: Vector4 in [inverse.x, inverse.y, inverse.z, inverse.w]:
		constants.append_array([column.x, column.y, column.z, column.w])
	var uniforms: Array[RDUniform] = [
		_sampled(0, colour), _sampled(1, depth), _sampled(2, normal), _image(3, _stylised)
	]
	var bound := UniformSetCacheRD.get_cache(_shader, 0, uniforms)
	var list := _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(list, _pipeline)
	_device.compute_list_bind_uniform_set(list, bound, 0)
	var bytes := constants.to_byte_array()
	_device.compute_list_set_push_constant(list, bytes, bytes.size())
	_device.compute_list_dispatch(list, groups.x, groups.y, 1)
	_device.compute_list_end()


func _copy_back(colour: RID, size: Vector2i, groups: Vector2i) -> void:
	var bytes := PackedFloat32Array([size.x, size.y, 0.0, 0.0]).to_byte_array()
	var uniforms: Array[RDUniform] = [_image(0, _stylised), _image(1, colour)]
	var bound := UniformSetCacheRD.get_cache(_blit_shader, 0, uniforms)
	var list := _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(list, _blit_pipeline)
	_device.compute_list_bind_uniform_set(list, bound, 0)
	_device.compute_list_set_push_constant(list, bytes, bytes.size())
	_device.compute_list_dispatch(list, groups.x, groups.y, 1)
	_device.compute_list_end()


func _sampled(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(_sampler)
	uniform.add_id(texture)
	return uniform


func _image(binding: int, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(texture)
	return uniform
