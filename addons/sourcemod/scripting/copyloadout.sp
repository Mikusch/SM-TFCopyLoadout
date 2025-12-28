#pragma semicolon 1
#pragma newdecls required

#include <tf2utils>
#include <tf_econ_data>

static Handle g_hSDKCallGiveNamedItem;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	GameData gameconf = new GameData("copyloadout");
	if (!gameconf)
		SetFailState("Failed to load copyloadout gamedata");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameconf, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKCallGiveNamedItem = EndPrepSDKCall();

	if (!g_hSDKCallGiveNamedItem)
		SetFailState("Failed to set up SDKCall: CTFPlayer::GiveNamedItem");

	delete gameconf;

	RegAdminCmd("sm_disguise", ConCmd_Disguise, ADMFLAG_CHEATS, "");
}

void StealIdentity(int victim, int stealer)
{
	TF2_SetPlayerClass(stealer, TF2_GetPlayerClass(victim), _, false);
	TF2_RegeneratePlayer(stealer);

	char szCustomModel[PLATFORM_MAX_PATH];
	GetEntPropString(victim, Prop_Send, "m_iszCustomModel", szCustomModel, sizeof(szCustomModel));

	// Copy victim's model.
	SetVariantString(szCustomModel);
	AcceptEntityInput(stealer, "SetCustomModel");

	// Nuke items.
	int nMaxWeapons = GetEntPropArraySize(stealer, Prop_Data, "m_hMyWeapons");
	for (int i = 0; i < nMaxWeapons; i++)
	{
		int weapon = GetEntPropEnt(stealer, Prop_Data, "m_hMyWeapons", i);
		if (weapon == -1)
			continue;
		
		// Initializing builder weapons is a pain, so just let the game handle it by regenerating the player
		if (TF2Util_GetWeaponID(weapon) == TF_WEAPON_BUILDER)
			continue;

		RemovePlayerItem(stealer, weapon);
		RemoveEntity(weapon);
	}

	// Nuke wearables.
	for (int wbl = TF2Util_GetPlayerWearableCount(stealer) - 1; wbl >= 0; wbl--)
	{
		int wearable = TF2Util_GetPlayerWearable(stealer, wbl);
		if (wearable == -1)
			continue;

		TF2_RemoveWearable(stealer, wearable);
	}

	// Copy victim's weapons.
	for (int i = 0; i < GetEntPropArraySize(victim, Prop_Data, "m_hMyWeapons"); i++)
	{
		int weapon = GetEntPropEnt(victim, Prop_Data, "m_hMyWeapons", i);
		if (weapon == -1)
			continue;

		int iItemOffset = FindItemOffset(weapon);
		if (iItemOffset == -1)
			continue;
			
		Address pItem = GetEntityAddress(weapon) + view_as<Address>(iItemOffset);
		if (!pItem)
			continue;
			
		char szClassname[64];
		if (!GetEntityClassname(weapon, szClassname, sizeof(szClassname)))
			continue;
			
		TF2Econ_TranslateWeaponEntForClass(szClassname, sizeof(szClassname), TF2_GetPlayerClass(stealer));

		int newItem = SDKCall(g_hSDKCallGiveNamedItem, stealer, szClassname, 0, pItem, true);
		if (newItem == -1)
			continue;
			
		SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
		EquipPlayerWeapon(stealer, newItem);
			
		// Switch to our victim's active weapon.
		if (weapon == GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon"))
		{
			TF2Util_SetPlayerActiveWeapon(stealer, newItem);
		}
	}
		
	// Copy victim's wearables.
	for (int wbl = TF2Util_GetPlayerWearableCount(victim) - 1; wbl >= 0; wbl--)
	{
		int wearable = TF2Util_GetPlayerWearable(victim, wbl);
		if (wearable == -1)
			continue;
			
		int iItemOffset = FindItemOffset(wearable);
		if (iItemOffset == -1)
			continue;
			
		Address pItem = GetEntityAddress(wearable) + view_as<Address>(iItemOffset);
		if (!pItem)
			continue;
			
		char szClassname[64];
		if (!GetEntityClassname(wearable, szClassname, sizeof(szClassname)))
			continue;

		TF2Econ_TranslateWeaponEntForClass(szClassname, sizeof(szClassname), TF2_GetPlayerClass(stealer));
			
		int newItem = SDKCall(g_hSDKCallGiveNamedItem, stealer, szClassname, 0, pItem, true);
		if (newItem == -1)
			continue;
			
		SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
		TF2Util_EquipPlayerWearable(stealer, newItem);
	}
}

int FindItemOffset(int entity)
{
	char szNetClass[32];
	if (!GetEntityNetClass(entity, szNetClass, sizeof(szNetClass)))
		return -1;
	
	return FindSendPropInfo(szNetClass, "m_Item");
}

static Action ConCmd_Disguise(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_disguise <#userid|name> [#userid|name]");
		return Plugin_Handled;
	}

	char arg[MAX_TARGET_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));

	char sourceName[MAX_TARGET_LENGTH];
	int sourceList[MAXPLAYERS], sourceCount;
	bool sourceIsML;

	if ((sourceCount = ProcessTargetString(arg, client, sourceList, sizeof(sourceList), COMMAND_FILTER_NO_MULTI, sourceName, sizeof(sourceName), sourceIsML)) <= 0)
	{
		ReplyToTargetError(client, sourceCount);
		return Plugin_Handled;
	}

	int source = sourceList[0];

	if (GetCmdArg(2, arg, sizeof(arg)))
	{
		char recipientName[MAX_TARGET_LENGTH];
		int recipientList[MAXPLAYERS], recipientCount;
		bool recipientIsML;

		if ((recipientCount = ProcessTargetString(arg, client, recipientList, sizeof(recipientList), COMMAND_TARGET_NONE, recipientName, sizeof(recipientName), recipientIsML)) <= 0)
		{
			ReplyToTargetError(client, recipientCount);
			return Plugin_Handled;
		}

		for (int i = 0; i < recipientCount; i++)
		{
			if (recipientList[i] == source)
				continue;

			StealIdentity(source, recipientList[i]);
		}

		if (recipientIsML)
		{
			ShowActivity2(client, "[SM] ", "Copied %s's loadout onto %t.", sourceName, recipientName);
		}
		else
		{
			ShowActivity2(client, "[SM] ", "Copied %s's loadout onto %s.", sourceName, recipientName);
		}
	}
	else
	{
		StealIdentity(source, client);

		if (sourceIsML)
		{
			ShowActivity2(client, "[SM] ", "Copied %t's loadout.", sourceName);
		}
		else
		{
			ShowActivity2(client, "[SM] ", "Copied %s's loadout.", sourceName);
		}
	}

	return Plugin_Handled;
}