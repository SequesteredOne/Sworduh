/// <reference types="@rbxts/types" />

export interface DamageValues {
    BASE: number;
    SLASH: number;
    LUNGE: number;
    PASSIVE: number;
}

export interface Combat {
    STUD_CAP: number;
    DAMAGE_VALUES: DamageValues;
}

export interface Timing {
    SLASH_TIME: number;
    LUNGE_TIME: number;
    LUNGE_WINDOW: number;
}

export interface SwordProperties {
    HANDLE_SIZE: Vector3;
    HITBOX_SIZE: Vector3;
    HITBOX_OFFSET: Vector3;
}

export interface Sound {
    VOLUME: number;
}

export interface SoundSettings {
    SLASH: Sound;
    LUNGE: Sound;
    UNSHEATHE: Sound;
}

export interface Grips {
    UP: CFrame;
    OUT: CFrame;
}

export interface SoundIds {
    SLASH: string;
    LUNGE: string;
    UNSHEATHE: string;
}

export interface Assets {
    TEXTURE_ID: string;
    MESH_ID: string;
    MESH_TEXTURE_ID: string;
    SOUND_IDS: SoundIds;
}

export interface Tool {
    CAN_BE_DROPPED: boolean;
    GRIPS: Grips;
    ASSETS: Assets;
}

export interface Character {
    TIMEOUT: number;
    POLL_INTERVAL: number;
    GIVE_SWORD_ON_SPAWN: boolean;
}

export interface System {
    TASK_CLEANUP_THRESHOLD: number;
    COMPONENT_WAIT_TIME: number;
    SOUND_NAMES: string[];
}

export interface Configuration {
    COMBAT: Combat;
    TIMING: Timing;
    SWORD_PROPERTIES: SwordProperties;
    SOUND_SETTINGS: SoundSettings;
    TOOL: Tool;
    CHARACTER: Character;
    SYSTEM: System;
}

declare const Configuration: Configuration;
export default Configuration
