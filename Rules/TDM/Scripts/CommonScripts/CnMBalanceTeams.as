// Weighted team balancing for Cat n Mouse by Koi

#include "BaseTeamInfo.as";
#include "RulesCore.as";

#define SERVER_ONLY

const float MOUSE_TO_CAT_RATIO =  3.0f / 3.0f; // mice / cats

s32 getSmallestWeightedTeam(BaseTeamInfo@[]@ teams)
{
	return (teams[0].players_count - (teams[1].players_count + 1) / MOUSE_TO_CAT_RATIO) < -0.0001f ? 0 : 1;
}

void BalanceAll(CRules@ this)
{
	getNet().server_SendMsg("Scrambling the teams...");

	RulesCore@ core;
	this.get("core", @core);

	if(core !is null)
	{
		int playerCount = getPlayerCount();

		string[] playerNames;

		for (int i = 0; i < playerCount; i++)
		{
			playerNames.push_back(getPlayer(i).getUsername());
		}

		for(int i = 0; i < playerCount; i++)
		{
			int playerIndex = XORRandom(playerCount - i);

			CPlayer@ player = getPlayerByUsername(playerNames[playerIndex]);
			playerNames.removeAt(playerIndex);

			if (player.getTeamNum() != this.getSpectatorTeamNum())
			{
				core.ChangePlayerTeam(player, getSmallestWeightedTeam(core.teams));
			}
		}
	}
}

void onInit(CRules@ this)
{
	this.set_bool("managed teams", true); // core shouldn't try to manage the teams
	BalanceAll(this);
}

void onRestart(CRules@ this)
{
	BalanceAll(this);
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	RulesCore@ core;
	this.get("core", @core);

	if (core !is null)
	{
		core.ChangePlayerTeam(player, getSmallestWeightedTeam(core.teams));
	}
}

void onPlayerRequestTeamChange(CRules@ this, CPlayer@ player, u8 newTeam)
{
	RulesCore@ core;
	this.get("core", @core);

	if (core !is null)
	{
		if (newTeam == 255) // auto-assign when a player changes to team 255 (-1)
		{
			newTeam = getSmallestWeightedTeam(core.teams);
		}

		core.ChangePlayerTeam(player, newTeam);
	}
}