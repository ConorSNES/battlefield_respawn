-- tool menu compat
hook.Add("AddToolMenuCategories", "bfres_optionsmake", function()
	---@diagnostic disable-next-line: deprecated
	spawnmenu.AddToolMenuOption("Utilities", "User", "bfres_config", "Respawn Menu Settings", nil, nil, function( form )
		-- This is the menu.
		form:CheckBox("Show overlay on death", "bfres_doshowui")
		--form:CheckBox("Quick select (Immediately respawn after selecting respawn point)", "bfres_doquickselect")
		form:NumSlider("Spawn picker scale", "bfres_uiscale", 0, 1, 2)

		form:Button("Open spawn picker", "bfres_openspawn")
		form:Button("Retake map image", "bfres_retakemap")
		form:Help("Map image is retaken the next time the spawn picker is shown.")
		form:Button("Reset my spawn preferences", "bfres_resetspawn")
		form:Button("Respawn now", "bfres_requestRespawn")
		form:Help("Note: Respawning while still alive requires bfres_allowspawnteleport be enabled on server!")
	end )

	---@diagnostic disable-next-line: deprecated
	spawnmenu.AddToolMenuOption("Utilities", "Admin", "bfres_server_config", "Respawn Menu Settings", nil, nil, function( form ) 
		form:Help("These options may only be modified by the server.")

		form:CheckBox("Allow players to select a spawn point", "bfres_allowselect")
		form:CheckBox("Allow players to respawn while they are alive", "bfres_allowspawnteleport")
	end)
end )