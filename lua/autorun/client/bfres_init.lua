---@diagnostic disable: inject-field

-- assert cache dir
if not file.Exists("bfres", "DATA") then
	file.CreateDir("bfres")
end

-- cvars
local doShowUI = CreateClientConVar("bfres_doshowui", "1", true, false, "Show the bfres UI on death", 0, 1)
local uiScale = CreateClientConVar("bfres_uiscale", "0.5", true, false,
	"Scale of bfres UI relative to screen size, may cause issues with map image quality", 0, 1)
--[[ local doQuickSelect = CreateClientConVar("bfres_doquickselect", "0", true, false,
	"Immediately respawn after interacting with the spawn selector", 0, 1) ]]
local allowSelect = GetConVar("bfres_allowselect")

-- constants
local ICON_INACTIVE = "bfres01.png"
local ICON_ACTIVE = "bfres02.png"
local ICON_RESET = "bfresreset.png"
local COL_LABEL_BG = Color(0, 0, 0, 77)

-- derived
local function get_ratio()
	-- Screen size ratio
	return ScrW() / ScrH()
end

-- state
local doMapRetake = true
local doRegeneratePoints = true

local function request_spawns()
	net.Start("bfres_requestSpawns")
	net.SendToServer()
end

local coords = {
	_todo = {}
} -- managed access to coordinate data
function coords.fetch(onLoad)
	if coords._inner == nil then
		table.insert(coords._todo, onLoad)
		request_spawns()
	else
		onLoad(coords._inner)
	end
end

function coords.assign(msg)
	coords._inner = {}
	for k, v in ipairs(msg) do
		if (k % 2 > 0) then
			-- If this is odd, add a new vec to the coords
			coords._inner[math.ceil(k / 2)] = Vector()
			coords._inner[math.ceil(k / 2)].x = v
		else
			coords._inner[math.ceil(k / 2)].y = v
		end
	end

	print("[bfres] Collected " .. #(coords._inner) .. " spawnpoints")

	if #(coords._todo) > 0 then
		for _, todo in pairs(coords._todo) do
			todo(coords._inner)
		end
		coords._todo = {}
	end
end

local coords_derived = {} -- managed access to values derived from the coordinate data (mapscale)
function coords_derived.fetch(onLoad)
	if coords_derived._inner == nil then
		coords_derived.derive(onLoad)
	else
		onLoad(coords_derived._inner)
	end
end

function coords_derived.derive(onLoad)
	coords.fetch(function(coord)
		coords_derived._inner = {}
		local focal = Vector()
		-- Average a focal point for the map
		for _, v in ipairs(coord) do
			focal:Add(v)
		end
		focal.z = 0
		focal = focal / #coord

		coords_derived._inner.focal = focal

		-- Get map scale from all spawn positions
		local minis, maxis = 0, 0
		for _, p in ipairs(coord) do
			local finalx = p.x - focal.x
			local finaly = p.y - focal.y
			minis = math.min(finalx, finaly, minis)
			maxis = math.max(finalx, finaly, maxis)
		end
		-- The scale has a minimum of 1000
		coords_derived._inner.map_scale = math.max(maxis, -minis, 0) + 100

		onLoad(coords_derived._inner)
	end)
end

-- Text overlay message handler.
local text_overlay = {
	_labelcontent = "Respawning at random location.",
	_widgets = {}
}
function text_overlay.setWidget(key, value)
	text_overlay._widgets[key] = value
	if text_overlay._labelcontent then value:SetText(text_overlay._labelcontent) end
end

function text_overlay.updateLabel(value)
	text_overlay._labelcontent = value
	for _, v in pairs(text_overlay._widgets) do
		v:SetText(text_overlay._labelcontent)
	end
end

-- Selection state handler. Implements the subscriber pattern.
local selected = {
	_inner = 0,
	_subscribers = {}
}
function selected.get()
	return selected._inner
end

function selected.set(value)
	selected._inner = value

	-- run all subscriber values
	for _, v in pairs(selected._subscribers) do
		v(value)
	end
end

function selected.subscribe(id, todo)
	-- add/override subscriber to this value
	selected._subscribers[id] = todo
end

-- do this once to keep the server in the loop
selected.set(0)
-- add subscriber for sending net messages for every update
selected.subscribe("netmessage", function(v)
	net.Start("bfres_respawnIndex")
	net.WriteUInt(v, 8)
	net.SendToServer()
end)
-- add another for updating the label with every change to the selection
selected.subscribe("labelupdate", function(v)
	if v == 0 then
		text_overlay.updateLabel("Respawning at random location.")
	else
		coords.fetch(function(coord)
			local thispoint = coord[v]
			text_overlay.updateLabel("Respawning at (" .. thispoint.x .. ", " .. thispoint.y .. ")")
		end)
	end
end)


local function map_to_screen_coords(v2, focal, scaleMap)
	-- after messing about this for a couple hours, I found out a really specific transformation of the original coord is required bc we rotate the map by 90deg
	-- also, this equ. is long and awful
	local uis = uiScale:GetFloat()
	local ratio = get_ratio()
	return Vector(
		uis * ScrW() * (((v2.x - focal.x) / (2 * scaleMap * ratio)) + .5),
		uis * ScrH() * (((focal.y - v2.y) / (2 * scaleMap)) + .5)
	)
end

local function captureNew(fname, focal, scaleMap)
	-- Capture a new snapshot of the world from top down, save to file
	-- Codependent on internal scale values (patch better ways later snuss)
	local mapbounds = Vector(scaleMap * get_ratio(), scaleMap)
	local uis = uiScale:GetFloat()

	render.Clear(0, 0, 0, 0)
	render.ClearStencil()
	render.ClearDepth()
	render.SetLightingMode(1)
	render.FogMode(0)
	render.RenderView({
		w = ScrW() * uis,
		h = ScrH() * uis,
		origin = Vector(0, 0, 16384),
		angles = Angle(90, 90, 0),
		znear = 20,
		zfar = 30000,
		ortho = {
			left = focal.x - mapbounds.x,
			right = focal.x + mapbounds.x,
			top = focal.y - mapbounds.y,
			bottom = focal.y + mapbounds.y,
		},
		dopostprocess = false,
		drawviewmodel = false,
	})
	local data = render.Capture({
		format = "png",
		alpha = true,
		w = ScrW() * uis,
		h = ScrH() * uis,
		dopostprocess = false,
	})
	render.SetLightingMode(0)
	file.Write(fname, data)
end

-- Net handlers;
local function request_respawn_now()
	net.Start("bfres_respawnNow")
	net.SendToServer()
end

-- UI code;

local _selectmap_cache = nil

-- Show full screen map allowing selection of a particular respawn point
local function show_selection_map()
	local map_fname = "bfres/" .. game.GetMap() .. "_bfres.png"

	if _selectmap_cache == nil then
		local root = vgui.Create("DPanel")
		local quitter = vgui.Create("DButton")
		local map = vgui.Create("DImage", root)
		local iconlayer = vgui.Create("DButton", root)
		local resetbutton = vgui.Create("DImageButton", root)
		local selectedlabel = vgui.Create("DLabel", root)
		local helplabel = vgui.Create("DLabel", root)

		-- cache these widgets
		_selectmap_cache = {}
		_selectmap_cache.root = root
		_selectmap_cache.map = map
		_selectmap_cache.iconlayer = iconlayer
		text_overlay.setWidget("map_hint", selectedlabel)


		function root:FancyHide()
			root:AlphaTo(0, 0.1, nil, function()
				root:Hide()
			end)
		end

		function iconlayer:GeneratePoints()
			-- Defer adding some elements until the coords are loaded
			coords.fetch(function(coord)
				coords_derived.fetch(function(derived)
					-- set the points on UI
					for i, v in ipairs(coord) do
						local newic = vgui.Create("DImageButton", iconlayer)

						newic:SetSize(16, 16)

						newic.bfres_id = i

						function newic:DoClick()
							selected.set(self.bfres_id) -- Change the selected spawnpoint to this one
						end

						function newic:DoRightClick()
							root:FancyHide()
						end

						local postcalc = map_to_screen_coords(v, derived.focal, derived.map_scale)
						newic:SetPos(postcalc.x - 8, postcalc.y - 8)
					end

					-- once all ui points exist on hud, assign their icons
					local function icon_assign()
						local curr_selected = selected.get()
						for _, v in pairs(iconlayer:GetChildren()) do
							if v.bfres_id then
								local icon
								if v.bfres_id == curr_selected then
									icon = ICON_ACTIVE
								else
									icon = ICON_INACTIVE
								end
								v:SetImage(icon)
							end
						end
					end
					icon_assign()
					selected.subscribe("icon_assign", icon_assign)

					-- if we're to set a new map image...
					if doMapRetake or not file.Exists(map_fname, "DATA") then
						-- retake it and assert.
						captureNew(map_fname, derived.focal, derived.map_scale)
						doMapRetake = false
						_selectmap_cache.map:SetImage("../data/" .. map_fname)
					end
				end)
			end)
		end

		function root:PerformLayout(panel_w, panel_h)
			map:SetSize(panel_w, panel_h)

			iconlayer:SetSize(panel_w, panel_h)

			selectedlabel:SetSize(panel_w, 16)
			selectedlabel:SetAutoStretchVertical(true)
			selectedlabel:AlignLeft(8)
			selectedlabel:AlignTop(8)

			helplabel:SetSize(panel_w, 16)
			helplabel:SetAutoStretchVertical(true)
			helplabel:AlignLeft(8)
			helplabel:AlignBottom(8)

			resetbutton:SetSize(16, 16)
			resetbutton:AlignRight(16)
			resetbutton:AlignTop(16)
		end

		function root:OnScreenSizeChanged(oldWidth, oldHeight, newWidth, newHeight)
			local uis = uiScale:GetFloat()
			local wid = newWidth * uis
			local hei = newHeight * uis

			root:SetSize(wid, hei)
			root:Center()
		end

		root:OnScreenSizeChanged(0, 0, ScrW(), ScrH())
		root:SetBackgroundColor(color_black)

		-- rescale the menu when the ui scale is tinkered with
		cvars.AddChangeCallback("bfres_uiscale", function(convar, old, new)
			doMapRetake = true
			doRegeneratePoints = true
			root:OnScreenSizeChanged(0, 0, ScrW(), ScrH())
		end)

		quitter:SetSize(ScrW(), ScrH())
		quitter:SetAlpha(0)
		quitter:MoveToBack()
		quitter:SetCursor("pointer")
		function quitter:DoClick()
			root:FancyHide()
		end

		iconlayer:SetPaintBackground(false)
		iconlayer:SetText("")
		iconlayer:SetCursor("arrow")
		function iconlayer:DoRightClick()
			root:FancyHide()
		end

		resetbutton:SetImage(ICON_RESET)
		function resetbutton:DoClick()
			selected.set(0)
		end

		function resetbutton:DoRightClick()
			iconlayer:DoRightClick()
		end

		-- The resetter is invisible when the selected spawn is 0.
		resetbutton:SetVisible(selected:get() ~= 0)
		selected.subscribe("resetbutton_react", function(v)
			resetbutton:SetVisible(v ~= 0)
		end)

		selectedlabel:SetFont("HudHintTextLarge")

		helplabel:SetFont("HudHintTextLarge")
		helplabel:SetText("[rmb] to close")

		iconlayer:GeneratePoints()
	else
		-- like during construction, if we're to set a new map image...
		if doMapRetake or not file.Exists(map_fname, "DATA") then
			coords_derived.fetch(function(derived)
				-- retake it and assert.
				captureNew(map_fname, derived.focal, derived.map_scale)
				doMapRetake = false
				_selectmap_cache.map:SetImage("../data/" .. map_fname)
			end)
		end

		if doRegeneratePoints then
			if _selectmap_cache.iconlayer:HasChildren() then
				_selectmap_cache.iconlayer:Clear()
				_selectmap_cache.iconlayer:MoveToFront()
				_selectmap_cache.iconlayer:GeneratePoints()
			end
		end
	end

	_selectmap_cache.root:SetAlpha(0)
	_selectmap_cache.root:AlphaTo(255, 0.1)
	_selectmap_cache.root:MakePopup()
	_selectmap_cache.root:MoveToFront()
	_selectmap_cache.root:Show()
end
local function hide_selection_map()
	if _selectmap_cache then
		_selectmap_cache.root:FancyHide()
	end
end
local function selection_map_visible()
	if _selectmap_cache == nil then return false end
	return _selectmap_cache.root:IsVisible()
end
local function toggle_selection_map()
	if selection_map_visible() then
		hide_selection_map()
		return
	else
		show_selection_map()
	end
end


local _overlay_cache = nil

-- Show the "overview" overlay to remind user of their respawn preference
local function show_overlay()
	if ! doShowUI:GetBool() then return end

	if _overlay_cache == nil then
		local root           = vgui.Create("DPanel")
		local label          = vgui.Create("DLabel", root)
		local keybindlabel   = vgui.Create("DLabel", root)
		-- cache UI references (do not delete these elements)
		_overlay_cache       = {}
		_overlay_cache.root  = root
		_overlay_cache.label = label
		text_overlay.setWidget("overlay_label", label)

		local WIDTH = ScrW() * 0.3
		local HEIGHT = 50

		root:SetSize(WIDTH, HEIGHT)
		root:Center()
		root:AlignBottom(8)
		root:SetBackgroundColor(COL_LABEL_BG)

		local keybindlabel_text = "Press Alt-Fire (+attack2) to select spawn point"
		keybindlabel:SetText(keybindlabel_text)
		keybindlabel:SetWidth(WIDTH - 16)
		keybindlabel:SetBright(true)
		keybindlabel:SetFont("HudHintTextLarge")
		keybindlabel:AlignBottom(4)
		keybindlabel:AlignLeft(8)

		label:SetWidth(WIDTH - 16)
		label:SetFont("HudHintTextLarge")
		label:MoveAbove(keybindlabel, 4)
		label:AlignLeft(8)
	end
	_overlay_cache.root:Show()
end

local function hide_all()
	if _overlay_cache ~= nil then
		_overlay_cache.root:Hide()
	end
	hide_selection_map()
end

-- listeners

-- The server sends the spawnpoint array to this client.
net.Receive("bfres_handleSpawns", function(len, ply)
	local msg = {}
	if len ~= nil and len > 0 then
		for i = 1, (len / 15) do
			msg[i] = net.ReadInt(15)
		end
	else
		error("Recieved a bfres_handleSpawns without a body!")
	end
	-- After raw parsing, pass these to initialize the coords struct.
	coords.assign(msg)
end)
-- perform a spawn request right from the start
request_spawns()

-- The server requests the overlay be shown (player is dead).
net.Receive("bfres_showUI", function(len, ply)
	show_overlay()
end)

-- The server requests all overlays be hidden (player is revived).
net.Receive("bfres_hideUI", function(len, ply)
	hide_all()
end)

-- client event hooks

-- Listens to input when dead for triggering respawns or showing selection menu.
local function bfres_respawnAttemptListener(ply, key)
	if ply:Alive() then return end          -- early exit- player is not dead
	if ! allowSelect:GetBool() then return end -- no use processing input if selection is disallowed
	if selection_map_visible() then return end -- do not interpret input if the selector is visible

	if (bit.band(key, bit.bor(IN_ATTACK, IN_JUMP)) > 0) then
		-- Generic respawn action. Hides overlaid menus.
		request_respawn_now()
		hide_all()
	elseif (bit.band(key, IN_ATTACK2) > 0) then
		-- When the user presses rmb, toggle selection map
		-- Do this with a literal one-frame delay to avoid the map INSTANTLY hiding itself
		timer.Simple(0, toggle_selection_map)
	end
end
hook.Add("KeyPress", "bfres_respawnAttemptListener", function(ply, key)
	-- wrap this just in case it messes with other mods
	bfres_respawnAttemptListener(ply, key)
end)

-- concommands

local function resetspawn()
	-- Reset spawn to default arrangement
	selected.set(0)
end

concommand.Add("bfres_resetspawn", resetspawn, nil, "Reset spawn selection")

concommand.Add("bfres_retakemap", function()
	doMapRetake = true
end, nil, "Retakes the respawn dialog map")

concommand.Add("bfres_requestRespawn", request_respawn_now, nil, "Request respawn from server")

concommand.Add("bfres_openspawn", show_selection_map, nil, "Open spawn selector menu")
