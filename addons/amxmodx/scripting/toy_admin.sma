#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <toys_system>

#define PLUGIN_NAME    "[Adventures] Toy Admin"
#define PLUGIN_VERSION "2.0"
#define PLUGIN_AUTHOR  "medusa"

#define MAX_NAME_LEN    64
#define MAX_MODEL_LEN   128
#define MAX_POSITIONS   512

#define PLACE_TRACE_DIST   600.0
#define YAW_STEP             2.0
#define ROTATE_INTERVAL      0.033

#define ENT_PREVIEW     "toy_admin_preview"
#define ENT_VIS         "toy_admin_vis"

#define HUD_PLACE_CH    4
#define HUD_VIS_CH      5
#define HUD_BEAM_CH     6

#define TASK_PLACE      1000
#define TASK_CYCLE      3000
#define TASK_VIS        2000
#define TASK_VIS_CYCLE  9999
#define TASK_BEAMS      4000
#define TASK_BEAM_HUD   5000

#define OFFSET_NEXTATTACK  83
#define OFFSET_LINUX       5

#define MY_TE_BEAMPOINTS   0
#define MY_SVC_TEMPENTITY  23

new bool:g_placing[33]
new bool:g_is_relocate[33]
new g_place_bound_rarity[33]
new Float:g_place_hit[33][3]
new Float:g_place_yaw[33]
new g_preview_ent[33]
new g_preview_model_idx[33]
new Float:g_place_last_rotate[33]

new g_vis_ents[MAX_POSITIONS]
new g_vis_count = 0
new g_vis_users = 0
new bool:g_vis_active[33]
new Float:g_last_vis_hud[33]
new g_vis_cycle_idx = 0

new bool:g_beam_view[33]
new Float:g_last_beam_hud[33]
new g_sprite_beam

new g_edit_pos_idx[33]
new g_toy_select_mode[33]

new g_pending_count[33]

new cvar_admin_flags
new cvar_toy_count

public plugin_precache()
{
    g_sprite_beam = precache_model("sprites/laserbeam.spr")
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    arrayset(g_pending_count, -2, sizeof(g_pending_count))

    register_dictionary("toy_system.txt")

    cvar_admin_flags = get_cvar_pointer("toy_admin_flags")
    if(!cvar_admin_flags)
        cvar_admin_flags = register_cvar("toy_admin_flags", "g")

    cvar_toy_count = get_cvar_pointer("toy_count")
    if(!cvar_toy_count)
        cvar_toy_count = register_cvar("toy_count", "5")

    register_clcmd("say /toys",     "cmd_toys_menu")
    register_clcmd("amx_toys_menu", "cmd_toys_menu")

    register_forward(FM_CmdStart, "fw_cmd_start")
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    if(g_pending_count[id] > -2)
        save_pending_count(id)
    g_pending_count[id] = -2

    if(g_placing[id])
        exit_placement_mode(id, false)

    if(g_vis_active[id])
        toggle_vis(id, false)

    if(g_beam_view[id])
        stop_beam_view(id)
}

bool:is_admin(id)
{
    new flagstr[16]
    get_pcvar_string(cvar_admin_flags, flagstr, charsmax(flagstr))
    return bool:(get_user_flags(id) & read_flags(flagstr))
}

save_pending_count(id)
{
    remove_task(id + 5000)
    if(g_pending_count[id] <= -2) return
    toy_set_map_file_count(g_pending_count[id])
    toy_save_positions()
}

public task_autosave_count(taskid)
{
    save_pending_count(taskid - 5000)
}

format_count_item(id, buf[], buflen)
{
    new pc = g_pending_count[id]
    if(pc < 0)
        formatex(buf, buflen, "%L", id, "TOY_MENU_COUNT_AUTO", get_pcvar_num(cvar_toy_count))
    else if(pc == 0)
        formatex(buf, buflen, "%L", id, "TOY_MENU_COUNT_OFF")
    else
        formatex(buf, buflen, "%L", id, "TOY_MENU_COUNT_N", pc)
}

draw_pos_beams(id)
{
    new count = toy_get_pos_count()
    if(!count) return

    new i
    for(i = 0; i < count; i++)
    {
        new Float:origin[3], Float:yaw, bound_toy
        toy_get_pos_data(i, origin, yaw, bound_toy)

        new Float:top[3]
        top[0] = origin[0]
        top[1] = origin[1]
        top[2] = origin[2] + 180.0

        message_begin(MSG_ONE, MY_SVC_TEMPENTITY, _, id)
        write_byte(MY_TE_BEAMPOINTS)
        write_coord(floatround(origin[0]))
        write_coord(floatround(origin[1]))
        write_coord(floatround(origin[2]))
        write_coord(floatround(top[0]))
        write_coord(floatround(top[1]))
        write_coord(floatround(top[2]))
        write_short(g_sprite_beam)
        write_byte(0)    // framestart
        write_byte(5)    // framerate
        write_byte(20)   // life 2.0s
        write_byte(4)    // width
        write_byte(0)    // noise
        write_byte(0)    // r
        write_byte(200)  // g
        write_byte(255)  // b  (cyan)
        write_byte(220)  // alpha
        write_byte(0)    // speed
        message_end()
    }
}

stop_beam_view(id)
{
    if(!g_beam_view[id]) return
    g_beam_view[id] = false
    remove_task(id + TASK_BEAMS)
    remove_task(id + TASK_BEAM_HUD)
}

teleport_to_pos(id, pos_idx)
{
    new Float:origin[3], Float:yaw, bound
    toy_get_pos_data(pos_idx, origin, yaw, bound)

    new Float:top[3]
    top[0] = origin[0]; top[1] = origin[1]; top[2] = origin[2] + 200.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceHull, top, origin, IGNORE_MONSTERS, 1, id, tr)
    new Float:land[3]
    get_tr2(tr, TR_vecEndPos, land)
    free_tr2(tr)

    land[2] += 2.0

    new Float:zero[3]
    engfunc(EngFunc_SetOrigin, id, land)
    set_pev(id, pev_velocity,     zero)
    set_pev(id, pev_basevelocity, zero)

    client_print(id, print_chat, "%L", id, "TOY_ADM_TELEPORT", pos_idx + 1)
}

create_vis_entities()
{
    destroy_vis_entities()

    new count      = toy_get_pos_count()
    new type_count = toy_get_type_count()
    if(!count || !type_count) return

    new i
    for(i = 0; i < count && g_vis_count < MAX_POSITIONS; i++)
    {
        new Float:origin[3], Float:yaw, bound_rarity
        toy_get_pos_data(i, origin, yaw, bound_rarity)

        new toy_idx
        if(bound_rarity >= 0)
        {
            // Preview model — первая игрушка этого тира (fallback к cycle).
            toy_idx = first_toy_of_rarity(bound_rarity)
            if(toy_idx < 0) toy_idx = g_vis_cycle_idx % type_count
        }
        else
            toy_idx = g_vis_cycle_idx % type_count

        new model[MAX_MODEL_LEN]
        toy_get_model(toy_idx, model, charsmax(model))

        if(!model[0]) continue

        new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
        if(!pev_valid(ent)) continue

        engfunc(EngFunc_SetModel,  ent, model)
        set_pev(ent, pev_body, toy_get_body(toy_idx))
        set_pev(ent, pev_skin, toy_get_skin(toy_idx))
        engfunc(EngFunc_SetOrigin, ent, origin)

        set_pev(ent, pev_classname, ENT_VIS)
        set_pev(ent, pev_iuser1,    i)
        set_pev(ent, pev_solid,     SOLID_NOT)
        set_pev(ent, pev_movetype,  MOVETYPE_NONE)

        new Float:angles[3]
        angles[1] = yaw
        set_pev(ent, pev_angles, angles)

        new Float:color[3]
        color[0] = 0.0; color[1] = 200.0; color[2] = 255.0
        set_pev(ent, pev_renderfx,    kRenderFxGlowShell)
        set_pev(ent, pev_rendercolor, color)
        set_pev(ent, pev_renderamt,   Float:30.0)

        new Float:mins[3], Float:maxs[3]
        mins[0] = -8.0; mins[1] = -8.0; mins[2] =  0.0
        maxs[0] =  8.0; maxs[1] =  8.0; maxs[2] = 24.0
        engfunc(EngFunc_SetSize, ent, mins, maxs)

        g_vis_ents[g_vis_count++] = ent
    }
}

destroy_vis_entities()
{
    new i
    for(i = 0; i < g_vis_count; i++)
    {
        if(pev_valid(g_vis_ents[i]))
            engfunc(EngFunc_RemoveEntity, g_vis_ents[i])
        g_vis_ents[i] = 0
    }
    g_vis_count = 0
}

refresh_vis_entities()
{
    if(g_vis_users > 0)
        create_vis_entities()
}

toggle_vis(id, bool:enable)
{
    if(enable == g_vis_active[id]) return

    if(enable)
    {
        g_vis_active[id] = true
        g_vis_users++
        if(g_vis_users == 1)
        {
            create_vis_entities()
            set_task(3.0, "task_vis_cycle", TASK_VIS_CYCLE, _, _, "b")
        }
        set_task(0.12, "task_vis_hud", id + TASK_VIS, _, _, "b")
        client_print(id, print_chat, "%L", id, "TOY_ADM_VIS_ON", toy_get_pos_count())
    }
    else
    {
        g_vis_active[id] = false
        g_vis_users--
        remove_task(id + TASK_VIS)
        if(g_vis_users <= 0)
        {
            g_vis_users = 0
            remove_task(TASK_VIS_CYCLE)
            destroy_vis_entities()
        }
        client_print(id, print_chat, "%L", id, "TOY_ADM_VIS_OFF")
    }
}

create_preview_ent(const model[], const Float:origin[3])
{
    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if(!pev_valid(ent)) return 0

    engfunc(EngFunc_SetModel,  ent, model)
    engfunc(EngFunc_SetOrigin, ent, origin)

    set_pev(ent, pev_classname,  ENT_PREVIEW)
    set_pev(ent, pev_solid,      SOLID_NOT)
    set_pev(ent, pev_movetype,   MOVETYPE_NONE)
    set_pev(ent, pev_rendermode, kRenderTransAdd)
    set_pev(ent, pev_renderamt,  Float:150.0)

    new Float:mins[3], Float:maxs[3]
    mins[0] = -8.0; mins[1] = -8.0; mins[2] =  0.0
    maxs[0] =  8.0; maxs[1] =  8.0; maxs[2] = 24.0
    engfunc(EngFunc_SetSize, ent, mins, maxs)

    return ent
}

update_preview_model(id)
{
    if(!pev_valid(g_preview_ent[id])) return

    new type_count = toy_get_type_count()
    if(type_count <= 0) return

    new toy_idx
    if(g_place_bound_rarity[id] >= 0)
    {
        // Binding тира → показываем первую игрушку этого тира как репрезентатив
        toy_idx = first_toy_of_rarity(g_place_bound_rarity[id])
        if(toy_idx < 0) toy_idx = g_preview_model_idx[id] % type_count
    }
    else
        toy_idx = g_preview_model_idx[id] % type_count

    new model[MAX_MODEL_LEN]
    toy_get_model(toy_idx, model, charsmax(model))

    if(model[0])
    {
        engfunc(EngFunc_SetModel, g_preview_ent[id], model)
        set_pev(g_preview_ent[id], pev_body, toy_get_body(toy_idx))
        set_pev(g_preview_ent[id], pev_skin, toy_get_skin(toy_idx))
    }
}

forward show_placement_menu(id);

exit_placement_mode(id, bool:save)
{
    g_placing[id] = false
    remove_task(id + TASK_PLACE)
    remove_task(id + TASK_CYCLE)

    set_pdata_float(id, OFFSET_NEXTATTACK, 0.0, OFFSET_LINUX)

    if(pev_valid(g_preview_ent[id]))
    {
        engfunc(EngFunc_RemoveEntity, g_preview_ent[id])
        g_preview_ent[id] = 0
    }

    if(save)
    {
        new Float:origin[3]
        origin[0] = g_place_hit[id][0]
        origin[1] = g_place_hit[id][1]
        origin[2] = g_place_hit[id][2]

        if(g_is_relocate[id])
        {
            new pos_idx = g_edit_pos_idx[id]
            new Float:dummy[3], Float:dummy_yaw, orig_bound
            toy_get_pos_data(pos_idx, dummy, dummy_yaw, orig_bound)
            toy_update_position(pos_idx, origin, g_place_yaw[id], orig_bound)
            toy_save_positions()
            refresh_vis_entities()
            client_print(id, print_chat, "%L", id, "TOY_ADM_POS_MOVED", pos_idx + 1)
        }
        else
        {
            new new_idx = toy_add_position(origin, g_place_yaw[id], g_place_bound_rarity[id])
            toy_save_positions()
            refresh_vis_entities()
            client_print(id, print_chat, "%L", id, "TOY_ADM_POS_ADDED", new_idx + 1)
        }
    }
    else
    {
        client_print(id, print_chat, "%L", id, "TOY_ADM_CANCELLED")
    }

    g_is_relocate[id] = false
    set_task(0.15, "task_reopen_main", id)
}

enter_placement_mode(id)
{
    new type_count = toy_get_type_count()
    if(type_count <= 0)
    {
        client_print(id, print_chat, "%L", id, "TOY_ADM_NO_MODELS")
        set_task(0.1, "task_reopen_main", id)
        return
    }

    g_is_relocate[id]       = false
    g_place_bound_rarity[id]   = -1
    g_preview_model_idx[id] = 0
    g_place_last_rotate[id] = 0.0

    new Float:v_angle[3]
    pev(id, pev_v_angle, v_angle)
    g_place_yaw[id] = v_angle[1] + 180.0
    if(g_place_yaw[id] >= 360.0) g_place_yaw[id] -= 360.0

    new model[MAX_MODEL_LEN]
    toy_get_model(0, model, charsmax(model))
    if(!model[0]) { set_task(0.1, "task_reopen_main", id); return; }

    new Float:origin[3]
    pev(id, pev_origin, origin)

    new ent = create_preview_ent(model, origin)
    if(!ent) { set_task(0.1, "task_reopen_main", id); return; }

    g_preview_ent[id] = ent
    g_placing[id]     = true

    set_task(0.05, "task_placement",     id + TASK_PLACE, _, _, "b")
    set_task(3.0,  "task_preview_cycle", id + TASK_CYCLE, _, _, "b")

    show_placement_menu(id)
}

enter_placement_mode_relocate(id, pos_idx)
{
    new type_count = toy_get_type_count()
    if(type_count <= 0) { set_task(0.1, "task_reopen_main", id); return; }

    new Float:dummy[3], Float:cur_yaw, bound_rarity
    toy_get_pos_data(pos_idx, dummy, cur_yaw, bound_rarity)

    g_edit_pos_idx[id]      = pos_idx
    g_is_relocate[id]       = true
    g_preview_model_idx[id] = 0
    g_place_last_rotate[id] = 0.0
    g_place_yaw[id]         = cur_yaw
    g_place_bound_rarity[id]= bound_rarity

    // Для preview берём первую игрушку тира (если тир задан) или модель[0].
    new model[MAX_MODEL_LEN]
    new preview_toy = (bound_rarity >= 0) ? first_toy_of_rarity(bound_rarity) : 0
    if(preview_toy < 0) preview_toy = 0
    toy_get_model(preview_toy, model, charsmax(model))
    if(!model[0]) { set_task(0.1, "task_reopen_main", id); return; }

    new Float:origin[3]
    pev(id, pev_origin, origin)

    new ent = create_preview_ent(model, origin)
    if(!ent) { set_task(0.1, "task_reopen_main", id); return; }

    g_preview_ent[id] = ent
    g_placing[id]     = true

    set_task(0.05, "task_placement", id + TASK_PLACE, _, _, "b")
    if(g_place_bound_rarity[id] < 0)
        set_task(3.0, "task_preview_cycle", id + TASK_CYCLE, _, _, "b")

    show_placement_menu(id)
}

show_main_menu(id)
{
    if(g_pending_count[id] <= -2)
        g_pending_count[id] = toy_get_map_file_count()

    new pos_count   = toy_get_pos_count()
    new spawn_count = toy_get_spawned_count()

    new title[96]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_MAIN_TITLE", pos_count, spawn_count)

    new menu = menu_create(title, "menu_main")

    new buf[96]
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_ADD_POS")
    menu_additem(menu, buf, "1")

    formatex(buf, charsmax(buf), "%L", id, g_vis_active[id] ? "TOY_MENU_VIS_ON" : "TOY_MENU_VIS_OFF")
    menu_additem(menu, buf, "2")

    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_MANAGE_POS")
    menu_additem(menu, buf, "3")

    format_count_item(id, buf, charsmax(buf))
    menu_additem(menu, buf, "4")

    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_RESPAWN")
    menu_additem(menu, buf, "5")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_DELETE_ALL")
    menu_additem(menu, buf, "6")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

show_placement_menu(id)
{
    if(!g_placing[id]) return

    new title[64], buf[96]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_PLACE_TITLE")
    new menu = menu_create(title, "menu_placement")

    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_SAVE_POS")
    menu_additem(menu, buf, "2")

    if(g_place_bound_rarity[id] >= 0)
    {
        new rar_str[32]
        toy_rarity_to_str(id, g_place_bound_rarity[id], rar_str, charsmax(rar_str))
        formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_TOY_BOUND", rar_str)
    }
    else
        formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_TOY_RANDOM")
    menu_additem(menu, buf, "1")

    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_CANCEL")
    menu_additem(menu, buf, "3")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

show_toy_select_menu(id, mode)
{
    g_toy_select_mode[id] = mode

    new title[64]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_RARITY_SEL_TITLE")
    new menu = menu_create(title, "menu_toy_select")

    // "Любой" — TOY_RARITY_ANY (-1)
    new any_str[48]
    formatex(any_str, charsmax(any_str), "%L", id, "TOY_MENU_RARITY_ANY")
    menu_additem(menu, any_str, "-1")

    // 4 тира по порядку
    for(new r = TOY_RARITY_COMMON; r <= TOY_RARITY_LEGENDARY; r++)
    {
        new rar_str[32], info[4], count_str[32]
        toy_rarity_to_str(id, r, rar_str, charsmax(rar_str))
        new cnt = count_toys_of_rarity_admin(r)
        formatex(count_str, charsmax(count_str), " \d[%d шт.]", cnt)
        new buf[96]
        formatex(buf, charsmax(buf), "%s%s", rar_str, count_str)
        num_to_str(r, info, charsmax(info))
        menu_additem(menu, buf, info)
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

// Счётчик игрушек указанного тира (для UI "N шт.").
count_toys_of_rarity_admin(rarity)
{
    new n = 0
    new count = toy_get_type_count()
    for(new i = 0; i < count; i++)
        if(toy_get_rarity(i) == rarity)
            n++
    return n
}

// Первая зарегистрированная игрушка указанного тира (для preview-модели
// при rarity-binding). -1 если нет.
first_toy_of_rarity(rarity)
{
    new count = toy_get_type_count()
    for(new i = 0; i < count; i++)
        if(toy_get_rarity(i) == rarity)
            return i
    return -1
}

show_pos_list(id)
{
    new count = toy_get_pos_count()
    new pl_title[80], pl_empty[64]
    formatex(pl_title, charsmax(pl_title), "%L", id, "TOY_MENU_POS_LIST_TITLE")
    formatex(pl_empty, charsmax(pl_empty), "%L", id, "TOY_MENU_POS_LIST_EMPTY")
    new menu = menu_create(pl_title, "menu_pos_list")
    menu_setprop(menu, MPROP_PERPAGE, 7)

    new i
    for(i = 0; i < count; i++)
    {
        new Float:origin[3], Float:yaw, bound_rarity
        toy_get_pos_data(i, origin, yaw, bound_rarity)

        new buf[96], idata[8]
        if(bound_rarity >= 0)
        {
            new rar_str[32]
            toy_rarity_to_str(id, bound_rarity, rar_str, charsmax(rar_str))
            formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_POS_ITEM_BOUND", i + 1, rar_str)
        }
        else
            formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_POS_ITEM_RANDOM", i + 1)

        num_to_str(i, idata, charsmax(idata))
        menu_additem(menu, buf, idata)
    }

    if(!count)
        menu_additem(menu, pl_empty, "-1")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)

    if(!g_beam_view[id])
    {
        g_beam_view[id] = true
        set_task(1.5, "task_pos_beams",   id + TASK_BEAMS,   _, _, "b")
        set_task(0.1, "task_beam_hud",    id + TASK_BEAM_HUD, _, _, "b")
        draw_pos_beams(id) 
    }
}

show_edit_pos_menu(id, pos_idx)
{
    new Float:origin[3], Float:yaw, bound_rarity
    toy_get_pos_data(pos_idx, origin, yaw, bound_rarity)

    new title[80], buf[96]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_EDIT_TITLE", pos_idx + 1)
    new menu = menu_create(title, "menu_edit_pos")

    if(bound_rarity >= 0)
    {
        new rar_str[32]
        toy_rarity_to_str(id, bound_rarity, rar_str, charsmax(rar_str))
        formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_EDIT_TOY_CHANGE", rar_str)
    }
    else
        formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_EDIT_TOY_BIND")
    menu_additem(menu, buf, "2")

    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_EDIT_RELOCATE")
    menu_additem(menu, buf, "3")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_EDIT_DELETE")
    menu_additem(menu, buf, "4")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

show_confirm_delete(id, pos_idx)
{
    new title[64], buf[32]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_DEL_TITLE", pos_idx + 1)
    new menu = menu_create(title, "menu_confirm_delete")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_DEL_YES")
    menu_additem(menu, buf, "1")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_DEL_NO")
    menu_additem(menu, buf, "0")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

show_confirm_delete_all(id)
{
    new title[64], buf[32]
    formatex(title, charsmax(title), "%L", id, "TOY_MENU_DEL_ALL_TITLE", toy_get_pos_count())
    new menu = menu_create(title, "menu_confirm_delete_all")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_DEL_ALL_YES")
    menu_additem(menu, buf, "1")
    formatex(buf, charsmax(buf), "%L", id, "TOY_MENU_DEL_NO")
    menu_additem(menu, buf, "0")
    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu, 0)
}

public cmd_toys_menu(id)
{
    if(!is_admin(id))
    {
        client_print(id, print_chat, "%L", id, "TOY_ADM_NO_ACCESS")
        return PLUGIN_HANDLED
    }
    show_main_menu(id)
    return PLUGIN_HANDLED
}

public menu_main(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        save_pending_count(id)
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new data[4], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    switch(str_to_num(data))
    {
        case 1:
        {
            save_pending_count(id)
            enter_placement_mode(id)
        }
        case 2:
        {
            toggle_vis(id, !g_vis_active[id])
            show_main_menu(id)
        }
        case 3:
        {
            save_pending_count(id)
            show_pos_list(id)
        }
        case 4:
        {
            new pc = g_pending_count[id]
            pc++
            if(pc > 10) pc = -1
            g_pending_count[id] = pc
            remove_task(id + 5000)
            set_task(2.0, "task_autosave_count", id + 5000)
            show_main_menu(id)
        }
        case 5:
        {
            toy_respawn_all()
            client_print(id, print_chat, "%L", id, "TOY_ADM_RESPAWNED", toy_get_spawned_count())
            set_task(0.2, "task_reopen_main", id)
        }
        case 6:
        {
            save_pending_count(id)
            show_confirm_delete_all(id)
        }
    }
    return PLUGIN_HANDLED
}

public task_reopen_main(id)
{
    if(is_user_connected(id) && is_admin(id))
        show_main_menu(id)
}

public menu_placement(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu)
        if(g_placing[id])
            exit_placement_mode(id, false)
        return PLUGIN_HANDLED
    }

    if(!g_placing[id]) { menu_destroy(menu); return PLUGIN_HANDLED; }

    new data[4], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    switch(str_to_num(data))
    {
        case 1:
        {
            if(g_is_relocate[id])
                show_placement_menu(id)
            else
                show_toy_select_menu(id, 0)
        }
        case 2: exit_placement_mode(id, true)
        case 3: exit_placement_mode(id, false)
    }
    return PLUGIN_HANDLED
}

public menu_toy_select(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu)
        if(g_toy_select_mode[id] == 1)
            show_edit_pos_menu(id, g_edit_pos_idx[id])
        else if(g_placing[id])
            show_placement_menu(id)
        else
            show_main_menu(id)
        return PLUGIN_HANDLED
    }

    new data[8], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    new toy_idx = str_to_num(data)

    if(g_toy_select_mode[id] == 0)
    {
        g_place_bound_rarity[id] = toy_idx

        remove_task(id + TASK_CYCLE)
        if(toy_idx < 0)
        {
            g_preview_model_idx[id] = 0
            set_task(3.0, "task_preview_cycle", id + TASK_CYCLE, _, _, "b")
        }
        else
            update_preview_model(id)

        show_placement_menu(id)
    }
    else
    {
        // toy_idx — это теперь rarity (из меню выбора тира): -1..3
        new pos_idx = g_edit_pos_idx[id]
        new Float:origin[3], Float:yaw, bound_rarity
        toy_get_pos_data(pos_idx, origin, yaw, bound_rarity)
        toy_update_position(pos_idx, origin, yaw, toy_idx)
        toy_save_positions()
        refresh_vis_entities()
        client_print(id, print_chat, "%L", id, "TOY_ADM_BIND_UPDATED", pos_idx + 1)
        set_task(0.1, "task_show_edit_menu", id)
    }
    return PLUGIN_HANDLED
}

public task_show_edit_menu(id)
{
    if(is_user_connected(id))
        show_edit_pos_menu(id, g_edit_pos_idx[id])
}

public menu_pos_list(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu)
        stop_beam_view(id)
        show_main_menu(id)
        return PLUGIN_HANDLED
    }

    new data[8], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)
    stop_beam_view(id)

    new pos_idx = str_to_num(data)
    if(pos_idx < 0) { show_main_menu(id); return PLUGIN_HANDLED; }

    g_edit_pos_idx[id] = pos_idx
    teleport_to_pos(id, pos_idx)
    set_task(0.2, "task_show_edit_menu", id)
    return PLUGIN_HANDLED
}

public menu_edit_pos(id, menu, item)
{
    if(item == MENU_EXIT) { menu_destroy(menu); show_pos_list(id); return PLUGIN_HANDLED; }

    new data[4], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    new pos_idx = g_edit_pos_idx[id]

    switch(str_to_num(data))
    {
        case 2: show_toy_select_menu(id, 1)
        case 3: enter_placement_mode_relocate(id, pos_idx)
        case 4: show_confirm_delete(id, pos_idx)
    }
    return PLUGIN_HANDLED
}

public menu_confirm_delete(id, menu, item)
{
    new data[4], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    if(str_to_num(data) == 1)
    {
        new pos_idx = g_edit_pos_idx[id]
        toy_remove_position(pos_idx)
        toy_save_positions()
        refresh_vis_entities()
        client_print(id, print_chat, "%L", id, "TOY_ADM_POS_DELETED", pos_idx + 1)
        set_task(0.1, "task_reopen_main", id)
    }
    else
        set_task(0.05, "task_show_edit_menu", id)

    return PLUGIN_HANDLED
}

public menu_confirm_delete_all(id, menu, item)
{
    new data[4], iname[64], acc, cb
    menu_item_getinfo(menu, item, acc, data, charsmax(data), iname, charsmax(iname), cb)
    menu_destroy(menu)

    if(str_to_num(data) == 1)
    {
        toy_clear_positions()
        toy_save_positions()
        refresh_vis_entities()
        client_print(id, print_chat, "%L", id, "TOY_ADM_ALL_DELETED")
    }

    set_task(0.1, "task_reopen_main", id)
    return PLUGIN_HANDLED
}

public fw_cmd_start(id, uc_handle, seed)
{
    if(!g_placing[id]) return FMRES_IGNORED
    if(!is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(uc_handle, UC_Buttons)

    set_uc(uc_handle, UC_Buttons, buttons & ~IN_ATTACK & ~IN_ATTACK2)

    new Float:now = get_gametime()
    if(now - g_place_last_rotate[id] >= ROTATE_INTERVAL)
    {
        if(buttons & IN_ATTACK)
        {
            g_place_yaw[id] -= YAW_STEP
            if(g_place_yaw[id] < -180.0) g_place_yaw[id] += 360.0
            g_place_last_rotate[id] = now
        }
        else if(buttons & IN_ATTACK2)
        {
            g_place_yaw[id] += YAW_STEP
            if(g_place_yaw[id] > 180.0) g_place_yaw[id] -= 360.0
            g_place_last_rotate[id] = now
        }
    }

    return FMRES_IGNORED
}

public task_placement(taskid)
{
    new id = taskid - TASK_PLACE

    if(!is_user_connected(id) || !g_placing[id])
    {
        exit_placement_mode(id, false)
        return
    }

    set_pdata_float(id, OFFSET_NEXTATTACK, get_gametime() + 9999.0, OFFSET_LINUX)

    new Float:eye[3], Float:viewofs[3]
    pev(id, pev_origin, eye)
    pev(id, pev_view_ofs, viewofs)
    eye[0] += viewofs[0]; eye[1] += viewofs[1]; eye[2] += viewofs[2]

    new Float:angles[3], Float:fwd[3]
    pev(id, pev_v_angle, angles)
    angle_vector(angles, ANGLEVECTOR_FORWARD, fwd)

    new Float:end_pt[3]
    end_pt[0] = eye[0] + fwd[0] * PLACE_TRACE_DIST
    end_pt[1] = eye[1] + fwd[1] * PLACE_TRACE_DIST
    end_pt[2] = eye[2] + fwd[2] * PLACE_TRACE_DIST

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, eye, end_pt, IGNORE_MONSTERS, id, tr)

    new Float:hit[3]
    get_tr2(tr, TR_vecEndPos, hit)
    free_tr2(tr)

    g_place_hit[id][0] = hit[0]
    g_place_hit[id][1] = hit[1]
    g_place_hit[id][2] = hit[2]

    if(pev_valid(g_preview_ent[id]))
    {
        engfunc(EngFunc_SetOrigin, g_preview_ent[id], hit)

        new Float:ent_angles[3]
        ent_angles[1] = g_place_yaw[id]
        set_pev(g_preview_ent[id], pev_angles, ent_angles)
    }

    new toy_str[MAX_NAME_LEN]
    new type_count = toy_get_type_count()
    if(g_place_bound_rarity[id] >= 0)
        toy_get_name(g_place_bound_rarity[id], toy_str, charsmax(toy_str))
    else if(type_count > 0)
    {
        new idx = g_preview_model_idx[id] % type_count
        toy_get_name(idx, toy_str, charsmax(toy_str))
        add(toy_str, charsmax(toy_str), " (авто)")
    }

    new hud_place[192]
    formatex(hud_place, charsmax(hud_place), "%L", id, "TOY_HUD_PLACEMENT",
        hit[0], hit[1], hit[2], g_place_yaw[id], toy_str)
    set_hudmessage(255, 255, 150, 0.55, 0.15, 0, 0.0, 0.5, 0.0, 0.0, HUD_PLACE_CH)
    show_hudmessage(id, "%s", hud_place)
}

public task_preview_cycle(taskid)
{
    new id = taskid - TASK_CYCLE

    if(!is_user_connected(id) || !g_placing[id]) return
    if(g_place_bound_rarity[id] >= 0) return

    g_preview_model_idx[id]++
    update_preview_model(id)
}

public task_vis_cycle()
{
    if(g_vis_users <= 0) return

    new type_count = toy_get_type_count()
    if(type_count <= 0) return

    g_vis_cycle_idx++

    new i
    for(i = 0; i < g_vis_count; i++)
    {
        new ent = g_vis_ents[i]
        if(!pev_valid(ent)) continue

        new pos_idx = pev(ent, pev_iuser1)
        new Float:origin[3], Float:yaw, bound_rarity
        toy_get_pos_data(pos_idx, origin, yaw, bound_rarity)

        // Зафиксированный тир — не циклим модель, оставляем как есть
        if(bound_rarity >= 0) continue

        new toy_idx = g_vis_cycle_idx % toy_get_type_count()
        new model[MAX_MODEL_LEN]
        toy_get_model(toy_idx, model, charsmax(model))
        if(model[0])
        {
            engfunc(EngFunc_SetModel, ent, model)
            set_pev(ent, pev_body, toy_get_body(toy_idx))
            set_pev(ent, pev_skin, toy_get_skin(toy_idx))
        }
    }
}

public task_vis_hud(taskid)
{
    new id = taskid - TASK_VIS

    if(!is_user_connected(id) || !g_vis_active[id])
    {
        g_vis_active[id] = false
        return
    }

    new Float:now = get_gametime()
    if(now - g_last_vis_hud[id] < 0.12) return
    g_last_vis_hud[id] = now

    new Float:eye[3], Float:viewofs[3]
    pev(id, pev_origin, eye)
    pev(id, pev_view_ofs, viewofs)
    eye[0] += viewofs[0]; eye[1] += viewofs[1]; eye[2] += viewofs[2]

    new Float:angles[3], Float:fwd[3]
    pev(id, pev_v_angle, angles)
    angle_vector(angles, ANGLEVECTOR_FORWARD, fwd)

    new best_ent = 0
    new Float:best_t = 400.0

    new i
    for(i = 0; i < g_vis_count; i++)
    {
        new ent = g_vis_ents[i]
        if(!pev_valid(ent)) continue

        new Float:epos[3]
        pev(ent, pev_origin, epos)
        epos[2] += 12.0

        new Float:v[3]
        v[0] = epos[0] - eye[0]; v[1] = epos[1] - eye[1]; v[2] = epos[2] - eye[2]

        new Float:t = v[0]*fwd[0] + v[1]*fwd[1] + v[2]*fwd[2]
        if(t < 0.0 || t > 400.0) continue

        new Float:cx, Float:cy, Float:cz
        cx = eye[0] + fwd[0]*t - epos[0]
        cy = eye[1] + fwd[1]*t - epos[1]
        cz = eye[2] + fwd[2]*t - epos[2]
        if(floatsqroot(cx*cx + cy*cy + cz*cz) > 30.0) continue

        if(t < best_t) { best_t = t; best_ent = ent; }
    }

    if(!best_ent) return

    new pos_idx = pev(best_ent, pev_iuser1)
    new Float:origin[3], Float:yaw, bound_rarity
    toy_get_pos_data(pos_idx, origin, yaw, bound_rarity)

    new rar_str[32]
    if(bound_rarity >= 0)
        toy_rarity_to_str(id, bound_rarity, rar_str, charsmax(rar_str))
    else
        copy(rar_str, charsmax(rar_str), "Любой")

    new hud_vis[192]
    formatex(hud_vis, charsmax(hud_vis), "%L", id, "TOY_HUD_VIS_POS",
        pos_idx + 1, origin[0], origin[1], origin[2], yaw, rar_str)
    set_hudmessage(255, 255, 100, -1.0, 0.72, 0, 0.0, 0.5, 0.0, 0.0, HUD_VIS_CH)
    show_hudmessage(id, "%s", hud_vis)
}

public task_pos_beams(taskid)
{
    new id = taskid - TASK_BEAMS

    if(!is_user_connected(id) || !g_beam_view[id])
    {
        stop_beam_view(id)
        return
    }

    draw_pos_beams(id)
}

public task_beam_hud(taskid)
{
    new id = taskid - TASK_BEAM_HUD

    if(!is_user_connected(id) || !g_beam_view[id])
    {
        stop_beam_view(id)
        return
    }

    new Float:now = get_gametime()
    if(now - g_last_beam_hud[id] < 0.1) return
    g_last_beam_hud[id] = now

    new Float:eye[3], Float:viewofs[3]
    pev(id, pev_origin, eye)
    pev(id, pev_view_ofs, viewofs)
    eye[0] += viewofs[0]; eye[1] += viewofs[1]; eye[2] += viewofs[2]

    new Float:angles[3], Float:fwd[3]
    pev(id, pev_v_angle, angles)
    angle_vector(angles, ANGLEVECTOR_FORWARD, fwd)

    new count = toy_get_pos_count()
    new best_pos = -1
    new Float:best_t = 500.0

    new i
    for(i = 0; i < count; i++)
    {
        new Float:origin[3], Float:yaw, bound
        toy_get_pos_data(i, origin, yaw, bound)

        new Float:mid[3]
        mid[0] = origin[0]; mid[1] = origin[1]; mid[2] = origin[2] + 90.0

        new Float:v[3]
        v[0] = mid[0] - eye[0]; v[1] = mid[1] - eye[1]; v[2] = mid[2] - eye[2]

        new Float:t = v[0]*fwd[0] + v[1]*fwd[1] + v[2]*fwd[2]
        if(t < 0.0 || t > 500.0) continue

        new Float:cx, Float:cy, Float:cz
        cx = eye[0] + fwd[0]*t - mid[0]
        cy = eye[1] + fwd[1]*t - mid[1]
        cz = eye[2] + fwd[2]*t - mid[2]
        if(floatsqroot(cx*cx + cy*cy + cz*cz) > 35.0) continue

        if(t < best_t) { best_t = t; best_pos = i; }
    }

    if(best_pos < 0) return

    new Float:origin[3], Float:yaw, bound_rarity
    toy_get_pos_data(best_pos, origin, yaw, bound_rarity)

    new rar_str[32]
    if(bound_rarity >= 0)
        toy_rarity_to_str(id, bound_rarity, rar_str, charsmax(rar_str))
    else
        copy(rar_str, charsmax(rar_str), "Любой")

    new hud_beam[192]
    formatex(hud_beam, charsmax(hud_beam), "%L", id, "TOY_HUD_BEAM_POS",
        best_pos + 1, origin[0], origin[1], origin[2], rar_str)
    set_hudmessage(255, 220, 80, -1.0, 0.72, 0, 0.0, 0.6, 0.0, 0.0, HUD_BEAM_CH)
    show_hudmessage(id, "%s", hud_beam)
}

public toy_on_pickup(id, ent, toy_idx)
{
    if(g_placing[id])
        return PLUGIN_HANDLED
    return PLUGIN_CONTINUE
}
