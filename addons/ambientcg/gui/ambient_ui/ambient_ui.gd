@tool class_name AmbientUI extends Control

const BROWSER_WIDGET = preload("res://addons/ambientcg/gui/browser_widget/browser_widget.tscn")

@onready var search_result_count: Label = %SearchResultCount
@onready var api_version_info_label: Label = %APIVersionInfo

@onready var type_options: OptionButton = %TypeOptions
@onready var search_bar: LineEdit = %SearchBar
@onready var material_browser: Panel = %MaterialBrowser
@onready var search_scroll: ScrollContainer = %SearchScroll
@onready var search_grid: GridContainer = %SearchGrid
@onready var searching_indicator: Label = %SearchingIndicator

var type_text : String

var v_scroll_bar : VScrollBar

var next_query_uri : String

var last_search_result : Dictionary

var awaiting_search_finish : bool = false
var active : bool = false

func open() -> void:
	last_search_result.clear()
	next_query_uri = ""
	awaiting_search_finish = false
	active = true
	
	connect_signals()
	
	await AmbientAPI.api_init()
	
	api_version_info_label.text = AmbientParser.api_info_to_version_string(AmbientAPI.api_information)
	AmbientParser.api_info_to_option_button(type_options, AmbientAPI.api_information)
	
	search(search_bar.text)


func connect_signals():
	resized.connect(_resized)
	get_window().size_changed.connect(_resized)
	
	_resized()
	
	type_options.item_selected.connect(type_selected.bind(type_options))
	search_bar.text_submitted.connect(search.bind(false))


func _process(delta: float) -> void:
	if (not visible): return
	if v_scroll_bar == null: v_scroll_bar = search_scroll.get_v_scroll_bar()
	else:
		var current_y = v_scroll_bar.size.y + v_scroll_bar.value
		var should_load_more = current_y > v_scroll_bar.max_value * 0.8
		
		if should_load_more and not awaiting_search_finish:
			search("", true)
	
	%SearchingIndicator.visible = awaiting_search_finish

func _resized() -> void:
	search_grid.columns = floor(size.x / 130.0)


func type_selected(index : int, button : OptionButton) -> void:
	type_text = button.get_item_text(index)
	search(search_bar.text, false)


func search(search_query : String = "", use_next_query : bool = false):
	if not active: return
	var use_shortlink : bool = false
	
	# this is broken ignore it.
	# but it should assume its a shortlink and automatically find the download https://github.com/VenitStudios/AmbientCG/issues/7
	#if search_query.containsn("https://ambientcg.com/a/"):
		#use_shortlink = true
		#search_query = search_query.replacen("https://ambientcg.com/a/", "")
	
	awaiting_search_finish = true
	
	var search_result := await AmbientAPI.search_assets(search_query, type_text, next_query_uri if use_next_query else "")
	
	# avoid parsing if awaiting_search_finish is false, can happen if a new search is started while waiting for a response
	if awaiting_search_finish: 
		var parsed := AmbientParser.parse_search_query_data(search_result)
		last_search_result = parsed
		next_query_uri = parsed.get("next_query_uri", "")
		create_search_results(parsed, not use_next_query)
		
		search_result_count.text = "%s Results Found" % int(parsed.get("result_count_total", 0)) 
	else:
		search_result_count.text = ""
	
	awaiting_search_finish = false

func clear_search_results() -> void:
	for c in search_grid.get_children():
		c.queue_free()


func create_search_results(data : Dictionary, clear : bool) -> void:
	if clear: 
		clear_search_results()
	
	await get_tree().process_frame
	
	for asset in data.get("assets"):
		var widget : AmbientBrowserWidget = BROWSER_WIDGET.instantiate()
		widget.material_json = asset
		widget.update(self)
		
		search_grid.add_child(widget)

signal pop_up_closed(accepted: bool)
func popup_accept(title: String, content: String, ok_text:="Ok", cancel_text:="Cancel") -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	add_child(dialog)
	dialog.visible = true
	dialog.title = title
	dialog.dialog_text = content
	
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = cancel_text
	
	dialog.canceled.connect(pop_up_closed.emit.bind(false))
	dialog.confirmed.connect(pop_up_closed.emit.bind(true))
	
	var result: bool = await pop_up_closed
	dialog.queue_free()
	
	return result
