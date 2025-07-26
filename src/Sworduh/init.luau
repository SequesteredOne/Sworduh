--[=[
    @class Sworduh
    @server

    A comprehensive sword system using Roblox's linked sword mechanics.

    Handles sword creation, management, and cleanup for players. Also manages character respawning, 
    player validation, and damage tracking.

    :::info
    This class should only be used on the server. It manages the server-side sword mechanics
    and damage tracking for all players.
    :::

    :::warning
    Currently, players will automatically recieve a sword when respawning.

    Call the [Unsword](#Unsword) function to disable this. In the future, this will be togglable. 
    :::

    :::warning
    Always call [Sworduh:Cleanup] when shutting down your game to prevent memory leaks.
    :::

    ## Basic Usage

    ```lua
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Sworduh = require(ReplicatedStorage.Sworduh)

    -- Give a sword to a specific player
    local sword = Sworduh:Sword(player)

    -- Check if the sword is still active
    if sword and sword:IsActive() then
        print("Sword is active")
    end

    -- Give a sword to all valid players
    Sworduh:SwordAll()

    -- Remove a specific player's sword
    Sworduh:Unsword(player)
    -- Alternatively, using the returned sword handler
    sword:Destroy()

    -- Get the last player to damage a specific player (useful for kill tracking)
    local killer = Sworduh:GetKiller(deadPlayer)
    ```

    ## Other Usage

    ```lua
    -- Set up automatic sword giving for new players
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Sworduh = require(ReplicatedStorage.Sworduh)
    
    -- Note: You do not need to worry about waiting for the player's character to load
    -- The system will handle this for you
    Players.PlayerAdded:Connect(function(player)
        Sworduh:Sword(player)
    end)

    -- Clean up when server shuts down
    game:BindToClose(function()
        Sworduh:Cleanup()
    end)
    ```

    @since v0.1.0
]=]

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local SwordHandler = require(script:WaitForChild("SwordHandler"))

export type SwordHandler = SwordHandler.SwordHandler

--[=[
    @interface Constants
    @within Sworduh
    
    Configuration constants for the Sworduh system.
    
    .CHARACTER_TIMEOUT number -- Maximum time to wait for character components (seconds)
    .CHARACTER_POLL_INTERVAL number -- How often to check if character is ready (seconds)
]=]
local CONSTANTS = {
    CHARACTER_TIMEOUT = 5,
    CHARACTER_POLL_INTERVAL = 0.1, -- How often to check if character is ready
}

--[=[
    @interface Sworduh
    @within Sworduh

    @field ClassName string
    @field __index Sworduh
    
    @field SwordObjects {[Player]: SwordHandler}
    @field LastDamagerCache {[Player]: Player}, -- A cache mapping players to the last player who damaged them.
    @field Connections {[string]: RBXScriptConnection | {Disconnect: () -> ()}},

    @field Sword (self: Sworduh, player: Player) -> SwordHandler?,
    @field SwordAll (self: Sworduh) -> (),
    @field Unsword (self: Sworduh, player: Player) -> boolean,
    @field UnswordAll (self: Sworduh) -> (),
    @field GetKiller: (self: Sworduh, player: Player) -> Player?,
    @field Cleanup: (self: Sworduh) -> (),

    @field _setupPlayerConnections: (self: Sworduh, player: Player) -> (),
    @field _cleanupPlayerSword: (self: Sworduh, player: Player) -> (),
    @field _createSword: (self: Sworduh) -> Tool?,
]=]

export type Sworduh = {
    ClassName: string,
    __index: Sworduh,
    
    SwordObjects: {[Player]: SwordHandler},
    LastDamagerCache: {[Player]: Player},
    Connections: {[string]: RBXScriptConnection | {Disconnect: () -> ()}},

    Sword: (self: Sworduh, player: Player) -> SwordHandler?,
    SwordAll: (self: Sworduh) -> (),
    Unsword: (self: Sworduh, player: Player) -> boolean,
    UnswordAll: (self: Sworduh) -> (),
    GetKiller: (self: Sworduh, player: Player) -> Player?,
    Cleanup: (self: Sworduh) -> (),
    _setupPlayerConnections: (self: Sworduh, player: Player) -> (),
    _cleanupPlayerSword: (self: Sworduh, player: Player) -> (),
    _createSword: (self: Sworduh) -> Tool?,
}

--[=[
    @prop SwordObjects {[Player]: SwordHandler}
    @within Sworduh
    @readonly
    
    Active sword handlers for each player. This table maps each player to their corresponding
    sword handler instance.
]=]

--[=[
    @prop LastDamagerCache {[Player]: Player}
    @within Sworduh
    @readonly
    
    Cache tracking who last damaged each player. This is essential for kill tracking systems
    and leaderboard functionality. The cache automatically validates that killers are still
    valid before returning them.
]=]

--[=[
    @prop Connections {[string]: RBXScriptConnection | {Disconnect: () -> ()}}
    @within Sworduh
    @readonly
    
    Active connections for cleanup. This table stores all event connections created by the
    system, allowing for proper cleanup when the system is shut down or when players leave.
]=]

local Sworduh: Sworduh = {} :: Sworduh
Sworduh.ClassName = "Sworduh"
Sworduh.__index = Sworduh

Sworduh.SwordObjects = {} :: {[Player]: SwordHandler}
Sworduh.LastDamagerCache = {} :: {[Player]: Player}
Sworduh.Connections = {} :: {[string]: RBXScriptConnection | {Disconnect: () -> ()}}

-- Public Methods

--[=[
    Creates and equips a sword for the specified player.

    Automatically handles character respawning and player validation.
    If the player already has a sword, the existing sword handler is returned.

    :::tip
    This method is safe to call multiple times for the same player - it will return 
    the existing sword if one is already equipped.
    :::

    :::warning
    If character loading fails or times out, this method returns `nil`. Always check
    the return value before using the sword handler.
    :::

    @param player -- The player to equip with a sword
    @return SwordHandler? -- The created sword handler, or nil if failed
    @yields -- May yield while waiting for character to load
    @error "Invalid player" -- When player is missing or has left the game
    @tag core
    @since v0.1.0
    
    ## Example
    
    ```lua
    local sword = Sworduh:Sword(player)
    if sword then
        -- Check if still active later
        if sword:IsActive() then
            print("Sword is still active!")S
        end
    else
        warn("Failed to give sword to", player.Name)
    end
    ```
]=]

function Sworduh:Sword(player: Player): SwordHandler?
    if not player or not player.Parent then
        warn("Attempted to sword a missing or invalid player.")
        return nil
    end

	local character: Model? = player.Character
    if not character then
        local success, result = pcall(function()
            return player.CharacterAdded:Wait()
        end)
        if not success then
            warn("Failed to get character for ".. player.Name.. " |\n".. tostring(result))
            return nil
        end

        character = result
    end

    if character then
        if not character.Parent then
            local connection: RBXScriptConnection?
            local timeOutConnection: thread?
            local characterReady: boolean = false

            connection = character.AncestryChanged:Connect(function()
                if character and character.Parent then
                    characterReady = true
                    if connection then connection:Disconnect() end
                    if timeOutConnection then task.cancel(timeOutConnection) end
                end
            end)

            timeOutConnection = task.delay(CONSTANTS.CHARACTER_TIMEOUT, function()
                if connection then connection:Disconnect() end
                warn(player.Name, "timeout while waiting for character to be parented.")
            end)

            while not characterReady and connection and connection.Connected do
                task.wait(CONSTANTS.CHARACTER_POLL_INTERVAL)
            end

            if not characterReady then
                return nil
            end
        end

        local humanoid = character:WaitForChild("Humanoid", CONSTANTS.CHARACTER_TIMEOUT)
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart", CONSTANTS.CHARACTER_TIMEOUT)
        
        if not humanoid or not humanoidRootPart then
            warn("Character components not ready for", player.Name)
            return nil
        end
    end

    if not self.SwordObjects then
        self.SwordObjects = {}
    end

	local existingSword = self.SwordObjects[player]
	if existingSword then
        if existingSword.SwordTool and existingSword.SwordTool.Parent == character then
            return existingSword
        end

        self:_cleanupPlayerSword(player)
	end

    local swordTool: Tool? = self:_createSword()
    if not swordTool then
        warn("Failed to create sword tool for", player.Name)
        return nil
    end

    swordTool.Parent = character

    local success, swordObject = pcall(function()
        return SwordHandler.new(player, swordTool, self.LastDamagerCache)
    end)

    if not success then
        warn("Failed to create sword handler for", player.Name, " |\n", swordObject)
        if swordTool then swordTool:Destroy() end
        return nil
    end

    self.SwordObjects[player] = swordObject
    self:_setupPlayerConnections(player)

    return swordObject
end

--[=[
    Gives a sword to all players currently in the game.
    
    This method calls [Sworduh:Sword] for each player currently in the server.
    
    :::warning
    Players who join after this method is called will not automatically receive swords.
    You'll need to call this method again or set up individual player handling.
    :::
    
    @tag utility
    @since v0.1.0
]=]

function Sworduh:SwordAll()
    local players = Players:GetPlayers()
    for i = 1, #players do
        local player = players[i]
        if player and player.Parent then
            self:Sword(player)
        end
    end
end

--[=[
    Removes a player's sword and cleans up all associated data.

    @param player -- The player whose sword should be removed
    @return boolean -- `true` if a sword was removed, `false` if no sword was found
    @tag core
    @since v0.1.0
]=]

function Sworduh:Unsword(player: Player): boolean
    if not player then
        return false
    end

    local swordObject = self.SwordObjects[player]
	if swordObject then
        self:_cleanupPlayerSword(player)
        return true
    end

    return false
end

--[=[
    Removes swords from all players in the game.
    
    This method calls [Sworduh:Unsword] for every player who currently has a sword.
    Useful for ending game modes or resetting the server state.
    
    @since v0.1.0
]=]

function Sworduh:UnswordAll()
    -- Create a copy to avoid modification during iteration
    local players: {Player} = {}
    for player, _ in pairs(self.SwordObjects) do
        table.insert(players, player)
    end

    for i = 1, #players do
        self:Unsword(players[i])
    end
end

--[=[
    Returns the last player that damaged the specified player.
    
    This method is essential for kill tracking, leaderboard systems, and reward distribution.
    The damage cache automatically validates that the killer is still in the game and has
    a valid character before returning them.
    
    :::tip
    This method automatically cleans up invalid killers (players who have left the game),
    so you can trust that any returned player is still valid.
    :::

    @param player -- The player to find the killer for
    @return Player? -- The player who last damaged the specified player, or nil if no valid killer exists
    @tag utility
    @since v0.1.0
    
    ## Example
    
    ```lua
    -- In a character death handler
    local function onPlayerDied(deadPlayer)
        local killer = Sworduh:GetKiller(deadPlayer)
        
        if killer then
            print(killer.Name, "eliminated", deadPlayer.Name)
            
            -- Award points to the killer
            local leaderstats = killer:FindFirstChild("leaderstats")
            if leaderstats and leaderstats:FindFirstChild("Kills") then
                leaderstats.Kills.Value += 1
            end
        else
            print(deadPlayer.Name, "died from unknown causes")
        end
    end
    ```
]=]

function Sworduh:GetKiller(player: Player): Player?
    if not player then
        return nil
    end
    local killer = self.LastDamagerCache[player]

    if not killer then
        return nil
    end

    if killer.Character and killer.Character.Parent and Players:GetPlayerFromCharacter(killer.Character) then
        return killer
    else
        self.LastDamagerCache[player] = nil
        return nil
    end
end

--[=[
    Cleans up the entire sword system.

    Removes all swords, clears internal caches, and disconnects all event connections.
    This method should always be called when shutting down the system to prevent memory leaks.
    
    :::warning
    After calling this method, the Sworduh instance will be in a clean state but
    you'll need to re-establish any swords for continuing gameplay.
    :::
    
    @since v0.1.0
    
    ## Example
    
    ```lua
    -- Clean shutdown
    game:BindToClose(function()
        Sworduh:Cleanup()
    end)
    ```
]=]

function Sworduh:Cleanup()
    self:UnswordAll()

    table.clear(self.LastDamagerCache)

    for key, connection in pairs(self.Connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" and connection.Connected then
                connection:Disconnect()
            elseif typeof(connection) == "table" and connection.Disconnect then
                connection.Disconnect()
            end
        end
    end
    table.clear(self.Connections)
end

-- Private Methods

--[=[
    Sets up event connections for a player.
    
    Creates connections for character removal and player leaving events to automatically
    clean up sword data when appropriate.

    @param player -- The player to set up connections for
    @private
    @since v0.1.0
]=]

function Sworduh:_setupPlayerConnections(player: Player)
    local connectionKey: string = "PlayerEvents_".. player.UserId

    local existingConnection = self.Connections[connectionKey]
    if existingConnection then
        if typeof(existingConnection) == "RBXScriptConnection" and existingConnection.Connected then
            existingConnection:Disconnect()
        elseif typeof(existingConnection) == "table" and existingConnection.Disconnect then
            existingConnection.Disconnect()
        end
    end

    local connections: {RBXScriptConnection} = {}

    table.insert(connections, player.CharacterRemoving:Connect(function()
        self:_cleanupPlayerSword(player)
    end))

    table.insert(connections, player.AncestryChanged:Connect(function()
        if not player.Parent then
            self:_cleanupPlayerSword(player)
        end
    end))

    self.Connections[connectionKey] = {
        Disconnect = function()
            for _, connection in pairs(connections) do
                if connection and connection.Connected then
                    connection:Disconnect()
                end
            end
        end
    }
end

--[=[
    Cleans up all data associated with a player's sword.
    
    Destroys the sword handler, removes the player from tracking caches,
    and disconnects any player-specific event connections.

    @param player -- The player whose sword data should be cleaned up
    @private
    @since v0.1.0
]=]

function Sworduh:_cleanupPlayerSword(player: Player)
    local swordObject = self.SwordObjects[player]
    if swordObject then
        if swordObject.Destroy then
            swordObject:Destroy()
        end
        self.SwordObjects[player] = nil
    end

    self.LastDamagerCache[player] = nil

    local connectionKey: string = "PlayerEvents_".. player.UserId
    local connection = self.Connections[connectionKey]
    if connection then
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        elseif typeof(connection) == "table" and connection.Disconnect then
            connection.Disconnect()
        end
        self.Connections[connectionKey] = nil
    end
end

--[=[
    Creates a new sword [Tool](https://create.roblox.com/docs/reference/engine/classes/Tool) instance.

    @return Tool? -- The created sword tool, or nil if mesh creation failed
    @private
    @since v0.1.0
    @error "Failed to create sword mesh" -- When InsertService fails to load the sword mesh
]=]

function Sworduh:_createSword(): Tool?
    local sword = Instance.new("Tool")
    sword.Name = "Sword"
    sword.CanBeDropped = false
    sword.Grip = CFrame.new(0, 0, -1.5, 0, 0, 1, 1, 0, 0, 0, 1, 0)
    sword.TextureId = "http://www.roblox.com/asset/?id=124987047"

    local success, handle = pcall(function()
        return InsertService:CreateMeshPartAsync(
            "http://www.roblox.com/asset/?id=12221720",
            Enum.CollisionFidelity.Default,
            Enum.RenderFidelity.Automatic
        )
    end)

    if not success then
        warn("Failed to create sword mesh |\n", handle)
        return nil
    end

    handle.Name = "Handle"
    handle.TextureID = "http://www.roblox.com/asset/?id=12224218"
    handle.Parent = sword

    local hitbox = Instance.new("Part")
    hitbox.Name = "Hitbox"
    hitbox.Size = Vector3.new(1, 0.8, 4)
    hitbox.CFrame = handle.CFrame
    hitbox.Transparency = 1
    hitbox.CanCollide = false
    hitbox.Parent = sword

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = hitbox
    weld.Parent = handle

    type SoundData = {
        name: string,
        id: string,
        volume: number,
    }

    local sounds: {[string]: SoundData} = {
        slash = {
            name = "Slash",
            id = "http://www.roblox.com/asset/?id=12222216",
            volume = 0.7,
        },
        lunge = {
            name = "Lunge",
            id = "http://www.roblox.com/asset/?id=12222208",
            volume = 0.6,
        },
        unsheathe = {
            name = "Unsheathe",
            id = "http://www.roblox.com/asset/?id=12222225",
            volume = 1,
        },
    }

    for _, soundData in sounds do
        local sound = Instance.new("Sound")
        sound.Name = soundData.name
        sound.SoundId = soundData.id
        sound.Volume = soundData.volume
        sound.Parent = handle
    end

    return sword
end

return Sworduh