# 🦫 Feed the Giant Capy

A brainrot co-op collect-and-escape game for Roblox. Grab snacks in four
zones, run them back to **Sir Chonks the Giant Capybara**, and don't get
bonked by the **Giant Angry Rubber Ducks** that guard every zone.

**Core loop**
1. **Collect:** walk over snacks (magnet pickup) or click the snack machines.
   They stack up as a tower on your back.
2. **Risk:** each zone has duck(s) that patrol, spot you (vision cone + line of
   sight, so you can hide behind props), chase you, and bonk you. Getting
   bonked ragdolls you and **scatters your snacks** for anyone to grab.
   The hub is always safe.
3. **Cash in:** walk into the orange ring around the Capybara. He eats
   everything and pays out cash. Every snack also fills a server-wide meter;
   when it's full, everyone gets a **CAPY FEAST** (2x cash).
4. **Progress:** upgrades, four zones to unlock, pet eggs with RNG rarities,
   and rebirths (permanent multiplier plus an RNG title roll; Legendary and
   Mythic titles come with an aura).

Random server events every few minutes: Golden Snack Rain, Duck Frenzy (faster
ducks, 2x cash), Double Cash, Moon Gravity. Retention: 7-day login streak,
playtime gifts every session, global leaderboards.

---

## Quick start: play it in Studio

1. Open **`FeedTheGiantCapy.rbxlx`** in Roblox Studio.
2. Press **Play**.

The map is built by code when the game starts, so in edit mode the place
looks almost empty. That's expected; everything appears once you press Play.

> **Saving in Studio:** an unpublished place can't use DataStores, so the game
> runs in *test mode* (a red note under your cash says progress won't save).
> To test saving: publish the place, then in Game Settings > Security turn on
> **Enable Studio Access to API Services**.

### Controls (PC)

| Key | Action |
|---|---|
| WASD / mouse | Move / look |
| Click | Use snack machines |
| E | Hatch eggs, unlock zone gates, open shop / rebirth stalls |
| B | Shop (upgrades + zones) |
| P | Pets |
| R | Rebirth |
| T | Titles |
| G | Rewards (daily streak + playtime gifts) |

---

## Getting updates

`FeedTheGiantCapy.rbxlx` is **generated** from the code in `src/`. When the
repo updates:

1. `git pull`
2. Re-open `FeedTheGiantCapy.rbxlx` in Studio.

⚠️ Pulling replaces the place file, so **don't keep your own Studio edits in
it**. Either save your work as a separate place, or use live sync (below) and
keep custom models in `ReplicatedStorage/Assets` of your own place.

### Live sync with Rojo (recommended once you start editing)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install`
   in this folder (installs the exact tool versions in `rokit.toml`).
2. Install the [Rojo Studio plugin](https://rojo.space/docs/v7/getting-started/installation/).
3. Run `rojo serve`, open your place in Studio, click **Connect** in the Rojo
   plugin. Code changes in `src/` now appear in Studio instantly.

Rebuild the place file yourself with `scripts/build.bat` (Windows) or
`scripts/build.sh`.

---

## Tuning the game

All balance and content lives in `src/shared/Config/`. You shouldn't need to
touch system code to rebalance:

| File | What's in it |
|---|---|
| `GameConfig` | ragdoll time, immunity, delivery radius, feast meter size, pet slots, autosave |
| `ZoneConfig` | the 4 zones: cost, colors, snacks + spawn weights, snack machine, duck stats |
| `FoodConfig` | every snack: name, emoji, value, rarity, look |
| `UpgradeConfig` | the 5 upgrades: base, per-level, max level, cost curve |
| `PetConfig` | pets (multipliers) and eggs (cost, zone requirement, odds) |
| `RebirthConfig` | rebirth cost curve, multiplier per rebirth, title RNG table |
| `EventConfig` | random events: duration, weight, effects |
| `RewardConfig` | daily streak and playtime gift rewards |
| `SoundConfig` | every sound cue (layered stings) |
| `RarityConfig` | rarity colors / which rarities luck boosts / announce |

All names are parody names (no trademarked characters), so you're safer
against takedowns and moderation. Rename anything in the configs.

### Swapping in real models

The capybara and ducks are greybox models built from parts. To use your own:

- Put a Model named **`Capybara`** in `ReplicatedStorage/Assets`. A part named
  `Head` inside it is animated when he eats.
- Put a Model named **`Duck`** in `ReplicatedStorage/Assets`. Set its
  `PrimaryPart`; it's scaled per zone automatically.

### Sounds

Defaults use sound files built into the Roblox client (`rbxasset://sounds/...`),
so they always load, even unpublished. There are only 11 of them, so stings
are made by layering and pitch-shifting them. For better audio, replace any
`Id` in `SoundConfig` with `rbxassetid://<id>` from the Creator Store or your
own uploads, and set `MusicId` for background music.

---

## Before you publish

- [ ] Publish the place, then turn on **Enable Studio Access to API Services**
      and play once to confirm saving works (rejoin and check your cash).
- [ ] Check the global leaderboards in the hub fill in after a couple of minutes.
- [ ] Try a ragdoll with both an R15 and an R6 avatar.
- [ ] Add a thumbnail and icon, and set the game's genre and age settings.
- [ ] Monetization isn't included yet (none was requested).

---

## Project layout

```
default.project.json      Rojo project (maps src/ into the DataModel)
FeedTheGiantCapy.rbxlx    Built place file (generated, open this in Studio)
src/shared/               ReplicatedStorage.Shared: configs, formulas, map layout, remotes, utils
src/server/               ServerScriptService.Server: Main + Services/
src/client/               StarterPlayerScripts.Client: Main + Controllers/ + UI/
tests/run.luau            Offline tests (lune run tests/run.luau)
scripts/                  build + check scripts
```

**Server services** (`src/server/Services`): `DataService` (session-locked
saves, autosave, offline fallback), `MapBuilder`, `FoodService` (spawns,
pickup, carry, machines), `DuckService` (AI), `CapybaraService` (delivery,
feast meter), `RagdollService`, `EventService`, `UpgradeService`,
`ZoneService`, `PetService`, `RebirthService`, `RewardService`,
`LeaderboardService`, `CharacterService`.

**Security:** the server is authoritative. Pickups, deliveries and catches
are all detected on the server, every purchase is validated there, and every
remote is rate-limited. Clients only send "I clicked buy" style requests.

## Checks

```
scripts/check.sh   # stylua --check, selene, offline tests
```

`tests/run.luau` runs the real shared modules under [Lune](https://lune-org.github.io/docs)
and checks config integrity, formulas, map geometry, and that every sound
cue, remote, effect and window name used anywhere actually exists.
