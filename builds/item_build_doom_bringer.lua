X = {}

local IBUtil = require(GetScriptDirectory() .. "/ItemBuildUtility");
local npcBot = GetBot();
local talents = IBUtil.FillTalenTable(npcBot);
local skills  = IBUtil.FillSkillTable(npcBot, IBUtil.GetSlotPattern(1));

X["items"] = { 
	"item_magic_wand",
	"item_phase_boots",
	"item_vanguard",
	"item_blade_mail",
	"item_invis_sword",
	--"item_aghanims_shard",
	"item_heavens_halberd",
	"item_crimson_guard",
	"item_ultimate_scepter_2",
	"item_shivas_guard",
	"item_silver_edge",
	"item_aghanims_shard",
};	

X["builds"] = {
	{3,1,2,2,2,4,2,3,3,3,4,1,1,1,4},
	{3,1,2,3,3,4,3,2,2,2,4,1,1,1,4},
	{1,3,1,2,1,4,1,2,2,2,4,3,3,3,4}
}

X["skills"] = IBUtil.GetBuildPattern(
	  "normal", 
	  IBUtil.GetRandomBuild(X['builds']), skills, 
	  {2,4,5,8}, talents
);

return X