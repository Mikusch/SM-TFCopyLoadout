#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION	"1.0.0"

#include <tf2utils>
#include <tf_econ_data>

static Handle g_SDKCallGiveNamedItem;

public Plugin myinfo = 
{
	name = "Copy Player Loadout",
	author = "Mikusch",
	description = "Allows copying a player's exact loadout.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/SM-TFCopyLoadout"
};

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
	g_SDKCallGiveNamedItem = EndPrepSDKCall();

	if (!g_SDKCallGiveNamedItem)
		SetFailState("Failed to set up SDKCall: CTFPlayer::GiveNamedItem");

	delete gameconf;

	RegAdminCmd("sm_copyloadout", ConCmd_Disguise, ADMFLAG_CHEATS, "");
}

void CopyLoadout(int source, int target)
{
	TF2_SetPlayerClass(target, TF2_GetPlayerClass(source), _, false);
	TF2_RegeneratePlayer(target);

	char model[PLATFORM_MAX_PATH];
	GetEntPropString(source, Prop_Send, "m_iszCustomModel", model, sizeof(model));

	// Copy victim's model.
	SetVariantString(model);
	AcceptEntityInput(target, "SetCustomModel");

	// Nuke items.
	int maxWeapons = GetEntPropArraySize(target, Prop_Data, "m_hMyWeapons");
	for (int i = 0; i < maxWeapons; i++)
	{
		int weapon = GetEntPropEnt(target, Prop_Data, "m_hMyWeapons", i);
		if (weapon == -1)
			continue;
		
		// Builder weapons suck, you need to set the buildable objects on them, similar to the logic in CTFPlayer::ManageBuilderWeapons.
		// To avoid more gamedata, keep the builder weapons the player generated. This unfortunately means that sappers will not be copied, but it is what it is.
		if (TF2Util_GetWeaponID(weapon) == TF_WEAPON_BUILDER)
			continue;

		RemovePlayerItem(target, weapon);
		RemoveEntity(weapon);
	}

	// Nuke wearables.
	for (int wbl = TF2Util_GetPlayerWearableCount(target) - 1; wbl >= 0; wbl--)
	{
		int wearable = TF2Util_GetPlayerWearable(target, wbl);
		if (wearable == -1)
			continue;

		TF2_RemoveWearable(target, wearable);
	}

	// Copy victim's weapons.
	for (int i = 0; i < maxWeapons; i++)
	{
		int weapon = GetEntPropEnt(source, Prop_Data, "m_hMyWeapons", i);
		if (weapon == -1)
			continue;

		int offset = FindItemOffset(weapon);
		if (offset == -1)
			continue;

		Address item = GetEntityAddress(weapon) + view_as<Address>(offset);
		if (!item)
			continue;

		char clsname[64];
		if (!GetEntityClassname(weapon, clsname, sizeof(clsname)))
			continue;

		TF2Econ_TranslateWeaponEntForClass(clsname, sizeof(clsname), TF2_GetPlayerClass(target));

		int newItem = SDKCall(g_SDKCallGiveNamedItem, target, clsname, 0, item, true);
		if (newItem == -1)
			continue;

		SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
		EquipPlayerWeapon(target, newItem);

		// Switch to victim's active weapon.
		if (weapon == GetEntPropEnt(source, Prop_Send, "m_hActiveWeapon"))
		{
			TF2Util_SetPlayerActiveWeapon(target, newItem);
		}
	}

	// Copy victim's wearables.
	for (int wbl = TF2Util_GetPlayerWearableCount(source) - 1; wbl >= 0; wbl--)
	{
		int wearable = TF2Util_GetPlayerWearable(source, wbl);
		if (wearable == -1)
			continue;

		int offset = FindItemOffset(wearable);
		if (offset == -1)
			continue;

		Address item = GetEntityAddress(wearable) + view_as<Address>(offset);
		if (!item)
			continue;

		char clsname[64];
		if (!GetEntityClassname(wearable, clsname, sizeof(clsname)))
			continue;

		TF2Econ_TranslateWeaponEntForClass(clsname, sizeof(clsname), TF2_GetPlayerClass(target));

		int newItem = SDKCall(g_SDKCallGiveNamedItem, target, clsname, 0, item, true);
		if (newItem == -1)
			continue;

		SetEntProp(newItem, Prop_Send, "m_bValidatedAttachedEntity", true);
		TF2Util_EquipPlayerWearable(target, newItem);
	}
}

int FindItemOffset(int entity)
{
	static int offset = -1;

	if (offset != -1)
		return offset;
	
	char clsname[32];
	if (!GetEntityNetClass(entity, clsname, sizeof(clsname)))
		return -1;

	offset = FindSendPropInfo(clsname, "m_Item");
	return offset;
}

static Action ConCmd_Disguise(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_copyloadout <#userid|name> [#userid|name]");
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
		char targetName[MAX_TARGET_LENGTH];
		int targetList[MAXPLAYERS], targetCount;
		bool targetIsML;

		if ((targetCount = ProcessTargetString(arg, client, targetList, sizeof(targetList), COMMAND_FILTER_ALIVE, targetName, sizeof(targetName), targetIsML)) <= 0)
		{
			ReplyToTargetError(client, targetCount);
			return Plugin_Handled;
		}

		for (int i = 0; i < targetCount; i++)
		{
			if (targetList[i] == source)
				continue;

			CopyLoadout(source, targetList[i]);
		}

		if (targetIsML)
		{
			ShowActivity2(client, "[SM] ", "Copied loadout of %s onto %t.", sourceName, targetName);
		}
		else
		{
			ShowActivity2(client, "[SM] ", "Copied loadout of %s onto %s.", sourceName, targetName);
		}
	}
	else
	{
		CopyLoadout(source, client);

		if (sourceIsML)
		{
			ShowActivity2(client, "[SM] ", "Copied loadout of %t.", sourceName);
		}
		else
		{
			ShowActivity2(client, "[SM] ", "Copied loadout of %s.", sourceName);
		}
	}

	return Plugin_Handled;
}