# Battlefield-ish respawn
A mod for Garry's Mod that allows you to explicitly select one of the spawnpoints on a map to respawn to

(c) ConorSNES 2023-2026

## Description
When a player dies, they can select a spawnpoint on a visual map popup. Upon initiating a respawn, they respawn at the selected point.
This mod is designated for use in sandbox/sandbox derived only as use in others is unstable (may cause bugs related to net messages). 
The mod will automatically deactivate if the gamemode is not sandbox.

### CVARs

|name|desc|type|is server?|
|---|---|---|---|
|bfres_allowselect|Enable/disable use of spawnpoint selection|boolean|**Yes**|
|bfres_showui|Should UI be shown on death? (Your preference of spawnpoint will be saved)|boolean||
|bfres_uiscale|Scale of UI relative to screen space|numeric||
|bfres_retakemap|Retake the map the next time the UI is shown|trigger||
|bfres_resetspawn|Reset spawn preference. If you have none selected, you will fall back to the typical random spawn selection|trigger||
|bfres_reset|Fully reset client-side UI|trigger||

## Known issues
- Addon is nonfunctional on gamemodes other than sandbox
	- This is as it is due to unpredictible hook structuring
- Addon is compatible with only up to 255 spawnlocation/s
	- It is unlikely there is more than 255 in a map, but if this needs changing, raise an issue

## Possible future features
- Translation support
- Select anywhere as a spawnpoint
