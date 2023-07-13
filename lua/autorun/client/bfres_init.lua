

if not file.Exists("bfres", "DATA") then
	file.CreateDir("bfres", "DATA")
end

local doShowUI = CreateClientConVar("bfres_doshowui", 1, true, false, "Show the bfres UI on death", 0, 1)
local uiScale = CreateClientConVar("bfres_uiscale", 0.5, true, false, "Scale of bfres UI relative to screen size, may cause issues with map image quality", 0, 1)

local resHost = nil
local resMap = nil
local resIcons = nil
local resText = nil
local scaleMap = 10000      -- Scale of map
local coords = {}           -- Coordinates of spawnpoints
local focal = Vector()      -- Map focal point
local selected = 0
local retake = true

ratio = ScrW() / ScrH() -- Screen size ratio

-- Filename of respawn position icon (non/live)
local iconFN0 = "bfres01.png"
local iconFN1 = "bfres02.png"

function mapToScreenCoords( v2 )
	-- after messing about this for a couple hours, I found out a really specific transformation of the original coord is required bc we rotate the map by 90deg
	-- also, this eq. is long and awful
	local uis = uiScale:GetFloat()
	return Vector(
		uis * ScrW() * ( ( ( v2.x - focal.x ) / (2 * scaleMap * ratio) ) + .5 ),
		uis * ScrH() * ( ( ( focal.y - v2.y ) / (2 * scaleMap) ) + .5 )
	)
end

function setup( msg )
	-- Assign a buncha variables like the coords, the mapscale, etcs
	-- Store the coords
	for k, v in ipairs(msg) do
		if (k % 2 > 0) then
			-- If this is odd, add a new vec to the coords
			coords[ math.ceil( k / 2 ) ] = Vector()
			coords[ math.ceil( k / 2 ) ].x = v
		else
			coords[ math.ceil( k / 2 ) ].y = v
		end
	end

	if #coords < 1 then
	   resText:SetText( "ERROR: No info_player_start or similar entities on map!\n\tAre you on a custom gamemode map?" )
	else
		-- Average a focal point for the map
		for k, v in ipairs(coords) do
			focal = focal + v
		end
		focal.z = 0
		focal = focal / #coords

		-- Get map scale from all spawn positions
		minis = 0
		maxis = 0
		for i, p in ipairs(coords) do
			final = Vector(p.x, p.y)    -- bc apparently I can't just pass these by value
			final.y = -final.y
			final = final - focal
			minis = math.min( final.x, final.y, minis )
			maxis = math.max( final.x, final.y, maxis )
		end
		-- The scale has a minimum of 1000 
		scaleMap = math.max( maxis, -minis, 0 ) + 500
		resText:SetText( "Registered " .. #msg / 2 .. " spawnpoints.\nClick an icon to select spawnpoint. Select none to spawn somewhere random." )
	end
end

function captureNew( fname )
	-- Capture a new snapshot of the world from top down, save to file
	-- Codependent on internal scale values (patch better ways later snuss)
	mapbounds = Vector( scaleMap * ratio, scaleMap  )
	uis = uiScale:GetFloat()

	render.Clear( 0, 0, 0, 0 )
	render.ClearStencil()
	render.ClearDepth()
	render.SetLightingMode( 1 )
	render.FogMode( 0 )
	render.RenderView( {
		w =         ScrW() * uis,
		h =         ScrH() * uis,
		origin =    Vector(0, 0, 16384),
		angles =    Angle(90, 90, 0),
		znear =     20,
		zfar =      30000,
		ortho =     {
			left =      focal.x - mapbounds.x,
			right =     focal.x + mapbounds.x,
			top =       focal.y - mapbounds.y,
			bottom =    focal.y + mapbounds.y,
		},
		dopostprocess = false,
		drawviewmodel = false,
	} )
	data = render.Capture( {
		format =    "png",
		alpha =     true,
		w =         ScrW() * uis,
		h =         ScrH() * uis,
		dopostprocess = false,
	} )
	render.SetLightingMode( 0 )
	file.Write(fname, data)

end



function chgselected( id )
	-- The easy part
	selected = id
	-- The UI
	if resText then
		-- Update text element on UI
		if (selected > 0 and selected <= #coords) then -- forgot about the possibility of id being oob, yipe
			local selpos = coords[selected]
			resText:SetText( "Selected location: (" .. selpos.x .. ", " .. selpos.y .. ")\nClick anywhere outside window to respawn." )
		else
			resText:SetText( "No location selected. Random location will be picked instead.\nClick anywhere outside window to respawn." )
		end
	end
	if resIcons then
		-- Correct the icon visuals on the UI
		for _, v2 in ipairs( resIcons:GetChildren() ) do
			if v2.bfres_id then
				if v2.bfres_id == selected then
					-- Active location
					v2:SetImage( iconFN1 )
				else
					-- Inactive location
					v2:SetImage( iconFN0 )
				end
			end
		end
	end		-- gnarly 4 end chain
	-- Send using net
	sendselected()
end

function sendselected()
	net.Start( "bfres_respawnIndex" )
	net.WriteUInt( selected, 8 )
	net.SendToServer()
end

sendselected() -- do this once just to let the server know gmod deleted all the locals again

function ShowUI( msg )

	if selected != 0 then
		sendselected()
	end

	if not doShowUI:GetBool() then return end

	if resHost == nil then
		uis = uiScale:GetFloat()
		local quitter = vgui.Create( "DButton" )    -- literally use an invisible button to check if the user has clicked out the window
		resHost = vgui.Create( "DFrame" )
		resMap = vgui.Create( "DImage", resHost )
		resIcons = vgui.Create( "DPanel", resHost )
		resText = vgui.Create( "DLabel", resIcons )
		wid = ScrW() * uis
		hei = ScrH() * uis

		-- And thus, the massive config string begins
		resHost:SetTitle( "Respawn Dialog" )
		resHost:SetSize( wid + 8, hei + 32 )
		resHost:Center()
		resHost:SetDeleteOnClose( false )
		function resHost:Close()
			net.Start("bfres_respawnNow")
			net.SendToServer()
			self:Hide()
		end

		quitter:SetSize( ScrW(), ScrH() )
		quitter:SetAlpha( 0 )
		function quitter:DoClick()
			if resHost:IsVisible() then
				-- quitter shouldn't do anything if the menu is already hidden
				resHost:Close()
			end
		end

		resMap:SetSize( wid, hei )
		resMap:AlignBottom(4)
		resMap:CenterHorizontal()

		resIcons:SetSize( wid, hei )
		resIcons:AlignBottom(4)
		resIcons:CenterHorizontal()
		resIcons:SetPaintBackground( false )

		resText:SetFont( "HudHintTextSmall" )
		resText:SetSize( wid, 16 )
		resText:SetAutoStretchVertical( true )
		resText:AlignLeft(4)
		resText:AlignBottom(4)
		resText:SetText( "ERROR: This text should not appear! \n\tIf it does, please send a bug report to the github with\n\ta method and related console errors if they occur." )

		if msg != nil then
			setup( msg )
		end

		for i, v in ipairs(coords) do
			newic = resIcons:Add( "DImageButton" )

			newic:SetImage( iconFN0 )
			newic:SetSize(16, 16)

			newic.bfres_id = i

			function newic:DoClick()
				chgselected( self.bfres_id )    -- Change the selected spawnpoint to this one
			end
			postcalc = mapToScreenCoords( v )
			newic:SetPos( postcalc.x-8, postcalc.y-8 )
		end

		resHost:MakePopup()

	else
		resHost:Show()
	end

	local fname = "bfres/" .. game.GetMap() .. "_bfres.png"

	if retake or not file.Exists( fname, "DATA" ) then
		-- Get a new map
		captureNew(fname)
		retake = false
	end
	resMap:SetImage("../data/" .. fname)

end




net.Receive( "bfres_showUI", function( len, ply )
	local msg = {}
	if len != nil and len > 0 then
		for i = 1, (len / 15) do
			msg[i] = net.ReadInt(15)
		end
	else
		msg = nil
	end
	timer.Simple( 0.5, function()
		ShowUI(msg)
	end )
end )

function retakemap()
	-- Mark the map to be retaken
	retake = true
end

concommand.Add( "bfres_retakemap", retakemap, nil, "Retakes the respawn dialog map" )

function resetspawn()
	-- Reset spawn to default arrangement
	chgselected( 0 )
end

concommand.Add( "bfres_resetspawn", resetspawn, nil, "Reset spawn selection" )

function reset()
	-- Reset the widget
	resHost = nil
	resMap = nil
	resIcons = nil
	scaleMap = 10000
	coords = {}
	focal = Vector()
	selected = 0
	retake = true
end

concommand.Add("bfres_reset", reset, nil, "Reset all clientside variables")

-- en finale, toolmenu interface
hook.Add("AddToolMenuCategories", "bfres_optionsmake", function()
	spawnmenu.AddToolCategory("Options", "ConorSNES", "ConorSNES")
	spawnmenu.AddToolMenuOption("Options", "ConorSNES", "bfres_config", "Bfres Config", "", "", function( form )
		-- This is the menu.
		form:CheckBox("Show the UI on death", "bfres_doshowui")
		form:NumSlider("UI scale", "bfres_uiscale", 0, 1, 2)
		form:Help("Note: Changing the UI scale may affect map image quality.")
		form:Button("Retake map image", "bfres_retakemap")
		form:Button("Reset my spawn preferences", "bfres_resetspawn")
	end )
end )