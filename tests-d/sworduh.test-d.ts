import { expectType } from "tsd";
import Sworduh from "../types";
import type { SwordHandler, SwordHandlerState, Configuration, Combat } from "../types";

declare const player: Player;
declare const model: Model;

const playerSword = Sworduh.Sword(player);
const npcSword = Sworduh.Sword(model);

expectType<SwordHandler | undefined>(playerSword);
expectType<SwordHandler | undefined>(npcSword);

expectType<void>(Sworduh.SwordAll());
expectType<boolean>(Sworduh.Unsword(player));
expectType<Player | Model | undefined>(Sworduh.GetKiller(player));
expectType<void>(Sworduh.Cleanup());

if (playerSword) {
    expectType<boolean>(playerSword.IsActive());
    expectType<SwordHandlerState>(playerSword.GetState());
    expectType<boolean>(playerSword.TryLunge());
    expectType<void>(playerSword.Destroy());

    expectType<Tool | undefined>(playerSword.SwordTool);

    // @ts-expect-error
    playerSword.poop;
    // @ts-expect-error
    playerSword.Owner = model;
}

declare const state: SwordHandlerState;
expectType<"UP" | "OUT">(state.CurrentGrip);
expectType<number>(state.Damage);

declare const config: Configuration;
expectType<Combat>(config.COMBAT);
expectType<number>(config.TIMING.LUNGE_TIME);