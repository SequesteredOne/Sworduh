/// <reference types="@rbxts/types" />

import { SwordHandler } from "./SwordHandler"

interface Sworduh {
    readonly SwordObjects: ReadonlyMap<Player | Model, SwordHandler>;
    readonly LastDamagerCache: ReadonlyMap<Player | Model, Player | Model>;
    readonly Connections: ReadonlyMap<Player | Model, RBXScriptConnection | { Disconnect: () => void }>;
    readonly RespawnConnections: ReadonlyMap<Player, RBXScriptConnection>;
    Sword(target: Player | Model): SwordHandler | undefined;
    SwordAll(): void;
    Unsword(target: Player | Model): boolean;
    UnswordAll(): void;
    GetKiller(target: Player | Model): Player | Model | undefined;
    Cleanup(): void;
}

declare const Sworduh: Sworduh;
export default Sworduh
export { SwordHandler };
export type { SwordHandlerState } from "./SwordHandler";
export type * from "./Configuration";
