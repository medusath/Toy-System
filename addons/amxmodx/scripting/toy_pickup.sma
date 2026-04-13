#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <toys_system>


#define PLUGIN_NAME    "[Adventures] Toy Pickup"
#define PLUGIN_VERSION "2.0"
#define PLUGIN_AUTHOR  "medusa"

#define AIM_HIT_RADIUS  20.0
#define MAX_NAME_LEN    64

#define HUD_CHANNEL     3

new g_looking_at[33]
new Float:g_last_hud_time[33]
new g_old_buttons[33]

new cvar_use_range              // toy_use_range — дистанция подбора

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    cvar_use_range = register_cvar("toy_use_range", "40")

    register_dictionary("toy_system.txt")

    register_forward(FM_PlayerPreThink, "fw_player_prethink")
    register_forward(FM_CmdStart,       "fw_cmd_start")
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    g_looking_at[id]    = 0
    g_last_hud_time[id] = 0.0
    g_old_buttons[id]   = 0
}

find_aimed_toy(id, Float:max_range)
{
    new Float:eye[3], Float:viewofs[3]
    pev(id, pev_origin, eye)
    pev(id, pev_view_ofs, viewofs)
    eye[0] += viewofs[0]
    eye[1] += viewofs[1]
    eye[2] += viewofs[2]

    new Float:angles[3], Float:fwd[3]
    pev(id, pev_v_angle, angles)
    angle_vector(angles, ANGLEVECTOR_FORWARD, fwd)

    new best_ent = 0
    new Float:best_t = max_range + 1.0

    new ent = -1
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", TOY_ENT_CLASSNAME)) > 0)
    {
        new Float:epos[3]
        pev(ent, pev_origin, epos)
        epos[2] += 12.0  // смещаемся к центру bbox (bbox height = 24, center = +12)

        new Float:v[3]
        v[0] = epos[0] - eye[0]
        v[1] = epos[1] - eye[1]
        v[2] = epos[2] - eye[2]

        new Float:t = v[0]*fwd[0] + v[1]*fwd[1] + v[2]*fwd[2]

        if(t < 0.0 || t > max_range) continue

        new Float:closest[3]
        closest[0] = eye[0] + fwd[0] * t
        closest[1] = eye[1] + fwd[1] * t
        closest[2] = eye[2] + fwd[2] * t

        new Float:dx, Float:dy, Float:dz
        dx = closest[0] - epos[0]
        dy = closest[1] - epos[1]
        dz = closest[2] - epos[2]
        new Float:ray_dist = floatsqroot(dx*dx + dy*dy + dz*dz)

        if(ray_dist > AIM_HIT_RADIUS) continue

        if(!has_line_of_sight(eye, epos, id)) continue

        if(t < best_t)
        {
            best_t   = t
            best_ent = ent
        }
    }

    return best_ent
}

public fw_player_prethink(id)
{
    if(!is_user_alive(id)) return FMRES_IGNORED

    new Float:now = get_gametime()
    if(now - g_last_hud_time[id] < 0.1) return FMRES_IGNORED
    g_last_hud_time[id] = now

    new Float:range = float(get_pcvar_num(cvar_use_range))
    new ent = find_aimed_toy(id, range)
    g_looking_at[id] = ent

    if(!ent || !pev_valid(ent)) return FMRES_IGNORED

    new toy_idx = toy_get_toy_idx(ent)
    if(toy_idx < 0) return FMRES_IGNORED

    new name[MAX_NAME_LEN]
    toy_get_name(toy_idx, name, charsmax(name))

    new rarity = toy_get_rarity(toy_idx)
    new rar_str[32]
    toy_rarity_to_str(id, rarity, rar_str, charsmax(rar_str))

    new r, g, b
    get_rarity_color(rarity, r, g, b)

    new hud_msg[128]
    formatex(hud_msg, charsmax(hud_msg), "%L", id, "TOY_HUD_PICKUP", name, rar_str)
    set_hudmessage(r, g, b, -1.0, 0.65, 0, 0.0, 0.1, 0.0, 0.5, HUD_CHANNEL)
    show_hudmessage(id, "%s", hud_msg)

    return FMRES_IGNORED
}

public fw_cmd_start(id, uc_handle, seed)
{
    if(!is_user_alive(id)) return FMRES_IGNORED

    new buttons = get_uc(uc_handle, UC_Buttons)

    if((buttons & IN_USE) && !(g_old_buttons[id] & IN_USE))
    {
        new Float:range = float(get_pcvar_num(cvar_use_range))
        new ent = find_aimed_toy(id, range)

        if(ent && pev_valid(ent))
            toy_trigger_pickup(id, ent)
    }

    g_old_buttons[id] = buttons
    return FMRES_IGNORED
}

bool:has_line_of_sight(const Float:from[3], const Float:to[3], shooter)
{
    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, from, to, IGNORE_MONSTERS, shooter, tr)

    new Float:fraction
    get_tr2(tr, TR_flFraction, fraction)
    free_tr2(tr)

    return bool:(fraction >= 0.99)
}

get_rarity_color(rarity, &r, &g, &b)
{
    switch(rarity)
    {
        case TOY_RARITY_COMMON:    { r=200; g=200; b=200; }  // серо-белый
        case TOY_RARITY_RARE:      { r=100; g=150; b=255; }  // синий
        case TOY_RARITY_EPIC:      { r=180; g= 80; b=255; }  // фиолетовый
        case TOY_RARITY_LEGENDARY: { r=255; g=200; b= 50; }  // золотой
        default:                   { r=200; g=200; b=200; }
    }
}
