--[=[
    @class Configuration
    @server

    Centralized configuration for the Sworduh system.
    
    The current values assigned to the configuration should be
    treated as the default values.

    :::tip
    Modify values in this file to customize the sword system behavior. Changes will
    automatically apply to all sword instances.
    :::

    @since v0.1.0
]=]
--[=[
    @interface CHARACTER
    @within Configuration
    
    Settings for character loading, validation, and readiness checking.
    
    .TIMEOUT number -- Maximum time to wait for character components (seconds)
    .POLL_INTERVAL number -- How often to check if character is ready (seconds)
    .GIVE_SWORD_ON_SPAWN boolean -- When true, players (not NPCs) will automatically recieve a sword on respawn
]=]

--[=[
    @interface TIMING
    @within Configuration
    
    Attack timing and animation durations.
    
    .SLASH_TIME number -- Duration of slash attack (seconds)
    .LUNGE_TIME number -- Duration of lunge attack (seconds) 
    .LUNGE_WINDOW number -- Time window for lunge activation (seconds)
]=]

--[=[
    @interface DAMAGE_VALUES
    @within Configuration
    
    Different damage amounts for each attack type.
    
    .BASE number
    .SLASH number
    .LUNGE number
    .PASSIVE number
]=]

--[=[
    @interface COMBAT
    @within Configuration
    
    Combat mechanics including damage values and range limitations.
    
    .STUD_CAP number -- Maximum distance for damage (studs)
    .DAMAGE_VALUES DAMAGE_VALUES
]=]

--[=[
    @interface GRIPS
    @within Configuration
    
    Tool grip configurations for different combat states.
    
    .UP CFrame -- Normal grip position
    .OUT CFrame -- Extended grip for lunge attacks
]=]

--[=[
    @interface ASSETS
    @within Configuration
    
    Asset IDs for sword appearance and sound effects.
    
    .TEXTURE_ID string
    .MESH_ID string
    .MESH_TEXTURE_ID string
    .SOUND_IDS SOUND_IDS
]=]

--[=[
    @interface SOUND_IDS
    @within Configuration
    
    Asset IDs for sword sound effects.
    
    .SLASH string
    .LUNGE string
    .UNSHEATHE string
]=]

--[=[
    @interface TOOL
    @within Configuration
    
    Settings for the tool object.
    
    .CAN_BE_DROPPED boolean -- Whether players can drop their sword
    .GRIPS GRIPS
    .ASSETS ASSETS
]=]

--[=[
    @interface SYSTEM
    @within Configuration
    
    System performance, cleanup, and component management settings.
    
    .TASK_CLEANUP_THRESHOLD number -- Clean up completed tasks when this many accumulate
    .COMPONENT_WAIT_TIME number -- Seconds to wait for sword components
    .SOUND_NAMES {string} -- Required sound effect names
]=]

--[=[
    @interface SWORD_PROPERTIES
    @within Configuration
    
    Physical properties and dimensions of the sword and its components.
    
    .HANDLE_SIZE Vector3
    .HITBOX_SIZE Vector3 -- Damage detection area size
    .HITBOX_OFFSET Vector3 -- Position offset of hitbox relative to handle
]=]

--[=[
    @interface SOUND_SETTINGS
    @within Configuration
    
    Audio settings for sword sound effects.
    
    .SLASH SOUND -- Slash attack sound settings
    .LUNGE SOUND -- Lunge attack sound settings
    .UNSHEATHE SOUND -- Sword equip sound settings
]=]

--[=[
    @interface SOUND
    @within Configuration
    
    Configuration for individual sound effects.
    
    .VOLUME number -- Audio volume level (0.0 to 1.0)
]=]

--[=[
    @interface Configuration
    @within Configuration
    
    Complete configuration structure for the sword system.
    
    .CHARACTER CHARACTER -- Character loading and validation settings
    .TIMING TIMING -- Attack timing and animation durations
    .COMBAT COMBAT -- Combat mechanics and damage settings
    .TOOL TOOL -- Tool behavior and appearance settings
    .SYSTEM SYSTEM -- System performance and cleanup settings
    .SWORD_PROPERTIES SWORD_PROPERTIES -- Physical properties of the sword
    .SOUND_SETTINGS SOUND_SETTINGS -- Audio settings for sound effects
]=]

local Configuration = {
    
    COMBAT = {
        STUD_CAP = 12, -- Maximum distance for damage (studs)

        DAMAGE_VALUES = {
            BASE = 5,
            SLASH = 10,
            LUNGE = 30,
            PASSIVE = 3,
        },
    },

    TIMING = {
        SLASH_TIME = 0.25, -- Duration of slash attack (seconds)
        LUNGE_TIME = 0.75, -- Duration of lunge attack (seconds)
        LUNGE_WINDOW = 0.2, -- Time window for lunge activation (seconds)
    },

    SWORD_PROPERTIES = {
        HANDLE_SIZE = Vector3.new(0.4, 0.4, 4),
        HITBOX_SIZE = Vector3.new(1, 0.8, 4), -- Damage detection area size
        HITBOX_OFFSET = Vector3.new(0, 0, 0), -- Offset from handle center
    },

    SOUND_SETTINGS = {
        SLASH = {
            VOLUME = 0.7,
        },
        LUNGE = {
            VOLUME = 0.6,
        },
        UNSHEATHE = {
            VOLUME = 1.0,
        },
    },

    TOOL = {
        CAN_BE_DROPPED = false,

        GRIPS = {
            UP = CFrame.new(0, 0, -1.5, 0, 0, 1, 1, 0, 0, 0, 1, 0), -- Normal grip
            OUT = CFrame.new(0, 0, -1.5, 0, -1, -0, -1, 0, -0, 0, 0, -1), -- Lunge grip
        },
        
        ASSETS = {
            TEXTURE_ID = "http://www.roblox.com/asset/?id=124987047",
            MESH_ID = "http://www.roblox.com/asset/?id=12221720",
            MESH_TEXTURE_ID = "http://www.roblox.com/asset/?id=12224218",
            
            SOUND_IDS = {
                SLASH = "http://www.roblox.com/asset/?id=12222216",
                LUNGE = "http://www.roblox.com/asset/?id=12222208",
                UNSHEATHE = "http://www.roblox.com/asset/?id=12222225",
            },
        },
    },
    
    CHARACTER = {
        TIMEOUT = 5, -- Maximum time to wait for character components (seconds)
        POLL_INTERVAL = 0.1, -- How often to check if character is ready (seconds)
        GIVE_SWORD_ON_SPAWN = true,
    },

    SYSTEM = {
        TASK_CLEANUP_THRESHOLD = 10, -- Clean up completed tasks when this many accumulate
        COMPONENT_WAIT_TIME = 5, -- Seconds to wait for sword components
        SOUND_NAMES = {"Slash", "Lunge", "Unsheathe"}, -- Required sound effect names
    },

}

return Configuration