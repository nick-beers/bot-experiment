X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_phase_boots",
	"item_ultimate_scepter",
	--"item_aghanims_shard",
	"item_pipe",
	"item_aeon_disk",
	"item_blink",
	"item_shivas_guard",
	"item_ultimate_scepter_2",
	"item_octarine_core",
	"item_aghanims_shard",
};			

X["builds"] = {
	{3,2,2,1,3,4,3,3,2,2,4,1,1,1,4},
	{1,3,1,2,3,4,1,3,1,3,4,2,2,2,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,8}, talents
);

return X