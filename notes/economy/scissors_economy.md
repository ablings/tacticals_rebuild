# Scissors economy vs RIVALS keys (proposal, 2026-10-22, main PC UI session)

Edward asked to "look at our scissor system and how much we sell and compare it to rivals key system and what keys are used for so
we can find an actual real scissor economy". This is a proposal only. Nothing in LobbyConfig / MatchCore is changed. The numbers
are his call; the lead applies them.

## 1. What we have now (LobbyConfig + MatchCore)

| | Now |
|---|---|
| Start | 500 |
| Per match | 25 + 10 / elimination + 50 for a win (1v1 first to 5: win ~125, loss ~50, ~90 average) |
| Daily missions | 3 drawn from a pool, 125-200 each (~515 / day) |
| Weekly contracts | 3 drawn, 750-1,000 each (~2,730 / week, ~390 / day) |
| Light player (3 matches / day) | ~1,170 / day |
| Heavy player (12 matches, ~1 h) | ~1,960 / day |
| Prices | weapons 1,500-4,000, gadgets 1,000-2,000, melee 800-3,000; bundles -17-20 %; **whole catalogue 35,500** |
| Robux | 500 / 49 R$ (10.2 per R$) up to 7,500 / 499 R$ (15 per R$); 2X Scissors pass 499 R$; VIP +25 % |
| Sinks | items and bundles only |

What that means:
- A light player owns everything in about **30 days**, a heavy one in about **18**. The priciest item (Sniper, 4,000) is ~3 days of light play.
- Most income comes from **playing matches**, not from tasks. Grinding matches is the fastest path, and the missions are a side bonus.
- After the catalogue is owned, scissors have **nothing left to buy**. The currency goes dead, and the Robux packs and the 2X pass lose their point.

## 2. RIVALS' keys (live game + wiki / guides, Oct 2026)

- **Earned mostly from tasks, not matches.** Daily Tasks are a fixed ladder: Play 5 duels = 1 key, Eliminate 15 = 2 keys,
  Win 2 duels = 3 keys (~6-9 keys a day with the other dailies). A daily **streak** row (Day 1-7, now a prize wheel) rewards
  coming back. **Weapon contracts** (per weapon: playtime / eliminations milestones) pay a key early, then cosmetics.
  Beginner Tasks pay 18 keys once.
- **Spent on:**
  - weapons: Bow 15, Shotgun 20, Burst Rifle 25, Wildcat 35, Sniper 75, and the "Prime" weapons (Flamethrower, Minigun, etc.) 400-475;
  - a manual weapon level-up: 10 keys;
  - skin cases through Robux or Skin Tickets.
- **Robux:** 10 keys for 49 R$ up to 1,100 keys for 4,999 R$ (~0.2 keys per R$). A daily's free keys are worth ~30-45 R$.
- **Shape:**
  - the cheapest unlock is ~2 days of dailies;
  - the Sniper is ~8-12 days;
  - the Prime weapons are ~2 months: an aspirational tier that sells key packs;
  - keys keep a use forever (level-ups, new weapons every update, cases).

## 3. The gap

| | Tacticals now | RIVALS |
|---|---|---|
| Free value a day | ~1,170-1,960 sc (~115-190 R$) | ~6-9 keys (~30-45 R$) |
| Cheapest unlock | 800 sc = 0.7 day | 15 keys = ~2 days |
| Top unlock | 4,000 sc = ~3 days | 450 keys = ~2 months |
| Income from | matches (grind) | tasks / streak / contracts (come back daily) |
| After you own it all | nothing to buy | level-ups, new weapons, cases |
| Numbers on screen | ×125, ×1,000 | ×1, ×2, ×3 |

## 4. Proposal (keeps the scissors and the scale; 1 RIVALS key ≈ 100 scissors)

**Earn: shift from grinding to coming back daily**
- **Per match:** 10 + 5 / elimination + 15 for a win (~40 a match; matches are for fun and for task progress).
- **Daily missions:** keep the pool, but pay by difficulty like RIVALS' ladder: easy 100, medium 200, hard 300 (~600 / day).
- **7-day login streak** (needs server, already specced to the lead): 50, 50, 100, 100, 150, 150, 400 (+ a cosmetic once
  cosmetics exist) = 1,000 / week. Missing a day resets it.
- **Weapon contracts** replace the weekly contracts: per weapon, 10 elims → 100, 50 → 200, 150 → 400, 500 → a cosmetic. This gives a
  reason to play every weapon, and more contracts unlock as you own more weapons.
- **Account level-up:** 100 each.
- Light player: ~120 matches + 600 dailies + ~140 streak + ~100 contracts ≈ **950 / day**. That's the same for casual players but
  far less for farmers. Daily free value is ~95 R$ (still kinder than RIVALS, which suits a smaller game).

**Spend: give the currency a top and a forever-use**
- Starters free (Pistol, Fists, Smoke).
- Rare 1,500 · Epic 2,500-3,000 · **Legendary 7,500** (Sniper, Riot Shield: ~8 days, like RIVALS' Sniper).
- **Prime tier** for future headline weapons: **40,000** (~6 weeks, or Robux). Every update can add one.
- **Weapon level-up skip:** 1,000 (RIVALS' 10 keys). The Kit's "Level up now!" button is already drawn and currently only
  shakes.
- **Mission reroll:** 250 (RIVALS charges 20 R$).
- **Cosmetic crates** (skins / wraps / charms, once they exist): 2,500 each, bundles -20 %.

**Robux: re-anchor packs to RIVALS' value (~20 scissors per R$)**
- 1,000 / 49 R$ · 2,200 / 99 R$ · 5,500 / 229 R$ · 12,500 / 499 R$ ("Best value"). The 2X pass and VIP stay (they double or
  boost the new task-heavy income).

**On screen:** missions and rewards show the full number with the scissors icon big (RIVALS-style "×1"-sized icon). At 100-300
per task the numbers stay short (no ×1,000).

## 5. Decisions for Edward
1. Go / no-go on the earn shift: low match pay, task-heavy income.
2. The Legendary 7,500 and a Prime tier at 40,000.
3. The sinks: level-up skip 1,000, mission reroll 250, crates later.
4. The Robux pack re-anchor (~20 scissors per R$).
5. Existing balances: no migration is needed (prices rise, balances stay). A one-off "economy update" message is optional.

Sources: [Keys (RIVALS wiki)](https://robloxrivals.fandom.com/wiki/Keys), [Tasks](https://robloxrivals.fandom.com/wiki/Tasks),
[Contracts](https://robloxrivals.fandom.com/wiki/Contracts), [Shop](https://robloxrivals.fandom.com/wiki/Shop),
[earnaldo RIVALS guide 2026](https://earnaldo.com/blog/rivals-free-robux-guide), [allthings.how Wildcat](https://allthings.how/roblox-rivals-wildcat-cost-stats-and-contract-rewards/),
[rivals.wiki keys](https://www.rivals.wiki/guides/keys-and-unlocks/), [Eldorado weapons list](https://www.eldorado.gg/blog/roblox-en/roblox-rivals-all-weapons-list/).
