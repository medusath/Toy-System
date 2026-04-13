#define TOY_CORE_PLUGIN

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <toys_system>

#define PLUGIN_NAME     "[Adventures] Toy Core"
#define PLUGIN_VERSION  "2.0"
#define PLUGIN_AUTHOR   "medusa"

#define MAX_TOYS        64
#define MAX_POSITIONS   512
#define MAX_MODEL_LEN   128
#define MAX_NAME_LEN    64
#define MAX_SOUND_LEN   64

new g_toy_model[MAX_TOYS][MAX_MODEL_LEN]
new g_toy_name[MAX_TOYS][MAX_NAME_LEN]
new g_toy_sound[MAX_TOYS][MAX_SOUND_LEN]
new g_toy_skin[MAX_TOYS]
new g_toy_body[MAX_TOYS]
new g_toy_sequence[MAX_TOYS]
new Float:g_toy_framerate[MAX_TOYS]
new g_toy_rarity[MAX_TOYS]
new g_toy_count = 0

new Float:g_pos_origin[MAX_POSITIONS][3]
new Float:g_pos_yaw[MAX_POSITIONS]
new g_pos_bound_toy[MAX_POSITIONS]
new g_pos_count = 0

new g_ent_list[MAX_POSITIONS]
new g_ent_toy_idx[MAX_POSITIONS]
new g_ent_pos_idx[MAX_POSITIONS]
new g_ent_count = 0

new g_legendary_spawned = 0
new g_map_count_from_file = -1

new g_weight_common    = TOY_RARITY_WEIGHT_COMMON
new g_weight_rare      = TOY_RARITY_WEIGHT_RARE
new g_weight_epic      = TOY_RARITY_WEIGHT_EPIC
new g_weight_legendary = TOY_RARITY_WEIGHT_LEGENDARY

new cvar_enabled
new cvar_count
new cvar_logging

new g_fwd_pickup
new g_fwd_spawned
new g_fwd_map_complete

new bool:g_spawn_used_toy[MAX_TOYS]

new g_logfile[192]

public plugin_natives()
{
    register_library("toys_system")

    register_native("toy_get_toy_idx",       "native_get_toy_idx",       0)
    register_native("toy_get_name",          "native_get_name",          0)
    register_native("toy_get_rarity",        "native_get_rarity",        0)
    register_native("toy_get_model",         "native_get_model",         0)
    register_native("toy_get_body",          "native_get_body",          0)
    register_native("toy_get_skin",          "native_get_skin",          0)
    register_native("toy_get_type_count",    "native_get_type_count",    0)
    register_native("toy_get_spawned_count", "native_get_spawned_count", 0)
    register_native("toy_get_pos_count",     "native_get_pos_count",     0)
    register_native("toy_get_pos_data",      "native_get_pos_data",      0)
    register_native("toy_add_position",      "native_add_position",      0)
    register_native("toy_remove_position",   "native_remove_position",   0)
    register_native("toy_update_position",   "native_update_position",   0)
    register_native("toy_save_positions",    "native_save_positions",    0)
    register_native("toy_reload_positions",  "native_reload_positions",  0)
    register_native("toy_remove_entity",     "native_remove_entity",     0)
    register_native("toy_spawn_at_position", "native_spawn_at_position", 0)
    register_native("toy_respawn_all",       "native_respawn_all",       0)
    register_native("toy_trigger_pickup",    "native_trigger_pickup",    0)
    register_native("toy_get_map_file_count","native_get_map_file_count",0)
    register_native("toy_set_map_file_count","native_set_map_file_count",0)
    register_native("toy_clear_positions",   "native_clear_positions",   0)
}

#define toy_log(%0) if(get_pcvar_num(cvar_logging)) log_to_file(g_logfile, %0)

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    cvar_enabled  = register_cvar("toy_enabled",  "1")
    cvar_count    = register_cvar("toy_count",    "5")
    if(!cvar_logging)
        cvar_logging = register_cvar("toy_logging", "0")
    register_cvar("toy_admin_flags", "g") //acces amx_cvar

    register_dictionary("toy_system.txt")

    g_fwd_pickup       = CreateMultiForward("toy_on_pickup",            ET_STOP,   FP_CELL, FP_CELL, FP_CELL)
    g_fwd_spawned      = CreateMultiForward("toy_on_spawned",           ET_IGNORE, FP_CELL, FP_CELL, FP_CELL)
    g_fwd_map_complete = CreateMultiForward("toy_on_map_spawn_complete", ET_IGNORE, FP_CELL)

    new logsdir[128]
    get_localinfo("amxx_logs", logsdir, charsmax(logsdir))
    formatex(g_logfile, charsmax(g_logfile), "%s/toy_system.log", logsdir)

    toy_log("[ToyCore] Initialized v%s", PLUGIN_VERSION)
}

public plugin_precache()
{
    if(!cvar_logging)
        cvar_logging = register_cvar("toy_logging", "1")

    precache_sound(TOY_DEFAULT_PICKUP_SOUND)
    load_toys_config()

    new i
    for(i = 0; i < g_toy_count; i++)
    {
        if(g_toy_model[i][0]) precache_model(g_toy_model[i])
        if(g_toy_sound[i][0]) precache_sound(g_toy_sound[i])
    }
}

public plugin_cfg()
{
    set_task(0.1, "task_map_start")
}

public task_map_start()
{
    new mapname[64]
    get_mapname(mapname, charsmax(mapname))
    toy_log("--- %s ---", mapname)

    if(!get_pcvar_num(cvar_enabled))
        return

    load_positions()

    if(!g_pos_count)
    {
        toy_log("[ToyCore] No positions for map, spawn skipped")
        return
    }
    if(!g_toy_count)
    {
        toy_log("[ToyCore] configs/toy_models.ini is empty or not found")
        return
    }

    spawn_toys()
}

load_toys_config()
{
    g_toy_count = 0

    new cfgdir[128], filepath[256]
    get_configsdir(cfgdir, charsmax(cfgdir))
    formatex(filepath, charsmax(filepath), "%s/toy_models.ini", cfgdir)

    if(!file_exists(filepath))
    {
        write_default_config(filepath)
        toy_log("[ToyCore] Created default configs/toy_models.ini")
    }

    new f = fopen(filepath, "rt")
    if(!f)
    {
        toy_log("[ToyCore] Failed to open configs/toy_models.ini")
        return
    }

    g_weight_common    = TOY_RARITY_WEIGHT_COMMON
    g_weight_rare      = TOY_RARITY_WEIGHT_RARE
    g_weight_epic      = TOY_RARITY_WEIGHT_EPIC
    g_weight_legendary = TOY_RARITY_WEIGHT_LEGENDARY

    new line[256], in_block = 0, cur = -1
    new bool:in_weights = false 

    while(!feof(f))
    {
        fgets(f, line, charsmax(line))
        trim(line)
        if(!line[0] || line[0] == '/' || line[0] == ';') continue

        if(line[0] == '"' && !in_block)
        {
            new section_name[32]
            parse_quoted(line, section_name, charsmax(section_name))

            if(equali(section_name, "weights"))
            {
                in_weights = true
                cur = -1
            }
            else
            {
                in_weights = false
                if(g_toy_count >= MAX_TOYS) continue

                cur = g_toy_count++
                g_toy_skin[cur]      = 0
                g_toy_body[cur]      = 0
                g_toy_sequence[cur]  = 0
                g_toy_framerate[cur] = 1.0
                g_toy_rarity[cur]    = TOY_RARITY_COMMON
                g_toy_model[cur][0]  = EOS
                g_toy_sound[cur][0]  = EOS
                copy(g_toy_name[cur], charsmax(g_toy_name[]), section_name)
            }
        }
        else if(line[0] == '{')
        {
            in_block = 1
        }
        else if(line[0] == '}')
        {
            in_block = 0
            in_weights = false
            cur = -1
        }
        else if(in_block && in_weights)
        {
            new key[32], val[32]
            parse_kv(line, key, charsmax(key), val, charsmax(val))
            new w = str_to_num(val)
            if(w < 1) w = 1

            if     (equali(key, "common"))    g_weight_common    = w
            else if(equali(key, "rare"))      g_weight_rare      = w
            else if(equali(key, "epic"))      g_weight_epic      = w
            else if(equali(key, "legendary")) g_weight_legendary = w
        }
        else if(in_block && cur >= 0)
        {
            new key[32], val[MAX_MODEL_LEN]
            parse_kv(line, key, charsmax(key), val, charsmax(val))

            if     (equali(key, "model"))     copy(g_toy_model[cur], charsmax(g_toy_model[]),   val)
            else if(equali(key, "sound"))     copy(g_toy_sound[cur], charsmax(g_toy_sound[]),   val)
            else if(equali(key, "skin"))      g_toy_skin[cur]      = str_to_num(val)
            else if(equali(key, "body"))      g_toy_body[cur]      = str_to_num(val)
            else if(equali(key, "sequence"))  g_toy_sequence[cur]  = str_to_num(val)
            else if(equali(key, "framerate")) g_toy_framerate[cur] = str_to_float(val)
            else if(equali(key, "rarity"))    g_toy_rarity[cur]    = str_to_rarity(val)
        }
    }
    fclose(f)
    toy_log("[ToyCore] Loaded toy types: %d (weights: C%d R%d E%d L%d)", g_toy_count, g_weight_common, g_weight_rare, g_weight_epic, g_weight_legendary)
}

write_default_config(const filepath[])
{
    new f = fopen(filepath, "wt")
    if(!f) return
    fputs(f, "// Adventures Toy System — конфиг игрушек^n")
    fputs(f, "// rarity: common | rare | epic | legendary^n")
    fputs(f, "// sequence: номер анимации модели (0 = статика)^n^n")
    fputs(f, "^"ExampleToy^"^n")
    fputs(f, "{^n")
    fputs(f, "    ^"model^"     ^"models/player/gordon/gordon.mdl^"^n")
    fputs(f, "    ^"rarity^"    ^"common^"^n")
    fputs(f, "    ^"sound^"     ^"items/gunpickup2.wav^"^n")
    fputs(f, "    ^"skin^"      ^"0^"^n")
    fputs(f, "    ^"body^"      ^"0^"^n")
    fputs(f, "    ^"sequence^"  ^"0^"^n")
    fputs(f, "    ^"framerate^" ^"1.0^"^n")
    fputs(f, "}^n")
    fclose(f)
}

build_pos_path(filepath[], maxlen)
{
    new datadir[128], mapname[64]
    get_datadir(datadir, charsmax(datadir))
    get_mapname(mapname, charsmax(mapname))
    formatex(filepath, maxlen, "%s/toy_spawn/%s.ini", datadir, mapname)
}

load_positions()
{
    g_pos_count = 0
    g_map_count_from_file = -1

    new filepath[256]
    build_pos_path(filepath, charsmax(filepath))

    if(!file_exists(filepath))
    {
        toy_log("[ToyCore] Position file not found: %s", filepath)
        return
    }

    new f = fopen(filepath, "rt")
    if(!f) return

    new line[256]
    while(!feof(f) && g_pos_count < MAX_POSITIONS)
    {
        fgets(f, line, charsmax(line))
        trim(line)
        if(!line[0] || line[0] == '/' || line[0] == ';') continue

        if((line[0] >= 'a' && line[0] <= 'z') || (line[0] >= 'A' && line[0] <= 'Z'))
        {
            new kv_key[16], kv_val[16]
            if(parse(line, kv_key, charsmax(kv_key), kv_val, charsmax(kv_val)) >= 2
            && equali(kv_key, "count"))
                g_map_count_from_file = str_to_num(kv_val)
            continue
        }

        new parts[6][MAX_NAME_LEN]
        new n = parse(line,
            parts[0], charsmax(parts[]),
            parts[1], charsmax(parts[]),
            parts[2], charsmax(parts[]),
            parts[3], charsmax(parts[]),
            parts[4], charsmax(parts[]),
            parts[5], charsmax(parts[]))

        if(n < 4) continue

        new idx = g_pos_count
        g_pos_origin[idx][0] = str_to_float(parts[0])
        g_pos_origin[idx][1] = str_to_float(parts[1])
        g_pos_origin[idx][2] = str_to_float(parts[2])
        g_pos_yaw[idx]        = str_to_float(parts[3])

        new bound_col = 4
        if(n >= 5 && (equali(parts[4], "easy") || equali(parts[4], "medium")
                   || equali(parts[4], "hard") || equali(parts[4], "secret")))
            bound_col = 5

        if(n > bound_col && parts[bound_col][0])
        {
            new bound_idx
            if(parts[bound_col][0] >= '0' && parts[bound_col][0] <= '9')
                bound_idx = str_to_num(parts[bound_col])
            else
                bound_idx = find_toy_by_name(parts[bound_col])
            g_pos_bound_toy[idx] = (bound_idx >= 0 && bound_idx < g_toy_count) ? bound_idx : -1
        }
        else
            g_pos_bound_toy[idx] = -1
        g_pos_count++
    }
    fclose(f)
    toy_log("[ToyCore] Loaded positions: %d", g_pos_count)
}

save_positions()
{
    new filepath[256], dir[192]
    build_pos_path(filepath, charsmax(filepath))

    new datadir[128]
    get_datadir(datadir, charsmax(datadir))
    formatex(dir, charsmax(dir), "%s/toy_spawn", datadir)
    if(!dir_exists(dir)) mkdir(dir)

    new f = fopen(filepath, "wt")
    if(!f)
    {
        toy_log("[ToyCore] Failed to write: %s", filepath)
        return
    }

    fputs(f, "// Adventures Toy System — позиции карты^n")
    fputs(f, "// Формат: x y z yaw [bound_toy_name]^n")
    fputs(f, "// count N — сколько игрушек спавнить на этой карте (переопределяет toy_count)^n^n")

    if(g_map_count_from_file >= 0) 
    {
        new count_line[32]
        formatex(count_line, charsmax(count_line), "count %d^n^n", g_map_count_from_file)
        fputs(f, count_line)
    }

    new i, line[256]
    for(i = 0; i < g_pos_count; i++)
    {
        if(g_pos_bound_toy[i] >= 0 && g_pos_bound_toy[i] < g_toy_count)
        {
            formatex(line, charsmax(line), "%.4f %.4f %.4f %.4f %d^n",
                g_pos_origin[i][0], g_pos_origin[i][1], g_pos_origin[i][2],
                g_pos_yaw[i], g_pos_bound_toy[i])
        }
        else
        {
            formatex(line, charsmax(line), "%.4f %.4f %.4f %.4f^n",
                g_pos_origin[i][0], g_pos_origin[i][1], g_pos_origin[i][2],
                g_pos_yaw[i])
        }
        fputs(f, line)
    }
    fclose(f)
    toy_log("[ToyCore] Saved positions: %d", g_pos_count)
}

remove_all_toys()
{
    new i
    for(i = 0; i < g_ent_count; i++)
    {
        if(pev_valid(g_ent_list[i]))
            engfunc(EngFunc_RemoveEntity, g_ent_list[i])
        g_ent_list[i] = 0
    }
    g_ent_count = 0
    g_legendary_spawned = 0
    arrayset(g_spawn_used_toy, 0, sizeof(g_spawn_used_toy))
}

spawn_toys()
{
    remove_all_toys()

    if(!g_pos_count || !g_toy_count) return

    new wanted
    if(g_map_count_from_file == 0)
        return
    else if(g_map_count_from_file > 0)
        wanted = g_map_count_from_file
    else
        wanted = get_pcvar_num(cvar_count)
    if(wanted <= 0)            wanted = 10
    if(wanted > g_pos_count)   wanted = g_pos_count
    if(wanted > MAX_POSITIONS) wanted = MAX_POSITIONS

    new bool:used_pos[MAX_POSITIONS]
    new avail = g_pos_count

    new spawned = 0, i
    for(i = 0; i < wanted && avail > 0; i++)
    {
        new pos_idx = pick_random_unused(used_pos, avail)
        if(pos_idx < 0) break

        used_pos[pos_idx] = true
        avail--

        new toy_idx = resolve_toy_for_position(pos_idx)
        if(toy_idx < 0 || !g_toy_model[toy_idx][0]) continue

        new ent = do_spawn_entity(toy_idx, pos_idx)
        if(!ent) continue

        if(g_toy_rarity[toy_idx] == TOY_RARITY_LEGENDARY)
            g_legendary_spawned++

        new ret
        ExecuteForward(g_fwd_spawned, ret, ent, toy_idx, pos_idx)

        spawned++
    }

    new ret
    ExecuteForward(g_fwd_map_complete, ret, spawned)

    toy_log("[ToyCore] Spawned: %d (positions available: %d)", spawned, g_pos_count)
}

pick_random_unused(const bool:used[], avail)
{
    if(avail <= 0) return -1

    new r = random_num(0, avail - 1)
    new seen = 0, i

    for(i = 0; i < g_pos_count; i++)
    {
        if(used[i]) continue
        if(seen == r) return i
        seen++
    }
    return -1
}

resolve_toy_for_position(pos_idx)
{
    new bound = g_pos_bound_toy[pos_idx]

    if(bound >= 0 && bound < g_toy_count)
    {
        if(g_toy_rarity[bound] == TOY_RARITY_LEGENDARY
        && g_legendary_spawned >= TOY_MAX_LEGENDARY_PER_MAP)
            return pick_toy_by_rarity()

        return bound
    }

    return pick_toy_by_rarity()
}

pick_toy_by_rarity()
{
    new rw[4], total = 0, i

    rw[TOY_RARITY_COMMON]    = g_weight_common
    rw[TOY_RARITY_RARE]      = g_weight_rare
    rw[TOY_RARITY_EPIC]      = g_weight_epic
    rw[TOY_RARITY_LEGENDARY] = (g_legendary_spawned < TOY_MAX_LEGENDARY_PER_MAP) ? g_weight_legendary : 0

    for(i = 0; i < 4; i++)
    {
        if(rw[i] > 0 && count_toys_of_rarity(i) == 0)
            rw[i] = 0
        total += rw[i]
    }

    if(total <= 0) return 0

    new r = random_num(0, total - 1)
    new cumul = 0, selected_rarity = 0
    for(i = 0; i < 4; i++)
    {
        cumul += rw[i]
        if(cumul > r) { selected_rarity = i; break; }
    }

    return pick_unused_of_rarity(selected_rarity)
}

count_toys_of_rarity(rarity)
{
    new n = 0, i
    for(i = 0; i < g_toy_count; i++)
        if(g_toy_rarity[i] == rarity && g_toy_model[i][0])
            n++
    return n
}

pick_unused_of_rarity(rarity)
{
    new avail[MAX_TOYS], count = 0, i

    for(i = 0; i < g_toy_count; i++)
    {
        if(g_toy_rarity[i] != rarity || !g_toy_model[i][0]) continue
        if(!g_spawn_used_toy[i]) avail[count++] = i
    }

    if(count == 0)
    {
        for(i = 0; i < g_toy_count; i++)
            if(g_toy_rarity[i] == rarity) g_spawn_used_toy[i] = false

        count = 0
        for(i = 0; i < g_toy_count; i++)
        {
            if(g_toy_rarity[i] != rarity || !g_toy_model[i][0]) continue
            avail[count++] = i
        }
    }

    if(count == 0) return 0

    new picked = avail[random_num(0, count - 1)]
    g_spawn_used_toy[picked] = true
    return picked
}

do_spawn_entity(toy_idx, pos_idx)
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if(!pev_valid(ent)) return 0

    new Float:origin[3]
    origin[0] = g_pos_origin[pos_idx][0]
    origin[1] = g_pos_origin[pos_idx][1]
    origin[2] = g_pos_origin[pos_idx][2]

    engfunc(EngFunc_SetOrigin, ent, origin)
    engfunc(EngFunc_SetModel,  ent, g_toy_model[toy_idx])

    set_pev(ent, pev_classname, TOY_ENT_CLASSNAME)
    set_pev(ent, pev_iuser1,    toy_idx)
    set_pev(ent, pev_iuser2,    pos_idx)
    set_pev(ent, pev_skin,      g_toy_skin[toy_idx])
    set_pev(ent, pev_body,      g_toy_body[toy_idx])

    set_pev(ent, pev_solid,    SOLID_TRIGGER)
    set_pev(ent, pev_movetype, MOVETYPE_NONE)

    new Float:mins[3], Float:maxs[3]
    mins[0] = -8.0; mins[1] = -8.0; mins[2] =  0.0
    maxs[0] =  8.0; maxs[1] =  8.0; maxs[2] = 24.0
    engfunc(EngFunc_SetSize, ent, mins, maxs)

    new Float:angles[3]
    angles[0] = 0.0
    angles[1] = g_pos_yaw[pos_idx]
    angles[2] = 0.0
    set_pev(ent, pev_angles, angles)

    set_pev(ent, pev_sequence,  g_toy_sequence[toy_idx])
    set_pev(ent, pev_framerate, g_toy_framerate[toy_idx])
    set_pev(ent, pev_animtime,  get_gametime())

    if(g_ent_count < MAX_POSITIONS)
    {
        g_ent_list[g_ent_count]    = ent
        g_ent_toy_idx[g_ent_count] = toy_idx
        g_ent_pos_idx[g_ent_count] = pos_idx
        g_ent_count++
    }

    return ent
}

remove_from_tracking(ent)
{
    new i
    for(i = 0; i < g_ent_count; i++)
    {
        if(g_ent_list[i] != ent) continue

        new j
        for(j = i; j < g_ent_count - 1; j++)
        {
            g_ent_list[j]    = g_ent_list[j+1]
            g_ent_toy_idx[j] = g_ent_toy_idx[j+1]
            g_ent_pos_idx[j] = g_ent_pos_idx[j+1]
        }
        g_ent_count--
        return
    }
}


str_to_rarity(const s[])
{
    if     (equali(s, "rare"))      return TOY_RARITY_RARE
    else if(equali(s, "epic"))      return TOY_RARITY_EPIC
    else if(equali(s, "legendary")) return TOY_RARITY_LEGENDARY
    return TOY_RARITY_COMMON
}

find_toy_by_name(const name[])
{
    new i
    for(i = 0; i < g_toy_count; i++)
        if(equali(g_toy_name[i], name))
            return i
    return -1
}

parse_quoted(const line[], out[], maxlen)
{
    new i = 0
    while(line[i] && line[i] != '"') i++
    if(!line[i]) return
    i++
    new o = 0
    while(line[i] && line[i] != '"' && o < maxlen - 1)
        out[o++] = line[i++]
    out[o] = EOS
}

parse_kv(const line[], key[], keylen, val[], vallen)
{
    new i = 0
    while(line[i] && line[i] != '"') i++
    if(!line[i]) return
    i++
    new k = 0
    while(line[i] && line[i] != '"' && k < keylen - 1) key[k++] = line[i++]
    key[k] = EOS
    if(line[i]) i++
    while(line[i] && line[i] != '"') i++
    if(!line[i]) return
    i++
    new v = 0
    while(line[i] && line[i] != '"' && v < vallen - 1) val[v++] = line[i++]
    val[v] = EOS
}

public native_get_toy_idx(plugin_id, num_params)
{
    new ent = get_param(1)
    if(!pev_valid(ent)) return -1

    new classname[32]
    pev(ent, pev_classname, classname, charsmax(classname))
    if(!equal(classname, TOY_ENT_CLASSNAME)) return -1

    return pev(ent, pev_iuser1)
}

public native_get_name(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_toy_count) return 0
    new len = get_param(3)
    set_string(2, g_toy_name[idx], len)
    return 1
}

public native_get_rarity(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_toy_count) return TOY_RARITY_COMMON
    return g_toy_rarity[idx]
}

public native_get_model(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_toy_count) return 0
    new len = get_param(3)
    set_string(2, g_toy_model[idx], len)
    return 1
}

public native_get_body(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_toy_count) return 0
    return g_toy_body[idx]
}

public native_get_skin(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_toy_count) return 0
    return g_toy_skin[idx]
}

public native_get_type_count(plugin_id, num_params)
{
    return g_toy_count
}

public native_get_spawned_count(plugin_id, num_params)
{
    return g_ent_count
}

public native_get_pos_count(plugin_id, num_params)
{
    return g_pos_count
}

public native_get_pos_data(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_pos_count) return 0

    new Float:origin[3]
    origin[0] = g_pos_origin[idx][0]
    origin[1] = g_pos_origin[idx][1]
    origin[2] = g_pos_origin[idx][2]

    set_array(2, _:origin, 3)
    set_param_byref(3, _:g_pos_yaw[idx])
    set_param_byref(4, g_pos_bound_toy[idx])
    return 1
}

public native_add_position(plugin_id, num_params)
{
    if(g_pos_count >= MAX_POSITIONS) return -1

    new Float:origin[3]
    get_array(1, _:origin, 3)

    new idx = g_pos_count
    g_pos_origin[idx][0] = origin[0]
    g_pos_origin[idx][1] = origin[1]
    g_pos_origin[idx][2] = origin[2]
    g_pos_yaw[idx]       = get_param_f(2)
    g_pos_bound_toy[idx] = get_param(3)
    g_pos_count++

    return idx
}

public native_remove_position(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_pos_count) return 0

    new i
    for(i = idx; i < g_pos_count - 1; i++)
    {
        g_pos_origin[i][0] = g_pos_origin[i+1][0]
        g_pos_origin[i][1] = g_pos_origin[i+1][1]
        g_pos_origin[i][2] = g_pos_origin[i+1][2]
        g_pos_yaw[i]       = g_pos_yaw[i+1]
        g_pos_bound_toy[i] = g_pos_bound_toy[i+1]
    }
    g_pos_count--
    return 1
}

public native_update_position(plugin_id, num_params)
{
    new idx = get_param(1)
    if(idx < 0 || idx >= g_pos_count) return 0

    new Float:origin[3]
    get_array(2, _:origin, 3)
    g_pos_origin[idx][0] = origin[0]
    g_pos_origin[idx][1] = origin[1]
    g_pos_origin[idx][2] = origin[2]
    g_pos_yaw[idx]       = get_param_f(3)
    g_pos_bound_toy[idx] = get_param(4)
    return 1
}

public native_save_positions(plugin_id, num_params)
{
    save_positions()
    return 1
}

public native_reload_positions(plugin_id, num_params)
{
    load_positions()
    return 1
}

public native_remove_entity(plugin_id, num_params)
{
    new ent = get_param(1)
    if(!pev_valid(ent)) return 0

    remove_from_tracking(ent)
    engfunc(EngFunc_RemoveEntity, ent)
    return 1
}

public native_spawn_at_position(plugin_id, num_params)
{
    new pos_idx = get_param(1)
    if(pos_idx < 0 || pos_idx >= g_pos_count || !g_toy_count) return 0

    new toy_idx = resolve_toy_for_position(pos_idx)
    if(toy_idx < 0 || !g_toy_model[toy_idx][0]) return 0

    new ent = do_spawn_entity(toy_idx, pos_idx)
    if(!ent) return 0

    new ret
    ExecuteForward(g_fwd_spawned, ret, ent, toy_idx, pos_idx)
    return ent
}

public native_respawn_all(plugin_id, num_params)
{
    spawn_toys()
    return 1
}

/**
 * toy_trigger_pickup — вызывается из toy_pickup.sma когда игрок нажал USE на игрушку.
 * Запускает forward toy_on_pickup. Если никто не заблокировал:
 *   — удаляет entity
 *   — воспроизводит звук подбора
 *   — отправляет игроку сообщение
 * Возвращает 1 если подбор состоялся, 0 если заблокирован или ошибка.
 */
public native_trigger_pickup(plugin_id, num_params)
{
    new id  = get_param(1)
    new ent = get_param(2)

    if(id < 1 || id > 32 || !is_user_alive(id)) return 0
    if(!pev_valid(ent)) return 0

    new classname[32]
    pev(ent, pev_classname, classname, charsmax(classname))
    if(!equal(classname, TOY_ENT_CLASSNAME)) return 0

    new toy_idx = pev(ent, pev_iuser1)
    if(toy_idx < 0 || toy_idx >= g_toy_count) return 0

    new ret
    ExecuteForward(g_fwd_pickup, ret, id, ent, toy_idx)

    if(ret == PLUGIN_HANDLED)
        return 0

    remove_from_tracking(ent)
    engfunc(EngFunc_RemoveEntity, ent)

    if(g_toy_sound[toy_idx][0])
        emit_sound(id, CHAN_AUTO, g_toy_sound[toy_idx], 1.0, ATTN_NORM, 0, PITCH_NORM)
    else
        emit_sound(id, CHAN_AUTO, TOY_DEFAULT_PICKUP_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM)

    return 1
}

public native_get_map_file_count(plugin_id, num_params)
{
    return g_map_count_from_file
}

public native_set_map_file_count(plugin_id, num_params)
{
    new count = get_param(1)
    if(count < 0) count = -1
    g_map_count_from_file = count
    return 1
}

public native_clear_positions(plugin_id, num_params)
{
    g_pos_count = 0
    return 1
}
