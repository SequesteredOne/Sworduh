/// <reference types="@rbxts/types" />

export interface SwordHandlerState {
    Owner: Player | Model | undefined;
    Damage: number;
    IsAttacking: boolean;
    IsToolEquipped: boolean;
    IsDestroyed: boolean;
    IsActive: boolean;
    LastAttackTime: number;
    TimeSinceLastAttack: number;
    IsInLungeWindow: boolean;
    CurrentGrip: "UP" | "OUT";
    CanAttack: boolean;
    NextAttackType: "slash" | "lunge";
    RemainingAttackTime: number;
    ActiveTaskCount: number;
    CurrentAttackType: "slash" | "lunge" | undefined;
}

export interface SwordHandler {
    readonly Owner: Player | Model | undefined;
    readonly SwordTool: Tool | undefined;
    Destroy(): void;
    IsActive(): boolean;
    TrySlash(): boolean;
    TryLunge(): boolean;
    GetState(): SwordHandlerState;
}
