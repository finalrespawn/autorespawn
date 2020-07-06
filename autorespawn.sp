//Make sure to include the libaries needed to compile the plugin.
#include <sourcemod>
#include <cstrike> //An example of when this is used in CS_RespawnPlayer().

//Just good practise.
#pragma semicolon 1 //Forces you to use semi-colons.
#pragma newdecls required //Forces you to use the new syntax.

//Defining is like const variables but better practise.
#define AUTO_RESPAWN_TIME 0.5
#define SPAWN_KILLER_TIME 0.5

//Define the plugin information to be displayed.
public Plugin myinfo = {
	name = "Auto Respawn",
	author = "Clarkey",
	description = "Respawns players until spawn protection is enabled.",
	version = "1.0",
	url = "http://finalrespawn.com"
};

//The reason MAXPLAYERS is used here and not MaxClients is because you can only use MAXPLAYERS in global variables as it is a static number and MaxClients changes on slot size.

bool g_CanSpawn = true; //Can you spawn and not die?
bool g_IsWorldHurter[MAXPLAYERS + 1]; //Variable to determine whether it was the world that hurt the player.
bool g_IsFirstHurt[MAXPLAYERS + 1] = {true,...}; //By default all the variables are false, this is how you make them all start true.
bool g_HurtChecker[MAXPLAYERS + 1]; //Boolean to make sure no coincidences can occur.
float g_SpawnTime[MAXPLAYERS + 1]; //We save the times they spawned in, in here.

//We use the public keyword here because it is called by another plugin or process.
public void OnPluginStart()
{
	//Hook all the events, this allows you to run code when something happens.
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//New round, all we are doing here is resetting all variables.
	g_CanSpawn = true;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_IsWorldHurter[i] = false;
		g_IsFirstHurt[i] = true;
		g_HurtChecker[i] = false;
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	//What's the point of running the code if auto respawn is already disabled?
	if (!g_CanSpawn)
	{
		//Return simply stops the current function from running.
		return;
	}
	
	//The player_hurt event send information, let's retrive it using functions.
	
	//By default the event's only return User IDs. These are more unique and not Client IDs which are numbers 1-64.
	int ClientUserId = GetEventInt(event, "userid");
	int AttackerUserId = GetEventInt(event, "attacker");
	
	//Now let's retrieve the Client ID (Numbers 1-64) from the User IDs using GetClientOfUserId()
	int Client = GetClientOfUserId(ClientUserId);
	int Attacker = GetClientOfUserId(AttackerUserId);
	
	//In this language 0 = false and any other number = true.
	//So this is saying if the Client is any number but 0 (Not the world, a live player) and the Attacker IS the world then the world must have done the damage.
	if (Client && !Attacker)
	{
		g_IsWorldHurter[Client] = true;
	}
	
	//Sometimes the world won't just do 100 in 1. If it does 50 damage every 0.5s, then the 2nd damage will be at 1s and g_HurtChecker will go back to false.
	if (!g_IsFirstHurt[Client])
	{
		return;
	}
	
	//We are currently processing the first time they have been hurt, so we need to set it for false when it happens again.
	g_IsFirstHurt[Client] = false;
	
	//This is where is gets a little complicated.
	
	//First of all we calculate the time between you spawning, and this function being called (you getting hurt). GetGameTime() gets the current time, and g_SpawnTime[Client] is the time they spawned.
	//We also make sure the World is doing the damage: g_IsWorldHurter[Client].
	if ((GetGameTime() - g_SpawnTime[Client] < SPAWN_KILLER_TIME) && g_IsWorldHurter[Client])
	{
		//g_HurtChecker[Client] is by default false, so if it is true it means last death they died within 0.5s and the world didn't do damage.
		if (g_HurtChecker[Client])
		{
			//If this is true it means they have to disable the auto respawn and print this to the Clients.
			g_CanSpawn = false;
			PrintToChatAll("[\x0BRespawn\x01] Auto Respawn has been \x02disabled.");
		}
		else
		{
			//If they have been hurt within 0.5s then set this boolean up for next time they die, after all it could just be coincidence.
			g_HurtChecker[Client] = true;
		}
	}
	else
	{
		//Last death must have just been by coincidence as this time they haven't taken damage within 0.5s, reset the boolean.
		g_HurtChecker[Client] = false;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//What's the point of running the code if auto respawn is already disabled?
	if (!g_CanSpawn)
	{
		return;
	}
	
	//By default the event's only return User IDs. These are more unique and not Client IDs which are numbers 1-64.
	int ClientUserId = GetEventInt(event, "userid");
	
	//Now let's retrieve the Client ID (Numbers 1-64) from the User IDs using GetClientOfUserId()
	int Client = GetClientOfUserId(ClientUserId);
	
	//Now we need to reset this boolean. Next time they get hurt it is going to be the first time, because they just died.
	g_IsFirstHurt[Client] = true;
	
	//They just died so we need to respawn them.
	if (g_CanSpawn)
	{
		//We need to pass the User ID in to the timer because passing the Client ID can cause bugs (idk why I was just told).
		CreateTimer(AUTO_RESPAWN_TIME, Timer_Respawn, ClientUserId);
	}
}

public Action Timer_Respawn(Handle timer, any data)
{
	//We passed in the User ID so we need to get the Client ID.
	int Client = GetClientOfUserId(data);
	
	//Now let's make sure they are on a team (trying to respawn spectators can cause very strange bugs).
	int Team = GetClientTeam(Client);
	
	//Now the respawn part. If they are a Client (live player) and they are on the CT or T team then go ahead and respawn them.
	if (Client && (Team == CS_TEAM_CT || Team == CS_TEAM_T))
	{
		CS_RespawnPlayer(Client);
	}
	
	//Save the time they were spawned in for comparison.
	g_SpawnTime[Client] = GetGameTime();
}