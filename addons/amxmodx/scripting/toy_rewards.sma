#include <amxmodx>
#include <amxmisc>
#include <toys_system>

#define PLUGIN_NAME    "[Adventures] Toy Rewards"
#define PLUGIN_VERSION "2.0"
#define PLUGIN_AUTHOR  "medusa"

#define MAX_NAME_LEN    64

new g_reward_points[4]      // очки
new g_reward_announce[4]    // 1 = объявлять всем, 0 = нет

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_dictionary("toy_system.txt")
}

public plugin_cfg()
{
    g_reward_points[TOY_RARITY_COMMON]    = 2
    g_reward_points[TOY_RARITY_RARE]      = 10
    g_reward_points[TOY_RARITY_EPIC]      = 25
    g_reward_points[TOY_RARITY_LEGENDARY] = 100

    g_reward_announce[TOY_RARITY_COMMON]    = 1
    g_reward_announce[TOY_RARITY_RARE]      = 1
    g_reward_announce[TOY_RARITY_EPIC]      = 1
    g_reward_announce[TOY_RARITY_LEGENDARY] = 1

    load_rewards_config()
}

load_rewards_config()
{
    new cfgdir[128], filepath[256]
    get_configsdir(cfgdir, charsmax(cfgdir))
    formatex(filepath, charsmax(filepath), "%s/toy_rewards.ini", cfgdir)

    if(!file_exists(filepath))
    {
        write_default_rewards_config(filepath)
        return
    }

    new f = fopen(filepath, "rt")
    if(!f) return

    new line[128], in_block = 0, cur_rarity = -1

    while(!feof(f))
    {
        fgets(f, line, charsmax(line))
        trim(line)
        if(!line[0] || line[0] == '/' || line[0] == ';') continue

        if(line[0] == '"' && !in_block)
        {
            new rarity_str[16]
            parse_quoted(line, rarity_str, charsmax(rarity_str))
            cur_rarity = str_to_rarity(rarity_str)
        }
        else if(line[0] == '{') { in_block = 1; }
        else if(line[0] == '}') { in_block = 0; cur_rarity = -1; }
        else if(in_block && cur_rarity >= 0)
        {
            new key[32], val[32]
            parse_kv(line, key, charsmax(key), val, charsmax(val))

            if     (equali(key, "points"))   g_reward_points[cur_rarity]   = str_to_num(val)
            else if(equali(key, "announce")) g_reward_announce[cur_rarity] = str_to_num(val)
        }
    }
    fclose(f)
}

write_default_rewards_config(const filepath[])
{
    new f = fopen(filepath, "wt")
    if(!f) return

    fputs(f, "// Adventures Toy System — конфиг наград^n")
    fputs(f, "// points: очки сервера (требует плагин наград)^n")
    fputs(f, "// announce: 1 = объявлять всем серверу, 0 = нет^n^n")

    fputs(f, "^"common^"^n{^n")
    fputs(f, "    ^"points^"   ^"2^"^n")
    fputs(f, "    ^"announce^" ^"1^"^n")
    fputs(f, "}^n^n")

    fputs(f, "^"rare^"^n{^n")
    fputs(f, "    ^"points^"   ^"10^"^n")
    fputs(f, "    ^"announce^" ^"1^"^n")
    fputs(f, "}^n^n")

    fputs(f, "^"epic^"^n{^n")
    fputs(f, "    ^"points^"   ^"25^"^n")
    fputs(f, "    ^"announce^" ^"1^"^n")
    fputs(f, "}^n^n")

    fputs(f, "^"legendary^"^n{^n")
    fputs(f, "    ^"points^"   ^"100^"^n")
    fputs(f, "    ^"announce^" ^"1^"^n")
    fputs(f, "}^n")

    fclose(f)
}

public toy_on_pickup(id, ent, toy_idx)
{
    new rarity = toy_get_rarity(toy_idx)

    new toy_name[MAX_NAME_LEN]
    toy_get_name(toy_idx, toy_name, charsmax(toy_name))

    new points = g_reward_points[rarity]
    if(points > 0)
        give_points_to_player(id, points, toy_name)

    if(g_reward_announce[rarity])
        do_announce(id, toy_name, rarity, points)

    return PLUGIN_CONTINUE
}

do_announce(id, const toy_name[], rarity, points)
{
    new player_name[32]
    get_user_name(id, player_name, charsmax(player_name))

    new rar_str[32]
    toy_rarity_to_str(LANG_PLAYER, rarity, rar_str, charsmax(rar_str))

    new pts_word[16]
    static const pts_keys[3][] = { "TOY_RWD_PTS_1", "TOY_RWD_PTS_2", "TOY_RWD_PTS_5" }
    formatex(pts_word, charsmax(pts_word), "%L", LANG_PLAYER, pts_keys[get_pts_form(points)])

    new msg[256]
    formatex(msg, charsmax(msg), "%L", LANG_PLAYER, "TOY_RWD_FOUND", player_name, toy_name, rar_str, points, pts_word)
    client_print_color(0, print_team_default, msg)
}

give_points_to_player(id, amount, const toy_name[])
{
    #pragma unused id, amount, toy_name
}

get_pts_form(n)
{
    new rem100 = n % 100
    if(rem100 >= 11 && rem100 <= 19) return 2
    new rem10 = n % 10
    if(rem10 == 1)               return 0
    if(rem10 >= 2 && rem10 <= 4) return 1
    return 2
}

str_to_rarity(const s[])
{
    if     (equali(s, "rare"))      return TOY_RARITY_RARE
    else if(equali(s, "epic"))      return TOY_RARITY_EPIC
    else if(equali(s, "legendary")) return TOY_RARITY_LEGENDARY
    return TOY_RARITY_COMMON
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
