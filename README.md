# Adventures Toy System — Documentation

> AMX Mod X plugin system for Counter-Strike 1.6  
> Author: medusa | Version: 2.1

## What's new in 2.1

- **Per-position rarity binding** — spawn points are now bound to a **tier**
  (common/rare/epic/legendary) instead of a specific toy. The admin picks a
  tier when placing a point, and any toy of that tier may appear there.
  Leave unbound for weighted random across all tiers (old behaviour).
- **One toy per player per map** — a player can pick up **only one** toy per
  map; subsequent attempts print `[Игрушки] Вы уже подобрали игрушку на этой карте.`.
  State persists by SteamID (reconnect doesn't reset it).
- **Legacy compatibility** — old `data/toy_spawn/<map>.ini` files written by
  v2.0 (with numeric toy index in the 5th column) are auto-migrated: the
  parser takes the rarity of that toy as the new binding.

---

## Table of Contents / Содержание

- [English Documentation](#english-documentation)
- [Русская документация](#русская-документация)

---

# English Documentation

## Overview

Adventures Toy System is a modular plugin system that places collectible toy models on the map. Players find and pick up toys by looking at them and pressing `E`. Each toy has a rarity, gives points on pickup, and triggers an announcement to all players.

The system consists of 5 plugins that must all be loaded together:

| Plugin | File | Role |
|---|---|---|
| Toy Core | `toy_core.amxx` | Engine: loads configs, spawns entities, exposes API |
| Toy Admin | `toy_admin.amxx` | Admin tool: place/manage toy positions on maps |
| Toy Pickup | `toy_pickup.amxx` | Player interaction: HUD hint, E-key pickup |
| Toy Rewards | `toy_rewards.amxx` | Points and chat announcements on pickup |
| Toy Announcer | `toy_announcer.amxx` | Periodic reminders about uncollected toys |

---

## Installation

1. Copy all `.amxx` files to `addons/amxmodx/plugins/`
2. Add to `addons/amxmodx/configs/plugins.ini`:
   ```
   toy_core.amxx
   toy_admin.amxx
   toy_pickup.amxx
   toy_rewards.amxx
   toy_announcer.amxx
   ```
3. Copy `toy_models.ini` and `toy_rewards.ini` to `addons/amxmodx/configs/`
4. Copy `toy_system.txt` to `addons/amxmodx/data/lang/`
5. Make sure your toy models exist under `cstrike/models/`
6. Restart the server

---

## CVars

| CVar | Default | Description |
|---|---|---|
| `toy_enabled` | `1` | Enable/disable the entire system |
| `toy_count` | `5` | Default number of toys spawned per map (used if no per-map override) |
| `toy_logging` | `0` | Enable debug logging to `logs/toy_system.log` |
| `toy_use_range` | `40` | Max distance (units) at which a player can pick up a toy |
| `toy_admin_flags` | `g` | Admin flag required to access the toy admin menu |

---

## Commands

### Player Commands

| Command | Description |
|---|---|
| `say /toy` | Shows how many toys remain uncollected on the current map |

### Admin Commands

| Command | Description |
|---|---|
| `say /toys` | Opens the toy admin menu (requires `toy_admin_flags`) |
| `amx_toys_menu` | Same as above, from server console or RCON |

---

## Admin Menu

Open with `say /toys`. Requires the flag set in `toy_admin_flags` (default: `g`).

### Main Menu Options

- **Add position** — enter placement mode at your crosshair position
- **Visualization ON/OFF** — show/hide floating markers for all toy positions on the map
- **Manage positions** — list all positions; click to teleport, then edit/delete/rebind
- **Respawn toys** — remove all current toys and respawn a fresh set
- **Delete all positions** — remove ALL positions for the current map (with confirmation)
- **Toy count** — set how many toys spawn on this map (auto / off / 1–N); autosaves 2 seconds after change

### Placement Mode

After selecting **Add position**, you enter placement mode:

- A preview model appears at your crosshair
- `MOUSE1` / `MOUSE2` — rotate the model left/right (yaw)
- The model auto-rotates 180° to face you when first placed
- Use the placement menu to:
  - **Save position** — confirm placement; choose a specific toy or Random
  - **Cancel** — exit without saving

### Visualization

- Green laser beams show all saved positions on the map
- HUD overlay shows position index, coordinates, yaw, and bound toy
- Models cycle every 3 seconds if set to Random (skin/body are applied from config)

### Editing a Position

In **Manage positions**, click any position to open its edit menu:

- **Toy: [name] (change)** / **Toy: Random (bind)** — change which toy is bound here
- **Relocate** — re-enter placement mode to move the position
- **Delete position** — remove with confirmation

---

## Config Files

### `configs/toy_models.ini` — Toy Definitions

Defines all available toy types and rarity spawn weights.

```ini
// Rarity weights — higher = more frequent
"weights"
{
    "common"    "100"
    "rare"      "40"
    "epic"      "20"
    "legendary" "5"
}

// Toy definition example
"Bonny"
{
    "model"     "models/toys/FNAF_toys.mdl"   // path from cstrike/
    "rarity"    "common"                       // common | rare | epic | legendary
    "skin"      "0"                            // model skin index
    "body"      "0"                            // model bodygroup index
    "sequence"  "0"                            // animation index (0 = static)
    "framerate" "1.0"                          // animation speed
    "sound"     "next21_kart/itembox_a03.wav"  // pickup sound (optional), path from sound/
}
```

**Notes:**
- `legendary` rarity: maximum **1** spawned per map at any time
- Spawn uses a shuffle-bag per rarity — all models of a rarity appear before any repeats
- Weights are relative to each other (e.g. common=100, rare=40 means common is 2.5× more likely)

---

### `configs/toy_rewards.ini` — Reward Settings

Controls points and announce behavior per rarity.

```ini
"common"
{
    "points"   "2"    // points awarded on pickup
    "announce" "1"    // 1 = announce to all players, 0 = silent
}

"rare"    { "points" "4"   "announce" "1" }
"epic"    { "points" "6"   "announce" "1" }
"legendary" { "points" "10"  "announce" "1" }
```

---

### `data/toy_spawn/<mapname>.ini` — Map Positions

Auto-generated by the admin tool. One file per map. Do not edit manually unless necessary.

```
// Optional: override toy count for this specific map
count 3

// Format: X Y Z Yaw [rarity]
// rarity: common | rare | epic | legendary | any  (or omit for "any")
-512.00 128.00 64.00 90.0
1024.50 -256.00 0.00 270.0 rare
 300.00  128.00 72.00  0.0 legendary
```

Binding the point to a **tier** means any toy of that tier may spawn there
(randomly chosen among toys that share that rarity). `any` or no binding =
weighted random across all tiers.

---

## Rarity System

| Rarity | Default Weight | Color (HUD) |
|---|---|---|
| Common | 100 | White |
| Rare | 40 | Cyan |
| Epic | 20 | Purple |
| Legendary | 5 | Gold |

- Weights are configurable in `toy_models.ini` under the `"weights"` section
- Legendary is capped at **1 per map** regardless of weight
- The shuffle-bag system ensures variety: all models of a rarity will appear before any model repeats
- **Per-position binding** (v2.1+): an admin can bind a spawn position to a
  specific tier. A random toy of that tier will be picked; weighted selection
  applies only to unbound ("any") positions.
- **Per-player limit** (v2.1+): each SteamID may pick up **1 toy per map**.
  Server state lives in a `Trie<steamid>` that is rebuilt on map change.

---

## Announcer Plugin

`toy_announcer.amxx` broadcasts reminders to all players:

- Up to **3 announcements** per map
- First announcement fires **~4.5 minutes** after map start
- Subsequent announcements every **~4.5 minutes** (configurable in source: `ANN_INTERVAL`)
- Announces only if at least 1 toy remains uncollected
- Players can type `/toy` at any time to check the current count

---

## Logging

When `toy_logging 1`:

- Log file: `addons/amxmodx/logs/toy_system.log`
- Each map start writes a header: `--- mapname ---`
- Logged events: initialization, config load, position load/save, spawn summary

---

## Developer API (`toys_system.inc`)

To use the API from your own plugin, include the header:

```pawn
#include <toys_system>
```

This adds `#pragma library toys_system` which makes AMX Mod X load your plugin only after `toy_core.amxx` is loaded.

---

### Constants

```pawn
#define TOY_RARITY_COMMON       0
#define TOY_RARITY_RARE         1
#define TOY_RARITY_EPIC         2
#define TOY_RARITY_LEGENDARY    3
#define TOY_RARITY_ANY         -1   // v2.1: "любой тир" при привязке точки

#define TOY_RARITY_WEIGHT_COMMON        100   // default weights
#define TOY_RARITY_WEIGHT_RARE           30
#define TOY_RARITY_WEIGHT_EPIC           10
#define TOY_RARITY_WEIGHT_LEGENDARY       3

#define TOY_MAX_LEGENDARY_PER_MAP         1   // legendary cap per map

#define TOY_DEFAULT_PICKUP_SOUND    "items/gunpickup2.wav"
#define TOY_ENT_CLASSNAME           "toy_ent"
```

Use `TOY_ENT_CLASSNAME` to find all toy entities on the map:
```pawn
new ent = -1
while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", TOY_ENT_CLASSNAME)) > 0)
{
    // ent is a live toy entity
}
```

---

### Forwards

Forwards are callbacks other plugins can hook into. Declare them as `public` functions in your plugin.

#### `toy_on_pickup(id, ent, toy_idx)`

Called **before** a toy is removed, when a player attempts to pick it up.

| Parameter | Description |
|---|---|
| `id` | Player entity index (1–32) |
| `ent` | Toy entity index (still valid in this forward) |
| `toy_idx` | Toy type index (0-based, from `toy_models.ini`) |

**Return values:**
- `PLUGIN_CONTINUE` — allow pickup (default if forward not defined)
- `PLUGIN_HANDLED` — block pickup (toy stays on map, no rewards given)

**Use cases:**
- Add your own points/money/XP system (this is what `toy_rewards.amxx` does)
- Restrict pickup by team, VIP flag, or condition
- Log or broadcast custom pickup events
- Grant gameplay bonuses (HP, armor, weapons)

**Example — block pickup for CTs:**
```pawn
public toy_on_pickup(id, ent, toy_idx)
{
    if(get_user_team(id) == 2) // CT
    {
        client_print(id, print_chat, "Only Terrorists can collect toys!")
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}
```

**Example — give HP on pickup:**
```pawn
public toy_on_pickup(id, ent, toy_idx)
{
    new rarity = toy_get_rarity(toy_idx)
    new hp = (rarity == TOY_RARITY_LEGENDARY) ? 100 : 25
    set_user_health(id, min(get_user_health(id) + hp, 150))
    return PLUGIN_CONTINUE
}
```

---

#### `toy_on_spawned(ent, toy_idx, pos_idx)`

Called **after** a toy entity has been created on the map (during initial spawn or respawn).

| Parameter | Description |
|---|---|
| `ent` | Newly created toy entity index |
| `toy_idx` | Toy type index |
| `pos_idx` | Position index (0-based, from `data/toy_spawn/<map>.ini`) |

**Return:** ignored (ET_IGNORE)

**Use cases:**
- Attach custom effects (glow, light, particles) to specific rarities
- Apply render overlays, transparency, color
- Extend tracking for analytics

**Example — gold glow on legendary toys:**
```pawn
public toy_on_spawned(ent, toy_idx, pos_idx)
{
    if(toy_get_rarity(toy_idx) != TOY_RARITY_LEGENDARY) return

    set_rendering(ent, kRenderFxGlowShell, 255, 200, 0, kRenderNormal, 16)
}
```

---

#### `toy_on_map_spawn_complete(count)`

Called **once per map**, right after all initial toys have been spawned.

| Parameter | Description |
|---|---|
| `count` | Actual number of toys spawned (may be less than requested if positions/types ran out) |

**Return:** ignored

**Use cases:**
- Set up scoreboard, scoreboard HUD, or announcer timers (this is what `toy_announcer.amxx` does)
- Initialize per-map collection tracking
- Save map-start snapshot for statistics

**Example — show map start message:**
```pawn
public toy_on_map_spawn_complete(count)
{
    client_print_color(0, print_team_default, "^4[Toys]^1 %d toys spawned. Happy hunting!", count)
}
```

---

### Natives — Read toy type data

These query the toy database loaded from `toy_models.ini`. Use `idx` = 0…`toy_get_type_count()-1`.

#### `toy_get_toy_idx(ent)`
Returns the toy type index for a toy entity, or `-1` if `ent` is not a toy.

```pawn
new toy_idx = toy_get_toy_idx(ent)
if(toy_idx < 0) return  // not a toy entity
```

#### `toy_get_name(idx, buf[], len)`
Copies the toy's display name (from the section header in `toy_models.ini`, e.g. `"Foxy Red"`) into `buf`.

#### `toy_get_rarity(idx)`
Returns one of `TOY_RARITY_COMMON`, `TOY_RARITY_RARE`, `TOY_RARITY_EPIC`, `TOY_RARITY_LEGENDARY`.

#### `toy_get_model(idx, buf[], len)`
Copies the model path (e.g. `models/toys/FNAF_toys.mdl`) into `buf`.

#### `toy_get_body(idx)` / `toy_get_skin(idx)`
Returns bodygroup / skin index used by this toy type. Useful if you spawn your own preview model.

#### `toy_get_type_count()`
Total number of toy types loaded from the config (across all rarities).

---

### Natives — Spawn state

#### `toy_get_spawned_count()`
Number of toy entities currently alive on the map (not yet collected). Decreases on every pickup, resets on respawn.

**Used by** `toy_announcer.amxx` to announce remaining toys.

```pawn
new remaining = toy_get_spawned_count()
client_print(id, print_chat, "%d toys still hidden on the map", remaining)
```

#### `toy_get_pos_count()`
Number of saved positions for the current map (from `data/toy_spawn/<map>.ini`).

---

### Natives — Position management

Positions are spawn anchors placed by admins. Each position has an origin, yaw, and an optional **rarity-tier binding** (v2.1+).

#### `toy_get_pos_data(pos_idx, Float:origin[3], &Float:yaw, &bound_rarity)`
Reads position data by index.
- `origin` filled with XYZ
- `yaw` filled with Y-axis rotation
- `bound_rarity` = `TOY_RARITY_ANY` (−1) if any, otherwise `TOY_RARITY_COMMON`/`RARE`/`EPIC`/`LEGENDARY`

Returns `1` on success, `0` if `pos_idx` is out of range.

#### `toy_add_position(const Float:origin[3], Float:yaw, bound_rarity = TOY_RARITY_ANY)`
Creates a new position in memory. Returns new `pos_idx` or `-1` if full (max 512 positions).  
**Does not save automatically** — call `toy_save_positions()` after batch changes.

#### `toy_remove_position(pos_idx)`
Removes position at index. Indices of later positions shift down by 1.

#### `toy_update_position(pos_idx, const Float:origin[3], Float:yaw, bound_rarity)`
Overwrites an existing position's data.

#### `toy_save_positions()`
Writes the current in-memory positions to `data/toy_spawn/<currentmap>.ini`. Call after adding/removing/updating.

#### `toy_reload_positions()`
Re-reads the file and replaces in-memory positions. Useful after manual file edits.

#### `toy_clear_positions()`
Removes **all** positions for the current map from memory (does not auto-save).

**Example — programmatically add a position at player's feet:**
```pawn
public cmd_addhere(id)
{
    new Float:origin[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_v_angle, angles)

    new pos_idx = toy_add_position(origin, angles[1] + 180.0, -1)
    if(pos_idx >= 0)
    {
        toy_save_positions()
        client_print(id, print_chat, "Position #%d added", pos_idx)
    }
    return PLUGIN_HANDLED
}
```

---

### Natives — Spawn control

#### `toy_spawn_at_position(pos_idx)`
Forces a spawn at the given position. Returns the new entity index or `0` on failure. Respects rarity rules (legendary cap, shuffle-bag).

#### `toy_respawn_all()`
Removes all live toys and re-runs the full spawn cycle. Useful after changing `toy_count` or reloading config.

#### `toy_remove_entity(ent)`
Removes a specific toy entity from the map (without triggering pickup). Cleans up internal tracking.

#### `toy_trigger_pickup(id, ent)`
Simulates a pickup: fires `toy_on_pickup`, gives rewards, plays sound, removes entity. Useful for:
- Alternative interaction (e.g., shooting the toy instead of pressing E)
- Admin "collect for player" commands
- Auto-pickup on touch zones

```pawn
// Admin command: force pickup the toy the admin is aiming at
public cmd_forcegrab(id)
{
    new ent = find_aimed_toy(id, 500.0)  // your own helper
    if(ent) toy_trigger_pickup(id, ent)
    return PLUGIN_HANDLED
}
```

---

### Natives — Per-map count override

#### `toy_get_map_file_count()`
Returns the override value stored in the map's spawn file:
- `-1` — auto (uses the `toy_count` cvar)
- `0`  — disabled (no toys spawn on this map)
- `N`  — exactly N toys

#### `toy_set_map_file_count(count)`
Sets the override. Call `toy_save_positions()` afterwards to persist. Used by the admin menu when changing the "Toy count" option.

---

### Stock Helper

#### `toy_rarity_to_str(id, rarity, buf[], len)`
Fills `buf` with the localized rarity name (via `%L` format), respecting the player's language.

```pawn
new rar_str[32]
toy_rarity_to_str(id, TOY_RARITY_EPIC, rar_str, charsmax(rar_str))
// rar_str = "Epic" (en) or "Эпическая" (ru)
```

> **Note:** use a buffer of **at least 32 cells** — Cyrillic letters take 2 bytes each in UTF-8, so "Легендарная" alone needs 22 bytes.

---

### Complete custom-reward plugin example

```pawn
#include <amxmodx>
#include <cstrike>
#include <toys_system>

public plugin_init()
    register_plugin("Toy Money Rewards", "1.0", "author")

public toy_on_pickup(id, ent, toy_idx)
{
    new rarity = toy_get_rarity(toy_idx)
    new money
    switch(rarity)
    {
        case TOY_RARITY_COMMON:    money = 100
        case TOY_RARITY_RARE:      money = 500
        case TOY_RARITY_EPIC:      money = 1500
        case TOY_RARITY_LEGENDARY: money = 5000
    }

    new current = cs_get_user_money(id)
    cs_set_user_money(id, min(current + money, 16000))

    new name[64], rar_str[32]
    toy_get_name(toy_idx, name, charsmax(name))
    toy_rarity_to_str(id, rarity, rar_str, charsmax(rar_str))

    client_print(id, print_chat, "You found %s [%s] and got $%d", name, rar_str, money)
    return PLUGIN_CONTINUE
}
```

---

---

# Русская документация

## Обзор

Adventures Toy System — модульная система плагинов для Counter-Strike 1.6 на базе AMX Mod X. Игрушки расставляются на карте администратором; игроки находят их, смотрят в сторону игрушки и нажимают `E` для подбора. Каждая игрушка имеет раритетность, за подбор начисляются очки и всем в чат приходит объявление.

Система состоит из 5 плагинов, которые должны быть загружены вместе:

| Плагин | Файл | Роль |
|---|---|---|
| Toy Core | `toy_core.amxx` | Ядро: загрузка конфигов, спавн энтитей, API |
| Toy Admin | `toy_admin.amxx` | Инструмент администратора: расстановка позиций |
| Toy Pickup | `toy_pickup.amxx` | Взаимодействие игрока: HUD-подсказка, подбор клавишей E |
| Toy Rewards | `toy_rewards.amxx` | Очки и анонс в чат при подборе |
| Toy Announcer | `toy_announcer.amxx` | Периодические напоминания о неподобранных игрушках |

---

## Установка

1. Скопировать все `.amxx` файлы в `addons/amxmodx/plugins/`
2. Добавить в `addons/amxmodx/configs/plugins.ini`:
   ```
   toy_core.amxx
   toy_admin.amxx
   toy_pickup.amxx
   toy_rewards.amxx
   toy_announcer.amxx
   ```
3. Скопировать `toy_models.ini` и `toy_rewards.ini` в `addons/amxmodx/configs/`
4. Скопировать `toy_system.txt` в `addons/amxmodx/data/lang/`
5. Убедиться, что модели игрушек находятся в `cstrike/models/`
6. Перезапустить сервер

---

## CVars

| CVar | По умолчанию | Описание |
|---|---|---|
| `toy_enabled` | `1` | Включить/выключить всю систему |
| `toy_count` | `5` | Количество игрушек на карте по умолчанию (если нет переопределения) |
| `toy_logging` | `0` | Включить запись отладочного лога в `logs/toy_system.log` |
| `toy_use_range` | `40` | Максимальная дистанция (единицы) для подбора игрушки |
| `toy_admin_flags` | `g` | Флаг доступа для открытия админ-меню |

---

## Команды

### Команды игроков

| Команда | Описание |
|---|---|
| `say /toy` | Показывает сколько игрушек осталось не собрано на карте |

### Команды администратора

| Команда | Описание |
|---|---|
| `say /toys` | Открыть меню управления игрушками (требует флаг `toy_admin_flags`) |
| `amx_toys_menu` | То же самое, из консоли сервера или RCON |

---

## Меню администратора

Открывается командой `say /toys`. Требует флаг из `toy_admin_flags` (по умолчанию: `g`).

### Пункты главного меню

- **Добавить позицию** — войти в режим размещения на точке прицела
- **Визуализация ВКЛ/ВЫКЛ** — показать/скрыть маркеры всех позиций на карте
- **Управление позициями** — список всех позиций; клик = телепорт, затем редактирование/удаление/привязка
- **Переспавнить игрушки** — убрать все текущие игрушки и заспавнить новый набор
- **Удалить все позиции** — удалить ВСЕ позиции для текущей карты (с подтверждением)
- **Количество игрушек** — задать сколько игрушек спавнится на этой карте (авто / выкл / 1–N); автосохранение через 2 секунды после изменения

### Режим размещения

После выбора **Добавить позицию** открывается режим размещения:

- Превью-модель появляется на точке прицела
- `MOUSE1` / `MOUSE2` — вращение модели влево/вправо (по оси Yaw)
- При первоначальном размещении модель автоматически разворачивается лицом к игроку (+180°)
- В меню размещения:
  - **Сохранить позицию** — подтвердить и выбрать конкретную игрушку или Случайную
  - **Отмена** — выйти без сохранения

### Визуализация

- Лазерные лучи (голубые) показывают все сохранённые позиции на карте
- В HUD отображается номер позиции, координаты, угол и привязанная игрушка
- При Случайной привязке модель меняется каждые 3 секунды (учитываются skin/body из конфига)

### Редактирование позиции

В меню **Управление позициями**, кликнув по позиции:

- **Игрушка: [название] (изменить)** / **Игрушка: Случайная (привязать)** — сменить привязку
- **Переместить** — заново войти в режим размещения для сдвига позиции
- **Удалить позицию** — удалить с подтверждением

---

## Конфигурационные файлы

### `configs/toy_models.ini` — Описание игрушек

Определяет все типы игрушек и веса вероятностей редкостей.

```ini
// Веса редкостей — чем больше, тем чаще выпадает
"weights"
{
    "common"    "100"
    "rare"      "40"
    "epic"      "20"
    "legendary" "5"
}

// Пример описания игрушки
"Bonny"
{
    "model"     "models/toys/FNAF_toys.mdl"   // путь от папки cstrike/
    "rarity"    "common"                       // common | rare | epic | legendary
    "skin"      "0"                            // номер скина модели
    "body"      "0"                            // номер bodygroup модели
    "sequence"  "0"                            // номер анимации (0 = статика)
    "framerate" "1.0"                          // скорость анимации
    "sound"     "next21_kart/itembox_a03.wav"  // звук подбора (необязательно), путь от sound/
}
```

**Важно:**
- `legendary`: максимум **1** экземпляр на всей карте одновременно
- Shuffle-bag система: все модели одной редкости появляются до повторений
- Веса относительны (common=100, rare=40 означает, что common в 2.5× чаще)

---

### `configs/toy_rewards.ini` — Настройки наград

Управляет очками и анонсом для каждой редкости.

```ini
"common"
{
    "points"   "2"    // очки за подбор
    "announce" "1"    // 1 = объявлять всем игрокам, 0 = тихо
}

"rare"      { "points" "4"   "announce" "1" }
"epic"      { "points" "6"   "announce" "1" }
"legendary" { "points" "10"  "announce" "1" }
```

---

### `data/toy_spawn/<mapname>.ini` — Позиции на карте

Автоматически создаётся и обновляется инструментом администратора. По одному файлу на карту. Ручное редактирование возможно, но не рекомендуется.

```
// Необязательно: переопределить количество игрушек для конкретной карты
count 3

// Формат: X Y Z Yaw [индекс_игрушки]
// индекс_игрушки: целое число (0-based) из toy_models.ini, или отсутствует для случайной
-512.00 128.00 64.00 90.0
1024.50 -256.00 0.00 270.0 2
```

---

## Система раритетности

| Раритет | Вес по умолчанию | Цвет (HUD) |
|---|---|---|
| Обычная (Common) | 100 | Белый |
| Редкая (Rare) | 40 | Голубой |
| Эпическая (Epic) | 20 | Фиолетовый |
| Легендарная (Legendary) | 5 | Золотой |

- Веса настраиваются в секции `"weights"` файла `toy_models.ini`
- Легендарная — не более **1 штуки на карту** вне зависимости от веса
- Shuffle-bag гарантирует разнообразие: каждая модель раритета появится по разу прежде чем начнутся повторения

---

## Плагин анонсер (Toy Announcer)

`toy_announcer.amxx` отправляет напоминания всем игрокам:

- До **3 анонсов** за карту
- Первый анонс — через **~4.5 минуты** после старта карты
- Следующие анонсы — каждые **~4.5 минуты** (настраивается в исходнике: `ANN_INTERVAL`)
- Анонс отправляется только если на карте ещё есть хотя бы 1 не собранная игрушка
- Игрок может написать `/toy` в любой момент, чтобы узнать количество оставшихся

---

## Логирование

При включённом `toy_logging 1`:

- Файл лога: `addons/amxmodx/logs/toy_system.log`
- В начале каждой карты пишется заголовок: `--- mapname ---`
- Записываются: инициализация, загрузка конфигов, загрузка/сохранение позиций, итог спавна

---

## API для разработчиков (`toys_system.inc`)

Чтобы использовать API из своего плагина, подключите заголовок:

```pawn
#include <toys_system>
```

Это добавляет `#pragma library toys_system`, благодаря чему AMX Mod X загрузит ваш плагин только после загрузки `toy_core.amxx`.

---

### Константы

```pawn
#define TOY_RARITY_COMMON       0
#define TOY_RARITY_RARE         1
#define TOY_RARITY_EPIC         2
#define TOY_RARITY_LEGENDARY    3
#define TOY_RARITY_ANY         -1   // v2.1: "любой тир" при привязке точки

#define TOY_RARITY_WEIGHT_COMMON        100   // веса по умолчанию
#define TOY_RARITY_WEIGHT_RARE           30
#define TOY_RARITY_WEIGHT_EPIC           10
#define TOY_RARITY_WEIGHT_LEGENDARY       3

#define TOY_MAX_LEGENDARY_PER_MAP         1   // лимит легендарных на карту

#define TOY_DEFAULT_PICKUP_SOUND    "items/gunpickup2.wav"
#define TOY_ENT_CLASSNAME           "toy_ent"
```

`TOY_ENT_CLASSNAME` можно использовать для поиска всех игрушек на карте:
```pawn
new ent = -1
while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", TOY_ENT_CLASSNAME)) > 0)
{
    // ent — живая игрушка
}
```

---

### Форварды

Форварды — это колбэки, в которые могут подключаться сторонние плагины. Объявляются как `public` функции.

#### `toy_on_pickup(id, ent, toy_idx)`

Вызывается **перед** удалением игрушки, когда игрок пытается её подобрать.

| Параметр | Описание |
|---|---|
| `id` | Индекс игрока (1–32) |
| `ent` | Индекс энтити игрушки (ещё валидный в момент вызова) |
| `toy_idx` | Индекс типа игрушки (0-based, из `toy_models.ini`) |

**Возвращаемые значения:**
- `PLUGIN_CONTINUE` — разрешить подбор (по умолчанию)
- `PLUGIN_HANDLED` — запретить подбор (игрушка останется, награды не выданы)

**Применения:**
- Реализовать собственную систему очков/денег/опыта (так делает `toy_rewards.amxx`)
- Ограничить подбор по команде, VIP-флагу или условию
- Логировать или транслировать свои события подбора
- Выдать игровой бонус (HP, броня, оружие)

**Пример — запретить подбор КТ:**
```pawn
public toy_on_pickup(id, ent, toy_idx)
{
    if(get_user_team(id) == 2) // CT
    {
        client_print(id, print_chat, "Только террористы собирают игрушки!")
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}
```

**Пример — выдача HP при подборе:**
```pawn
public toy_on_pickup(id, ent, toy_idx)
{
    new rarity = toy_get_rarity(toy_idx)
    new hp = (rarity == TOY_RARITY_LEGENDARY) ? 100 : 25
    set_user_health(id, min(get_user_health(id) + hp, 150))
    return PLUGIN_CONTINUE
}
```

---

#### `toy_on_spawned(ent, toy_idx, pos_idx)`

Вызывается **после** создания энтити игрушки на карте (при первом спавне или переспавне).

| Параметр | Описание |
|---|---|
| `ent` | Только что созданная энтити игрушки |
| `toy_idx` | Индекс типа игрушки |
| `pos_idx` | Индекс позиции (0-based, из `data/toy_spawn/<карта>.ini`) |

**Возврат:** игнорируется (ET_IGNORE)

**Применения:**
- Прикрепить кастомные эффекты (свечение, свет, частицы) для определённых раритетов
- Применить рендер-оверлеи, прозрачность, цвет
- Расширить трекинг для статистики

**Пример — золотое свечение легендарных игрушек:**
```pawn
public toy_on_spawned(ent, toy_idx, pos_idx)
{
    if(toy_get_rarity(toy_idx) != TOY_RARITY_LEGENDARY) return

    set_rendering(ent, kRenderFxGlowShell, 255, 200, 0, kRenderNormal, 16)
}
```

---

#### `toy_on_map_spawn_complete(count)`

Вызывается **один раз за карту**, сразу после того как все игрушки были заспавнены.

| Параметр | Описание |
|---|---|
| `count` | Сколько игрушек реально заспавнилось (может быть меньше запрошенного, если не хватило позиций/типов) |

**Возврат:** игнорируется

**Применения:**
- Инициализировать счётчик, HUD или таймеры анонсов (так делает `toy_announcer.amxx`)
- Запустить отслеживание коллекции на карту
- Сохранить снэпшот старта карты для статистики

**Пример — приветственное сообщение:**
```pawn
public toy_on_map_spawn_complete(count)
{
    client_print_color(0, print_team_default, "^4[Toys]^1 Заспавнено %d игрушек. Ищите!", count)
}
```

---

### Нативы — Чтение данных о типе игрушки

Эти функции читают базу игрушек, загруженную из `toy_models.ini`. Диапазон `idx` = 0…`toy_get_type_count()-1`.

#### `toy_get_toy_idx(ent)`
Возвращает индекс типа игрушки для энтити, или `-1` если `ent` — не игрушка.

```pawn
new toy_idx = toy_get_toy_idx(ent)
if(toy_idx < 0) return  // не игрушка
```

#### `toy_get_name(idx, buf[], len)`
Копирует в `buf` отображаемое имя игрушки (из заголовка секции в `toy_models.ini`, например `"Foxy Red"`).

#### `toy_get_rarity(idx)`
Возвращает одну из `TOY_RARITY_COMMON`, `TOY_RARITY_RARE`, `TOY_RARITY_EPIC`, `TOY_RARITY_LEGENDARY`.

#### `toy_get_model(idx, buf[], len)`
Копирует путь к модели (например `models/toys/FNAF_toys.mdl`) в `buf`.

#### `toy_get_body(idx)` / `toy_get_skin(idx)`
Возвращают номер bodygroup / skin этого типа игрушки. Полезно если вы спавните свою превью-модель.

#### `toy_get_type_count()`
Всего типов игрушек, загруженных из конфига (по всем раритетам).

---

### Нативы — Состояние спавна

#### `toy_get_spawned_count()`
Количество живых (не собранных) игрушек на карте сейчас. Уменьшается при каждом подборе, сбрасывается при переспавне.

**Используется в** `toy_announcer.amxx` для анонса оставшихся игрушек.

```pawn
new remaining = toy_get_spawned_count()
client_print(id, print_chat, "На карте ещё спрятано %d игрушек", remaining)
```

#### `toy_get_pos_count()`
Количество сохранённых позиций для текущей карты (из `data/toy_spawn/<карта>.ini`).

---

### Нативы — Управление позициями

Позиция — это точка спавна, расставленная админом. Каждая имеет origin, yaw и опциональную привязку к типу игрушки.

#### `toy_get_pos_data(pos_idx, Float:origin[3], &Float:yaw, &bound_toy_idx)`
Читает данные позиции по индексу.
- `origin` заполняется XYZ
- `yaw` заполняется углом поворота по оси Y
- `bound_toy_idx` = `-1` если случайная, иначе индекс типа игрушки

Возвращает `1` при успехе, `0` если `pos_idx` вне диапазона.

#### `toy_add_position(const Float:origin[3], Float:yaw, bound_toy_idx = -1)`
Создаёт новую позицию в памяти. Возвращает `pos_idx` или `-1` если лимит исчерпан (макс 512).  
**Не сохраняет автоматически** — после пакета изменений вызовите `toy_save_positions()`.

#### `toy_remove_position(pos_idx)`
Удаляет позицию по индексу. Индексы последующих позиций сдвигаются на 1 вниз.

#### `toy_update_position(pos_idx, const Float:origin[3], Float:yaw, bound_toy_idx)`
Перезаписывает данные существующей позиции.

#### `toy_save_positions()`
Пишет текущие позиции из памяти в `data/toy_spawn/<текущая_карта>.ini`. Вызывать после изменений.

#### `toy_reload_positions()`
Перечитывает файл и заменяет позиции в памяти. Полезно после ручного редактирования файла.

#### `toy_clear_positions()`
Удаляет **все** позиции текущей карты из памяти (на диске не сохраняет).

**Пример — программно добавить позицию под ногами игрока:**
```pawn
public cmd_addhere(id)
{
    new Float:origin[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_v_angle, angles)

    new pos_idx = toy_add_position(origin, angles[1] + 180.0, -1)
    if(pos_idx >= 0)
    {
        toy_save_positions()
        client_print(id, print_chat, "Позиция #%d добавлена", pos_idx)
    }
    return PLUGIN_HANDLED
}
```

---

### Нативы — Управление спавном

#### `toy_spawn_at_position(pos_idx)`
Принудительно спавнит игрушку в указанной позиции. Возвращает индекс новой энтити или `0` при неудаче. Учитывает правила раритета (лимит легендарных, shuffle-bag).

#### `toy_respawn_all()`
Убирает все живые игрушки и запускает полный цикл спавна заново. Полезно после изменения `toy_count` или перезагрузки конфига.

#### `toy_remove_entity(ent)`
Удаляет конкретную игрушку с карты (без триггера подбора). Чистит внутренний трекинг.

#### `toy_trigger_pickup(id, ent)`
Имитирует подбор: вызывает `toy_on_pickup`, выдаёт награды, проигрывает звук, удаляет энтити. Применения:
- Альтернативный способ взаимодействия (например, расстрелять игрушку вместо нажатия E)
- Админ-команды "собрать за игрока"
- Автосбор на зонах касания

```pawn
// Админ-команда: подобрать игрушку, на которую смотрит админ
public cmd_forcegrab(id)
{
    new ent = find_aimed_toy(id, 500.0)  // ваша вспомогательная функция
    if(ent) toy_trigger_pickup(id, ent)
    return PLUGIN_HANDLED
}
```

---

### Нативы — Переопределение количества на карту

#### `toy_get_map_file_count()`
Возвращает значение, записанное в файле спавна карты:
- `-1` — авто (используется cvar `toy_count`)
- `0`  — выключено (игрушки не спавнятся на этой карте)
- `N`  — ровно N игрушек

#### `toy_set_map_file_count(count)`
Устанавливает переопределение. Вызовите `toy_save_positions()` для сохранения. Используется в админ-меню при изменении пункта "Количество игрушек".

---

### Вспомогательная функция

#### `toy_rarity_to_str(id, rarity, buf[], len)`
Заполняет `buf` локализованным названием раритета (через `%L` форматирование), учитывая язык игрока.

```pawn
new rar_str[32]
toy_rarity_to_str(id, TOY_RARITY_EPIC, rar_str, charsmax(rar_str))
// rar_str = "Epic" (en) или "Эпическая" (ru)
```

> **Важно:** буфер должен быть **минимум 32 ячейки** — кириллица в UTF-8 занимает 2 байта на символ, одно только "Легендарная" = 22 байта.

---

### Полный пример плагина кастомных наград

```pawn
#include <amxmodx>
#include <cstrike>
#include <toys_system>

public plugin_init()
    register_plugin("Toy Money Rewards", "1.0", "author")

public toy_on_pickup(id, ent, toy_idx)
{
    new rarity = toy_get_rarity(toy_idx)
    new money
    switch(rarity)
    {
        case TOY_RARITY_COMMON:    money = 100
        case TOY_RARITY_RARE:      money = 500
        case TOY_RARITY_EPIC:      money = 1500
        case TOY_RARITY_LEGENDARY: money = 5000
    }

    new current = cs_get_user_money(id)
    cs_set_user_money(id, min(current + money, 16000))

    new name[64], rar_str[32]
    toy_get_name(toy_idx, name, charsmax(name))
    toy_rarity_to_str(id, rarity, rar_str, charsmax(rar_str))

    client_print(id, print_chat, "Ты нашёл %s [%s] и получил $%d", name, rar_str, money)
    return PLUGIN_CONTINUE
}
```

---

## Добавление новой игрушки

1. Поместить модель `.mdl` в папку `cstrike/models/` (например `models/toys/my_toy.mdl`)
2. Поместить звук подбора `.wav` в `cstrike/sound/` (необязательно)
3. Добавить секцию в `configs/toy_models.ini`:
   ```ini
   "My Toy"
   {
       "model"     "models/toys/my_toy.mdl"
       "rarity"    "rare"
       "skin"      "0"
       "body"      "0"
       "sequence"  "0"
       "framerate" "1.0"
       "sound"     "items/gunpickup2.wav"
   }
   ```
4. Перезапустить сервер (требуется для прекэша модели и звука)
5. Зайти на нужную карту, открыть `say /toys` и расставить позиции

---

# `toys_system.inc` — Quick Reference / Краткий справочник

Complete list of everything exposed by the header file. / Полный список того что экспортируется заголовком.

## Constants / Константы

| Name / Имя | Value / Значение | Description / Описание |
|---|---|---|
| `TOY_RARITY_COMMON` | `0` | Common rarity / Обычный раритет |
| `TOY_RARITY_RARE` | `1` | Rare rarity / Редкий раритет |
| `TOY_RARITY_EPIC` | `2` | Epic rarity / Эпический раритет |
| `TOY_RARITY_LEGENDARY` | `3` | Legendary rarity / Легендарный раритет |
| `TOY_RARITY_WEIGHT_COMMON` | `100` | Default weight for common / Вес по умолчанию |
| `TOY_RARITY_WEIGHT_RARE` | `30` | Default weight for rare / Вес по умолчанию |
| `TOY_RARITY_WEIGHT_EPIC` | `10` | Default weight for epic / Вес по умолчанию |
| `TOY_RARITY_WEIGHT_LEGENDARY` | `3` | Default weight for legendary / Вес по умолчанию |
| `TOY_MAX_LEGENDARY_PER_MAP` | `1` | Max legendary per map / Макс. легендарных на карту |
| `TOY_DEFAULT_PICKUP_SOUND` | `"items/gunpickup2.wav"` | Fallback pickup sound / Резервный звук подбора |
| `TOY_ENT_CLASSNAME` | `"toy_ent"` | Entity classname / Имя класса энтити |

---

## Forwards / Форварды

| Signature / Сигнатура | ET / Тип | Description / Описание |
|---|---|---|
| `toy_on_pickup(id, ent, toy_idx)` | `ET_STOP` | Called on pickup attempt. Return `PLUGIN_HANDLED` to cancel. / Вызов при попытке подбора. `PLUGIN_HANDLED` = отмена. |
| `toy_on_spawned(ent, toy_idx, pos_idx)` | `ET_IGNORE` | Called after a toy entity has been created. / Вызов после создания энтити игрушки. |
| `toy_on_map_spawn_complete(count)` | `ET_IGNORE` | Called once after all toys spawned on the map. / Однократный вызов после спавна всех игрушек на карте. |

### Parameter reference / Расшифровка параметров

| Parameter / Параметр | Type / Тип | Description / Описание |
|---|---|---|
| `id` | `int` | Player entity (1–32) / Индекс игрока |
| `ent` | `int` | Toy entity index / Индекс энтити игрушки |
| `toy_idx` | `int` | Toy type index (from config) / Индекс типа игрушки (из конфига) |
| `pos_idx` | `int` | Spawn position index / Индекс позиции спавна |
| `count` | `int` | Total toys spawned on map / Всего заспавнено на карте |

---

## Natives / Нативы

### Entity & type queries / Запросы по энтити и типу

| Native / Натив | Returns / Возвращает | Description / Описание |
|---|---|---|
| `toy_get_toy_idx(ent)` | `int` | Toy type idx from entity, or `-1`. / Индекс типа из энтити или `-1`. |
| `toy_get_name(idx, buf[], len)` | — | Copies toy name into `buf`. / Копирует имя игрушки в `buf`. |
| `toy_get_rarity(idx)` | `int` | `TOY_RARITY_*` constant. / Константа `TOY_RARITY_*`. |
| `toy_get_model(idx, buf[], len)` | — | Copies model path into `buf`. / Копирует путь к модели в `buf`. |
| `toy_get_body(idx)` | `int` | Bodygroup index. / Номер bodygroup. |
| `toy_get_skin(idx)` | `int` | Skin index. / Номер skin. |

### Counters / Счётчики

| Native / Натив | Returns / Возвращает | Description / Описание |
|---|---|---|
| `toy_get_type_count()` | `int` | Total toy types loaded. / Всего загруженных типов. |
| `toy_get_spawned_count()` | `int` | Live (uncollected) toys. / Живых (несобранных) игрушек. |
| `toy_get_pos_count()` | `int` | Saved positions on current map. / Сохранённых позиций на карте. |

### Position management / Управление позициями

| Native / Натив | Returns / Возвращает | Description / Описание |
|---|---|---|
| `toy_get_pos_data(pos_idx, Float:origin[3], &Float:yaw, &bound_toy_idx)` | `int` | Fills origin/yaw/binding. `1`=ok, `0`=out of range. / Заполняет origin/yaw/привязку. |
| `toy_add_position(const Float:origin[3], Float:yaw, bound_toy_idx = -1)` | `int` | New `pos_idx` or `-1` if full. / Новый `pos_idx` или `-1`. |
| `toy_remove_position(pos_idx)` | — | Removes position (shifts indices). / Удаляет позицию (сдвиг индексов). |
| `toy_update_position(pos_idx, const Float:origin[3], Float:yaw, bound_toy_idx)` | — | Overwrites position data. / Перезаписывает позицию. |
| `toy_save_positions()` | — | Writes to disk. / Пишет на диск. |
| `toy_reload_positions()` | — | Re-reads from disk. / Перечитывает с диска. |
| `toy_clear_positions()` | — | Clears all from memory. / Очищает всё из памяти. |

### Spawn control / Управление спавном

| Native / Натив | Returns / Возвращает | Description / Описание |
|---|---|---|
| `toy_spawn_at_position(pos_idx)` | `int` | New entity or `0`. / Новая энтити или `0`. |
| `toy_respawn_all()` | — | Removes all, respawns fresh set. / Переспавн всех игрушек. |
| `toy_remove_entity(ent)` | — | Removes one toy entity silently. / Тихое удаление одной игрушки. |
| `toy_trigger_pickup(id, ent)` | — | Simulates pickup (fires forward, rewards, sound). / Имитирует подбор (форвард, награды, звук). |

### Per-map count override / Переопределение количества на карту

| Native / Натив | Returns / Возвращает | Description / Описание |
|---|---|---|
| `toy_get_map_file_count()` | `int` | `-1` auto / `0` off / `N` exact. / `-1` авто / `0` выкл / `N` точно. |
| `toy_set_map_file_count(count)` | — | Sets the override (call save after). / Устанавливает (затем save). |

---

## Stock / Сток

| Stock / Сток | Description / Описание |
|---|---|
| `toy_rarity_to_str(id, rarity, buf[], len)` | Fills `buf` with localized rarity name for player `id`. Buffer should be ≥32. / Заполняет `buf` локализованным названием раритета для игрока `id`. Буфер ≥32. |

---

## Typical usage patterns / Типичные сценарии

| Goal / Цель | Hook / Call — Хук / вызов |
|---|---|
| Block pickup under condition / Заблокировать подбор | `toy_on_pickup` → `return PLUGIN_HANDLED` |
| Add custom rewards / Свои награды | `toy_on_pickup` + `toy_get_rarity` |
| Visual effect on spawn / Эффект при спавне | `toy_on_spawned` + `set_rendering` |
| Start map-wide timer / Таймер на карту | `toy_on_map_spawn_complete` |
| Periodic "X toys left" / Периодический анонс | `toy_get_spawned_count` + `set_task` |
| Shoot-to-pickup / Подбор выстрелом | damage forward → `toy_trigger_pickup` |
| Programmatic admin tool / Свой админ-тул | `toy_add_position` + `toy_save_positions` |
| Respawn on round start / Переспавн в начале раунда | round start event → `toy_respawn_all` |

---

## Required / recommended includes / Необходимые / рекомендуемые инклуды

```pawn
#include <amxmodx>       // required / обязательно
#include <toys_system>   // required / обязательно

// Optional, depending on what you do in callbacks:
// Опционально, по необходимости:
#include <fakemeta>      // pev/set_pev, engfunc — for position/rendering work
#include <engine>        // set_rendering, find_entity
#include <cstrike>       // cs_get_user_money etc.
#include <amxmisc>       // admin helpers
```

---

*Adventures Toy System v2.0 — medusa*
