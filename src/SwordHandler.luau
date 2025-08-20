--[=[
    @class SwordHandler
    @server

    Individual sword handler for the Sworduh system. 
    
    Each sword has a handler associated with it, which is created and returned from [Sworduh:Sword].
    You typically won't create handlers directly, but let the main [Sworduh] class manage them.
    
    :::warning
    Do not create SwordHandler instances directly. Always use [Sworduh:Sword] to create sword handlers.
    :::
    
    @since v0.1.0
]=]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Utils = require(script.Parent:WaitForChild("Utils"))
local Configuration = require(script.Parent:WaitForChild("Configuration"))

--[=[
    @interface SwordHandler
    @within SwordHandler

    @field __index SwordHandler
    @field new (target: Player | Model, sword: Tool, lastDamagerCache: {[Player | Model]: Player | Model}): SwordHandler -- Constructor

    @field Owner (Player | Model)? -- The player or NPC who owns this sword instance.
    @field SwordTool Tool? -- The [Tool](https://create.roblox.com/docs/reference/engine/classes/Tool) instance for the sword.
    @field LastDamagerCache {[Player | Model]: Player | Model} -- A reference to the shared cache from the main [Sworduh](Sworduh) module.
    @field ToolHandle BasePart?
    @field Hitbox BasePart?
    @field Sounds {[string]: Sound}
    @field Damage number -- The current damage value of the sword. Changes based on the attack type. (base/slash/lunge/passive)
    @field IsAttacking boolean -- True when the sword is currently in an attack animation.
    @field LastAttackTime number -- The os.clock() timestamp of the last attack.
    @field IsToolEquipped boolean
    @field IsDestroyed boolean
    @field Connections {[string]: RBXScriptConnection}
    @field ActiveTasks {thread} -- List of active threads for scheduled tasks.

    @field Destroy (self: SwordHandler)
    @field IsActive (self: SwordHandler): boolean
]=]

export type SwordHandler = {
    __index: SwordHandler,
    new: (player: Player | Model, sword: Tool, lastDamagerCache: {[Player | Model]: Player | Model}) -> SwordHandler,

    Owner: Player | Model?,
    SwordTool: Tool?,
    LastDamagerCache: {[Player | Model]: Player | Model},
    ToolHandle: BasePart?,
    Hitbox: BasePart?,
    Sounds: {[string]: Sound},
    Damage: number,
    IsAttacking: boolean,
    LastAttackTime: number,
    IsToolEquipped: boolean,
    IsDestroyed: boolean,
    Connections: {[string]: RBXScriptConnection},
    ActiveTasks: {thread},

    Destroy: (self: SwordHandler) -> (),
    IsActive: (self: SwordHandler) -> boolean,
    _initialize: (self: SwordHandler) -> (),
    _onActivated: (self: SwordHandler) -> (),
    _onEquipped: (self: SwordHandler) -> (),
    _onUnequipped: (self: SwordHandler) -> (),
    _onTouch: (self: SwordHandler, hit: BasePart) -> (),
    _isOwnerAlive: (self: SwordHandler) -> boolean,
    _playAnimation: (self: SwordHandler, animationName: string) -> (),
    _performSlash: (self: SwordHandler) -> (),
    _performLunge: (self: SwordHandler) -> (),
    _resetSwordState: (self: SwordHandler) -> (),
    _setSwordGrip: (self: SwordHandler, gripType: "UP" | "OUT") -> (),
    _cleanupCompletedTasks: (self: SwordHandler) -> (),
    _scheduleTask: (self: SwordHandler, callback: () -> (), delay: number) -> (),
}

local SwordHandler: SwordHandler = {}:: SwordHandler
SwordHandler.__index = SwordHandler

--[=[
    Creates a new sword handler for a player or NPC.
    
    :::warning
    This constructor should not be called directly. Use [Sworduh:Sword] instead.
    :::
    
    @param owner -- The player or NPC who owns this sword
    @param sword -- The sword tool instance
    @param lastDamagerCache -- Shared cache for tracking damage between entities
    @return SwordHandler -- The new handler instance
    @error "Invalid target" -- When target is missing or has left/been destroyed
    @error "Invalid sword tool" -- When sword tool is missing or invalid
    @error "Essential sword components missing" -- When Handle or Hitbox are missing
    @since v0.2.0
]=]

function SwordHandler.new(owner: Player | Model, sword: Tool, lastDamagerCache: {[Player | Model]: Player | Model}): SwordHandler
    local self = setmetatable({} :: any, SwordHandler) :: SwordHandler

    assert(owner and owner.Parent, "Player is invalid or has left the game")
    assert(sword and sword.Parent, "Invalid sword tool")

    self.Owner = owner
    self.SwordTool = sword
    self.LastDamagerCache = lastDamagerCache

    local handle = sword:WaitForChild("Handle", Configuration.SYSTEM.COMPONENT_WAIT_TIME) :: BasePart
    local hitbox = sword:WaitForChild("Hitbox", Configuration.SYSTEM.COMPONENT_WAIT_TIME) :: BasePart
    assert(handle and hitbox, "Essential sword components missing")

    self.ToolHandle = handle
    self.Hitbox = hitbox

    self.Sounds = {}
    for _, soundName in Configuration.SYSTEM.SOUND_NAMES do
        local sound = handle:WaitForChild(soundName, Configuration.SYSTEM.COMPONENT_WAIT_TIME) :: Sound?
        if sound then
            self.Sounds[soundName] = sound
        else
            warn("Missing sound:".. soundName.. " for player".. owner.Name)
        end
    end

    self.Damage = Configuration.COMBAT.DAMAGE_VALUES.BASE
    self.IsAttacking = false
    self.LastAttackTime = 0
    self.IsToolEquipped = false
    self.IsDestroyed = false

    self.Connections = {}
    self.ActiveTasks = {}

    self:_initialize()

    return self
end

-- Public

--[=[
    Safely destroys the handler and cleans up all resources.

    Cancels any running tasks, disconnects all event connections, destroys the sword tool, 
    and clears all references.
    
    :::tip
    This method is safe to call multiple times, it will not error if already destroyed.
    :::

    @tag core
    @since v0.1.0
    
    ## Example
    
    ```lua
    local sword = Sworduh:Sword(player)
    if sword then
        -- Later when cleaning up...
        sword:Destroy()
    end
    ```
]=]

function SwordHandler:Destroy()
    if self.IsDestroyed then return end
    self.IsDestroyed = true

    for _, taskThread in pairs(self.ActiveTasks) do
        if taskThread then
            task.cancel(taskThread)
        end
    end
    table.clear(self.ActiveTasks)

    for _, connection in pairs(self.Connections) do
        if connection then
            if connection.Connected then
                connection:Disconnect()
            end
        end
    end
    table.clear(self.Connections)

    if self.SwordTool and self.SwordTool.Parent then
        self.SwordTool:Destroy()
    end

    self.Owner = nil
    self.SwordTool = nil
    self.ToolHandle = nil
    self.Hitbox = nil
    table.clear(self.Sounds)
end

--[=[
    Checks if the sword handler is active and the owner is alive.
    
    A handler is considered active when:
    - It has not been destroyed
    - The owner is still in the game
    - The owner has a valid character
    - The character has required components (Humanoid, HumanoidRootPart)

    @return boolean -- `true` if the handler is active, `false` otherwise
    @tag utility
    @since v0.2.0
    
    ## Example
    
    ```lua
    local sword = Sworduh:Sword(player)
    if sword then
        -- Check periodically if sword is still valid
        if sword:IsActive() then
            print("Sword is ready for combat!")
        else
            print("Sword is no longer active")
        end
    end
    ```
]=]

function SwordHandler:IsActive(): boolean
    return not self.IsDestroyed and self:_isOwnerAlive()
end

-- Private

--[=[
    Sets up event connections for the sword tool.

    Connects tool activation, equipping/unequipping, hitbox touches, and tool destruction. 
    All connections are automatically cleaned up when [SwordHandler:Destroy] is called.
    
    This method handles:
    - Tool.Activated for slash/lunge attacks
    - Tool.Equipped for sword equipping
    - Tool.Unequipped for sword unequipping  
    - Hitbox.Touched for damage detection
    - Tool.AncestryChanged for cleanup when tool is removed

    @private
    @since v0.1.0
]=]

function SwordHandler:_initialize()
    if not self.SwordTool or not self.Hitbox then
        return
    end

    self.Connections["Activated"] = self.SwordTool.Activated:Connect(function()
        self:_onActivated()
    end)
    
    self.Connections["Equipped"] = self.SwordTool.Equipped:Connect(function()
        self:_onEquipped()
    end)
    
    self.Connections["Unequipped"] = self.SwordTool.Unequipped:Connect(function()
        self:_onUnequipped()
    end)

    self.Connections["Touched"] = self.Hitbox.Touched:Connect(function(hit)
        self:_onTouch(hit)
    end)

    self.Connections["AncestryChanged"] = self.SwordTool.AncestryChanged:Connect(function()
        if not self.SwordTool or not self.SwordTool.Parent then
            self:Destroy()
        end
    end)

    self:_setSwordGrip("UP")
end


--[=[
    Handles sword activation (clicking).

    Determines whether to perform a slash or a lunge attack based on the timing between clicks.
    If clicked again within the lunge window, performs a lunge. Otherwise performs a slash.

    @private
    @tag core
    @since v0.1.0
]=]

function SwordHandler:_onActivated()
    if self.IsDestroyed or self.IsAttacking or not self.IsToolEquipped or not self:_isOwnerAlive() then
        return
    end

    local currentTime = os.clock()
    local timeSinceLastAttack = currentTime - self.LastAttackTime
    local isLungeAttempt = timeSinceLastAttack < Configuration.TIMING.LUNGE_WINDOW

    self.LastAttackTime = currentTime

    if isLungeAttempt then
        self:_performLunge()
    else
        self:_performSlash()
    end
end

--[=[
    Called when the player or NPC equips their sword.
    
    Plays the unsheathe sound effect and updates the tool equipped state.

    @private
    @since v0.2.0
]=]

function SwordHandler:_onEquipped()
    if not self:_isOwnerAlive() or self.IsDestroyed then
        return
    end

    self.IsToolEquipped = true

    local unsheatheSound = self.Sounds.Unsheathe
    if unsheatheSound then
        unsheatheSound:Play()
    end
end

--[=[
    Called when the player or NPC unequips their sword.
    
    Resets the sword to its default state, stopping any ongoing attacks.

    @private
    @since v0.2.0
]=]

function SwordHandler:_onUnequipped()
    self:_resetSwordState()
end

--[=[
    Called when the sword's hitbox touches another part.

    Handles damage calculation, team checking, distance validation, and damage application.
    Also updates the damage tracking cache.
    
    The method performs these checks:
    - Validates the hit target is a valid character
    - Ensures different teams
    - Checks distance limits for damage
    - Applies appropriate damage based on attack type
    - Updates last damager cache

    @param hit -- The part that was touched by the sword hitbox
    @private
    @tag core
    @since v0.1.0
]=]

function SwordHandler:_onTouch(hit: BasePart)
    if self.IsDestroyed or not self:_isOwnerAlive() or not self.Owner then
        return
    end

    local hitCharacter = hit.Parent
    if not hitCharacter then
        return
    end
    
    local targetEntity: (Player | Model?) = nil
    local targetPlayer = Players:GetPlayerFromCharacter(hitCharacter :: Model)
     if targetPlayer then
        targetEntity = targetPlayer
    elseif hitCharacter:FindFirstChild("Humanoid") then
        targetEntity = hitCharacter :: Model
    end

    if not targetEntity or targetEntity == self.Owner then
        return
    end

    local myTeam = Utils.getTeam(self.Owner)
    local theirTeam = Utils.getTeam(targetEntity)
    if myTeam and theirTeam and myTeam == theirTeam then
        return
    end

    local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
    local hitRoot = hitCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hitHumanoid or not hitRoot then
        return
    end

    local myCharacter = Utils.getCharacter(self.Owner)
    if not myCharacter then return end
    local myRoot = myCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not myRoot then return end

    local deltaPosition = hitRoot.Position - myRoot.Position
    local studCap = Configuration.COMBAT.STUD_CAP

    if math.abs(deltaPosition.X) > studCap or 
        math.abs(deltaPosition.Y) > studCap or 
        math.abs(deltaPosition.Z) > studCap then
        return
    end

    local distanceSquared = deltaPosition.X^2 + deltaPosition.Y^2 + deltaPosition.Z^2

    if distanceSquared > studCap^2 then
        return
    end

    self.LastDamagerCache[targetEntity] = self.Owner

    local damage = (self.Damage == Configuration.COMBAT.DAMAGE_VALUES.BASE)
        and Configuration.COMBAT.DAMAGE_VALUES.PASSIVE
        or self.Damage

    hitHumanoid:TakeDamage(damage)
end

--[=[
    Checks if the handler's associated player or NPC is alive and in the game.

    @within SwordHandler
    @return boolean
    @private
]=]

function SwordHandler:_isOwnerAlive(): boolean
    if not self.Owner or not self.Owner.Parent then
        return false
    end

    local character = Utils.getCharacter(self.Owner)
    if not character or not character.Parent then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

--[=[
    Plays a tool animation by creating a specific [StringValue](https://create.roblox.com/docs/reference/engine/classes/StringValue)

    This is achieved by creating a StringValue named "toolanim" with a value of the animation name. (ex. "Slash", "Lunge")
    The default character animation scripts will listen for these StringValues and play them automatically.

    @within SwordHandler
    @param animationName string
    @private
]=]

function SwordHandler:_playAnimation(animationName: string)
    if self.IsDestroyed or not self.SwordTool then
        return
    end

    local animation = Instance.new("StringValue")
    animation.Name = "toolanim"
    animation.Value = animationName
    animation.Parent = self.SwordTool

    Debris:AddItem(animation, 0.1)
end

--[=[
    Performs a slash attack.

    @within SwordHandler
    @private
]=]

function SwordHandler:_performSlash()
    self.Damage = Configuration.COMBAT.DAMAGE_VALUES.SLASH

    local slashSound = self.Sounds.Slash
    if slashSound then
        slashSound:Play()
    end
    
    self:_playAnimation("Slash")

    self:_scheduleTask(function()
        if not self.IsDestroyed and self.Damage == Configuration.COMBAT.DAMAGE_VALUES.SLASH then
            self.Damage = Configuration.COMBAT.DAMAGE_VALUES.BASE
        end
    end, Configuration.TIMING.SLASH_TIME)
end

--[=[
    Performs a lunge attack. 

    @within SwordHandler
    @private
]=]

function SwordHandler:_performLunge()
    self.Damage = Configuration.COMBAT.DAMAGE_VALUES.LUNGE
    self.IsAttacking = true

    local lungeSound = self.Sounds.Lunge
    if lungeSound then
        lungeSound:Play()
    end
    
    self:_playAnimation("Lunge")

    self:_scheduleTask(function()
        if not self.IsDestroyed and self.IsAttacking then
            self:_setSwordGrip("OUT")
        end
    end, Configuration.TIMING.SLASH_TIME + 0.05)

    self:_scheduleTask(function()
        if not self.IsDestroyed then
            self:_setSwordGrip("UP")
            self.IsAttacking = false
            self.Damage = Configuration.COMBAT.DAMAGE_VALUES.BASE
        end
    end, Configuration.TIMING.SLASH_TIME + Configuration.TIMING.LUNGE_TIME)
end

--[=[
    Resets sword states to defaults.

    Called when attack is complete, or when the sword is unequipped.

    @within SwordHandler
    @private
]=]

function SwordHandler:_resetSwordState()
    self.IsAttacking = false
    self.Damage = Configuration.COMBAT.DAMAGE_VALUES.BASE
    self.IsToolEquipped = false

    if not self.IsDestroyed and self.SwordTool then
        self:_setSwordGrip("UP")
    end
end

--[=[
    Changes the way the sword is held.

    @within SwordHandler
    @param gripType "UP" | "OUT" -- UP for normal position, OUT for lunge position
    @private
]=]

function SwordHandler:_setSwordGrip(gripType: "UP" | "OUT")
    if self.IsDestroyed or not self.SwordTool then
        return
    end

    local grip = Configuration.TOOL.GRIPS[gripType]
    if not grip then
        return
    end
    
    self.SwordTool.Grip = grip
end

--[=[
    Removes completed tasks from the active tasks list. 
    Called when a new task is scheduled, and the [TASK_CLEANUP_THRESHOLD]() has been reached.

    @within SwordHandler
    @private
]=]

function SwordHandler:_cleanupCompletedTasks()
    -- Use swap-remove pattern
    local writeIndex = 1
    for readIndex = 1, #self.ActiveTasks do
        local taskThread = self.ActiveTasks[readIndex]
        if taskThread and coroutine.status(taskThread) ~= "dead" then
            self.ActiveTasks[writeIndex] = taskThread
            writeIndex += 1
        end
    end
    
    for i = writeIndex, #self.ActiveTasks do
        self.ActiveTasks[i] = nil
    end
end

--[=[
    Schedules a function to run after a delay (seconds)
    Automatically cleans task on completion.

    @within SwordHandler
    @param callback () -> () -- The function to call after the delay
    @param delay number -- How long to wait before calling the function
    @private
]=]

function SwordHandler:_scheduleTask(callback: () -> (), delay: number)
    if self.IsDestroyed then
        return
    end

    local taskThread = task.delay(delay, function()
        if not self.IsDestroyed then
            callback()
        end
    end)
    
    table.insert(self.ActiveTasks, taskThread)
    
    if #self.ActiveTasks > Configuration.SYSTEM.TASK_CLEANUP_THRESHOLD then
        self:_cleanupCompletedTasks()
    end
end

return SwordHandler