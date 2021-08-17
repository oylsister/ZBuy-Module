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
	TYPE_MACHINEGUN
}

Handle g_hZbuyPurchaseCount[MAXPLAYERS+1];

Weapons g_Weapons[64];

int g_iWeapons;

public Plugin myinfo = 
{
	name = "ZBuy Module", 
	author = "Oylsister", 
	description = "Custom weapon buy menu for Zombie:Reloaded", 
	version = "1.0", 
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_zbuy", ZBuyMenuCommand);
	LoadTranslations("zbuy.pharese");
}

public void OnConfigsExecuted()
{
	LoadConfig();
	OnCreateZBuyCommand();
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

void LoadConfig()
{
	g_iWeapons = 0;
	char sTemp[16];
	
	char sConfig[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfig, sizeof(sConfig), "configs/zr/weapons.txt");
	KeyValues kv = CreateKeyValues("zbuy");
	
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
		if(!g_Weapons[i].bAllow)
		{
			PrintToChat(client, "%s \x04\"%s\" \x01is currently restricted", sZbuyPrefix, g_Weapons[i].sWeaponName);
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
					PrintToChat(client, "%s You have bought \x04\"%s\" \x01type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].sWeaponCommand);
					return;
				}
				else
				{
					PrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
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
						GivePlayerItem(client, g_Weapons[i].weapon);
						PrintToChat(client, "%s You have bought \x04\"%s\" \x01you can re-purchase this item \x05%d \x01times. type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, iBuyCount, g_Weapons[i].sWeaponCommand);
						return;
					}
					else
					{
						PrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
						return;
					}
				}
				else
				{
					PrintToChat(client, "%s You're already reach maximum to purchase \x04\"%s\" \x01in this round.", sZbuyPrefix, g_Weapons[i].sWeaponName);
					return;
				}
			}
			
			// Not allow to purchase, but allow to pick up ("zmarketpurchasemax" = -1")
			else
			{
				PrintToChat(client, "%s You cannot purchase \x04\"%s\"\x01, but you're allow to use it or pick it up", sZbuyPrefix, g_Weapons[i].sWeaponName);
				return;
			}
		}
		
		else if(g_Weapons[i].bMulti)
		{
			int iBuyCount = GetPurchaseCount(client, g_Weapons[i].sWeaponName)
			if(iBuyCount == 0)
			{
				if(iCash > g_Weapons[i].iPrice)
				{
					SetEntProp(client, Prop_Send, "m_iAccount", iCash - g_Weapons[i].iPrice);
					SetPurchaseCount(client, g_Weapons[i].sWeaponName, 1, true);
					GivePlayerItem(client, g_Weapons[i].weapon);
					PrintToChat(client, "%s You have bought \x04\"%s\" \x01Next time it will cost \x05x%f \x01to purchase, type command \x05\"%s\" \x01on chat to rebuy again", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].fMulti, g_Weapons[i].sWeaponCommand);
					return;
				}
				else
				{
					PrintToChat(client, "%s You don't have enough money to purchase \x04\"%s\" \x01right now. (Price:\x05%d\x01)", sZbuyPrefix, g_Weapons[i].sWeaponName, g_Weapons[i].iPrice);
					return;
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


void ZMarketResetPurchaseCount(int client)
{
	if (g_hZBuPurchaseCount[client] != INVALID_HANDLE)
	{
		ClearTrie(g_hZbuyPurchaseCount[client]);
	}
}

