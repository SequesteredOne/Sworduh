# Sworduh

Sworduh is a server-side sword system for Roblox. It is designed to handle giving swords to players, tracking damage, and cleaning up resources automatically. It uses the classic linked sword mechanics, including slash and lunge attacks.

View the full documentation [here](https://sequesteredone.github.io/Sworduh/)
## Setup

### Rojo (Recommended)

1.  **Prerequisites**: Make sure you have the [Rojo CLI](https://rojo.space/docs/installation/) installed on your system.

2.  **Clone the Repository**: Get a local copy of the project files.
    ```bash
    git clone https://github.com/SequesteredOne/Sworduh.git
    cd sworduh
    ```

3.  **Build the Project**: You can build the project into a place file (`.rbxlx`) to open it directly in Studio.
    ```bash
    rojo build default.project.json -o "Sworduh.rbxlx"
    ```

### Manual Installation

If you prefer not to use Rojo, you can install the system manually.

1.  Go to the [Releases](https://github.com/SequesteredOne/Sworduh/releases) page and download the latest `.rbxm` model file.
2.  Drag the downloaded file into `ReplicatedStorage` in your Roblox Studio project.

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

## API

These are the main functions available in the `Sworduh` module.

*   `Sworduh:Sword(player)`: Gives a sword to the specified player. Returns a sword handler object or `nil` on failure.
*   `Sworduh:Unsword(player)`: Removes the sword from the specified player.
*   `Sworduh:SwordAll()`: Gives a sword to every player in the game.
*   `Sworduh:UnswordAll()`: Removes swords from every player.
*   `Sworduh:GetKiller(player)`: Returns the last player that damaged the specified player. Returns `nil` if no valid killer is found.
*   `Sworduh:Cleanup()`: Disconnects all events and cleans up all swords. Call this on server shutdown.

## Configuration

To change settings like damage values, attack speed, or sound effects, you can edit the `CONFIG` table at the top of the `src/Sworduh/SwordHandler.luau` script.

(Note: This will be improved and made easier in future updates.)
