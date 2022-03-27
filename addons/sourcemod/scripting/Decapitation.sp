#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>

#pragma tabsize 0

ConVar g_cvDecapitationHits;

int g_iHits[MAXPLAYERS+1] = { 0, ... };

bool g_DecapitableModel[MAXPLAYERS+1] = { false, ... };
bool g_bDecapitated[MAXPLAYERS+1] = { false, ... };

StringMap g_smModels = null;
ArrayList g_aModels = null;

public Plugin myinfo =
{
	name = "[ZR] Decapitation",
	author = "ire.",
	description = "Remove head or legs from a player model",
	version = "1.0.0"
};

public void OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDead);
	HookEvent("round_start", Event_RoundStart);
	
	g_cvDecapitationHits = CreateConVar("sm_decapitation_hits", "15", "Hits to the head required for decapitation");
	
	AutoExecConfig(true);
}

public void OnMapStart()
{
	if (g_smModels != null)
	{
		g_smModels.Clear();
		delete g_smModels;
		g_smModels = null;
	}

	if (g_aModels != null)
	{
		g_aModels.Clear();
		delete g_aModels;
		g_aModels = null;
	}

	g_smModels = new StringMap();
	g_aModels = new ArrayList(256);
	LoadModels();
}

public void OnClientDisconnect(int client)
{
	ResetVariables(client);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	char ModelPath[256], DecapitatedModel[256];
	
	int g_iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int g_iVictim = GetClientOfUserId(event.GetInt("userid"));
	int g_iHitGroup = event.GetInt("hitgroup");
	
	if(!IsValidClient(g_iAttacker) || !IsValidClient(g_iVictim) || g_iAttacker == g_iVictim)
	{
		return;
	}
	
	if(g_bDecapitated[g_iVictim] || !g_DecapitableModel[g_iVictim])
	{
		return;
	}
	
	if(g_iHitGroup == 1)
	{
		g_iHits[g_iVictim]++;
	}
	
	if(g_iHits[g_iVictim] >= g_cvDecapitationHits.IntValue)
	{
		GetClientModel(g_iVictim, ModelPath, sizeof(ModelPath));
		
		if(g_smModels.GetString(ModelPath, DecapitatedModel, sizeof(DecapitatedModel)))
		{
			SetEntityModel(g_iVictim, DecapitatedModel);
			g_bDecapitated[g_iVictim] = true;
		}
	}
}

public void Event_PlayerDead(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsValidClient(client))
	{
		ResetVariables(client);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			ResetVariables(i);
		}
	}
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	CreateTimer(0.1, CheckPlayerModel, client);
}

public Action CheckPlayerModel(Handle timer, int client)
{
	if(!IsValidClient(client))
	{
		return Plugin_Stop;
	}
	
	char ModelPath[256];
	GetClientModel(client, ModelPath, sizeof(ModelPath));
	
	if(g_aModels.FindString(ModelPath) != -1)
	{
		g_DecapitableModel[client] = true;
	}
	
	return Plugin_Continue;
}

void LoadModels()
{
	char FilePath[256], DefaultModel[256], DecapitatedModel[256];
	
	BuildPath(Path_SM, FilePath, sizeof(FilePath), "configs/decapitation.cfg");
	if(!FileExists(FilePath))
	{
		SetFailState("[Decapitation] Missing cfg file %s!", FilePath);
		return;
	}
	
	KeyValues Kv = new KeyValues("Models");
	Kv.ImportFromFile(FilePath);
	Kv.GotoFirstSubKey();
	do
	{
		Kv.GetString("DefaultModel", DefaultModel, sizeof(DefaultModel));
		Kv.GetString("DecapitatedModel", DecapitatedModel, sizeof(DecapitatedModel));
		PrecacheModel(DecapitatedModel);
		g_smModels.SetString(DefaultModel, DecapitatedModel);
		g_aModels.PushString(DefaultModel);
	}
	while Kv.GotoNextKey();
	
	delete Kv;
}

void ResetVariables(int client)
{
	g_iHits[client] = 0;
	g_DecapitableModel[client] = false;
	g_bDecapitated[client] = false;
}

bool IsValidClient(int client)
{
	return(0 < client <= MaxClients && IsClientInGame(client));
}
