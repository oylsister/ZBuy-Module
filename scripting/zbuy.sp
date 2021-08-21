/*	
	zbuy.sp Copyright (C) 2021 Oylsister
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/


#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>
#include <zombiereloaded>
#include <zbuy>

#pragma newdecls required

enum stuct Weapons
{
	char sWeaponName[64];
	char sWeaponentity[64];
	Type_Weapon wType;
	int iSlot;
	bool bAllow;
	int iMaxPurchase;
	int iPrice;
	bool bMulti;
	float fMulti;
	char sWeaponCommand[128];
}

enum Type_Weapon
{
	TYPE_INVALID = -1,
	TYPE_PISTOL,
	TYPE_SHOTGUN,
	TYPE_SMG,
	TYPE_RIFLE,
	TYPE_SNIPER,
	TYPE_MACHINEGUN,
	TYPE_KEVLAR
}

Handle g_hZbuyPurchaseCount[MAXPLAYERS+1];

Weapons g_Weapons[64];

ConVar g_Cvar_Enable, 
	g_Cvar_Hook_BuyZone, 
	g_Cvar_Prefix;

bool g_bEnable;
bool g_bHookBuyZone;

int g_iWeapons;

public Plugin myinfo = 
{
	name = "ZBuy Module", 
	author = "Oylsister", 
	description = "Custom weapon buy menu for Zombie:Reloaded", 
	version = "1.0", 
	url = "https://github.com/oylsister/ZBuy-Module"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zbuy", ZBuyMenuCommand);
	
	g_Cvar_Enable = CreateConVar("sm_zbuy_enable", "1.0", "Enable ZBuy Module plugins", _, true, 0.0, true, 1.0);
	g_Cvar_Hook_BuyZone = CreateConVar("sm_zbuy_hook_buyzone", "1.0", "Hook on player purchase weapon with 'b' key on buyzone or not", _, true, 0.0, true, 1.0);
	g_Cvar_Prefix = CreateConVar("sm_zbuy_prefix", "{green}[Zbuy]{default}", "Prefix for Zbuy Module");
	
	HookConVarChange(g_Cvar_Enable, OnConVarChage);
	HookConVarChange(g_Cvar_Hook_BuyZone, OnConVarChange);
	HookConVarChange(g_Cvar_Hook_BuyZone, OnConVarChange);
	
	HookEvent("player_spawn", OnPlayerSpawn);
	
	AutoExecConfig(true, "zbuy_module", "sourcemod/zombiereloaded");
	
	//LoadTranslations("zbuy.pharese");
}

public void OnConfigsExecuted()
{
	LoadConfig();
	OnCreateZBuyCommand();
	GetConVar();
}

public void OnClientPutInServer()
{
	if (g_hZbuyPurchaseCount[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hZbuyPurchaseCount[client]);
	}
	g_hZbuyPurchaseCount[client] = CreateTrie();
}

public void OnClientDisconnect()
{
	if (g_hZbuyPurchaseCount[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hZbuyPurchaseCount[client]);
	}
	g_hZbuyPurchaseCount[client] = INVALID_HANDLE;
}

public void OnConVarChage(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	if(cvar == g_Cvar_Enable)
		g_bEnable = GetConVarBool(g_Cvar_Enable);
		
	else if(cvar == g_Cvar_Hook_BuyZone)
		g_bHookBuyZone = GetConVarBool(g_Cvar_Hook_BuyZone);
		
	else if(cvar == g_Cvar_Prefix)
		GetConVarString(g_Cvar_Prefix, sZbuyPrefix, sizeof(sZbuyPrefix));
}

void GetConVar()
{
	g_bEnable = GetConVarBool(g_Cvar_Enable);
	g_bHookBuyZone = GetConVarBool(g_Cvar_Hook_BuyZone);
	GetConVarString(g_Cvar_Prefix, sZbuyPrefix, sizeof(sZbuyPrefix));
}

void LoadConfig()
{
	g_iWeapons = 0;
	char sTemp[16];
	
	char sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, sizeof(sConfig), "configs/zr/weapons.txt");
	KeyValues kv = CreateKeyValues("weapons");
	
	FileToKeyValues(kv, sConfig);
	
	if(KvGotoFirstSubKey(kv))
	{
		do
		{
			KvGetSectionName(kv, g_Weapons[g_iWeapons].sWeaponName, 64);
			KvGetString(kv, "weaponentity", g_Weapons[g_iWeapons].sWeaponentity, 64);
			g_Weapons[g_iWeapons].iSlot = KvGetNum(kv, "weaponslot", -1);
			KvGetString(kv, "restrictdefault", sTemp, sizeof(sTemp));
			
			if(StrEqual(sTemp, "yes", false))
				g_iWeapons[g_iWeapons].bAllow = false;
			
			else if(StrEqual(sTemp, "no", false))
				g_iWeapons[g_iWeapons].bAllow = true;
				
			else
				g_iWeapons[g_iWeapons].bAllow = true;
				
			g_Weapons[g_iWeapons].iPrice = KvGetNum(kv, "zmarketprice", -1);
			g_Weapons[g_iWeapons].iMaxPurchase = KvGetNum(kv, "zmarketpurchasemax", 0);
			KvGetString(kv, "zmarketcommand", g_Weapons[g_iWeapons].sWeaponCommand, 128);
			
			KvGetString(kv, "multipriceenable", sTemp, sizeof(sTemp));
			
			if(StrEqual(sTemp, "yes", false))
				g_iWeapons[g_iWeapons].bMulti = true;
			
			else if(StrEqual(sTemp, "no", false))
				g_iWeapons[g_iWeapons].bMulti = false;
				
			else
				g_iWeapons[g_iWeapons].bMulti = false;
				
			if(g_iWeapons[g_iWeapons].bMulti)
				g_iWeapons[g_iWeapons].fMulti = KvGetFloat(kv, "multiprice", -1);
				
			else
				g_iWeapons[g_iWeapons].fMulti = 1.0;
		}
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreateTimer(0.1, ResetZBuyPurchaseCountTimer, client);
}

public Action ResetZBuyPurchaseCountTimer(Handle timer, any client)
{
	if(!IsClientInGame(client))
	{
		return;
	}
	ZBuyResetPurchaseCount(client);
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if(g_bEnable)
	{
		if(g_bHookBuyZone)
		{
			if(IsWeaponInConfigFile(weapon))
			{
				ZBuyEquipWeapon(client, weapon);
				return Plugin_Handled;
			}
			else
			{
				return Plugin_Continue;
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

public void OnCreateZBuyCommand()
{
	for (int i = 0; i < g_iWeapons; i++)
	{
		if (FindCharInString(g_Weapons[i].sWeaponCommand, ',') != -1)
		{
			int idx;
			int lastidx;
			while ((idx = FindCharInString(g_Weapons[i].sWeaponCommand[lastidx], ',')) != -1)
			{
				char out[16];
				char fmt[8];
				Format(fmt, sizeof(fmt), "%%.%ds", idx);
				Format(out, sizeof(out), fmt, g_Weapons[i].sWeaponCommand[lastidx]);
				RegConsoleCmd(out, ZBuyCommand, g_Weapons[i].sWeaponName);
				lastidx += ++idx;

				if (FindCharInString(g_Weapons[i].sWeaponCommand[lastidx], ',') == -1 && g_Weapons[i].sWeaponCommand[lastidx+1] != '\0')
					RegConsoleCmd(g_Weapons[i].sWeaponCommand[lastidx], ZBuyCommand, g_Weapons[i].sWeaponName);
			}
		}
		else 
			RegConsoleCmd(g_Weapons[i].sWeaponCommand, ZBuyCommand, g_Weapons[i].sWeaponName); 
	}
}

public Action ZBuyCommand(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "%s You must be alive to purchase the weapons!", sZbuyPrefix);
		return Plugin_Handled;
	}
	
	if(ZR_IsClientZombie(client))
	{
		CReplyToCommand(client, "%s This feature is only for human!", sZbuyPrefix);
		return Plugin_Handled;
	}
	
	char sCommand[128];
	
	GetCmdArg(0, sCommand, sizeof(sCommand));
	
	for (int i = 0; i < g_iWeapons; i++)
	{
		if (FindCharInString(g_Weapons[i].sWeaponCommand, ',') != -1)
		{
			int idx;
			int lastidx;
			while ((idx = FindCharInString(g_Weapons[g_iWeapons].sWeaponCommand[lastidx], ',')) != -1)
			{
				if(!strncmp(sCommand, g_Weapons[g_iWeapons].sWeaponCommand[lastidx], idx))
				{
					ZBuyEquipWeapon(client, g_Weapons[g_iWeapons].sWeaponentity);
					return Plugin_Handled;
				}
				
				lastidx += ++idx;

				if (FindCharInString(g_Weapons[g_iWeapons].sWeaponCommand[lastidx], ',') == -1 && g_Weapons[g_iWeapons].sWeaponCommand[lastidx+1] != '\0')
				{
					if(!strncmp(sCommand, g_Weapons[g_iWeapons].sWeaponCommand[lastidx], idx))
					{
						ZBuyEquipWeapon(client, g_Weapons[g_iWeapons].sWeaponentity);
						return Plugin_Handled;
					}
				}
			}
		}
		else 
		{
			if(StrEqual(sCommand, g_Weapons[g_iWeapons].sWeaponCommand, false))
			{
				ZBuyEquipWeapon(client, g_Weapons[g_iWeapons].sWeaponentity);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Handled;
}

public void ZBuyEquipWeapon(int client, const char[] weapon)
{
	int iCash = GetEntProp(client, Prop_Send, "m_iAccount");
	
	for (int i = 0; i < g_iWeapons; i++)
	{
		if(StrEqual(weapon, g_Weapons[i].sWeaponentity, false)
		{
			if(!g_Weapons[i].bAllow)
			{
				CPrintToChat(client, "%s \x04\"%s\" \x01is currently restricted", sZbuyPrefix, g_Weapons[i].sWeaponName);
				return;
			}
		
			// No Multi Price
			if(!g_Weapons[i].bMulti)
			{
				// No limit
				if(g_Weapons[i].iMaxPurchase == 0)
				{
					if(iCash > g_Weapons[i].iPrice)
					{
						SetEntProp(client, Prop_Send, "m_iAccount", iCash - g_Weapons[i].iPrice);
						GivePlayerItem(client, g_Weapons[i].weapon);
						CPrintToChat(client, "%s You have bought \x04\"%s\" \x01type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].sWeaponCommand);
						return;
					}
					else
					{
						CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
						return;
					}
				}
			
				// Have limit
				else if(g_Weapons[i].iMaxPurchase > 0)
				{
					int iBuyCount = GetPurchaseCount(client, g_Weapons[i].sWeaponName)
					int iLeft = g_Weapons[i].iMaxPurchase - iBuyCount;
					if(iLeft > 0)
					{
						if(iCash > g_Weapons[i].iPrice)
						{
							SetEntProp(client, Prop_Send, "m_iAccount", iCash - g_Weapons[i].iPrice);
							SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
							GivePlayerItem(client, g_Weapons[i].sWeaponentity);
							CPrintToChat(client, "%s You have bought \x04\"%s\" \x01you can re-purchase this item \x05%d \x01times. type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, iBuyCount, g_Weapons[i].sWeaponCommand);
							return;
						}
						else
						{
							CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
							return;
						}
					}
					else
					{
						CPrintToChat(client, "%s You're already reach maximum to purchase \x04\"%s\" \x01in this round.", sZbuyPrefix, g_Weapons[i].sWeaponName);
						return;
					}
				}
			
				// Not allow to purchase, but allow to pick up ("zmarketpurchasemax" = -1")
				else
				{
					CPrintToChat(client, "%s You cannot purchase \x04\"%s\"\x01, but you're allow to use it or pick it up", sZbuyPrefix, g_Weapons[i].sWeaponName);
					return;
				}
			}
		
			else if(g_Weapons[i].bMulti)
			{
				int iBuyCount = GetPurchaseCount(client, g_Weapons[i].sWeaponName)
				// Not buy anything yet
				if(iBuyCount == 0)
				{
					// No limit
					if(g_Weapons[i].iMaxPurchase == 0)
					{
						if(iCash > g_Weapons[i].iPrice)
						{
							SetEntProp(client, Prop_Send, "m_iAccount", iCash - g_Weapons[i].iPrice);
							SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
							GivePlayerItem(client, g_Weapons[i].sWeaponentity);
							CPrintToChat(client, "%s You have bought \x04\"%s\", \x01Next time it will cost \x05x%f \x01to purchase, type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].fMulti, g_Weapons[i].sWeaponCommand);
							return;
						}
						else
						{
							CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
							return;
						}
					}
					
					else if(g_Weapons[i].iMaxPurchase > 0)
					{
						int iLeft = g_Weapons[i].iMaxPurchase - iBuyCount;
						if(iLeft > 0)
						{
							if(iCash > g_Weapons[i].iPrice)
							{
								SetEntProp(client, Prop_Send, "m_iAccount", iCash - g_Weapons[i].iPrice);
								SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
								GivePlayerItem(client, g_Weapons[i].sWeaponentity);
								CPrintToChat(client, "%s You have bought \x04\"%s\", \x01you can re-purchase this item \x05%d \x01times. type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, iBuyCount, g_Weapons[i].sWeaponCommand);
								return;
							}
							else
							{
								CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
								return;
							}
						}
						else
						{
							CPrintToChat(client, "%s You're already reach maximum to purchase \x04\"%s\" \x01in this round.", sZbuyPrefix, g_Weapons[i].sWeaponName);
							return;
						}
					}
					// Not allow to purchase, but allow to pick up ("zmarketpurchasemax" = -1")
					else
					{
						CPrintToChat(client, "%s You cannot purchase \x04\"%s\"\x01, but you're allow to use it or pick it up", sZbuyPrefix, g_Weapons[i].sWeaponName);
						return;
					}
				}
				// Already bought one
				else
				{
					int iMultiPrice = RoundToNearest(g_Weapons[i].iPrice * g_Weapons[i].fMulti);
					if(g_Weapons[i].iMaxPurchase == 0)
					{
						if(iCash > iMultiPrice)
						{
							SetEntProp(client, Prop_Send, "m_iAccount", iCash - iMultiPrice);
							SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
							GivePlayerItem(client, g_Weapons[i].sWeaponentity);
							CPrintToChat(client, "%s You have bought \x04\"%s\", \x01This time it has cost \x05x%f \x04(%d$)\x01to purchase, type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].fMulti, iMultiPrice, g_Weapons[i].sWeaponCommand);
							return;
						}
						else
						{
							CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, iMultiPrice);
							return;
						}
					}
					else if(g_Weapons[i].iMaxPurchase > 0)
					{
						int iLeft = g_Weapons[i].iMaxPurchase - iBuyCount;
						if(iLeft > 0)
						{
							if(iCash > iMultiPrice)
							{
								SetEntProp(client, Prop_Send, "m_iAccount", iCash - iMultiPrice);
								SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
								GivePlayerItem(client, g_Weapons[i].sWeaponentity);
								CPrintToChat(client, "%s You have bought \x04\"%s\", \x01you can re-purchase this item \x05%d \x01times. type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, iBuyCount, g_Weapons[i].sWeaponCommand);
								return;
							}
							else
							{
								CPrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, iMultiPrice);
								return;
							}
						}
						else
						{
							CPrintToChat(client, "%s You're already reach maximum to purchase \x04\"%s\" \x01in this round.", sZbuyPrefix, g_Weapons[i].sWeaponName);
							return;
						}
					}
					// Not allow to purchase, but allow to pick up ("zmarketpurchasemax" = -1")
					else
					{
						CPrintToChat(client, "%s You cannot purchase \x04\"%s\"\x01, but you're allow to use it or pick it up", sZbuyPrefix, g_Weapons[i].sWeaponName);
						return;
					}
				}
			}
		}
	}
}

void SetPurchaseCount(int client, const char[] weapon, int value, bool add = false)
{
	int current;
	
	if (add)
		current = GetPurchaseCount(client, weapon);
		
	SetTrieValue(g_hZbuyPurchaseCount[client], weapon, current + value);
}

int GetPurchaseCount(int client, const char[] weapon)
{
	int value;
	GetTrieValue(g_hZbuyPurchaseCount[client], weapon, value);
	return value;
}


void ZBuyResetPurchaseCount(int client)
{
	if (g_hZBuPurchaseCount[client] != INVALID_HANDLE)
	{
		ClearTrie(g_hZbuyPurchaseCount[client]);
	}
}

stock bool IsWeaponInConfigFile(const char[] weapon)
{
	int iFound = 0;
	for (int i = 0; i < g_iWeapons; i++)
	{
		char sTemp[64];
		Format(sTemp, sizeof(sTemp), "%s", g_Weapons[i].sWeaponentity)
		if(StrEqual(weapon, sTemp, false))
		{
			iFound++; 
			return true;
		}
	}
	
	if(iFound == 0)
		return false;
}
