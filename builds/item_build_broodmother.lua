X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = {
	"item_magic_wand",
	"item_phase_boots",
	"item_orchid",
	"item_black_king_bar",
	"item_assault",
	"item_monkey_king_bar",
	"item_ultimate_scepter_2",
	"item_bloodthorn",
	"item_ethereal_blade"
}

X["builds"] = {
	{2,1,1,2,1,2,1,2,4,3,4,3,3,3,4},
	{2,1,1,2,3,4,1,1,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {1,4,5,7}, talents
);

return X