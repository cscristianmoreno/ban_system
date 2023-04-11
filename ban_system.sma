/*
    Sistema de prohibición que restringe el ingreso del usuario al servidor.

    * ENLACE:
    https://amxmodx-es.com/Thread-Sistema-de-ban-SQLite3-Actualizaci%C3%B3n-17-02-2019
*/


#include <amxmisc>
#include <sqlx>
#include <fakemeta>

#pragma semicolon 1

/* 
=== CONSULTAS ===

// Borrar tablas
DROP TABLE IF EXISTS sql_ban;

// Vaciar contenido
DELETE FROM sql_ban; 

// Crear tablas
CREATE TABLE IF NOT EXISTS `sql_ban`
( 
	ban_name varchar(32) NOT NULL DEFAULT '', 
	ban_admin_name varchar(32) NOT NULL DEFAULT '', 
	ban_reason varchar(21) NOT NULL DEFAULT '', 
	ban_user varchar(32) NOT NULL DEFAULT '', 
	ban_time int NOT NULL DEFAULT '0', 
	ban_map varchar(21) NOT NULL DEFAULT '', 
	ban_register varchar(21) NOT NULL DEFAULT '', 
	ban_expire varchar(21) NOT NULL DEFAULT '', 
	ban_type varchar(8) NOT NULL DEFAULT '',
	ban_minutes int NOT NULL DEFAULT '0',
	ban_page int NOT NULL DEFAULT '0'
);
*/

#define PLUGIN_AUTHOR "; Cristian'"
#define PLUGIN_VERSION "v2.0"

#define SZPREFIX "!g[Sistema de ban]!y"

#define PRIVATE_DATA_CSMENUCODE 205
#define PRIVATE_DATA_LINUX 5

#define REASON_MAX_LENGTH 25
#define REASON_MIN_LENGTH 2

#define OPTION_BACKNAME "Pág. Anterior"
#define OPTION_NEXTNAME "Pág. Siguiente"
#define OPTION_EXITNAME "Volver al menú anterior"

#define USE_SQLITE // Activa el uso para la versión de SQLite3.

#define SQL_TABLE "sql_ban"
#define SQL_DATABASE "sql_ban_database"

#define SQL_HOST ""
#define SQL_USER ""
#define SQL_PASSWORD ""
#define SQL_DRIVE "sqlite"

enum _:MENU_STRUCT
{
	MENU_KICK = 1,
	MENU_BAN,
	MENU_BAN_IP,
	MENU_BAN_STEAMID,
	MENU_BAN_REMOVE
};

enum _:MESSAGEMODE_STRUCT
{
	CALCULAR_DIAS_EN_MINUTOS,
	CALCULAR_HORAS_EN_MINUTOS,
	INTRODUCIR_MINUTOS,
	INTRODUCIR_RAZON,
	INTRODUCIR_IP,
	INTRODUCIR_STEAMID
};

enum _:BAN_TYPE_STRUCT
{
	BAN_IP,
	BAN_STEAMID,
	BAN_HWID
};

enum _:USERS_DISCONNECTED_STRUCT
{
	USER_NAME[32],
	USER_IP[16],
	USER_STEAMID[35],
	USER_HWID[35]
};

enum _:STATS_BAN_STRUCT
{
	STAT_BAN_ADMIN_NAME[32],
	STAT_BAN_ADMIN_REASON[32],
	STAT_BAN_ADMIN_REGISTER[32],
	STAT_BAN_ADMIN_EXPIRE[32],
	STAT_BAN_ADMIN_MAP[32],
	STAT_BAN_TYPE_NAME[32],
	STAT_BAN_ADMIN_MINUTES,
	STAT_BAN_TYPE,
	STAT_BAN_TIME,
	STAT_BAN_QUERY_RESULT[35],
	STAT_BAN_QUERY_NAME[32]
};

new const BAN_TYPES[][] =
{
	"IP",
	"STEAMID",
	"HID"
};

new g_user_name[33][32];
new g_user_unban_name[33][32];
new g_user_ban_status[33];
new g_user_ban_admin[33][32];
new g_user_ban_reason[33][32];
new g_user_ban_register[33][32];
new g_user_ban_add[33][16];
new g_user_ban_expire[33][32];
new g_user_ban_minutes[33];
new g_user_ban_minutes_per_day_calculation[33];
new g_user_ban_minutes_per_hour_calculation[33];
new g_user_ban_selection[33];
new g_user_ban_map[33][32];
new g_user_ip[33][16];
new g_user_authid[33][35];
new g_user_ban_type[33];
new g_user_ban_type_name[33][32];
new g_user_hid[33][35];
new g_user_page_selection[33];
new g_user_unban_selected[33];
new g_maxplayers[1 char];
new g_messagemode[33];
new g_sxei_output;
new g_user_disconnected[10][USERS_DISCONNECTED_STRUCT];
new g_number_users_disconnected;

new Trie:g_trie_ban_stats;
new Array:g_array_ban_stats;

new g_cvar_ban_system_update_frequency;

new Handle:g_sql_connection;
new Handle:g_sql_htuple;

public plugin_init()
{
	register_plugin("AMX Ban System", PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	register_clcmd("say", "clcmd_say");
	register_clcmd("say_team", "clcmd_say");
	register_clcmd("CALCULAR_DIAS_EN_MINUTOS", "clcmd_messagemode");
	register_clcmd("CALCULAR_HORAS_EN_MINUTOS", "clcmd_messagemode");
	register_clcmd("INTRODUCIR_MINUTOS", "clcmd_messagemode");
	register_clcmd("INTRODUCIR_RAZON", "clcmd_messagemode");
	register_clcmd("INTRODUCIR_IP", "clcmd_messagemode");
	register_clcmd("INTRODUCIR_STEAMID", "clcmd_messagemode");
	register_clcmd("chooseteam", "clcmd_changeteam");
	register_clcmd("jointeam", "clcmd_changeteam");
	register_concmd("amx_ban_add_ip", "concmd_ban_add_ip", ADMIN_RCON, "Uso: amx_ban_add ^"IP^" ^"MINUTOS^" ^"RAZÓN^"");
	register_concmd("amx_ban_add_steamid", "concmd_ban_add_steamid", ADMIN_RCON, "Uso: amx_ban_add ^"STEAMID^" ^"MINUTOS^" ^"RAZÓN^"");
	register_concmd("amx_ban_add_hid", "concmd_ban_add_hid", ADMIN_RCON, "Uso: amx_ban_add ^"HID^" ^"MINUTOS^" ^"RAZÓN^"");
	
	g_sxei_output = get_cvar_pointer("__sxei_output");
	
	register_menu("Show Option Ban", (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), "handled_show_option_ban");
	register_menu("Show Answer Unban", (1<<0)|(1<<1), "handled_show_answer_unban");
	register_menu("Handled Clcmd Ban", (1<<9), "handled___clcmd_ban");
	register_menu("Show Menu Information", (1<<0)|(1<<9), "handled_show_menu_ban_information");
	
	register_forward(FM_ClientUserInfoChanged, "fw_ClientUserInfoChanged");
	
	g_cvar_ban_system_update_frequency = register_cvar("amx_ban_system_update_frequency", "60.0");
	
	g_maxplayers{0} = get_maxplayers();
	
	new error, szerror[512], get_type[12];
	SQL_SetAffinity(SQL_DRIVE);
	SQL_GetAffinity(get_type, charsmax(get_type));
	
	g_sql_htuple = SQL_MakeDbTuple(SQL_HOST, SQL_USER, SQL_PASSWORD, SQL_DATABASE);
	
	g_sql_connection = SQL_Connect(g_sql_htuple, error, szerror, 511);
	
	if (g_sql_htuple == Empty_Handle)
	{
		log_to_file("SQL_Htuple.log", "%s", szerror);
		set_fail_state(szerror);
		return;
	}
	
	if (g_sql_connection == Empty_Handle)
	{
		log_to_file("SQL_Connection.log", "%s", szerror);
		set_fail_state(szerror);
		return;
	}
	
	g_trie_ban_stats = TrieCreate();
	g_array_ban_stats = ArrayCreate(STATS_BAN_STRUCT);
	
	set_task(1.0, "check_user_banned");
	set_task(3.0, "check_user_unixtime");
}

public plugin_end()
{
	TrieDestroy(g_trie_ban_stats);
	ArrayDestroy(g_array_ban_stats);
	
	if (g_sql_connection)
		SQL_FreeHandle(g_sql_connection);
}

sql_query_error(Handle:query)
{
    static error[56];
    SQL_QueryError(query, error, 55);
        
    chat_color(0, "%s !yError: !g%s!y.", SZPREFIX, error);
    log_to_file("SQL_Query_Error.txt", "Error: %s", error);
    SQL_FreeHandle(query);
}

public check_user_banned()
{
	new Handle:query;
	query = SQL_PrepareQuery(g_sql_connection, "SELECT `ban_admin_name`, `ban_reason`, `ban_map`, `ban_register`, `ban_expire`, `ban_type`, `ban_user`, `ban_name`, `ban_minutes`, `ban_page`, `ban_time` FROM `%s`;", SQL_TABLE);
	
	if (!SQL_Execute(query))
		sql_query_error(query);
	else if (SQL_NumResults(query))
	{
		new query_result[35], query_name[32], ban_admin[32], ban_reason[32], ban_map[32], ban_register[32], ban_expire[32], ban_type_name[32], ban_minutes, ban_page, ban_time;
		
		while (SQL_MoreResults(query))
		{
			SQL_ReadResult(query, 0, ban_admin, 32);
			SQL_ReadResult(query, 1, ban_reason, 32);
			SQL_ReadResult(query, 2, ban_map, 32);
			SQL_ReadResult(query, 3, ban_register, 32);
			SQL_ReadResult(query, 4, ban_expire, 32);
			SQL_ReadResult(query, 5, ban_type_name, 32);
			SQL_ReadResult(query, 6, query_result, 34);
			SQL_ReadResult(query, 7, query_name, 32);
			
			ban_minutes = SQL_ReadResult(query, 8);
			ban_page = SQL_ReadResult(query, 9);
			ban_time = SQL_ReadResult(query, 10);
			
			check_copy_stats(ban_admin, ban_reason, ban_map, ban_register, ban_expire, ban_type_name, query_result, query_name, ban_minutes, ban_page, ban_time);
			SQL_NextRow(query);
		}
		
		
		SQL_FreeHandle(query);
	}
	else
		SQL_FreeHandle(query);
}

check_copy_stats(const ban_admin[], const ban_reason[], const ban_map[], const ban_register[], const ban_expire[], const ban_type_name[], const query_result[], const query_name[], ban_minutes, ban_page, ban_time)
{
	new stats[STATS_BAN_STRUCT];
	
	copy(stats[STAT_BAN_ADMIN_NAME], charsmax(stats[STAT_BAN_ADMIN_NAME]), ban_admin);
	copy(stats[STAT_BAN_ADMIN_REASON], charsmax(stats[STAT_BAN_ADMIN_REASON]), ban_reason);
	copy(stats[STAT_BAN_ADMIN_MAP], charsmax(stats[STAT_BAN_ADMIN_MAP]), ban_map);
	copy(stats[STAT_BAN_ADMIN_REGISTER], charsmax(stats[STAT_BAN_ADMIN_REGISTER]), ban_register);
	copy(stats[STAT_BAN_ADMIN_EXPIRE], charsmax(stats[STAT_BAN_ADMIN_EXPIRE]), ban_expire);
	copy(stats[STAT_BAN_TYPE_NAME], charsmax(stats[STAT_BAN_TYPE_NAME]), ban_type_name);
	copy(stats[STAT_BAN_QUERY_RESULT], charsmax(stats[STAT_BAN_QUERY_RESULT]), query_result);
	copy(stats[STAT_BAN_QUERY_NAME], charsmax(stats[STAT_BAN_QUERY_NAME]), query_name);

	stats[STAT_BAN_ADMIN_MINUTES] = ban_minutes;
	stats[STAT_BAN_TYPE] = ban_page;
	stats[STAT_BAN_TIME] = ban_time;
	
	TrieSetArray(g_trie_ban_stats, query_result, stats, sizeof(stats));
	ArrayPushArray(g_array_ban_stats, stats);
}

public check_user_unixtime()
{
	new stats[STATS_BAN_STRUCT], i;
	
	for (i = 0; i < ArraySize(g_array_ban_stats); i++)
	{
		if (ArrayGetArray(g_array_ban_stats, i, stats))
		{	
			if (get_systime() > stats[STAT_BAN_TIME])
			{
				new Handle:query;
				query = SQL_PrepareQuery(g_sql_connection, "DELETE FROM `%s` WHERE `ban_user` = ^"%s^";", SQL_TABLE, stats[STAT_BAN_QUERY_RESULT]);
				
				if (!SQL_Execute(query))
					sql_query_error(query);
				else
				{
					if (stats[STAT_BAN_QUERY_NAME][0])
					{
						server_print("El ban de %s expiró", stats[STAT_BAN_QUERY_NAME]);
						chat_color(0, "%s !yEl ban de !g%s!y expiró.", SZPREFIX, stats[STAT_BAN_QUERY_NAME]);
						log_to_file("ban_systime_expire.txt", "El ban de <%s> expiró", stats[STAT_BAN_QUERY_NAME]);
					}
					else
					{
						server_print("El ban de %s expiró", stats[STAT_BAN_QUERY_RESULT]);
						chat_color(0, "%s !yEl ban de !g%s!y expiró.", SZPREFIX, stats[STAT_BAN_QUERY_RESULT]);
						log_to_file("ban_systime_expire.txt", "El ban de <%s> expiró", stats[STAT_BAN_QUERY_RESULT]);
					}
					
					TrieDeleteKey(g_trie_ban_stats, stats[STAT_BAN_QUERY_RESULT]);
					ArrayDeleteItem(g_array_ban_stats, i);
					SQL_FreeHandle(query);
				}
			}
		}
	}
	
	set_task(get_pcvar_float(g_cvar_ban_system_update_frequency), "check_user_unixtime");
}

public client_putinserver(id)
{
	get_user_name(id, g_user_name[id], 31);
	get_user_ip(id, g_user_ip[id], charsmax(g_user_ip[]), .without_port = 1);
	get_user_authid(id, g_user_authid[id], charsmax(g_user_authid[]));
	
	g_user_ban_admin[id][0] = '^0';
	g_user_ban_reason[id][0] = '^0';
	g_user_ban_register[id][0] = '^0';
	g_user_ban_expire[id][0] = '^0';
	g_user_ban_type_name[id][0] = '^0';
	g_user_ban_map[id][0] = '^0';
	g_user_hid[id][0] = '^0';
	g_user_ban_add[id][0] = '^0';
	g_user_unban_name[id][0] = '^0';
	g_user_ban_reason[id][0] = '^0';
	g_user_ban_selection[id] = 0;
	g_user_page_selection[id] = 0;
	g_user_ban_minutes[id] = 0;
	g_user_ban_minutes_per_day_calculation[id] = 0;
	g_user_ban_minutes_per_hour_calculation[id] = 0;
	g_user_ban_status[id] = 0;
	g_user_ban_type[id] = 0;
	g_user_unban_selected[id] = 0;
	
	set_task(0.25, "check_user_ban", id);
}

public check_user_ban(id)
{
	new stats[STATS_BAN_STRUCT];
	
	if (TrieGetArray(g_trie_ban_stats, g_user_ip[id], stats, sizeof(stats)) || TrieGetArray(g_trie_ban_stats, g_user_authid[id], stats, sizeof(stats)))
	{
		g_user_ban_status[id] = 1;
		
		copy(g_user_ban_admin[id], charsmax(g_user_ban_admin[]), stats[STAT_BAN_ADMIN_NAME]);
		copy(g_user_ban_reason[id], charsmax(g_user_ban_reason[]), stats[STAT_BAN_ADMIN_REASON]);
		copy(g_user_ban_map[id], charsmax(g_user_ban_map[]), stats[STAT_BAN_ADMIN_MAP]);
		copy(g_user_ban_register[id], charsmax(g_user_ban_register[]), stats[STAT_BAN_ADMIN_REGISTER]);
		copy(g_user_ban_expire[id], charsmax(g_user_ban_expire[]), stats[STAT_BAN_ADMIN_EXPIRE]);
		copy(g_user_ban_type_name[id], charsmax(g_user_ban_type_name[]), stats[STAT_BAN_TYPE_NAME]);
		
		g_user_ban_minutes[id] = stats[STAT_BAN_ADMIN_MINUTES];
		g_user_page_selection[id] = stats[STAT_BAN_TYPE];
		
		clcmd_changeteam(id);
		return;
	}
	
	set_task(5.0, "check_user_hid", id);
}

reset_vars_string(id)
	g_user_ban_add[id][0] = '^0';

public check_user_hid(id)
{
	if (!is_user_connected(id))
		return;
	
	server_cmd("sxe_userhid #%d", get_user_userid(id));
	server_exec();
	get_pcvar_string(g_sxei_output, g_user_hid[id], charsmax(g_user_hid[])); 
	
	new stats[STATS_BAN_STRUCT];
	
	if (TrieGetArray(g_trie_ban_stats, g_user_hid[id], stats, sizeof(stats)))
	{
		chat_color(0, "%s !g%s!y fue expulsado por que su !gHID!y está baneada.", SZPREFIX, g_user_name[id]);
		
		console_print(id, "");
		console_print(id, "");
		console_print(id, "****** BANEADO ******");
		console_print(id, "");
		console_print(id, "* Fuiste baneado del servidor");
		console_print(id, "* Administrador: %s", stats[STAT_BAN_ADMIN_NAME]);
		console_print(id, "* Razón del ban: %s", stats[STAT_BAN_ADMIN_REASON]);
		console_print(id, "* Mapa: %s", stats[STAT_BAN_ADMIN_MAP]);
		console_print(id, "* Tipo de ban: %s", stats[STAT_BAN_TYPE_NAME]);
		console_print(id, "* Minutos: %d minuto%s", stats[STAT_BAN_ADMIN_MINUTES], (stats[STAT_BAN_ADMIN_MINUTES] == 1) ? "" : "s");
		console_print(id, "* Tiempo calculado: %s", check_time_calculated(stats[STAT_BAN_ADMIN_MINUTES]));
		console_print(id, "* Fecha del ban: %s", stats[STAT_BAN_ADMIN_REGISTER]);
		console_print(id, "* Expira en la fecha: %s", stats[STAT_BAN_ADMIN_EXPIRE]);
		console_print(id, "");
		console_print(id, "* Fuiste baneado del servidor");
		console_print(id, "");
		console_print(id, "****** BANEADO ******");
		console_print(id, "");
		console_print(id, "");
		
		server_cmd("kick #%d ^"Tu HID está baneada, mirá tu consola^"", get_user_userid(id));
	}
}

public concmd_ban_add_ip(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new Handle:query, args[35], reason[21], minutes[10], time[32], unixtime, name[32], map[32];
	read_argv(1, args, charsmax(args));
	read_argv(2, minutes, 9);
	read_argv(3, reason, 20);
	
	if (strlen(args) < 5)
	{
		console_print(id, "La IP introducida debe contener más de 5 carácteres");
		return PLUGIN_HANDLED;
	}
	
	if (!isdigit(minutes[0]))
	{
		console_print(id, "Los minutos no pueden ser letras");
		return PLUGIN_HANDLED;
	}
	
	if (!str_to_num(minutes))
	{
		console_print(id, "Tenés que introducir los minutos del ban");
		return PLUGIN_HANDLED;
	}
	
	if (strlen(reason) < REASON_MIN_LENGTH)
	{
		console_print(id, "La razón del ban debe tener al menos 5 carácteres");
		return PLUGIN_HANDLED;
	}
	else if (strlen(reason) > REASON_MAX_LENGTH)
	{
		console_print(id, "La razón del ban no debe superar los 20 carácteres");
		return PLUGIN_HANDLED;
	}
	
	copy(g_user_ban_reason[id], charsmax(g_user_ban_reason[]), reason);
	g_user_ban_minutes[id] = str_to_num(minutes);
	
	if (TrieKeyExists(g_trie_ban_stats, args))
	{
		console_print(id, "La IP introducida ya existe en la base de datos");
		return PLUGIN_HANDLED;
	}
	
	unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
	get_time("%d/%m/%Y - %H:%M:%S", time, 31);
	format_time(g_user_ban_expire[id], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
	get_user_name(id, name, 31);
	get_mapname(map, 31);
	
	query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, g_user_name[id], g_user_ban_reason[id], args, unixtime, map, time, g_user_ban_expire[id], g_user_ban_minutes[id], g_user_page_selection[id]);

	if (!SQL_Execute(query))
		sql_query_error(query);
	else
	{
		SQL_FreeHandle(query);
		chat_color(0, "%s !g%s!y baneó la IP !g%s!y. Razón: !g%s!y.", SZPREFIX, g_user_name[id], args, g_user_ban_reason[id]);
		chat_color(0, "%s !yMinutos: !g%d minuto%s !t(%s)!y.", SZPREFIX, g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), (g_user_ban_minutes[id] == 1) ? "" : "s");
		log_to_file("ban_systime_ban_ip.txt", "<%s> baneó la IP <%s>", g_user_name[id], args);
		check_copy_stats(g_user_name[id], g_user_ban_reason[id], map, time, g_user_ban_expire[id], "", args, "", g_user_ban_minutes[id], MENU_BAN_IP, unixtime);	
		reset_vars_string(id);
	}
	
	return PLUGIN_HANDLED;
}

public concmd_ban_add_steamid(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new Handle:query, args[35], reason[21], minutes[10], time[32], unixtime, name[32], map[32];
	read_argv(1, args, charsmax(args));
	read_argv(2, minutes, 9);
	read_argv(3, reason, 20);
	
	if (strlen(args) < 5)
	{
		console_print(id, "El SteamID introducido debe contener más de 5 carácteres");
		return PLUGIN_HANDLED;
	}
	
	if (!isdigit(minutes[0]))
	{
		console_print(id, "Los minutos no pueden ser letras");
		return PLUGIN_HANDLED;
	}
	
	if (!str_to_num(minutes))
	{
		console_print(id, "Tenés que introducir los minutos del ban");
		return PLUGIN_HANDLED;
	}
	
	if (strlen(reason) < REASON_MIN_LENGTH)
	{
		console_print(id, "La razón del ban debe tener al menos 5 carácteres");
		return PLUGIN_HANDLED;
	}
	else if (strlen(reason) > REASON_MAX_LENGTH)
	{
		console_print(id, "La razón del ban no debe superar los 20 carácteres");
		return PLUGIN_HANDLED;
	}
	
	copy(g_user_ban_reason[id], charsmax(g_user_ban_reason[]), reason);
	g_user_ban_minutes[id] = str_to_num(minutes);
	
	if (TrieKeyExists(g_trie_ban_stats, args))
	{
		console_print(id, "El SteamID introducido ya existe en la base de datos");
		return PLUGIN_HANDLED;
	}
	
	unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
	get_time("%d/%m/%Y - %H:%M:%S", time, 31);
	format_time(g_user_ban_expire[id], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
	get_user_name(id, name, 31);
	get_mapname(map, 31);
	
	query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, g_user_name[id], g_user_ban_reason[id], args, unixtime, map, time, g_user_ban_expire[id], g_user_ban_minutes[id], g_user_page_selection[id]);

	if (!SQL_Execute(query))
		sql_query_error(query);
	else
	{
		SQL_FreeHandle(query);
		chat_color(0, "%s !g%s!y baneó el SteamID !g%s!y. Razón: !g%s!y.", SZPREFIX, g_user_name[id], args, g_user_ban_reason[id]);
		chat_color(0, "%s !yMinutos: !g%d minuto%s !t(%s)!y.", SZPREFIX, g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), (g_user_ban_minutes[id] == 1) ? "" : "s");
		log_to_file("ban_systime_ban_authid.txt", "<%s> baneó el SteamID <%s>", g_user_name[id], args);
		check_copy_stats(g_user_name[id], g_user_ban_reason[id], map, time, g_user_ban_expire[id], "", args, "", g_user_ban_minutes[id], MENU_BAN_STEAMID, unixtime);	
		reset_vars_string(id);
	}
	
	return PLUGIN_HANDLED;
}

public concmd_ban_add_hid(id, level, cid)
{
	if (!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED;
	
	new Handle:query, args[35], reason[21], minutes[10], time[32], unixtime, name[32], map[32];
	read_argv(1, args, charsmax(args));
	read_argv(2, minutes, 9);
	read_argv(3, reason, 20);
	
	if (strlen(args) < 5)
	{
		console_print(id, "El HID introducido debe contener más de 5 carácteres");
		return PLUGIN_HANDLED;
	}
	
	if (!isdigit(minutes[0]))
	{
		console_print(id, "Los minutos no pueden ser letras");
		return PLUGIN_HANDLED;
	}
	
	if (!str_to_num(minutes))
	{
		console_print(id, "Tenés que introducir los minutos del ban");
		return PLUGIN_HANDLED;
	}
	
	if (strlen(reason) < REASON_MIN_LENGTH)
	{
		console_print(id, "La razón del ban debe tener al menos 5 carácteres");
		return PLUGIN_HANDLED;
	}
	else if (strlen(reason) > REASON_MAX_LENGTH)
	{
		console_print(id, "La razón del ban no debe superar los 20 carácteres");
		return PLUGIN_HANDLED;
	}
	
	copy(g_user_ban_reason[id], charsmax(g_user_ban_reason[]), reason);
	g_user_ban_minutes[id] = str_to_num(minutes);
	
	if (TrieKeyExists(g_trie_ban_stats, args))
	{
		console_print(id, "El HID introducido ya existe en la base de datos");
		return PLUGIN_HANDLED;
	}
	
	unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
	get_time("%d/%m/%Y - %H:%M:%S", time, 31);
	format_time(g_user_ban_expire[id], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
	get_user_name(id, name, 31);
	get_mapname(map, 31);
	
	query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, g_user_name[id], g_user_ban_reason[id], args, unixtime, map, time, g_user_ban_expire[id], g_user_ban_minutes[id], g_user_page_selection[id]);

	if (!SQL_Execute(query))
		sql_query_error(query);
	else
	{
		SQL_FreeHandle(query);
		chat_color(0, "%s !g%s!y baneó el HID !g%s!y. Razón: !g%s!y.", SZPREFIX, g_user_name[id], args, g_user_ban_reason[id]);
		chat_color(0, "%s !yMinutos: !g%d minuto%s !t(%s)!y.", SZPREFIX, g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), (g_user_ban_minutes[id] == 1) ? "" : "s");
		log_to_file("ban_systime_ban_hid.txt", "<%s> baneó el HID <%s>", g_user_name[id], args);
		check_copy_stats(g_user_name[id], g_user_ban_reason[id], map, time, g_user_ban_expire[id], "", args, "", g_user_ban_minutes[id], -1, unixtime);	
		reset_vars_string(id);
	}
	
	return PLUGIN_HANDLED;
}

public client_disconnected(id)
{
	static i, add_disconnected;
	add_disconnected = 1;
	
	for (i = 0; i < g_number_users_disconnected; i++)
	{
		if (equal(g_user_ip[id], g_user_disconnected[i][USER_IP]) && equal(g_user_authid[id], g_user_disconnected[i][USER_STEAMID]))
		{
			add_disconnected = 0;
			break;
		}
	}
	
	if (!add_disconnected)
		return;
	
	if (g_number_users_disconnected == 10)
		g_number_users_disconnected = 0;
	
	copy(g_user_disconnected[g_number_users_disconnected][USER_NAME], 31, g_user_name[id]);
	copy(g_user_disconnected[g_number_users_disconnected][USER_IP], 16, g_user_ip[id]);
	copy(g_user_disconnected[g_number_users_disconnected][USER_STEAMID], charsmax(g_user_disconnected[]), g_user_authid[id]);
	copy(g_user_disconnected[g_number_users_disconnected][USER_HWID], charsmax(g_user_disconnected[]), g_user_hid[id]);
		
	g_number_users_disconnected++;
}

public fw_ClientUserInfoChanged(id, buffer)
{
	static name[32];
	engfunc(EngFunc_InfoKeyValue, buffer, "name", name, charsmax(name));
	
	if (equali(name, g_user_name[id]))
		return FMRES_IGNORED;
	
	engfunc(EngFunc_SetClientKeyValue, id, buffer, "name", name);
	
	copy(g_user_name[id], 31, name);
	return FMRES_IGNORED;
}	

public clcmd_say(id)
{
	if (g_user_ban_status[id])
	{
		chat_color(id, "%s !yEstás baneado, no podés escribir por el chat.", SZPREFIX);
		return PLUGIN_HANDLED;
	}
	
	static args[9];
	read_args(args, charsmax(args));
	remove_quotes(args);
	trim(args);
	
	if (equal(args, "/ban") || equal(args, ".ban") || equal(args, "!ban"))
	{
		clcmd_ban(id);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}
	
public clcmd_ban(id)
{
	if (!is_user_admin(id))
		return PLUGIN_HANDLED;
	
	static menu;
	menu = menu_create("\yMenú de ban SQL", "handled_clcmd_ban");
	
	menu_additem(menu, "Expulsar\y,\w banear", "1", 0);
	menu_additem(menu, "Lista de ban^n", "2", 0);
	menu_additem(menu, "Último diez usuarios desconectados", "3", 0);
	menu_additem(menu, "Información del plugin", "4", 0);
	
	set_pdata_int(id, PRIVATE_DATA_CSMENUCODE, false, PRIVATE_DATA_LINUX);
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public bs_admin_flags_check(id, menu, item)
{
	if (!(get_user_flags(id) & ADMIN_RCON))
		return ITEM_DISABLED;
	
	return ITEM_ENABLED;
}

public handled_clcmd_ban(id, menu, item)
{
	menu_destroy(menu);
	
	switch(item)
	{
		case 0: show_menu_ban(id); 
		case 1: show_menu_ban_list(id); 
		case 2: show_view_last_ten_disconnected(id);
		case 3: 
		{
			static szmenu[530];
			format(szmenu, charsmax(szmenu), "\yInformación del plugin^n^n\wSistema de ban: \yv%s^n\wAutor: \y%s^n^n\r* \yComandos^n\r* \wamx_ban_add_ip \y^"IP^" ^"Razón^" ^"Minutos^"^n\r* \wamx_ban_add_steamid \y^"STEAMID^" ^"Razón^" ^"Minutos^"^n\r* \wamx_ban_add_hid \y^"HID^" ^"Razón^" ^"Minutos^"^n^n\r0. \w%s", PLUGIN_VERSION, PLUGIN_AUTHOR, OPTION_EXITNAME);
			show_menu(id, (1<<9), szmenu, FM_NULLENT, "Handled Clcmd Ban");
		}
	}
	
	return PLUGIN_HANDLED;
}

public handled___clcmd_ban(id, key)
{
	if (key == 9)
		clcmd_ban(id);
	
	return PLUGIN_HANDLED;
}

show_menu_ban(id)
{
	static menu;
	menu = menu_create("\yExpulsar.. Banear usuario", "handled_show_menu_ban");
	
	menu_additem(menu, "Expulsar \yUSUARIO^n", "1", 0);
	menu_additem(menu, "Banear \yUSUARIO", "2", 0);
	menu_additem(menu, "Banear \yIP", "3", 0);
	menu_additem(menu, "Banear \ySTEAMID^n", "4", 0);
	
	set_pdata_int(id, PRIVATE_DATA_CSMENUCODE, false, PRIVATE_DATA_LINUX);
	menu_setprop(menu, MPROP_EXITNAME, OPTION_EXITNAME);
	menu_display(id, menu);
}

public handled_show_menu_ban(id, menu, item)
{
	menu_destroy(menu);
	
	switch(item)
	{
		case MENU_EXIT: clcmd_ban(id);
		case 0: show_menu_users(id, "Expulsar usuario", MENU_KICK);
		case 1: show_menu_users(id, "Banear usuario", MENU_BAN);
		case 2: show_option_ban(id, MENU_BAN_IP); 
		case 3: show_option_ban(id, MENU_BAN_STEAMID); 
	}
	
	return PLUGIN_HANDLED;
}

show_menu_ban_list(id)
{
	static menu, num[3], i, stats[STATS_BAN_STRUCT], sztext[28];
	menu = menu_create("\yLista de ban^nPresioná para ver la información", "handled_show_menu_ban_list");
	
	for (i = 0; i < ArraySize(g_array_ban_stats); i++)
	{
		ArrayGetArray(g_array_ban_stats, i, stats);
		num_to_str((i + 1), num, charsmax(num));
		
		if (stats[STAT_BAN_QUERY_NAME][0])
			copy(sztext, charsmax(sztext), stats[STAT_BAN_QUERY_NAME]);
		else
			copy(sztext, charsmax(sztext), stats[STAT_BAN_QUERY_RESULT]);
			
		menu_additem(menu, sztext, num);
	}
	
	menu_setprop(menu, MPROP_BACKNAME, OPTION_BACKNAME);
	menu_setprop(menu, MPROP_NEXTNAME, OPTION_NEXTNAME);
	menu_setprop(menu, MPROP_EXITNAME, OPTION_EXITNAME);
	
	menu_display(id, menu);
}

public handled_show_menu_ban_list(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		clcmd_ban(id);
		return PLUGIN_HANDLED;
	}
	
	static num[3], access, item_name[35], sztext[400], stats[STATS_BAN_STRUCT];
	menu_item_getinfo(menu, item, access, num, charsmax(num), item_name, charsmax(item_name), access);

	g_user_unban_selected[id] = str_to_num(num) - 1;
	
	ArrayGetArray(g_array_ban_stats, g_user_unban_selected[id], stats);
	formatex(sztext, charsmax(sztext), "\r* \yInformación del ban \d(%s)^n^n\r* \wAdministrador: \y%s^n\r* \wRazón: \y%s^n\r* \wMapa: \y%s^n\r* \wMinutos: \y%d minuto%s^n\r* \wTiempo calculado: \y%s^n\r* \wFecha del ban: \y%s^n\r* \wEl ban expira en la fecha: \y%s^n^n\r1. \wRemover el ban^n\r0. \wVolver al menú anterior", item_name, stats[STAT_BAN_ADMIN_NAME], stats[STAT_BAN_ADMIN_REASON], stats[STAT_BAN_ADMIN_MAP], stats[STAT_BAN_ADMIN_MINUTES], (stats[STAT_BAN_ADMIN_MINUTES] == 1) ? "" : "s", check_time_calculated(stats[STAT_BAN_ADMIN_MINUTES]), stats[STAT_BAN_ADMIN_REGISTER], stats[STAT_BAN_ADMIN_EXPIRE]);
		
	show_menu(id, (1<<0)|(1<<9), sztext, FM_NULLENT, "Show Menu Information"); 
	copy(g_user_unban_name[id], charsmax(g_user_unban_name[]), item_name);
	
	return PLUGIN_HANDLED;
}

public handled_show_menu_ban_information(id, key)
{
	switch(key)
	{
		case 0: 
		{
			static sztext[100];
			
			format(sztext, charsmax(sztext), "\y¿Estás seguro de desbanear esto?^n\wSeleccionado: \y%s?^n^n\r1. \wSí^n\r2. \wNo", g_user_unban_name[id]);
			show_menu(id, (1<<0)|(1<<1), sztext, -1, "Show Answer Unban");
		}
		case 9: show_menu_ban_list(id);
	}
	
	return PLUGIN_HANDLED;
}

public handled_show_answer_unban(id, key)
{
	switch(key)
	{
		case 0: 
		{
			new Handle:query, stats[STATS_BAN_STRUCT];
			ArrayGetArray(g_array_ban_stats, g_user_unban_selected[id], stats);
			
			query = SQL_PrepareQuery(g_sql_connection, "DELETE FROM `%s` WHERE `ban_user` = ^"%s^";", SQL_TABLE, stats[STAT_BAN_QUERY_RESULT]);
			
			if (!SQL_Execute(query))
				sql_query_error(query);
			else
			{
				static name[32];
				get_user_name(id, name, 31);
				
				if (stats[STAT_BAN_QUERY_NAME][0])
				{
					chat_color(0, "%s !g%s!y desbaneó a !g%s!y.", SZPREFIX, name, stats[STAT_BAN_QUERY_NAME]);
					log_to_file("ban_systime_unban.txt", "<%s> desbaneó a <%s>", stats[STAT_BAN_QUERY_NAME]);
					TrieDeleteKey(g_trie_ban_stats, stats[STAT_BAN_QUERY_NAME]);
				}
				else
				{
					chat_color(0, "%s !g%s!y desbaneó a !g%s!y.", SZPREFIX, name, stats[STAT_BAN_QUERY_RESULT]);
					log_to_file("ban_systime_unban.txt", "<%s> desbaneó a <%s>", stats[STAT_BAN_QUERY_RESULT]);
					TrieDeleteKey(g_trie_ban_stats, stats[STAT_BAN_QUERY_RESULT]);
				}
				
				ArrayDeleteItem(g_array_ban_stats, g_user_unban_selected[id]);
				
				show_menu_ban_list(id);
				SQL_FreeHandle(query);
			}
		}
		case 1: clcmd_ban(id);

	}
	return PLUGIN_HANDLED;
}

show_view_last_ten_disconnected(id)
{
	static menu;
	menu = menu_create("\yÚltimo diez usuarios desconectados", "handled_show_view_last_ten_disconnected");
	
	menu_additem(menu, "Ver lista en menú", "1", 0);
	menu_additem(menu, "Ver lista en consola", "2", 0);
	
	menu_setprop(menu, MPROP_BACKNAME, OPTION_BACKNAME);
	menu_setprop(menu, MPROP_NEXTNAME, OPTION_NEXTNAME);
	menu_setprop(menu, MPROP_EXITNAME, OPTION_EXITNAME);
	
	menu_display(id, menu);
}

public handled_show_view_last_ten_disconnected(id, menu, item)
{
	menu_destroy(menu);
	
	switch(item)
	{
		case MENU_EXIT: clcmd_ban(id); 
		case 0: show_view_users_disconnected(id, 0);
		case 1: show_view_users_disconnected(id, 1);
	}
	
	return PLUGIN_HANDLED;
}

show_view_users_disconnected(id, page)
{
	static i, sztext[128];
	
	switch(page)
	{
		case 0:
		{
			static menu, num[2];
			menu = menu_create("\yUsuarios desconectados^nNombre de usuario | IP | STEAMID | HWID", "handled_show_view_users_disconnected");
			
			for (i = 0; i < g_number_users_disconnected; i++)
			{
				num_to_str((i + 1), num, charsmax(num));
				format(sztext, 127, "%s \r|\d%s \r| \d%s \r| \d%s", g_user_disconnected[i][USER_NAME], g_user_disconnected[i][USER_IP], g_user_disconnected[i][USER_STEAMID], g_user_disconnected[i][USER_HWID]);
				menu_additem(menu, sztext, num, _, menu_makecallback("bs_check_users_disconnected"));
			}
			
			menu_setprop(menu, MPROP_BACKNAME, OPTION_BACKNAME);
			menu_setprop(menu, MPROP_NEXTNAME, OPTION_NEXTNAME);
			menu_setprop(menu, MPROP_EXITNAME, OPTION_EXITNAME);
			
			menu_display(id, menu);
		}
		case 1:
		{
			client_cmd(id, "toggleconsole");
			
			console_print(id, "===== USUARIOS DESCONECTADOS =====");
			console_print(id, "");
			console_print(id, "");
			console_print(id, "");
			console_print(id, "# Nombre de usuario | IP | STEAMID | HWID");
			
			for (i = 0; i < g_number_users_disconnected; i++)
			{
				format(sztext, 127, "%d. %s | %s | %s | %s", (i + 1), g_user_disconnected[i][USER_NAME], g_user_disconnected[i][USER_IP], g_user_disconnected[i][USER_STEAMID], g_user_disconnected[i][USER_HWID]);
				console_print(id, sztext);
			}
			
			console_print(id, "");
			console_print(id, "");
			console_print(id, "");
			console_print(id, "");
			console_print(id, "===== USUARIOS DESCONECTADOS =====");
			
			show_view_last_ten_disconnected(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

public bs_check_users_disconnected(id, menu, item)
	return ITEM_DISABLED;
	
public handled_show_view_users_disconnected(id, menu, item)
{
	menu_destroy(menu);
	
	if (item == MENU_EXIT)
		show_view_last_ten_disconnected(id);
	
	return PLUGIN_HANDLED;
}	

show_menu_users(id, const tittle[], type)
{
	static menu, i, num[3];
	menu = menu_create(tittle, "handled_show_menu_users"); 
	
	g_user_page_selection[id] = type;
	
	for (i = 1; i <= g_maxplayers{0}; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		num_to_str((i + 1), num, charsmax(num));
		menu_additem(menu, g_user_name[i], num);
	}
	
	menu_setprop(menu, MPROP_BACKNAME, OPTION_BACKNAME);
	menu_setprop(menu, MPROP_NEXTNAME, OPTION_NEXTNAME);
	menu_setprop(menu, MPROP_EXITNAME, OPTION_BACKNAME);
	
	set_pdata_int(id, PRIVATE_DATA_CSMENUCODE, false, PRIVATE_DATA_LINUX);
	menu_display(id, menu);
}

public handled_show_menu_users(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu);
		show_menu_ban(id);
		return PLUGIN_HANDLED;
	}
	
	static num[3];
	static access;
	static itemid;
	
	menu_item_getinfo(menu, item, access, num, charsmax(num), _, _, access);
	itemid = str_to_num(num) - 1;
	menu_destroy(menu);
	
	if (is_user_connected(itemid))
	{
		switch(g_user_page_selection[id])
		{
			case MENU_BAN: 
			{
				g_user_ban_selection[id] = itemid;
				show_option_ban(id, g_user_page_selection[id]);
			}
			case MENU_KICK:
			{
				chat_color(id, "%s !g%s!y expulsó a !g%s!y del servidor.", SZPREFIX, g_user_name[id], g_user_name[itemid]);
				server_cmd("kick #%d ^"Un administrador te expulsó del servidor^"", get_user_userid(itemid));
				show_menu_users(id, "Expulsar usuario", MENU_KICK);
			}
		}
	}
	
	return PLUGIN_HANDLED;
}

show_option_ban(id, page)
{
	g_user_page_selection[id] = page;
	
	static menu[512];
	
	switch(page)
	{
		case MENU_BAN:
		{
			static name[32];
			
			get_user_name(g_user_ban_selection[id], name, 31);
			format(menu, charsmax(menu), "\yBanear usuario^n^n\r* \wUsuario: \y%s^n^n\r1. \wSeleccionar otro usuario^n\r2. \wCalcular días en minutos: \y%d \d(%d minuto(s))^n\r3. \wCalcular horas en minutos: \y%d \d(%d minuto(s))^n^n\r* \dMinutos en total: \y%d^n^n\r4. \wIntroducir minutos: \y%d^n\r5. \wIntroducir razón: \y%s^n^n\r6. \yTipo de ban: \d%s^n\r7. \yEjecutar el ban^n^n\r0. \wVolver al menú anterior", name, g_user_ban_minutes_per_day_calculation[id], (1440 * g_user_ban_minutes_per_day_calculation[id]), g_user_ban_minutes_per_hour_calculation[id], (60 * g_user_ban_minutes_per_hour_calculation[id]), ((1440 * g_user_ban_minutes_per_day_calculation[id]) + (60 * g_user_ban_minutes_per_hour_calculation[id])), g_user_ban_minutes[id], g_user_ban_reason[id], BAN_TYPES[g_user_ban_type[id]]);
			show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<6)|(1<<9), menu, -1, "Show Option Ban");
		}
		case MENU_BAN_IP:
		{
			format(menu, charsmax(menu), "\yBanear IP^n^n\r* \wIP: \y%s^n^n\r1. \wIntroducir IP^n\r2. \wCalcular días en minutos: \y%d \d(%d minuto(s))^n\r3. \wCalcular horas en minutos: \y%d \d(%d minuto(s))^n^n\r* \dMinutos en total: \y%d^n^n\r4. \wIntroducir minutos: \y%d^n\r5. \wIntroducir razón: \y%s^n^n\r6. \yAgregar IP^n^n^n\r0. \wVolver al menú anterior", g_user_ban_add[id], g_user_ban_minutes_per_day_calculation[id], (1440 * g_user_ban_minutes_per_day_calculation[id]), g_user_ban_minutes_per_hour_calculation[id], (60 * g_user_ban_minutes_per_hour_calculation[id]), ((1440 * g_user_ban_minutes_per_day_calculation[id]) + (60 * g_user_ban_minutes_per_hour_calculation[id])), g_user_ban_minutes[id], g_user_ban_reason[id]);
			show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), menu, -1, "Show Option Ban");
		}
		case MENU_BAN_STEAMID:
		{
			format(menu, charsmax(menu), "\yBanear STEAMID^n^n\r* \wSteamID: \y%s^n^n\r1. \wIntroducir SteamID^n\r2. \wCalcular días en minutos: \y%d \d(%d minuto(s))^n\r3. \wCalcular horas en minutos: \y%d \d(%d minuto(s))^n^n\r* \dMinutos en total: \y%d^n^n\r4. \wIntroducir minutos: \y%d^n\r5. \wIntroducir razón: \y%s^n^n\r6. \yAgregar STEAMID^n^n^n\r0. \wVolver al menú anterior", g_user_ban_add[id], g_user_ban_minutes_per_day_calculation[id], (1440 * g_user_ban_minutes_per_day_calculation[id]), g_user_ban_minutes_per_hour_calculation[id], (60 * g_user_ban_minutes_per_hour_calculation[id]), ((1440 * g_user_ban_minutes_per_day_calculation[id]) + (60 * g_user_ban_minutes_per_hour_calculation[id])), g_user_ban_minutes[id], g_user_ban_reason[id]);
			show_menu(id, (1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9), menu, -1, "Show Option Ban");
		}
	}
	
	return PLUGIN_HANDLED;
}

public handled_show_option_ban(id, key)
{
	switch(key)
	{
		case 0: 
		{
			switch(g_user_page_selection[id])
			{
				case MENU_BAN: show_menu_users(id, "Banear usuario", MENU_BAN);
				case MENU_BAN_IP: 
				{
					g_messagemode[id] = INTRODUCIR_IP;
					client_cmd(id, "messagemode INTRODUCIR_IP");
				}
				case MENU_BAN_STEAMID: 
				{
					g_messagemode[id] = INTRODUCIR_STEAMID;
					client_cmd(id, "messagemode INTRODUCIR_STEAMID");
				}
			}
		}
		case 1:
		{
			g_messagemode[id] = CALCULAR_DIAS_EN_MINUTOS;
			client_cmd(id, "messagemode CALCULAR_DIAS_EN_MINUTOS");
		}
		case 2:
		{
			g_messagemode[id] = CALCULAR_HORAS_EN_MINUTOS;
			client_cmd(id, "messagemode CALCULAR_HORAS_EN_MINUTOS");
		}
		case 3:
		{
			g_messagemode[id] = INTRODUCIR_MINUTOS;
			client_cmd(id, "messagemode INTRODUCIR_MINUTOS");
		}
		case 4:
		{
			g_messagemode[id] = INTRODUCIR_RAZON;
			client_cmd(id, "messagemode INTRODUCIR_RAZON");
		}
		case 5:
		{
			switch(g_user_page_selection[id])
			{
				case MENU_BAN:
				{
					if (g_user_ban_type[id] == 2)
						g_user_ban_type[id] = 0;
					else
						g_user_ban_type[id]++;
					
					show_option_ban(id, g_user_page_selection[id]);
				}
				case MENU_BAN_IP:
				{
					if (!strlen(g_user_ban_reason[id]))
					{
						chat_color(id, "%s !yTenés que introducir la razón del ban.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					if (!g_user_ban_minutes[id])
					{
						chat_color(id, "%s !yTenés que introducir los minutos del ban.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					if (!g_user_ban_add[id][0])
					{
						chat_color(id, "%s !yTenès que introducir una IP", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					new Handle:query, time[32], unixtime, name[32], map[32];
					
					if (TrieKeyExists(g_trie_ban_stats, g_user_ban_add[id]))
					{
						chat_color(id, "%s !yLa IP introducida ya existe en la base de datos.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
					get_time("%d/%m/%Y - %H:%M:%S", time, 31);
					format_time(g_user_ban_expire[id], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
					get_user_name(id, name, 31);
					get_mapname(map, 31);
					
					query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, g_user_name[id], g_user_ban_reason[id], g_user_ban_add[id], unixtime, map, time, g_user_ban_expire[id], g_user_ban_minutes[id], g_user_page_selection[id]);
			
					if (!SQL_Execute(query))
						sql_query_error(query);
					else
					{
						SQL_FreeHandle(query);
						chat_color(0, "%s !g%s!y baneó la IP !g%s!y durante !g%d minuto%s!y. Razón: !g%s!y.", SZPREFIX, name, g_user_ban_add[id], g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", g_user_ban_reason[id]);
						chat_color(0, "%s !yMinutos: !g%d minuto%s !t(%s)!y.", SZPREFIX, g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), (g_user_ban_minutes[id] == 1) ? "" : "s");
						log_to_file("ban_system_ban_ip.txt", "<%s> baneó la IP <%s>", g_user_name[id], g_user_ban_add[id]);
						check_copy_stats(g_user_name[id], g_user_ban_reason[id], map, time, g_user_ban_expire[id], "", g_user_ban_add[id], "", g_user_ban_minutes[id], MENU_BAN_IP, unixtime);	
						reset_vars_string(id);
					}
				}
				case MENU_BAN_STEAMID:
				{
					if (!strlen(g_user_ban_reason[id]))
					{
						chat_color(id, "%s !yTenés que introducir la razón del ban.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					if (!g_user_ban_minutes[id])
					{
						chat_color(id, "%s !yTenés que introducir los minutos del ban.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					if (!g_user_ban_add[id][0])
					{
						chat_color(id, "%s !yTenès que introducir un SteamID", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					new Handle:query, time[32], unixtime, name[32], map[31];
					
					if (TrieKeyExists(g_trie_ban_stats, g_user_ban_add[id]))
					{
						chat_color(id, "%s !yEl SteamID introducido ya existe en la base de datos.", SZPREFIX);
						show_option_ban(id, g_user_page_selection[id]);
						return PLUGIN_HANDLED;
					}
					
					unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
					get_time("%d/%m/%Y - %H:%M:%S", time, 31);
					format_time(g_user_ban_expire[id], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
					get_user_name(id, name, 31);
					get_mapname(map, 31);
					
					query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, g_user_name[id], g_user_ban_reason[id], g_user_ban_add[id], unixtime, map, time, g_user_ban_expire[id], g_user_ban_minutes[id], g_user_page_selection[id]);
			
					if (!SQL_Execute(query))
						sql_query_error(query);
					else
					{
						SQL_FreeHandle(query);
						chat_color(0, "%s !g%s!y baneó el SteamID !g%s!y durante !g%d minuto%s!y. Razón: !g%s!y.", SZPREFIX, name, g_user_ban_add[id], g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", g_user_ban_reason[id]);
						log_to_file("ban_system_ban_authid.txt", "<%s> baneó el SteamID <%s>", g_user_name[id], g_user_ban_add[id]);
						check_copy_stats(g_user_name[id], g_user_ban_reason[id], map, time, g_user_ban_expire[id], "", g_user_ban_add[id], "", g_user_ban_minutes[id], MENU_BAN_STEAMID, unixtime);	
						reset_vars_string(id);
					}
				}
			}		
		}
		case 6:
		{
			if (!strlen(g_user_ban_reason[id]))
			{
				chat_color(id, "%s !yTenés que introducir la razón del ban.", SZPREFIX);
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (!g_user_ban_minutes[id])
			{
				chat_color(id, "%s !yTenés que introducir los minutos del ban.", SZPREFIX);
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (!is_user_connected(g_user_ban_selection[id]))
			{
				chat_color(id, "%s !yEl usuario seleccionado se desconectó del servidor.", SZPREFIX);
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (g_user_ban_type[id] == BAN_HWID && !is_valid_hid(g_user_hid[id]))
			{
				chat_color(id, "%s !yEl usuario seleccionado no posee HID.", SZPREFIX);
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			new Handle:query, time[32], mapname[64], unixtime, name[32], myname[32], query_result[35];
			
			switch(g_user_ban_type[id])
			{
				case BAN_IP: copy(query_result, 16, g_user_ip[g_user_ban_selection[id]]);
				case BAN_STEAMID: copy(query_result, 35, g_user_authid[g_user_ban_selection[id]]);
				case BAN_HWID: copy(query_result, 35, g_user_hid[g_user_ban_selection[id]]);
				
			}
			
			if (TrieKeyExists(g_trie_ban_stats, query_result))
			{
				chat_color(id, "%s !yYa existe un registro insertado de este tipo.", SZPREFIX);
				return PLUGIN_HANDLED;
			}
			
			unixtime = (get_systime() + (g_user_ban_minutes[id] * 60));
			get_time("%d/%m/%Y - %H:%M:%S", time, 31);
			format_time(g_user_ban_expire[g_user_ban_selection[id]], 31, "%d/%m/%Y - %H:%M:%S", unixtime);
			
			get_mapname(mapname, 63);
			get_user_name(id, myname, 31);
			get_user_name(g_user_ban_selection[id], name, 31);
			
			remove_quotes(g_user_ban_reason[id]);
			trim(g_user_ban_reason[id]);
			
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "****** BANEADO ******");
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "* Fuiste baneado del servidor");
			console_print(g_user_ban_selection[id], "* Administrador: %s", g_user_name[id]);
			console_print(g_user_ban_selection[id], "* Razón del ban: %s", g_user_ban_reason[id]);
			console_print(g_user_ban_selection[id], "* Mapa: %s", mapname);
			console_print(g_user_ban_selection[id], "* Tipo de ban: %s", BAN_TYPES[g_user_ban_type[id]]);
			console_print(g_user_ban_selection[id], "* Minutos: %d minuto%s", g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s");
			console_print(g_user_ban_selection[id], "* Tiempo calculado: %s", check_time_calculated(g_user_ban_minutes[id]));
			console_print(g_user_ban_selection[id], "* Fecha del ban: %s", time);
			console_print(g_user_ban_selection[id], "* Expira en la fecha: %s", g_user_ban_expire[g_user_ban_selection[id]]);
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "* Fuiste baneado del servidor");
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "****** BANEADO ******");
			console_print(g_user_ban_selection[id], "");
			console_print(g_user_ban_selection[id], "");
			
			query = SQL_PrepareQuery(g_sql_connection, "INSERT INTO `%s` (`ban_name`, `ban_admin_name`, `ban_reason`, `ban_user`, `ban_time`, `ban_map`, `ban_register`, `ban_expire`, `ban_type`, `ban_minutes`, `ban_page`) VALUES (^"%s^", ^"%s^", ^"%s^", ^"%s^", '%d', ^"%s^", ^"%s^", ^"%s^", ^"%s^", '%d', '%d');", SQL_TABLE, name, myname, g_user_ban_reason[id], query_result, unixtime, mapname, time, g_user_ban_expire[g_user_ban_selection[id]], BAN_TYPES[g_user_ban_type[id]], g_user_ban_minutes[id], g_user_page_selection[id]);
			
			if (!SQL_Execute(query))
				sql_query_error(query);
			else
			{
				SQL_FreeHandle(query);
				reset_vars_string(id);
			}
			
			check_copy_stats(g_user_name[id], g_user_ban_reason[id], mapname, time, g_user_ban_expire[g_user_ban_selection[id]], BAN_TYPES[g_user_ban_type[id]], query_result, g_user_name[g_user_ban_selection[id]], g_user_ban_minutes[id], g_user_page_selection[id], unixtime);
			
			server_cmd("kick #%d ^"Te banearon del servidor, mirá tu consola^"", get_user_userid(g_user_ban_selection[id]));
			chat_color(0, "%s !g%s!y baneó a !g%s!y. Razón: !g%s!y.", SZPREFIX, g_user_name[id], g_user_name[g_user_ban_selection[id]], g_user_ban_reason[id]);
			chat_color(0, "%s !yMinutos: !g%d minuto%s !t(%s)!y.", SZPREFIX, g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), (g_user_ban_minutes[id] == 1) ? "" : "s");
			log_to_file("ban_systime_ban.txt", "<%s> baneó a <%s>", g_user_name[id], g_user_name[g_user_ban_selection[id]]);
		}
			
		case 9: show_menu_ban(id);
	}
	
	return PLUGIN_HANDLED;
}

public clcmd_messagemode(id)
{
	if (!is_user_admin(id))
		return PLUGIN_HANDLED;
	
	if (g_user_ban_status[id])
		return PLUGIN_HANDLED;
	
	static args[28];
	read_args(args, 27);
	remove_quotes(args);
	trim(args);
	
	switch(g_messagemode[id])
	{
		case CALCULAR_DIAS_EN_MINUTOS:
		{
			if (!isdigit(args[0]))
			{
				chat_color(id, "%s !ySolo están permitidos números.", SZPREFIX);
				client_cmd(id, "messagemode CALCULAR_DIAS_EN_MINUTOS");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			g_user_ban_minutes_per_day_calculation[id] = str_to_num(args);
			show_option_ban(id, g_user_page_selection[id]);
		}
		case CALCULAR_HORAS_EN_MINUTOS:
		{
			if (!isdigit(args[0]))
			{
				chat_color(id, "%s !ySolo están permitidos números.", SZPREFIX);
				client_cmd(id, "messagemode CALCULAR_HORAS_EN_MINUTOS");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			g_user_ban_minutes_per_hour_calculation[id] = str_to_num(args);
			show_option_ban(id, g_user_page_selection[id]);
		}
		case INTRODUCIR_MINUTOS:
		{
			if (!isdigit(args[0]))
			{
				chat_color(id, "%s !ySolo están permitidos números.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_MINUTOS");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			g_user_ban_minutes[id] = str_to_num(args);
			show_option_ban(id, g_user_page_selection[id]);
		}
		case INTRODUCIR_RAZON:
		{
			if (strlen(args) < 4)
			{
				chat_color(id, "%s !yLa razón del ban debe tener más de 4 carácteres.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_RAZON");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (strlen(args) > REASON_MAX_LENGTH)
			{
				chat_color(id, "%s !yLa razón del ban no puede tener más de %d carácteres.", SZPREFIX, REASON_MAX_LENGTH);
				client_cmd(id, "messagemode INTRODUCIR_RAZON");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			copy(g_user_ban_reason[id], 127, args);
			show_option_ban(id, g_user_page_selection[id]);
		}
		case INTRODUCIR_IP:
		{
			if (strlen(args) < 5)
			{
				chat_color(id, "%s !yLa IP debe tener más de 5 carácteres.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_IP");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (!(contain(args, ".") != -1))
			{
				chat_color(id, "%s !yTenés que introducir una IP.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_IP");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			copy(g_user_ban_add[id], 16, args);
			show_option_ban(id, g_user_page_selection[id]);
		}
		case INTRODUCIR_STEAMID:
		{
			if (strlen(args) < 5)
			{
				chat_color(id, "%s !yEl SteamID debe tener más de 5 carácteres.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_STEAMID");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			if (!(contain(args, "STEAM_") != -1))
			{
				chat_color(id, "%s !yTenés que introducir una SteamID.", SZPREFIX);
				client_cmd(id, "messagemode INTRODUCIR_STEAMID");
				show_option_ban(id, g_user_page_selection[id]);
				return PLUGIN_HANDLED;
			}
			
			copy(g_user_ban_add[id], 16, args);
			show_option_ban(id, g_user_page_selection[id]);
		}
	}
	
	return PLUGIN_HANDLED;
} 

public clcmd_changeteam(id)
{
	if (g_user_ban_status[id])
	{
		show_menu_banned(id);
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

show_menu_banned(id)
{
	static menu[400];
	
	switch(g_user_page_selection[id])
	{
		case MENU_BAN: formatex(menu, charsmax(menu), "\yMenú de ban SQL desarrollado por \r%s^n^n\r* \yEstás baneado del servidor^n\r* \wAdministrador: \y%s^n\r* \wRazón: \y%s^n\r* \wMapa: \y%s^n\r* \wTipo de ban: \y%s^n\r* \wMinutos: \y%d minuto%s^n\r* \wTiempo calculado: \y%s^n\r* \wFecha del ban: \y%s^n\r* \wEl ban expira en la fecha: \y%s", PLUGIN_AUTHOR, g_user_ban_admin[id], g_user_ban_reason[id], g_user_ban_map[id], g_user_ban_type_name[id], g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), g_user_ban_register[id], g_user_ban_expire[id]);
		case MENU_BAN_IP: formatex(menu, charsmax(menu), "\yMenú de ban SQL desarrollado por \r%s^n^n\r* \wTu IP fue baneada^n\r* \wAdministrador: \y%s^n\r* \wRazón: \y%s^n\r* \wTu IP fue agregada en el mapa: \y%s^n\r* \wMinutos: \y%d minuto%s^n\r* \wTiempo calculado: \y%s^n\r* \wFecha del ban: \y%s^n\r* \wEl ban expira en la fecha: \y%s", PLUGIN_AUTHOR, g_user_ban_admin[id], g_user_ban_reason[id], g_user_ban_map[id], g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), g_user_ban_register[id], g_user_ban_expire[id]);
		case MENU_BAN_STEAMID: formatex(menu, charsmax(menu), "\yMenú de ban SQL desarrollado por \r%s^n^n\r* \yTu SteamID fue baneado^n\r* \wAdministrador: \y%s^n\r* \wRazón: \y%s^n\r* \wTu SteamID fue agregado en el mapa: \y%s^n\r* \wMinutos: \y%d minuto%s^n\r* \wTiempo calculado: \y%s^n\r* \wFecha del ban: \y%s^n\r* \wEl ban expira en la fecha: \y%s", PLUGIN_AUTHOR, g_user_ban_admin[id], g_user_ban_reason[id], g_user_ban_map[id], g_user_ban_minutes[id], (g_user_ban_minutes[id] == 1) ? "" : "s", check_time_calculated(g_user_ban_minutes[id]), g_user_ban_register[id], g_user_ban_expire[id]);
	}

	show_menu(id, FM_NULLENT, menu, FM_NULLENT, "Show Menu Banned"); 
}

check_time_calculated(user_minutes)
{
	new hours, minutes, days, time_calculated[40];
	minutes = user_minutes;
	
	days = 0;
	hours = 0;
	
	while (minutes >= 1440)
	{
		days++;
		minutes -= 1440;
	}
	
	while (minutes >= 60)
	{
		hours++;
		minutes -= 60;
	}
	
	format(time_calculated, charsmax(time_calculated), "%d día%s, %d hora%s, %d minuto%s", days, (days == 1) ? "" : "s", hours, (hours == 1) ? "" : "s", minutes, (minutes == 1) ? "" : "s");
	return time_calculated;
}

is_valid_hid(const buffer[]) 
{
    if(strlen(buffer) < 28
    || buffer[0] == '!'
    || equali(buffer, "no HID present, try again.")
    || equali(buffer, "")
    || containi(buffer, " ") != -1
    || buffer[8] != '-'
    || buffer[17] != '-'
    || buffer[26] != '-')
    {
        return 0; // No es valido
    }
    
    return 1; // Es valido
} 

chat_color(id, const input[], any:...)
{
	static message[191];
	vformat(message, 190, input, 3);
	
	replace_all(message, 190, "!g", "^4");
	replace_all(message, 190, "!t", "^3");
	replace_all(message, 190, "!y", "^1");
	
	message_begin((id) ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, get_user_msgid("SayText"), .player = id);
	write_byte((id) ? id : 33);
	write_string(message);
	message_end();
}