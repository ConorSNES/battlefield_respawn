-- net strings
util.AddNetworkString( "bfres_showUI" )
util.AddNetworkString( "bfres_respawnIndex" )
util.AddNetworkString( "bfres_respawnNow" )

function GetSpawns()
	-- This code is from the player.lua file in the base gamemode- it should obtain all possible spawnpoints
	local o

	-- HL2 Maps
	o = ents.FindByClass( "info_player_start" )
	o = table.Add( o, ents.FindByClass( "info_player_deathmatch" ) )
	o = table.Add( o, ents.FindByClass( "info_player_combine" ) )
	o = table.Add( o, ents.FindByClass( "info_player_rebel" ) )

	-- CS Maps
	o = table.Add( o, ents.FindByClass( "info_player_counterterrorist" ) )
	o = table.Add( o, ents.FindByClass( "info_player_terrorist" ) )

	-- DOD Maps
	o = table.Add( o, ents.FindByClass( "info_player_axis" ) )
	o = table.Add( o, ents.FindByClass( "info_player_allies" ) )

	-- (Old) GMod Maps
	o = table.Add( o, ents.FindByClass( "gmod_player_start" ) )

	-- TF Maps
	o = table.Add( o, ents.FindByClass( "info_player_teamspawn" ) )

	-- INS Maps
	o = table.Add( o, ents.FindByClass( "ins_spawnpoint" ) )

	-- AOC Maps
	o = table.Add( o, ents.FindByClass( "aoc_spawnpoint" ) )

	-- Dystopia Maps
	o = table.Add( o, ents.FindByClass( "dys_spawn_point" ) )

	-- PVKII Maps
	o = table.Add( o, ents.FindByClass( "info_player_pirate" ) )
	o = table.Add( o, ents.FindByClass( "info_player_viking" ) )
	o = table.Add( o, ents.FindByClass( "info_player_knight" ) )

	-- DIPRIP Maps
	o = table.Add( o, ents.FindByClass( "diprip_start_team_blue" ) )
	o = table.Add( o, ents.FindByClass( "diprip_start_team_red" ) )

	-- OB Maps
	o = table.Add( o, ents.FindByClass( "info_player_red" ) )
	o = table.Add( o, ents.FindByClass( "info_player_blue" ) )

	-- SYN Maps
	o = table.Add( o, ents.FindByClass( "info_player_coop" ) )

	-- ZPS Maps
	o = table.Add( o, ents.FindByClass( "info_player_human" ) )
	o = table.Add( o, ents.FindByClass( "info_player_zombie" ) )

	-- ZM Maps
	o = table.Add( o, ents.FindByClass( "info_player_zombiemaster" ) )

	-- FOF Maps
	o = table.Add( o, ents.FindByClass( "info_player_fof" ) )
	o = table.Add( o, ents.FindByClass( "info_player_desperado" ) )
	o = table.Add( o, ents.FindByClass( "info_player_vigilante" ) )

	-- L4D Maps
	o = table.Add( o, ents.FindByClass( "info_survivor_rescue" ) )

	return o
end

-- locals
local g = {} -- Stored table of user's selected spawnlocation
local spawns = {}
function spawns:fetch()
	if spawns._inner == nil then
		spawns:force_reload()
	elseif #(spawns._inner) > 0 and spawns._inner[0] == NULL then -- fix for NULL entity bug
		spawns:force_reload() -- I understand this seems redundant with the previous branch. However, using "or" would result in a nil error.
	end
	return spawns._inner
end
function spawns:force_reload()
	spawns._inner = GetSpawns()
end
local AllowSelect = CreateConVar( "bfres_allowselect", 1, nil, "Allow/Disallow selection of spawn point using bfres window", 0, 1)



hook.Add( "InitPostEntity", "bfres_initspawns", function()
	spawns:force_reload()
end )

hook.Add( "DoPlayerDeath", "bfres_ondeath", function( ply )
	local spawns_now = spawns:fetch()
	if AllowSelect:GetBool() then
		local st		-- staggering indicator
		if g[ply:AccountID()] == nil or g[ply:AccountID()] == 0 then
			-- Try again to get a log of all spawns if there are none currently here
			if #spawns_now <= 0 then
				GetSpawns()
			end

			-- Manage net
			st = net.Start("bfres_showUI")	-- Activation only as required

			-- Get the vectors for the spawns bc the spawns don't exist on the client
			-- also min/max for hammer editor is 15 bit (2^15), unless you cracked it or something idk
			for k, v in ipairs( spawns_now ) do
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
	local spawns_now = spawns:fetch()
	if AllowSelect:GetBool() and g[ply:AccountID()] ~= nil then
		if not spawns_now[ g[ply:AccountID()] ]:IsValid() then
			spawns:force_reload()
			spawns_now = spawns:fetch()
		end
		return spawns_now[ g[ply:AccountID()] ]
	end
end )

hook.Add( "PostGamemodeLoaded", "bfres_isUsed", function()
	-- alright, trying again
	if engine.ActiveGamemode() ~= "sandbox" then
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