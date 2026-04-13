#include <amxmodx>
#include <toys_system>

#define PLUGIN_NAME    "[Adventures] Toy Announcer"
#define PLUGIN_VERSION "2.0"
#define PLUGIN_AUTHOR  "medusa"

#define TASK_ANNOUNCE   9301
#define ANN_INTERVAL    280.0
#define ANN_MAX         3

new g_total_toys
new g_ann_count

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
    register_dictionary("toy_system.txt")

    register_clcmd("say /toy", "cmd_toy")
}

public toy_on_map_spawn_complete(count)
{
    g_total_toys = count
    g_ann_count = 0
    remove_task(TASK_ANNOUNCE)
    if(count > 0)
        set_task(ANN_INTERVAL, "task_announce", TASK_ANNOUNCE)
}

public task_announce()
{
    new remaining = toy_get_spawned_count()
    if(remaining <= 0) return

    g_ann_count++

    new players[32], num
    get_players(players, num, "c")
    new i
    for(i = 0; i < num; i++)
        client_print_color(players[i], print_team_default, "%L", players[i], "TOY_ANN_CHAT", remaining, g_total_toys)

    if(g_ann_count < ANN_MAX)
        set_task(ANN_INTERVAL, "task_announce", TASK_ANNOUNCE)
}

public cmd_toy(id)
{
    new remaining = toy_get_spawned_count()
    if(remaining <= 0)
        client_print_color(id, print_team_default, "%L", id, "TOY_ANN_NONE")
    else
        client_print_color(id, print_team_default, "%L", id, "TOY_ANN_CMD", remaining, g_total_toys)
    return PLUGIN_HANDLED
}
