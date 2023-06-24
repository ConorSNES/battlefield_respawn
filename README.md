# Battlefield-ish respawn
A mod for Gmod that allows you to select one of the spawnpoints on a map
(c) ConorSNES 2023

## Description
When a player dies, they can select a spawnpoint on a visual map popup. Upon respawning, they respawn at the selected point.
This mod is designated for use in sandbox/sandbox derived only as use in others is unstable (may cause bugs). The mod will automatically break execution if the gamemode is not sandbox.

Upon rendering the map for the first time, the data sent from the server to the client is at n-length scale with the amount of spawnpoints in the current level. This has been optimised where possible.
Addon should be server-secure, unless you want to hide where your spawnpoints are.

## Known issues
- Addon is nonfunctional on gamemodes other than sandbox
	- This is as it is due to unpredictible hook structuring
- Addon is compatible with only up to 255 spawnlocation/s
	- It is unlikely there is more than 255, but if this needs changing, raise an issue

## Possible future features
- Translation support
- Select anywhere as a spawnpoint