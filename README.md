# Sworduh

Sworduh is a server-side sword system for Roblox. It is designed to handle giving swords to players, tracking damage, and cleaning up resources automatically. It uses the classic linked sword mechanics, including slash and lunge attacks.

 - View the full documentation [here](https://sequesteredone.github.io/Sworduh/)

## Install

### Wally (Recommended)

- Add to your wally.toml:

```toml
    [dependencies]
    sequesteredone/sworduh = "0.2.0" # use latest version
```
- Or run:

`wally add "sequesteredone/sworduh@0.2.0"`

### Manual

- Download the latest .rbxm from Releases:

https://github.com/SequesteredOne/Sworduh/releases

- Insert the model into ReplicatedStorage and require it:

```lua
local Sworduh = require(ReplicatedStorage.Sworduh)
```

## Basic Usage

Here are a few common examples of how to use Sworduh.

### Giving and Removing Swords

You can give a sword to a player when they join and remove it with the `Unsword` function.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Sworduh = require(ReplicatedStorage.Sworduh)

Players.PlayerAdded:Connect(function(player)
	-- Give a sword to the new player
	-- The system waits for the character to load automatically
	local sword = Sworduh:Sword(player)

	-- You can also remove the sword later
	-- Sworduh:Unsword(player)
end)
```

### Tracking Kills

The `GetKiller` function is useful for creating a kill feed or leaderboard. It returns the last player who damaged another player.

```lua
-- In a script that handles character deaths
local function onCharacterDied(character)
    local deadPlayer = Players:GetPlayerFromCharacter(character)
    if not deadPlayer then return end

    local killer = Sworduh:GetKiller(deadPlayer)

    if killer then
        print(killer.Name .. " defeated " .. deadPlayer.Name)
        -- Announce or update leaderboards here
    else
        print(deadPlayer.Name .. " was defeated.")
    end
end

-- Connect this to all players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            onCharacterDied(character)
        end)
    end)
end)
```

### Server Cleanup

It is important to call the `Cleanup` function when the server shuts down to prevent memory leaks.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sworduh = require(ReplicatedStorage.Sworduh)

game:BindToClose(function()
	Sworduh:Cleanup()
end)
```

## Respawn Behavior

By default, players automatically recieve a new sword when they respawn.
This is controlled by the configuration:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = require(ReplicatedStorage.Sworduh.Configuration)

Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN = true -- default
```

If you set this to false, players will not recieve a sword on respawn. 
You will need to call Sworduh:Sword(player) again.

Calling Sworduh:Unsword(player) removes both the current sword,
and the respawn connection for the provided player.
This means they will no longer auto-recieve a sword again until Sworduh:Sword(player) again.

**NPCs do not automatically recieve swords on respawn.**


## API

These are the main functions available in the `Sworduh` module.

*   `Sworduh:Sword(player)`: Gives a sword to the specified player. Returns a sword handler object or `nil` on failure.
*   `Sworduh:Unsword(player)`: Removes the sword from the specified player.
*   `Sworduh:SwordAll()`: Gives a sword to every player in the game.
*   `Sworduh:UnswordAll()`: Removes swords from every player.
*   `Sworduh:GetKiller(player)`: Returns the last player that damaged the specified player. Returns `nil` if no valid killer is found.
*   `Sworduh:Cleanup()`: Disconnects all events and cleans up all swords. Call this on server shutdown.

## Configuration

Runtime configuration can be found in src/Configuration.luau