/**************************************************************
--------------------------------------------------------------
 NEOTOKYO° Deathmatch

 Plugin licensed under the GPLv3
 
 Coded by Agiel.
--------------------------------------------------------------

Changelog

	0.0.1
		* Extended pre-game timer for rudimentary deathmatch
	0.1.0
		* Added cvars, spawn protection and hooked up team score
**************************************************************/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION	"0.1.0"

public Plugin:myinfo =
{
    name = "NEOTOKYO° Deathmatch",
    author = "Agiel",
    description = "Neotokyo team deathmatch",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:convar_nt_dm_version = INVALID_HANDLE;
new Handle:convar_nt_dm_enabled = INVALID_HANDLE;
new Handle:convar_nt_dm_timelimit = INVALID_HANDLE;
new Handle:convar_nt_dm_spawnprotect = INVALID_HANDLE;

new bool:g_DMStarted = false;

new clientProtected[MAXPLAYERS+1];
new clientHP[MAXPLAYERS+1];

public OnPluginStart()
{
	convar_nt_dm_version = CreateConVar("sm_nt_dm_version", PLUGIN_VERSION, "NEOTOKYO° Deathmatch.", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	convar_nt_dm_enabled = CreateConVar("sm_nt_dm_enabled", "1", "Enables or Disables deathmatch.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	convar_nt_dm_timelimit = CreateConVar("sm_nt_dm_timelimit", "20", "Sets deathmatch timilimit.", FCVAR_PLUGIN, true, 0.0, true, 60.0);
	convar_nt_dm_spawnprotect = CreateConVar("sm_nt_dm_spawnprotect", "5.0", "Length of time to protect spawned players", FCVAR_PLUGIN, true, 0.0, true, 30.0);
	AutoExecConfig(true);

	HookConVarChange(convar_nt_dm_timelimit, OnTimeLimitChanged);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_death", OnPlayerDeath);
}

public OnConfigsExecuted()
{
	g_DMStarted = false;
	if (GetConVarBool(convar_nt_dm_enabled))
	{
		StartDeathmatch();
		g_DMStarted = true;
	}
}

public StartDeathmatch()
{
	new timeLimit = GetConVarInt(convar_nt_dm_timelimit);
	new Handle:hTimeLimit = FindConVar("mp_timelimit");

	//GameRules_SetProp("m_iGameState", 1);
	SetConVarInt(hTimeLimit, timeLimit);
	GameRules_SetPropFloat("m_fRoundTimeLeft", timeLimit * 60.0);
}

public OnTimeLimitChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (g_DMStarted)
	{
		new timeLimit = GetConVarInt(convar_nt_dm_timelimit);
		new Handle:hTimeLimit = FindConVar("mp_timelimit");

		SetConVarInt(hTimeLimit, timeLimit);
		GetMapTimeLeft(timeLimit);
		GameRules_SetPropFloat("m_fRoundTimeLeft", timeLimit * 1.0);
	}
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_DMStarted)
	{
		new victim = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		new victimTeam = GetClientTeam(victim);
		new attackerTeam = GetClientTeam(attacker);

		new score = 1;
		if (attackerTeam == victimTeam)
			score = -1;

		SetTeamScore(attackerTeam, GetTeamScore(attackerTeam) + score);
	}
}

public OnPlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	if (g_DMStarted)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (GetClientTeam(client) > 1)
		{
			CreateTimer(0.1, timer_GetHealth, client);
			
			//Enable Protection on the client
			clientProtected[client] = true;

			CreateTimer(GetConVarFloat(convar_nt_dm_spawnprotect), timer_PlayerProtect, client);
		}
	}
}

//Get the player's health after they spawn
public Action:timer_GetHealth(Handle:timer, any:client)
{
	if(IsClientConnected(client) && IsClientInGame(client))
	{
		clientHP[client] = GetClientHealth(client);
	}
}

//Player protection expires
public Action:timer_PlayerProtect(Handle:timer, any:client)
{
	//Disable protection on the Client
	clientProtected[client] = false;
	
	if(IsClientConnected(client) && IsClientInGame(client))
	{
		PrintToChat(client, "[nt-dm] Your spawn protection is now disabled");
	}
}

// Restore players health if they take damage while protected
public OnPlayerHurt(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (clientProtected[client])
	{
		SetEntData(client, FindDataMapOffs(client, "m_iMaxHealth"), clientHP[client], 4, true);
		SetEntData(client, FindDataMapOffs(client, "m_iHealth"), clientHP[client], 4, true);
	}
}