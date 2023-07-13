-- net strings
util.AddNetworkString( "bfres_showUI" )
util.AddNetworkString( "bfres_respawnIndex" )
util.AddNetworkString( "bfres_respawnNow" )

-- locals
local g = {} -- Stored table of user's selected spawnlocation
local spawns = {}
local AllowSelect = CreateConVar( "bfres_allowselect", 1, nil, "Allow/Disallow selection of spawn point using bfres window", 0, 1)

function GetSpawns()
	-- This code is from the player.lua file in the base gamemode- it should obtain all possible spawnpoints

	-- HL2 Maps
	spawns = ents.FindByClass( "info_player_start" )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_deathmatch" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_combine" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_rebel" ) )

	-- CS Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_counterterrorist" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_terrorist" ) )

	-- DOD Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_axis" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_allies" ) )

	-- (Old) GMod Maps
	spawns = table.Add( spawns, ents.FindByClass( "gmod_player_start" ) )

	-- TF Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_teamspawn" ) )

	-- INS Maps
	spawns = table.Add( spawns, ents.FindByClass( "ins_spawnpoint" ) )

	-- AOC Maps
	spawns = table.Add( spawns, ents.FindByClass( "aoc_spawnpoint" ) )

	-- Dystopia Maps
	spawns = table.Add( spawns, ents.FindByClass( "dys_spawn_point" ) )

	-- PVKII Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_pirate" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_viking" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_knight" ) )

	-- DIPRIP Maps
	spawns = table.Add( spawns, ents.FindByClass( "diprip_start_team_blue" ) )
	spawns = table.Add( spawns, ents.FindByClass( "diprip_start_team_red" ) )

	-- OB Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_red" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_blue" ) )

	-- SYN Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_coop" ) )

	-- ZPS Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_human" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_zombie" ) )

	-- ZM Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_zombiemaster" ) )

	-- FOF Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_player_fof" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_desperado" ) )
	spawns = table.Add( spawns, ents.FindByClass( "info_player_vigilante" ) )

	-- L4D Maps
	spawns = table.Add( spawns, ents.FindByClass( "info_survivor_rescue" ) )
end

hook.Add( "InitPostEntity", "bfres_initspawns", function()
	GetSpawns()
end )

hook.Add( "DoPlayerDeath", "bfres_ondeath", function( ply )
	if AllowSelect:GetBool() then
		local st		-- staggering indicator
		if g[ply:AccountID()] == nil or g[ply:AccountID()] == 0 then
			-- Try again to get a log of all spawns if there are none currently here
			if #spawns <= 0 then
				GetSpawns()
			end

			-- Manage net
			st = net.Start("bfres_showUI")	-- Activation only as required

			-- Get the vectors for the spawns bc the spawns don't exist on the client
			-- also min/max for hammer editor is 15 bit (2^15), unless you cracked it or something idk
			for k, v in ipairs( spawns ) do
				if net.BytesLeft() and net.BytesLeft() < 31 then break end -- fix for memoryfull
				local pos = v:GetPos()
				net.WriteInt( math.floor(pos.x), 15)
				net.WriteInt( math.floor(pos.y), 15)
			end
		end

		if not st then net.Start("bfres_showUI") end -- Catch-all

		net.Send( ply )
		g[ply:AccountID()] = nil
	end
end )

hook.Add( "PlayerSelectSpawn", "bfres_selectspawn", function( ply )
	if AllowSelect:GetBool() and g[ply:AccountID()] != nil then
		if not spawns[ g[ply:AccountID()] ]:IsValid() then
			GetSpawns()
		end
		return spawns[ g[ply:AccountID()] ]
	end
end )

hook.Add( "PostGamemodeLoaded", "bfres_isUsed", function()
	-- alright, trying again
	if engine.ActiveGamemode() != "sandbox" then
		print("Battlefield respawn disabled serverside as gamemode is " .. engine.ActiveGamemode())
		AllowSelect:SetBool(false)
	end
end )

net.Receive( "bfres_respawnIndex", function( len, ply )
	local d = net.ReadUInt( 8 )
	g[ply:AccountID()] = d
end )

net.Receive( "bfres_respawnNow", function( len, ply )
	if not ply:Alive() then	-- whoopsies (issue 1, teleportation exploit)
		ply:Spawn()
	end
end )