--[=[
    @class Sworduh
    @server

    A comprehensive sword system using Roblox's linked sword mechanics.

    Handles sword creation, management, and cleanup for players and NPCs. Also manages character respawning, 
    player validation, and damage tracking.

    :::info
    This class should only be used on the server. It manages the server-side sword mechanics
    and damage tracking for all players and NPCs.
    :::

    :::info
    Players can automatically recieve a sword when they respawn.
    This behavior is controlled by [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER)

    - When enabled, a CharacterAdded connection for each player will re-call the [Sword()](./Sworduh#Sword) method if they previously had a sword.
    It will not give a sword to players who did not have a sword.
    - Calling [Unsword()](./Sworduh#Unsword) disconnects the CharacterAdded connection for the provided player. 
    (They will not recieve a sword on respawn until [Sword()](./Sworduh#Sword) is called again)
    - NPCs do not automatically recieve swords on respawn. 
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

    -- Give a sword to an NPC
    local npcModel = workspace:WaitForChild("NPC")
    local npcSword = Sworduh:Sword(npcModel)

    -- Check if the sword is still active
    if sword and sword:IsActive() then
        print("Sword is active")
    end

    -- Give a sword to all valid players (Does not affect NPCs)
    Sworduh:SwordAll()

    -- Remove a specific entity's sword
    Sworduh:Unsword(player)
    -- Alternatively, using the returned sword handler
    sword:Destroy()

    -- Get the last player to damage a specific target (useful for kill tracking)
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

    @since v0.2.0
]=]

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local Packages = script:WaitForChild("Packages")
local Promise = require(Packages:WaitForChild("promise"))

local Utils = require(script:WaitForChild("Utils"))
local Configuration = require(script:WaitForChild("Configuration"))
local SwordHandler = require(script:WaitForChild("SwordHandler"))

type Promise<T> = typeof(Promise.new(function() end))
export type SwordHandler = SwordHandler.SwordHandler

--[=[
    @interface Sworduh
    @within Sworduh

    @field ClassName string
    @field __index Sworduh
    
    @field SwordObjects {[Player | Model]: SwordHandler}
    @field LastDamagerCache {[Player | Model]: Player | Model}, -- A cache mapping entities to the last entity who damaged them.
    @field Connections {[string]: RBXScriptConnection | {Disconnect: () -> ()}},
    @field RespawnConnections {[Player]: RBXScriptconnection}

    @field Sword (self: Sworduh, target: Player | Model) -> SwordHandler?,
    @field SwordAll (self: Sworduh) -> (),
    @field Unsword (self: Sworduh, target: Player | Model) -> boolean,
    @field UnswordAll (self: Sworduh) -> (),
    @field GetKiller: (self: Sworduh, target: Player | Model) -> (Player | Model)?,
    @field Cleanup: (self: Sworduh) -> (),

    @field _setupEntityConnections: (self: Sworduh, target: Player | Model) -> (),
    @field _cleanupEntitySword: (self: Sworduh, target: Player | Model) -> (),
    @field _setupPlayerRespawnConnections (self: Sworduh, target: Player) -> ()
    @field _cleanupPlayerRespawnConnection (self: Sworduh, target: Player) -> ()
    @field _createSword: (self: Sworduh) -> Tool?,
]=]

export type Sworduh = {
    ClassName: string,
    __index: Sworduh,
    
    SwordObjects: {[Player | Model]: SwordHandler},
    LastDamagerCache: {[Player | Model]: Player | Model},
    RespawnConnections: {[Player]: RBXScriptConnection},
    Connections: {[Player | Model]: RBXScriptConnection | {Disconnect: () -> ()}},

    Sword: (self: Sworduh, target: Player | Model) -> SwordHandler?,
    SwordAll: (self: Sworduh) -> (),
    Unsword: (self: Sworduh, target: Player | Model) -> boolean,
    UnswordAll: (self: Sworduh) -> (),
    GetKiller: (self: Sworduh, target: Player | Model) -> (Player | Model)?,
    Cleanup: (self: Sworduh) -> (),
    _setupEntityConnections: (self: Sworduh, target: Player | Model) -> (),
    _setupPlayerRespawnConnections: (self: Sworduh, target: Player) -> (),
    _cleanupPlayerRespawnConnection: (self: Sworduh, target: Player) -> (),
    _cleanupEntitySword: (self: Sworduh, target: Player | Model) -> (),
    _getPlayerCharacter: (self: Sworduh, player: Player) -> Promise<Model>,
    _createSword: (self: Sworduh) -> Tool?,
}

--[=[
    @prop SwordObjects {[Player | Model]: SwordHandler}
    @within Sworduh
    @readonly
    
    Active sword handlers for each entity (player or NPC). This table maps each entity to their corresponding
    sword handler instance.
]=]

--[=[
    @prop LastDamagerCache {[Player | Model]: Player | Model}
    @within Sworduh
    @readonly
    
    Cache tracking who last damaged each entity. This is essential for kill tracking systems
    and leaderboard functionality. The cache automatically checks that killers are still
    valid before returning them.
]=]

--[=[
    @prop Connections {[string]: RBXScriptConnection | {Disconnect: () -> ()}}
    @within Sworduh
    @readonly
    
    Active connections for cleanup. This table stores all event connections created by the
    system, allowing for proper cleanup when the system is shut down or when entities leave.
]=]

--[=[
    @prop RespawnConnections {[Player]: RBXScriptConnection}
    @within Sworduh
    @readonly

    Per-player CharacterAdded connections.
    When [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER) is true, these connections recreate
    the player's sword after they respawn. The connection is created the first time [Sword()](./Sworduh#Sword) is called.
    It is removed by [Unsword()](./Sworduh#Unsword) and during [Cleanup()](./Sworduh#Cleanup).
]=]

local Sworduh: Sworduh = {} :: Sworduh
Sworduh.ClassName = "Sworduh"
Sworduh.__index = Sworduh

Sworduh.SwordObjects = {} :: {[Player | Model]: SwordHandler}
Sworduh.LastDamagerCache = {} :: {[Player | Model]: Player | Model}
Sworduh.Connections = {} :: {[Player | Model]: RBXScriptConnection | {Disconnect: () -> ()}}
Sworduh.RespawnConnections = {} :: {[Player]: RBXScriptConnection}

-- Public Methods

--[=[
    Retrieves a player's character using a promise-based flow. 
]=]

function Sworduh:_getPlayerCharacter(player: Player): Promise<Model>
    if not player or player.Parent == nil then
        return Promise.reject("Player is invalid or has left the game")
    end
    
    local existingCharacter = player.Character
    if existingCharacter and existingCharacter.Parent then
        return Promise.resolve(existingCharacter)
    end

    local candidates = {}

    if existingCharacter and not existingCharacter.Parent then
        local characterReference = existingCharacter
        table.insert(candidates, Promise.fromEvent(characterReference.AncestryChanged, function(_, parent)
            return parent ~= nil
        end):andThen(function()
            return characterReference
        end))
    end

    table.insert(candidates, Promise.fromEvent(player.CharacterAdded, function(character: Model?) -- Model should always be valid, but I do not trust Roblox
        return character ~= nil and character.Parent ~= nil
    end))

    table.insert(candidates, Promise.fromEvent(player.AncestryChanged, function(_, parent)
        return parent == nil
    end):andThen(function()
        return Promise.reject("Player", player.Name, "left before character loaded")
    end))

    table.insert(candidates, Promise.delay(Configuration.CHARACTER.TIMEOUT):andThen(function()
        return Promise.reject("Character loading timeout for player", player.Name)
    end))

    return Promise.race(candidates)
end

--[=[
    Creates and equips a sword for the specified player or NPC.

    When [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER) is true, player's who this method is called on
    will automatically recieve a new sword when respawning. This is disabled by calling [Unsword()](./Sworduh#Unsword), or setting the configuration to false.
    NPCs are not affected by this, and do not recieve swords on respawn. 

    If the entity already has a sword, the existing sword handler is returned.

    :::tip
    This method is safe to call multiple times for the same entity - it will return 
    the existing sword if one is already equipped.
    :::

    :::warning
    If character loading fails or times out, this method returns `nil`. Always check
    the return value before using the sword handler.
    :::

    @param target -- The entity to equip with a sword
    @return SwordHandler? -- The created sword handler, or nil if failed
    @yields -- May yield while waiting for character to load
    @error "Invalid target" -- When target is missing or has left the game
    @tag core
    @since v0.2.0
    
    ## Example
    
    ```lua
    local sword = Sworduh:Sword(player)
    if sword then
        -- Check if still active later
        if sword:IsActive() then
            print("Sword is still active!")
        end
    else
        warn("Failed to give sword to", player.Name)
    end
    ```
]=]

function Sworduh:Sword(target: Player | Model): SwordHandler?
    if not target or not target.Parent then
        warn("Attempted to sword a missing or invalid target.")
        return nil
    end

	local character: Model?

    if Utils.isPlayer(target) then
        local success, result = self:_getPlayerCharacter(target :: Player):await()

        if not success then
            warn("Failed to get character for", target.Name, "|\n", tostring(result))
            return nil
        end

        if not (target :: Player).Parent then
            warn("Player", target.Name, "left after character resolved")
        end

        if not (result :: Model).Parent then
            warn("Character for", target.Name, "became unparented")
        end
        
        character = result
    else
        character = target :: Model
        assert(character, "Target must be a Model")

        if not character:FindFirstChild("Humanoid") then
            warn("NPC missing Humanoid: ", target.Name)
            return nil
        end
    end

    assert(character, "Character is nil")
    local humanoid = character:WaitForChild("Humanoid", Configuration.CHARACTER.TIMEOUT)
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", Configuration.CHARACTER.TIMEOUT)
    
    if not humanoid or not humanoidRootPart then
        warn("Character components not ready for", target.Name)
        return nil
    end

    if not self.SwordObjects then
        self.SwordObjects = {}
    end

	local existingSword = self.SwordObjects[target]
	if existingSword then
        if existingSword.SwordTool and existingSword.SwordTool.Parent == character then
            return existingSword
        end

        self:_cleanupEntitySword(target)
	end

    local swordTool: Tool? = self:_createSword()
    if not swordTool then
        warn("Failed to create sword tool for", target.Name)
        return nil
    end

    swordTool.Parent = character

    local success, swordObject = pcall(function()
        return SwordHandler.new(target, swordTool, self.LastDamagerCache)
    end)

    if not success then
        warn("Failed to create sword handler for", target.Name, " |\n", swordObject)
        if swordTool then
            swordTool:Destroy()
        end
        return nil
    end

    self.SwordObjects[target] = swordObject
    self:_setupEntityConnections(target)

    if Utils.isPlayer(target) then
        self:_setupPlayerRespawnConnections(target :: Player)
    end

    return swordObject
end

--[=[
    Gives a sword to all players currently in the game.
    
    This method calls [Sworduh:Sword] for each player currently in the server.

    :::warning
    This does not affect NPCs.
    :::
    
    :::warning
    Players who join after this method is called will not automatically receive swords.
    You'll need to call this method again or set up individual player handling.
    :::
    
    @tag utility
    @since v0.2.0
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
    Removes an entity's sword and cleans up all associated data.

    For players, this also removes their respawn connection. 
    This means they will no longer recieve a sword when respawning, even if 
    [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER) is true.
    Re-call [Sword()](./Sworduh#Sword) to re-establish this connection. 

    @param target -- The player whose sword should be removed
    @return boolean -- `true` if a sword was removed, `false` if no sword was found
    @tag core
    @since v0.2.0
]=]

function Sworduh:Unsword(target: Player | Model): boolean
    if not target then
        return false
    end

    self:_cleanupEntitySword(target)

    if Utils.isPlayer(target) then
        self:_cleanupPlayerRespawnConnection(target :: Player)
    end

    return self.SwordObjects[target] == nil
end

--[=[
    Removes swords from all entities in the game.
    
    This method calls [Sworduh:Unsword] for every entity who currently has a sword.
    Useful for ending game modes or resetting the server state.
    
    @since v0.2.0
]=]

function Sworduh:UnswordAll()
    -- Create a copy to avoid modification during iteration
    local targets: {Player | Model} = {}
    for target, _ in pairs(self.SwordObjects) do
        table.insert(targets, target)
    end

    for i = 1, #targets do
        self:Unsword(targets[i])
    end
end

--[=[
    Returns the last entity that damaged the specified target.
    
    This method is essential for kill tracking, leaderboard systems, and reward distribution.
    The damage cache automatically validates that the killer is still in the game and has
    a valid character before returning them.
    
    :::tip
    This method automatically cleans up invalid killers (players who have left the game),
    so you can trust that any returned player is still valid.
    :::

    @param target -- The entity to find the killer for
    @return (Player | Model)? -- The entity who last damaged the specified player, or nil if no valid killer exists
    @tag utility
    @since v0.2.0
    
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

function Sworduh:GetKiller(target: Player | Model): Player | Model?
    if not target then
        return nil
    end
    local killer = self.LastDamagerCache[target]
    if not killer then
        return nil
    end

    if Utils.isPlayer(killer) then
        local player = killer :: Player
        if player.Character and player.Character.Parent and Players:GetPlayerFromCharacter(player.Character) then
            return killer
        end
    else
        local model = killer :: Model
        if model.Parent and model:FindFirstChild("Humanoid") then
            return killer
        end
    end
    
    self.LastDamagerCache[target] = nil
    return nil
end

--[=[
    Cleans up the entire sword system.

    - Removes all swords from players and NPCs
    - Clears internal caches
    - Disconnects all event connections, including per-entity events and per-player respawn connections.

    This method should always be called when shutting down the system to prevent memory leaks.
    
    :::warning
    After calling this method, the Sworduh instance will be in a clean state but
    you'll need to re-establish any swords for continuing gameplay.
    :::
    
    @since v0.2.0
    
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

    for _, connection in pairs(self.Connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" and connection.Connected then
                connection:Disconnect()
            elseif typeof(connection) == "table" and connection.Disconnect then
                connection.Disconnect()
            end
        end
    end
    table.clear(self.Connections)

    for _, connection in pairs(self.RespawnConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    table.clear(self.RespawnConnections)
end

-- Private Methods

--[=[
    Sets up event connections for an entity.
    
    Creates connections for character removal and entity destruction events to automatically 
    clean up sword data when appropriate. For players, connects to CharacterRemoving.
    For NPCs, connects to AncestryChanged.

    @param target -- The player or NPC to set up connections for
    @private
    @since v0.2.0
]=]

function Sworduh:_setupEntityConnections(target: Player | Model)

    local existingConnection = self.Connections[target]
    if existingConnection then
        if typeof(existingConnection) == "RBXScriptConnection" and existingConnection.Connected then
            existingConnection:Disconnect()
        elseif typeof(existingConnection) == "table" and existingConnection.Disconnect then
            existingConnection.Disconnect()
        end
    end

    local connections: {RBXScriptConnection} = {}

    if Utils.isPlayer(target) then
        table.insert(connections, (target :: Player).CharacterRemoving:Connect(function()
            self:_cleanupEntitySword(target)
        end)) 
    end

    table.insert(connections, target.AncestryChanged:Connect(function()
        if not target.Parent then
            self:_cleanupEntitySword(target)
            if Utils.isPlayer(target) then
                self:_cleanupPlayerRespawnConnection(target :: Player)
            end
        end
    end))

    self.Connections[target] = {
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
    Cleans up all data associated with a entity's sword.
    
    Destroys the sword handler, removes the entity from tracking caches,
    and disconnects any entity-specific event connections.

    @param target -- The player or NPC whose sword data should be cleaned up
    @private
    @since v0.2.0
]=]

function Sworduh:_cleanupEntitySword(target: Player | Model)
    local swordObject = self.SwordObjects[target]
    if swordObject then
        if swordObject.Destroy then
            swordObject:Destroy()
        end
        self.SwordObjects[target] = nil
    end

    self.LastDamagerCache[target] = nil

    local connection = self.Connections[target]
    if connection then
        if typeof(connection) == "RBXScriptConnection" and connection.Connected then
            connection:Disconnect()
        elseif typeof(connection) == "table" and connection.Disconnect then
            connection.Disconnect()
        end
        self.Connections[target] = nil
    end
end

--[=[
    Sets up the player's respawn connection.

    Creates a CharacterAdded connection for the provided player.
    On respawn, if the [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER) is true,
    a new sword will be given to the player.

    This connection is created when you call [Sword()](./Sworduh#Sword) and is disconnected by [Unsword()](./Sworduh#Unsword) or [Cleanup()](./Sworduh#Cleanup)

    @param target Player
    @private
    @since v0.2.0
]=]

function Sworduh:_setupPlayerRespawnConnections(target: Player)
    if 
        Utils.isPlayer(target) 
        and Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN 
        and not self.RespawnConnections[target] 
    then
        self.RespawnConnections[target] = (target :: Player).CharacterAdded:Connect(function(character)
            if character and character.Parent then
                self:_cleanupEntitySword(target)
                self:Sword(target)
            end
        end)
    end
end

--[=[
    Removes the provided player's respawn connection.

    After this is called, the player will not automatically receive a sword on
    future respawns (regardless of the [Configuration.CHARACTER.GIVE_SWORD_ON_SPAWN](./Configuration#CHARACTER) configuration)
    until [Sword()](./Sworduh#Sword) is called again.

    @param target Player
    @private
    @since v0.2.0
]=]

function Sworduh:_cleanupPlayerRespawnConnection(target: Player)
    local connection = self.RespawnConnections[target]

    if connection then
        connection:Disconnect()
        self.RespawnConnections[target] = nil
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
    sword.CanBeDropped = Configuration.TOOL.CAN_BE_DROPPED
    sword.Grip = Configuration.TOOL.GRIPS.UP
    sword.TextureId = Configuration.TOOL.ASSETS.TEXTURE_ID
    sword.RequiresHandle = true

    local success, handle = pcall(function()
        return InsertService:CreateMeshPartAsync(
            Configuration.TOOL.ASSETS.MESH_ID,
            Enum.CollisionFidelity.Default,
            Enum.RenderFidelity.Automatic
        )
    end)

    if not success then
        warn("Failed to create sword mesh |\n", handle)
        return nil
    end

    handle.Name = "Handle"
    handle.Massless = true
    handle.TextureID = Configuration.TOOL.ASSETS.MESH_TEXTURE_ID
    handle.Parent = sword

    local hitbox = Instance.new("Part")
    hitbox.Name = "Hitbox"
    hitbox.Massless = true
    hitbox.Size = Configuration.SWORD_PROPERTIES.HITBOX_SIZE
    hitbox.CFrame = handle.CFrame * CFrame.new(Configuration.SWORD_PROPERTIES.HITBOX_OFFSET)
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
            id = Configuration.TOOL.ASSETS.SOUND_IDS.SLASH,
            volume = Configuration.SOUND_SETTINGS.SLASH.VOLUME,
        },
        lunge = {
            name = "Lunge",
            id = Configuration.TOOL.ASSETS.SOUND_IDS.LUNGE,
            volume = Configuration.SOUND_SETTINGS.LUNGE.VOLUME,
        },
        unsheathe = {
            name = "Unsheathe",
            id = Configuration.TOOL.ASSETS.SOUND_IDS.UNSHEATHE,
            volume = Configuration.SOUND_SETTINGS.UNSHEATHE.VOLUME,
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