# Adventures Toy System — Documentation

> AMX Mod X plugin system for Counter-Strike 1.6  
> Author: medusa | Version: 2.0

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

// Format: X Y Z Yaw [bound_toy_idx]
// bound_toy_idx: integer index from toy_models.ini (0-based), or omit for random
-512.00 128.00 64.00 90.0
1024.50 -256.00 0.00 270.0 2
```

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

## Developer API

### Forwards

```pawn
// Called when a player picks up a toy. Return PLUGIN_HANDLED to cancel pickup.
forward toy_on_pickup(id, ent, toy_idx);

// Called when a toy entity is spawned.
forward toy_on_spawned(ent, toy_idx, pos_idx);

// Called after all toys for the map have been spawned.
forward toy_on_map_spawn_complete(count);
```

### Natives

```pawn
// Get toy index from entity
native toy_get_toy_idx(ent);

// Get toy properties
native toy_get_name(idx, buf[], len);
native toy_get_rarity(idx);         // returns TOY_RARITY_* constant
native toy_get_model(idx, buf[], len);
native toy_get_body(idx);
native toy_get_skin(idx);

// Count information
native toy_get_type_count();        // total toy types loaded from config
native toy_get_spawned_count();     // currently alive (uncollected) toy entities
native toy_get_pos_count();         // saved positions for current map

// Position management
native toy_get_pos_data(pos_idx, Float:origin[3], &Float:yaw, &bound_toy_idx);
native toy_add_position(const Float:origin[3], Float:yaw, bound_toy_idx = -1);
native toy_remove_position(pos_idx);
native toy_update_position(pos_idx, const Float:origin[3], Float:yaw, bound_toy_idx);
native toy_save_positions();
native toy_reload_positions();
native toy_clear_positions();

// Spawn control
native toy_spawn_at_position(pos_idx);
native toy_respawn_all();
native toy_remove_entity(ent);
native toy_trigger_pickup(id, ent);

// Per-map count override
native toy_get_map_file_count();    // -1 = auto, 0 = off, N = exact count
native toy_set_map_file_count(count);
```

### Constants

```pawn
#define TOY_RARITY_COMMON       0
#define TOY_RARITY_RARE         1
#define TOY_RARITY_EPIC         2
#define TOY_RARITY_LEGENDARY    3

#define TOY_ENT_CLASSNAME       "toy_ent"
```

### Stock Helper

```pawn
// Fills buf with the localized rarity string for player id
stock toy_rarity_to_str(id, rarity, buf[], len)
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

## API для разработчиков

### Форварды

```pawn
// Вызывается когда игрок подбирает игрушку. PLUGIN_HANDLED = отменить подбор.
forward toy_on_pickup(id, ent, toy_idx);

// Вызывается при спавне игрушки на карте.
forward toy_on_spawned(ent, toy_idx, pos_idx);

// Вызывается после того, как все игрушки заспавнены на карте.
forward toy_on_map_spawn_complete(count);
```

### Нативы

```pawn
// Получить индекс игрушки из энтити
native toy_get_toy_idx(ent);

// Свойства игрушки
native toy_get_name(idx, buf[], len);
native toy_get_rarity(idx);          // возвращает константу TOY_RARITY_*
native toy_get_model(idx, buf[], len);
native toy_get_body(idx);
native toy_get_skin(idx);

// Счётчики
native toy_get_type_count();         // количество типов игрушек из конфига
native toy_get_spawned_count();      // текущее количество живых (несобранных) энтитей
native toy_get_pos_count();          // количество сохранённых позиций для текущей карты

// Управление позициями
native toy_get_pos_data(pos_idx, Float:origin[3], &Float:yaw, &bound_toy_idx);
native toy_add_position(const Float:origin[3], Float:yaw, bound_toy_idx = -1);
native toy_remove_position(pos_idx);
native toy_update_position(pos_idx, const Float:origin[3], Float:yaw, bound_toy_idx);
native toy_save_positions();
native toy_reload_positions();
native toy_clear_positions();

// Управление спавном
native toy_spawn_at_position(pos_idx);
native toy_respawn_all();
native toy_remove_entity(ent);
native toy_trigger_pickup(id, ent);

// Переопределение количества игрушек на карту
native toy_get_map_file_count();     // -1 = авто, 0 = выкл, N = точное количество
native toy_set_map_file_count(count);
```

### Константы

```pawn
#define TOY_RARITY_COMMON       0
#define TOY_RARITY_RARE         1
#define TOY_RARITY_EPIC         2
#define TOY_RARITY_LEGENDARY    3

#define TOY_ENT_CLASSNAME       "toy_ent"
```

### Вспомогательная функция

```pawn
// Заполняет buf локализованным названием раритета для игрока id
stock toy_rarity_to_str(id, rarity, buf[], len)
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

*Adventures Toy System v2.0 — medusa*
