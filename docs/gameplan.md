# b3dp.mw: turning the systems into a game

## What we have
- **World:** a 12 km ash island with dead forest, weather, campfires and day-dark lighting.
- **You:** a character sheet with attributes and skills that level with use, directional melee, spells, inventory and loot, hunger and thirst, torches that burn out, crouch and dash.
- **People:** about 40 to 2400 drifters and bandits living in camps. Bands roam, bandits raid, you can talk to anyone, and it's all watchable on the M map.
- **Monsters:** goblins and an orc that wander, chase you and leash home.

## The core loop (proposal)
**Survive the ash. Find the way off the island.**

1. **Leave a fire.** Your torch is your clock: 4 minutes, a few relights.
2. **Head into the dark** toward a glow on the horizon (a camp) or a landmark.
3. **At a camp:** drifters trade, talk, give rumours and work. Bandits are a fight, with loot in their chest.
4. **Come back stronger:** skills level, gear improves, and you carry more food.
5. **Rumours point to the next goal** (a ruin, a shrine, the mountains) further out, where the dark is worse.

What makes this work is the tension between **light, food and distance**. Every step away from a fire is a risk you choose to take.

## What's missing (gaps)
| Gap | Why it matters |
|---|---|
| No goal | Nothing to work toward beyond survival |
| No economy | Loot has no use beyond equipping it, and coins do nothing |
| Drifters are flavour only | Talking gives no rewards and no tasks |
| The dark isn't dangerous | Losing your torch costs nothing |
| No progression gate | You can walk anywhere from minute one |
| No save | Nothing persists between runs |
| Death is a respawn | No stakes |

## Steps, in order (each is playable on its own)
1. **Darkness bites.** Without a lit torch or fire nearby, stamina and health slowly drain, and monsters see you more easily while you can't see them. Monsters spawn more away from fires. Light becomes the main resource.
2. **Coins and trading.** Coins become an item. Drifters get a simple buy/sell list (food, torches, potions). Bandit loot gets sold, so raiding a bandit camp pays off.
3. **Drifter favours.** Talking can offer a small job: "bring me 3 bread", "kill the bandits at the camp to the east" (the sim map already knows where they are), "light the cold fire". Rewards are coins, an item, or a rumour that marks a place.
4. **Places worth reaching.** 3 to 5 landmarks (a ruined tower, a shrine in the marsh, a cave in the mountains), each with a guardian or puzzle and a key item. Rumours point at them.
5. **The goal.** The key items open the way off the island, or end the ash. That's a win state.
6. **Stakes.** Dying drops your pack where you fell, so you walk back for it (Souls-style), and you respawn at the last fire you lit. Lit fires become checkpoints.
7. **Save and load.** Save the player, the Camps records (they're already plain data) and the lit fires.
8. **Polish loop.** Sounds (fire crackle, footsteps, hunger), real NPC models, and a title screen.

## Suggested next step
**Step 1, darkness bites.** It's the cheapest step and it turns the torch, fire and hunger systems we just built into the core tension.

## Things you can do while I'm away (all sliders)
- **Camps node:** density, bandit ratio, raid odds, roaming behaviour, clutter.
- **Player `needs` node:** drain times and messages.
- **Torch root:** burn time, lights per torch.
- **Mob AI on goblin/orc/drifter/bandit:** aggro range, speeds, damage.
- **Talker on drifter/bandit:** names, greetings, rumours. Write the rumours that will point at your landmarks.
