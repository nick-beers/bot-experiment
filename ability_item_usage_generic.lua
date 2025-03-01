local BotsInit = require( "game/botsinit" );
local MyModule = BotsInit.CreateGeneric();

local bot = GetBot();

if bot:GetUnitName() == 'npc_dota_hero_monkey_king' then
	local trueMK = nil;
	for i, id in pairs(GetTeamPlayers(GetTeam())) do
		if IsPlayerBot(id) and GetSelectedHeroName(id) == 'npc_dota_hero_monkey_king' then
			local member = GetTeamMember(i);
			if member ~= nil then
				trueMK = member;
			end
		end
	end
	if trueMK ~= nil and bot ~= trueMK then
		print("AbilityItemUsage "..tostring(bot).." isn't true MK")
		return;
	elseif trueMK == nil or bot == trueMK then
		print("AbilityItemUsage "..tostring(bot).." is true MK")
	end
end

if bot:IsInvulnerable() or bot:IsHero() == false or bot:IsIllusion()
then
	return;
end

local build = "NOT IMPLEMENTED";

if bot:IsHero() then
	build = require(GetScriptDirectory() .. "/builds/item_build_" .. string.gsub(GetBot():GetUnitName(), "npc_dota_hero_", ""));
end

if build == "NOT IMPLEMENTED" then 
	return 
end

local role = require(GetScriptDirectory() .. "/RoleUtility");
local mutil = require(GetScriptDirectory() ..  "/MyUtility");
local utils = require(GetScriptDirectory() ..  "/util");
local eUtils = require(GetScriptDirectory() ..  "/EnemyUtility");
local courierUtils = require(GetScriptDirectory() ..  "/CourierUtility");
local uItem = require(GetScriptDirectory() .. "/ItemUtility" );
local itemUseUtils = require(GetScriptDirectory() .. "/ItemUsageUtility" );



local IdleTime = 0;
local AllowedIddle = 15;
local TimeDeath = nil;
local count = 1;
local humanInTeam = nil;

--clone skill build to bot.abilities in reverse order 
--plus overcome the usage of the same memory address problem for bot.abilities in same heroes game which result in bot failed to level up correctly 
bot.abilities = {};
for i=1, math.ceil(#build['skills']/2) do
	bot.abilities[i] = build['skills'][#build['skills']-i+1]; 
	bot.abilities[#build['skills']-i+1] = build['skills'][i];
end

--prevent dota_bot_reload_script for breaking skill build
local first_ability = bot:GetAbilityByName(bot.abilities[#bot.abilities]);
if first_ability ~= nil and first_ability:GetLevel() > 0 then
	for i=#bot.abilities, #bot.abilities-bot:GetLevel()+1, -1 do
		bot.abilities[i] = nil;
	end
end

--Remove "-1" value
local function RemoveMinusOne(tableSkill)
	local temp = {};
	for i=1, #bot.abilities do
		if bot.abilities[i] ~= "-1" then
			temp[#temp+1] = bot.abilities[i];
		end
	end
	return temp;
end

bot.abilities = RemoveMinusOne(bot.abilities);

function AbilityLevelUpThink()  

	if GetGameState() ~= GAME_STATE_PRE_GAME and GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS 
	then
		return;
	end

	if DotaTime() < 15 then
		bot.theRole = role.GetCurrentSuitableRole(bot, bot:GetUnitName());	
	end	
	
	if bot:IsChanneling() then
		bot:Action_ClearActions( false ) 
		return
	end
	
	--UnImplementedItemUsage()
	UseGlyph()
	
	local botLoc = bot:GetLocation();
	-- if bot:GetUnitName() == "npc_dota_hero_monkey_king" then
		-- print(tostring(bot:GetCurrentActionType()==BOT_ACTION_TYPE_MOVE_TO)..tostring(IsLocationPassable(bot:GetLocation())))
	-- end
	if bot:IsAlive() and bot:GetCurrentActionType() == BOT_ACTION_TYPE_MOVE_TO and IsLocationPassable(botLoc) == false then
		if bot.stuckLoc == nil then
			bot.stuckLoc = botLoc
			bot.stuckTime = DotaTime();
		elseif bot.stuckLoc ~= botLoc then
			bot.stuckLoc = botLoc
			bot.stuckTime = DotaTime();
		end
	else	
		bot.stuckTime = nil;
		bot.stuckLoc = nil;
	end
	
	
	if bot:GetAbilityPoints() > 0 and bot:GetLevel() <= 25 then
		local lastIdx = #bot.abilities;
		local ability = bot:GetAbilityByName(bot.abilities[lastIdx]);
		if ability ~= nil and ability:CanAbilityBeUpgraded() and ability:GetLevel() < ability:GetMaxLevel() then
			if bot:GetUnitName() == "npc_dota_hero_troll_warlord" and bot.abilities[lastIdx] == "troll_warlord_whirling_axes_ranged" and ability:IsHidden() then
				bot:ActionImmediate_LevelAbility("troll_warlord_whirling_axes_melee");
			elseif bot:GetUnitName() == "npc_dota_hero_keeper_of_the_light" and bot.abilities[lastIdx] == "keeper_of_the_light_illuminate" and bot:HasScepter() then
				local ability_alt = bot:GetAbilityByName("keeper_of_the_light_spirit_form_illuminate");
				if ability_alt:IsHidden() then
					return;
				else
					bot:ActionImmediate_LevelAbility("keeper_of_the_light_spirit_form_illuminate");
				end			
			elseif ability:IsHidden() then
				return;	
			else
				bot:ActionImmediate_LevelAbility(bot.abilities[lastIdx]);
			end	
			bot.abilities[lastIdx] = nil;
		end
	end
	
end

function GetNumEnemyNearby(building)
	local nearbynum = 0;
	for i,id in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(id) then
			local info = GetHeroLastSeenInfo(id);
			if info ~= nil then
				local dInfo = info[1]; 
				if dInfo ~= nil and GetUnitToLocationDistance(building, dInfo.location) <= 2750 and dInfo.time_since_seen < 1.0 then
					nearbynum = nearbynum + 1;
				end
			end
		end
	end
	return nearbynum;
end

function GetNumOfAliveHeroes(team)
	local nearbynum = 0;
	for i,id in pairs(GetTeamPlayers(team)) do
		if IsHeroAlive(id) then
			nearbynum = nearbynum + 1;
		end
	end
	return nearbynum;
end

function GetRemainingRespawnTime()
	if TimeDeath == nil then
		return 0;
	else
		return bot:GetRespawnTime() - ( DotaTime() - TimeDeath );
	end
end

function IsMeepoClone()
	if bot:GetUnitName() == "npc_dota_hero_meepo" and bot:GetLevel() > 1 
	then
		for i=0, 5 do
			local item = bot:GetItemInSlot(i);
			if item ~= nil and not ( string.find(item:GetName(),"boots") or string.find(item:GetName(),"treads") )  
			then
				return false;
			end
		end
		return true;
    end
	return false;
end

function BuybackUsageThink() 
	
	if bot:IsInvulnerable() or not bot:IsHero() or bot:IsIllusion() or IsMeepoClone() or role.ShouldBuyBack() == false then
		return;
	end
	
	if bot:IsAlive() and TimeDeath ~= nil then
		TimeDeath = nil;
	end
	
	if not bot:HasBuyback() then
		return;
	end

	if not bot:IsAlive() then
		if TimeDeath == nil then
			TimeDeath = DotaTime();
		end
		--print(bot:GetUnitName()..":"..tostring(bot:GetRespawnTime()).."><"..tostring(RespawnTime))
	end
	
	local RespawnTime = GetRemainingRespawnTime();
	
	if RespawnTime < 10 then
		return;
	end
	
	local ancient = GetAncient(GetTeam());
	
	if ancient ~= nil 
	then
		local nEnemies = GetNumEnemyNearby(ancient);
		if  nEnemies > 0 and nEnemies >= GetNumOfAliveHeroes(GetTeam()) then
			role['lastbbtime'] = DotaTime();
			bot:ActionImmediate_Buyback();
			return;
		end	
	end

end

--[[function ItemUsageThink()
	--print(bot:GetUnitName().."item usage")
	if GetGameState()~=GAME_STATE_PRE_GAME and GetGameState()~= GAME_STATE_GAME_IN_PROGRESS then
		return;
	end
	
	UnImplementedItemUsage()
	--UseShrine()
end]]--

function PrintCourierState(state)
	
		if state == 0 then
			print("COURIER_STATE_IDLE ");
		elseif state == 1 then
			print("COURIER_STATE_AT_BASE");
		elseif state == 2 then
			print("COURIER_STATE_MOVING");
		elseif state == 3 then
			print("COURIER_STATE_DELIVERING_ITEMS");
		elseif state == 4 then
			print("COURIER_STATE_RETURNING_TO_BASE");
		elseif state == 5 then
			print("COURIER_STATE_DEAD");
		else
			print("UNKNOWN");
		end
		
end

local courierTime = -90;
local cState = -1;
bot.SShopUser = false;
local returnTime = -90;
local apiAvailable = true;

bot.courierID = 0;
bot.courierAssigned = false;
-- local calibrateTime = DotaTime();
local checkCourier = false;
local define_courier = false;
local cr = nil;
local tm =  GetTeam();
local pIDs = GetTeamPlayers(tm);
function CourierUsageThink()
	if GetGameMode() == 23 or bot:IsInvulnerable() or not bot:IsHero() or bot:IsIllusion() or bot:HasModifier("modifier_arc_warden_tempest_double") or GetNumCouriers() == 0 then
		return;
	end
	
	-- if GetTeam() == TEAM_DIRE then
		-- print(bot:GetUnitName().."----"..tostring(bot:GetPlayerID()));
		-- for i = 1, #pIDs do
			-- print(GetSelectedHeroName(pIDs[i])..":"..pIDs[i])
		-- end
	-- end
	
	-- if bot.courierAssigned == false then
		-- for i=1, #pIDs do
			-- if IsPlayerBot(pIDs[i]) == true then
				-- local mbr = GetTeamMember(i);
				-- if  bot == mbr then
					-- bot.courierID = i - 1;
					-- bot.courierAssigned = true;
					-- print(bot:GetUnitName().." : Courier Successfully Assigned To Courier "..tostring(bot.courierID));
				-- end
			-- end
		-- end
	-- end
	
	if courierUtils.pIDInc < #pIDs + 1 and DotaTime() > -60 then
		if IsPlayerBot(pIDs[courierUtils.pIDInc]) == true then
			local currID = pIDs[courierUtils.pIDInc];
				if bot:GetPlayerID() == currID  then
					if checkCourier == true and DotaTime() > courierUtils.calibrateTime + 5  then
						local cst = GetCourierState(cr);
						-- print(bot:GetUnitName());
						if cst == COURIER_STATE_MOVING then
							courierUtils.pIDInc = courierUtils.pIDInc + 1;
							print(bot:GetUnitName().." : Courier Successfully Assigned ."..tostring(bot.courierID));
							checkCourier = false;
							bot.courierAssigned = true;
							courierUtils.calibrateTime = DotaTime();
							bot:ActionImmediate_Courier( cr, COURIER_ACTION_RETURN_STASH_ITEMS );	
							return;
						else
							-- print("Failed to Assign Courier.");
							bot.courierID = bot.courierID + 1;
							checkCourier = false;
							courierUtils.calibrateTime = DotaTime();
						end
					elseif checkCourier == false then
						cr = GetCourier(bot.courierID);
						bot:ActionImmediate_Courier( cr, COURIER_ACTION_SECRET_SHOP );
						checkCourier = true;
					end
				end
		else
			courierUtils.pIDInc = courierUtils.pIDInc + 1;
		end
	end	
	
	if bot.courierAssigned == true then
	-- if bot:GetCourierValue( ) > 0 then
	
		-- print(bot:GetUnitName()..":"..tostring(bot:GetCourierValue( )));
	-- end
		local npcCourier = GetCourier(bot.courierID);	
		-- local itm = npcCourier:GetItemInSlot(1);
		-- if itm ~= nil then
			-- print(itm:GetName());
		-- end
		local cState = GetCourierState( npcCourier );

		local courierPHP = npcCourier:GetHealth() / npcCourier:GetMaxHealth(); 
		
		if cState == COURIER_STATE_DEAD then
			npcCourier.latestUser = nil;
			return
		end
		
		if IsFlyingCourier(npcCourier) then
			local burst = npcCourier:GetAbilityByName('courier_burst');
			if IsTargetedByUnit(npcCourier) then
				if bot:GetLevel() >= 10 and burst:IsFullyCastable() and apiAvailable == true 
				then
					bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_BURST );
					return
				elseif DotaTime() > returnTime + 5.0
					   --and not burst:IsFullyCastable() and not npcCourier:HasModifier('modifier_courier_shield') 
				then
					bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_RETURN_STASH_ITEMS );
					returnTime = DotaTime();
					return
				end
			end
		else	
			if IsTargetedByUnit(npcCourier) then
				if DotaTime() > returnTime + 5.0 then
					bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_RETURN_STASH_ITEMS );
					returnTime = DotaTime();
					return
				end
			end
		end
		
		if ( IsCourierAvailable() and cState ~= COURIER_STATE_IDLE )  then
			npcCourier.latestUser = "temp";
		end
		
		if bot.SShopUser and ( not bot:IsAlive() or bot:GetActiveMode() == BOT_MODE_SECRET_SHOP or not bot.SecretShop  ) then
			--bot:ActionImmediate_Chat( "Releasing the courier to anticipate secret shop stuck", true );
			npcCourier.latestUser = "temp";
			bot.SShopUser = false;
			bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_RETURN_STASH_ITEMS );
			return
		end
		
		if ( cState == COURIER_STATE_AT_BASE or cState == COURIER_STATE_IDLE or cState == COURIER_STATE_RETURNING_TO_BASE ) then 
			if courierPHP < 1.0 then
				return;
			end
			
			--RETURN COURIER TO BASE WHEN IDLE 
			if cState == COURIER_STATE_IDLE then
				bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_RETURN_STASH_ITEMS );
				return
			end
			
			--TAKE ITEM FROM STASH
			if  cState == COURIER_STATE_AT_BASE then
				local nCSlot = GetCourierEmptySlot(npcCourier);
					if bot:IsAlive() 
					then
						local nMSlot = GetNumStashItem(bot);
						if nMSlot > 0 and nMSlot <= nCSlot 
						then
							-- print("Transfer Item");
							bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_TAKE_STASH_ITEMS );
							nCSlot = nCSlot - nMSlot ;
							courierTime = DotaTime();
							return;
						end
					end
			end
			
			--MAKE COURIER GOES TO SECRET SHOP
			if  bot:IsAlive() and bot.SecretShop and npcCourier:DistanceFromFountain() < 7000 and IsInvFull(npcCourier) == false and DotaTime() > courierTime + 1.0 then
				--bot:ActionImmediate_Chat( "Using Courier for secret shop.", true );
				bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_SECRET_SHOP )
				npcCourier.latestUser = bot;
				bot.SShopUser = true;
				UpdateSShopUserStatus(bot);
				courierTime = DotaTime();
				-- print("Transfer Secret Shop");
				return
			end
			
			--TRANSFER ITEM IN COURIER
			if bot:IsAlive() and bot:GetCourierValue( ) > 0 
			then
				bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_TRANSFER_ITEMS )
				npcCourier.latestUser = bot;
				courierTime = DotaTime();
				-- print("Transfer Item 2");
				return
			end
			
			--RETURN STASH ITEM WHEN DEATH
			if  not bot:IsAlive() and cState == COURIER_STATE_DELIVERING_ITEMS  
				and bot:GetCourierValue( ) > 0 and DotaTime() > courierTime + 1.0
			then
				bot:ActionImmediate_Courier( npcCourier, COURIER_ACTION_RETURN_STASH_ITEMS );
				npcCourier.latestUser = bot;
				courierTime = DotaTime();
				-- print("Return Item");
				return
			end
			
		
		end
	
	end	
	
end

function IsHumanHaveItemInCourier()
	local numPlayer =  GetTeamPlayers(GetTeam());
	for i = 1, #numPlayer
	do
		if not IsPlayerBot(numPlayer[i]) then
			local member = GetTeamMember(i);
			if member ~= nil and member:IsAlive() and member:GetCourierValue( ) > 0 
			then
				return true;
			end
		end
	end
	return false;
end

function IsTheClosestToCourier(bot, npcCourier)
	local numPlayer =  GetTeamPlayers(GetTeam());
	local closest = nil;
	local closestD = 100000;
	for i = 1, #numPlayer
	do
		local member =  GetTeamMember(i);
		if member ~= nil and IsPlayerBot(numPlayer[i]) and member:IsAlive() and member:GetCourierValue( ) > 0 
		then
			local invFull = IsInvFull(member);
			local nStash = GetNumStashItem(member);
			if invFull == false 
				or ( invFull == true and nStash == 0 and bot.currListItemToBuy ~= nil and #bot.currListItemToBuy == 0 ) 
			then
				local dist = GetUnitToUnitDistance(member, npcCourier);
				if dist < closestD then
					closest = member;
					closestD = dist;
				end
			end	
		end
	end
	return closest ~= nil and closest == bot
end

function GetCourierEmptySlot(courier)
	local amount = 0;
	for i=0, 8 do
		if courier:GetItemInSlot(i) == nil then
			amount = amount + 1;
		end
	end
	return amount;
end

function GetNumStashItem(unit)
	local amount = 0;
	for i=9, 14 do
		if unit:GetItemInSlot(i) ~= nil then
			amount = amount + 1;
		end
	end
	return amount;
end

function UpdateSShopUserStatus(bot)
	local numPlayer =  GetTeamPlayers(GetTeam());
	for i = 1, #numPlayer
	do
		local member =  GetTeamMember(i);
		if member ~= nil and IsPlayerBot(numPlayer[i]) and  member:GetUnitName() ~= bot:GetUnitName() 
		then
			member.SShopUser = false;
		end
	end
end

function IsTargetedByUnit(courier)
	for i = 0, 10 do
	local tower = GetTower(GetOpposingTeam(), i)
		if tower ~= nil and tower:GetAttackTarget() == courier then
			return true;
		end
	end
	for i,id in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(id) then
			local info = GetHeroLastSeenInfo(id);
			if info ~= nil then
				local dInfo = info[1];
				if dInfo ~= nil and GetUnitToLocationDistance(courier, dInfo.location) <= 700 and dInfo.time_since_seen < 0.5 then
					return true;
				end
			end
		end
	end
	return false;
end

function IsInvFull(npcHero)
	for i=0, 8 do
		if(npcHero:GetItemInSlot(i) == nil) then
			return false;
		end
	end
	return true;
end

function CanCastOnTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsMagicImmune() and not npcTarget:IsInvulnerable();
end
function CanCastOnMagicImmuneTarget( npcTarget )
	return npcTarget:CanBeSeen() and not npcTarget:IsInvulnerable();
end

function IsDisabled(npcTarget)
	if npcTarget:IsRooted( ) or npcTarget:IsStunned( ) or npcTarget:IsHexed( ) or npcTarget:IsSilenced() or npcTarget:IsNightmared() then
		return true;
	end
	return false;
end

function GiveToMidLaner()
	local teamPlayers = GetTeamPlayers(GetTeam())
	local target = nil;
	for k,v in pairs(teamPlayers)
	do
		local member = GetTeamMember(k);
		if member ~= nil and not member:IsIllusion() and member:IsAlive() then
			local num_stg = GetItemCount(member, "item_tango_single"); 
			local num_ff = GetItemCount(member, "item_faerie_fire"); 
			if num_ff > 0 and num_stg < 1 then
				return member;
			end
		end
	end
	return nil;
end

function GetItemCount(unit, item_name)
	local count = 0;
	for i = 0, 8 
	do
		local item = unit:GetItemInSlot(i)
		if item ~= nil and item:GetName() == item_name then
			count = count + 1;
		end
	end
	return count;
end

function CanSwitchPTStat(pt)
	if bot:GetPrimaryAttribute() == ATTRIBUTE_STRENGTH and pt:GetPowerTreadsStat() ~= ATTRIBUTE_STRENGTH then
		return true;
	elseif bot:GetPrimaryAttribute() == ATTRIBUTE_AGILITY  and pt:GetPowerTreadsStat() ~= ATTRIBUTE_INTELLECT then
		return true;
	elseif bot:GetPrimaryAttribute() == ATTRIBUTE_INTELLECT and pt:GetPowerTreadsStat() ~= ATTRIBUTE_AGILITY then
		return true;
	end 
	return false;
end

local myTeam = GetTeam();
local opTeam = GetOpposingTeam();

local teamT1Top = nil;
local teamT1Mid = nil;
local teamT1Bot = nil;
local enemyT1Top = nil;
local enemyT1Mid = nil;
local enemyT1Bot = nil;

if myTeam == TEAM_DIRE then
	teamT1Top = GetTower(myTeam,TOWER_TOP_1) == nil and Vector(-4693, 5998) or GetTower(myTeam,TOWER_TOP_1):GetLocation();
	teamT1Mid = GetTower(myTeam,TOWER_MID_1) == nil and Vector(530, 657) or GetTower(myTeam,TOWER_MID_1):GetLocation();
	teamT1Bot = GetTower(myTeam,TOWER_BOT_1) == nil and Vector(6262, -1687) or GetTower(myTeam,TOWER_BOT_1):GetLocation();
	enemyT1Top = GetTower(opTeam,TOWER_TOP_1) == nil and Vector(-6262, 1815) or GetTower(opTeam,TOWER_TOP_1):GetLocation();
	enemyT1Mid = GetTower(opTeam,TOWER_MID_1) == nil and Vector(-1530, -1412) or GetTower(opTeam,TOWER_MID_1):GetLocation();
	enemyT1Bot = GetTower(opTeam,TOWER_BOT_1) == nil and Vector(4949, -6130) or GetTower(opTeam,TOWER_BOT_1):GetLocation();
else
	teamT1Top = GetTower(myTeam,TOWER_TOP_1) == nil and Vector(-6262, 1815) or GetTower(myTeam,TOWER_TOP_1):GetLocation();
	teamT1Mid = GetTower(myTeam,TOWER_MID_1) == nil and Vector(-1530, -1412) or GetTower(myTeam,TOWER_MID_1):GetLocation();
	teamT1Bot = GetTower(myTeam,TOWER_BOT_1) == nil and Vector(4949, -6130) or GetTower(myTeam,TOWER_BOT_1):GetLocation();
	enemyT1Top = GetTower(opTeam,TOWER_TOP_1) == nil and Vector(-4693, 5998) or GetTower(opTeam,TOWER_TOP_1):GetLocation();
	enemyT1Mid = GetTower(opTeam,TOWER_MID_1) == nil and Vector(530, 657) or GetTower(opTeam,TOWER_MID_1):GetLocation();
	enemyT1Bot = GetTower(opTeam,TOWER_BOT_1) == nil and Vector(6262, -1687) or GetTower(opTeam,TOWER_BOT_1):GetLocation();
end

function GetLaningTPLocation(nLane)
	if nLane == LANE_TOP then
		return teamT1Top
	elseif nLane == LANE_MID then
		return teamT1Mid
	elseif nLane == LANE_BOT then
		return teamT1Bot			
	end	
	return teamT1Mid
end	

function GetDefendTPLocation(nLane)
	return GetLaneFrontLocation(opTeam,nLane,-1600)
end

function GetPushTPLocation(nLane)
	return GetLaneFrontLocation(myTeam,nLane,0)
end


local idlt = 0;
local idlm = 0;
local idlb = 0;
function printDefendLaneDesire()
	local md = bot:GetActiveMode()
	local mdd = bot:GetActiveModeDesire()
	local dlt = GetDefendLaneDesire(LANE_TOP)
	local dlm = GetDefendLaneDesire(LANE_MID)
	local dlb = GetDefendLaneDesire(LANE_BOT)
	if bot:GetPlayerID() == 2 then
		if idlt ~= dlt then 
			idlt = dlt
			print("DefendLaneDesire TOP: "..tostring(dlt))
		elseif idlm ~= dlm then 
			idlm = dlm
			print("DefendLaneDesire MID: "..tostring(dlm))
		elseif idlb ~= dlb then 
			idlb = dlb
			print("DefendLaneDesire TOP: "..tostring(dlb))
		end	
		if md == BOT_MODE_DEFEND_TOWER_TOP then 
			print("Def Tower Des TOP: "..tostring(mdd))
		elseif md == BOT_MODE_DEFEND_TOWER_MID then
			print("Def Tower Des MID: "..tostring(mdd))
		elseif md == BOT_MODE_DEFEND_TOWER_BOT then 	
			print("Def Tower Des BOT: "..tostring(mdd))
		end
	end	
end

local enemyPids = nil;
function CanJuke()
	if enemyPids == nil then
		enemyPids = GetTeamPlayers(GetOpposingTeam())
	end	
	local heroHG = GetHeightLevel(bot:GetLocation())
	for i = 1, #enemyPids do
		local info = GetHeroLastSeenInfo(enemyPids[i])
		if info ~= nil then
			local dInfo = info[1]; 
			if dInfo ~= nil and dInfo.time_since_seen < 2.5  
				and GetUnitToLocationDistance(bot,dInfo.location) < 1500 
				and GetHeightLevel(dInfo.location) <= heroHG + 1   
			then
				return false;
			end
		end	
	end
	return true;
end	

function GetNumHeroWithinRange(nRange)
	if enemyPids == nil then
		enemyPids = GetTeamPlayers(GetOpposingTeam())
	end	
	local cHeroes = 0;
	for i = 1, #enemyPids do
		local info = GetHeroLastSeenInfo(enemyPids[i])
		if info ~= nil then
			local dInfo = info[1]; 
			if dInfo ~= nil and dInfo.time_since_seen < 2.0  
				and GetUnitToLocationDistance(bot,dInfo.location) < nRange 
			then
				cHeroes = cHeroes + 1;
			end
		end	
	end
	return cHeroes;
end	

local tpThreshold = 4500;

function ShouldTP()
    local stuckTP = false;
	local tpLoc = nil;
	local mode = bot:GetActiveMode();
	local modDesire = bot:GetActiveModeDesire();
	local botLoc = bot:GetLocation();
	local enemies = GetNumHeroWithinRange(1600);
	if mutil.IsStuck(bot) and enemies == 0 then
		bot:ActionImmediate_Chat("I'm using tp while stuck.", true);
		tpLoc = GetAncient(GetTeam()):GetLocation()
	elseif mode == BOT_MODE_LANING and enemies == 0 then
		local assignedLane = bot:GetAssignedLane();
		if assignedLane == LANE_TOP  then
			local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
			local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
			if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
				tpLoc = GetLaningTPLocation(LANE_TOP)
			end	
		elseif assignedLane == LANE_MID then
			local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
			local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
			if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
				tpLoc = GetLaningTPLocation(LANE_MID)
			end	
		elseif assignedLane == LANE_BOT then
			local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
			local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
			if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
				tpLoc = GetLaningTPLocation(LANE_BOT)
			end	
		end
	elseif mode == BOT_MODE_DEFEND_TOWER_TOP and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then
		local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetDefendTPLocation(LANE_TOP)
		end	
	elseif mode == BOT_MODE_DEFEND_TOWER_MID and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then
		local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetDefendTPLocation(LANE_MID)
		end	
	elseif mode == BOT_MODE_DEFEND_TOWER_BOT and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then	
		local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetDefendTPLocation(LANE_BOT)
		end	
	elseif mode == BOT_MODE_PUSH_TOWER_TOP and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then
		local botAmount = GetAmountAlongLane(LANE_TOP, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_TOP, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetPushTPLocation(LANE_TOP)
		end	
	elseif mode == BOT_MODE_PUSH_TOWER_MID and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then
		local botAmount = GetAmountAlongLane(LANE_MID, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_MID, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetPushTPLocation(LANE_MID)
		end	
	elseif mode == BOT_MODE_PUSH_TOWER_BOT and modDesire >= BOT_MODE_DESIRE_MODERATE and enemies == 0 then
		local botAmount = GetAmountAlongLane(LANE_BOT, botLoc)
		local laneFront = GetLaneFrontAmount(myTeam, LANE_BOT, false)
		if botAmount.distance > tpThreshold or botAmount.amount < laneFront / 5 then 
			tpLoc = GetPushTPLocation(LANE_BOT)
		end	
	elseif mode == BOT_MODE_DEFEND_ALLY and modDesire >= BOT_MODE_DESIRE_MODERATE and role.CanBeSupport(bot:GetUnitName()) == true and enemies == 0 then
		local target = bot:GetTarget()
		if target ~= nil and target:IsHero() then
			local nearbyTower = target:GetNearbyTowers(1300, true)
			if nearbyTower ~= nil and #nearbyTower > 0 and bot:GetMana() >  0.25*bot:GetMaxMana()  then
				tpLoc = nearbyTower[1]:GetLocation()
			end
		end
	elseif mode == BOT_MODE_RETREAT and modDesire >= BOT_MODE_DESIRE_HIGH 
	then
		if bot:GetHealth() < 0.15*bot:GetMaxHealth() and bot:WasRecentlyDamagedByAnyHero(2.0) and enemies == 0 then
			tpLoc = mutil.GetTeamFountain();
		elseif bot:GetHealth() < 0.25*bot:GetMaxHealth() and bot:WasRecentlyDamagedByAnyHero(3.0) and CanJuke() == true then
			-- print(bot:GetUnitName().." JUKE TP")
			tpLoc = mutil.GetTeamFountain();	
		end
	elseif bot:HasModifier('modifier_bloodseeker_rupture') and enemies <= 1 then
		local allies = bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE);
		if #allies <= 1 then
			tpLoc = mutil.GetTeamFountain();
		end
	end	
	if ( stuckTP == true and tpLoc ~= nil ) or ( stuckTP == false and tpLoc ~= nil and GetUnitToLocationDistance(bot, tpLoc) > 2000 ) then
		return true, tpLoc;
	end
	return false, nil;
end

local giveTime = -90;
local armToggle = -90;
local castFusionRuneTime = -90;
function UnImplementedItemUsage()

	if bot:IsChanneling() or bot:IsUsingAbility() or bot:IsInvisible() or bot:IsMuted( ) or bot:HasModifier("modifier_doom_bringer_doom") then
		return;
	end
	
	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( 800, true, BOT_MODE_NONE );
	local npcTarget = bot:GetTarget();
	local mode = bot:GetActiveMode();
	
	local tps = bot:GetItemInSlot(15);
	if tps ~= nil and tps:IsFullyCastable() then
		local tpLoc = nil
		local shouldTP = false
		shouldTP, tpLoc = ShouldTP()
		if shouldTP then
			bot:Action_UseAbilityOnLocation(tps, tpLoc);
			return;
		end	
	end
	
	local pt = IsItemAvailable("item_power_treads");
	if pt~=nil and pt:IsFullyCastable() then
		if mode == BOT_MODE_RETREAT and pt:GetPowerTreadsStat() ~= ATTRIBUTE_STRENGTH and bot:WasRecentlyDamagedByAnyHero(5.0) then
			bot:Action_UseAbility(pt);
			return
		elseif mode == BOT_MODE_ATTACK and CanSwitchPTStat(pt) then
			bot:Action_UseAbility(pt);
			return
		else
			local enemies = bot:GetNearbyHeroes( 1300, true, BOT_MODE_NONE );
			if #enemies == 0 and  mode ~= BOT_MODE_RETREAT and CanSwitchPTStat(pt)  then
				bot:Action_UseAbility(pt);
				return
			end
		end
	end
	
	local qb = IsItemAvailable('item_quelling_blade');
	local bf = IsItemAvailable('item_bfury');
	if ( qb ~= nil and qb:IsFullyCastable() ) or ( bf ~= nil and bf:IsFullyCastable() )  then
		if bot:GetUnitName() ~= 'npc_dota_hero_monkey_king' and ( mode == BOT_MODE_ATTACK or ( mode == BOT_MODE_RETREAT and bot:IsInvisible() == false ) )
		then	
			local nCastRange = 300;
			local trees = bot:GetNearbyTrees(nCastRange);
			for i=1,#trees do
				if bot:IsFacingLocation(GetTreeLocation(trees[i]), 5) then
					if qb~=nil then
						bot:Action_UseAbilityOnTree(qb, trees[i]);
						return
					elseif bf~=nil then
						bot:Action_UseAbilityOnTree(bf, trees[i]);
						return
					end
				end
			end
		end	
	end
	-- local bas = IsItemAvailable("item_ring_of_basilius");
	-- if bas~=nil and bas:IsFullyCastable() then
		-- if mode == BOT_MODE_LANING and not bas:GetToggleState() then
			-- bot:Action_UseAbility(bas);
			-- return
		-- elseif mode ~= BOT_MODE_LANING and bas:GetToggleState() then
			-- bot:Action_UseAbility(bas);
			-- return
		-- end
	-- end
	
	local hl=IsItemAvailable("item_holy_locket");
	if hl~=nil and hl:IsFullyCastable() then
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and 
			bot:DistanceFromFountain() > 0 and
			( bot:GetHealth() / bot:GetMaxHealth() ) < 0.15 ) and
			hl:GetCurrentCharges() > 10
		then
			bot:Action_UseAbility(hl);
			return;
		end
	end
	
	-- local aq = IsItemAvailable("item_ring_of_aquila");
	-- if aq~=nil and aq:IsFullyCastable() then
	-- 	if mode == BOT_MODE_LANING and not aq:GetToggleState() then
	-- 		bot:Action_UseAbility(aq);
	-- 		return
	-- 	elseif mode ~= BOT_MODE_LANING and aq:GetToggleState() then
	-- 		bot:Action_UseAbility(aq);
	-- 		return
	-- 	end
	-- end

	-- Tangos expire so there's no point in giving tangos pregame
	-- local itg=IsItemAvailable("item_tango");
	-- if itg~=nil and itg:IsFullyCastable() then
	-- 	local tCharge = itg:GetCurrentCharges()
	-- 	if DotaTime() > -80 and DotaTime() < 0 and bot:DistanceFromFountain() == 0 and role.CanBeSupport(bot:GetUnitName())
	-- 	   and bot:GetAssignedLane() ~= LANE_MID and tCharge > 2 and DotaTime() > giveTime + 2.0 then
	-- 		local target = GiveToMidLaner()
	-- 		if target ~= nil then
	-- 			bot:ActionImmediate_Chat(string.gsub(bot:GetUnitName(),"npc_dota_hero_","")..
	-- 					" giving tango to "..
	-- 					string.gsub(target:GetUnitName(),"npc_dota_hero_","")
	-- 					, false);
	-- 			bot:Action_UseAbilityOnEntity(itg, target);
	-- 			giveTime = DotaTime();
	-- 			return;
	-- 		end
	-- 	elseif bot:GetActiveMode() == BOT_MODE_LANING and role.CanBeSupport(bot:GetUnitName()) and tCharge > 1 and DotaTime() > giveTime + 2.0 then
	-- 		local allies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
	-- 		for _,ally in pairs(allies)
	-- 		do
	-- 			local tangoSlot = ally:FindItemSlot('item_tango');
	-- 			if ally:GetUnitName() ~= bot:GetUnitName() and not ally:IsIllusion() 
	-- 			   and tangoSlot == -1 and GetItemCount(ally, "item_tango_single") == 0 
	-- 			then
	-- 				bot:Action_UseAbilityOnEntity(itg, ally);
	-- 				giveTime = DotaTime();
	-- 				return
	-- 			end
	-- 		end
	-- 	end
	-- end
	
	local bdg=IsItemAvailable("item_blink");
	if bdg~=nil and bdg:IsFullyCastable() then
		if mutil.IsStuck(bot)
		then
			bot:ActionImmediate_Chat("I'm using blink while stuck.", true);
			bot:Action_UseAbilityOnLocation(bdg, bot:GetXUnitsTowardsLocation( GetAncient(GetTeam()):GetLocation(), 1100 ));
			return;
		end
	end
	
	local fst=IsItemAvailable("item_force_staff");
	if fst~=nil and fst:IsFullyCastable() then
		if mutil.IsStuck(bot)
		then
			bot:ActionImmediate_Chat("I'm using force staff while stuck.", true);
			bot:Action_UseAbilityOnEntity(fst, bot);
			return;
		end
	end
	
	-- local tpt=IsItemAvailable("item_tpscroll");
	-- if tpt~=nil and tpt:IsFullyCastable() then
		-- if mutil.IsStuck(bot)
		-- then
			-- bot:ActionImmediate_Chat("I'm using tp while stuck.", true);
			-- bot:Action_UseAbilityOnLocation(tpt, GetAncient(GetTeam()):GetLocation());
			-- return;
		-- end
	-- end
	
	local its=IsItemAvailable("item_tango_single");
	if its~=nil and its:IsFullyCastable() and bot:DistanceFromFountain() > 1000 then
		if DotaTime() > 10*60 
		then
			local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( 1600, true, BOT_MODE_NONE );
			local trees = bot:GetNearbyTrees(1000);
			if trees[1] ~= nil  and ( IsLocationVisible(GetTreeLocation(trees[1])) or IsLocationPassable(GetTreeLocation(trees[1])) )
			   and #tableNearbyEnemyHeroes == 0 
			then
				bot:Action_UseAbilityOnTree(its, trees[1]);
				return;
			end
		end
	end
	
	-- local irt=IsItemAvailable("item_iron_talon");
	-- if irt~=nil and irt:IsFullyCastable() then
	-- 	if bot:GetActiveMode() == BOT_MODE_FARM or mutil.IsDefending(bot) or mutil.IsPushing(bot) 
	-- 	then
	-- 		local neutrals = bot:GetNearbyCreeps(500, true);
	-- 		local maxHP = 0;
	-- 		local target = nil;
	-- 		for _,c in pairs(neutrals) do
	-- 			local cHP = c:GetHealth();
	-- 			if cHP > maxHP and not c:IsAncientCreep() then
	-- 				maxHP = cHP;
	-- 				target = c;
	-- 			end
	-- 		end
	-- 		if target ~= nil then
	-- 			bot:Action_UseAbilityOnEntity(irt, target);
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	local msh=IsItemAvailable("item_moon_shard");
	if msh~=nil and msh:IsFullyCastable() then
		if not bot:HasModifier("modifier_item_moon_shard_consumed")
		then
			bot:Action_UseAbilityOnEntity(msh, bot);
			return;
		end
	end
	
	local mg=IsItemAvailable("item_enchanted_mango");
	if mg~=nil and mg:IsFullyCastable() then
		if bot:GetMana()/bot:GetMaxMana() < 0.10 and mode == BOT_MODE_ATTACK then
			bot:Action_UseAbility(mg);
			return;
		end
	end
	
	local tok=IsItemAvailable("item_tome_of_knowledge");
	if tok~=nil and tok:IsFullyCastable() then
		bot:Action_UseAbility(tok);
		return;
	end
	
	local ff=IsItemAvailable("item_faerie_fire");
	if ff~=nil and ff:IsFullyCastable() then
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and 
			bot:DistanceFromFountain() > 0 and
			( bot:GetHealth() / bot:GetMaxHealth() ) < 0.15 ) or DotaTime() > 10*60
		then
			bot:Action_UseAbility(ff);
			return;
		end
	end
	
	local bst=IsItemAvailable("item_bloodstone");
	if bst ~= nil and bst:IsFullyCastable() then
		if  mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and 
			( bot:GetHealth() / bot:GetMaxHealth() ) < 0.10 - ( bot:GetLevel() / 500 ) and
			( bot:GetMana() / bot:GetMaxMana() > 0.6 )
		then
			bot:Action_UseAbility(bst);
			return;
		end
	end
	
	
	
	local pb=IsItemAvailable("item_phase_boots");
	if pb~=nil and pb:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_ATTACK or
			 ( mode == BOT_MODE_RETREAT and bot:IsInvisible() == false ) or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY )
		then
			bot:Action_UseAbility(pb);
			return;
		end	
	end
	
	local bt=IsItemAvailable("item_bloodthorn");
	if bt~=nil and bt:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_ATTACK or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY )
		then
			local npcTarget = bot:GetTarget();
			if ( npcTarget ~= nil and npcTarget:IsHero() and CanCastOnTarget(npcTarget) and not npcTarget:IsSilenced() and GetUnitToUnitDistance(npcTarget, bot) < 900 )
			then
			    bot:Action_UseAbilityOnEntity(bt,npcTarget);
				return
			end
		end
	end
	
	local eb=IsItemAvailable("item_ethereal_blade");
	if eb~=nil and eb:IsFullyCastable() and bot:GetUnitName() ~= "npc_dota_hero_morphling"
	then
		if ( mode == BOT_MODE_ATTACK or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY )
		then
			local npcTarget = bot:GetTarget();
			if ( npcTarget ~= nil and npcTarget:IsHero() and CanCastOnTarget(npcTarget) and GetUnitToUnitDistance(npcTarget, bot) < 1000 )
			then
			    bot:Action_UseAbilityOnEntity(eb,npcTarget);
				return
			end
		end
	end
	
	local rs=IsItemAvailable("item_refresher_shard");
	if rs~=nil and rs:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_ATTACK or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY ) and mutil.CanUseRefresherShard(bot)  
		then
			bot:Action_UseAbility(rs);
			return
		end
	end
	
	local ro=IsItemAvailable("item_refresher");
	if ro~=nil and ro:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_ATTACK or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY ) and mutil.CanUseRefresherOrb(bot)  
		then
			bot:Action_UseAbility(ro);
			return
		end
	end
	
	local sc=IsItemAvailable("item_solar_crest");
	if sc~=nil and sc:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_ATTACK or
			 mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK or
			 mode == BOT_MODE_DEFEND_ALLY )
		then
			if ( npcTarget ~= nil and npcTarget:IsHero() 
			   and not npcTarget:HasModifier('modifier_item_solar_crest_armor_reduction') 
			   and not npcTarget:IsMagicImmune()
			   and GetUnitToUnitDistance(npcTarget, bot) < 900 )
			then
			    bot:Action_UseAbilityOnEntity(sc, npcTarget);
				return
			end
		end
	end
	
	if sc~=nil and sc:IsFullyCastable() then
		local Allies=bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE);
		for _,Ally in pairs(Allies) do
			if Ally:GetUnitName() ~= bot:GetUnitName() and not Ally:HasModifier('modifier_item_solar_crest_armor_reduction') and
			   ( ( Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 and CanCastOnTarget(Ally) ) or 
				 ( IsDisabled(Ally) and CanCastOnTarget(Ally) ) )
			then
				bot:Action_UseAbilityOnEntity(sc,Ally);
				return;
			end
		end
	end
	
	local se=IsItemAvailable("item_silver_edge");
    if se ~= nil and se:IsFullyCastable() then
		if mode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and 
			tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0
		then
			bot:Action_UseAbility(se);
			return;
	    end
		if ( mode == BOT_MODE_ROAM or
			 mode == BOT_MODE_TEAM_ROAM or
			 mode == BOT_MODE_GANK )
		then
			if ( npcTarget ~= nil and npcTarget:IsHero() and GetUnitToUnitDistance(npcTarget, bot) > 1000 and  GetUnitToUnitDistance(npcTarget, bot) < 2500 )
			then
			    bot:Action_UseAbility(se);
				return;
			end
		end
	end
	
	local hood=IsItemAvailable("item_hood_of_defiance");
    if hood~=nil and hood:IsFullyCastable() and bot:GetHealth()/bot:GetMaxHealth()<0.8 and not bot:HasModifier('modifier_item_pipe_barrier')
	then
		if tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 then
			bot:Action_UseAbility(hood);
			return;
		end
	end
	
	local lotus=IsItemAvailable("item_lotus_orb");
	if lotus~=nil and lotus:IsFullyCastable() 
	then
		if  not bot:HasModifier('modifier_item_lotus_orb_active') 
			and not bot:IsMagicImmune()
			and ( bot:IsSilenced() or ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 and bot:GetHealth()/bot:GetMaxHealth() < 0.35 + (0.05*#tableNearbyEnemyHeroes) ) )
	    then
			bot:Action_UseAbilityOnEntity(lotus,bot);
			return;
		end
	end
	
	if lotus~=nil and lotus:IsFullyCastable() 
	then
		local Allies=bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE);
		for _,Ally in pairs(Allies) do
			if  not Ally:HasModifier('modifier_item_lotus_orb_active') 
				and not Ally:IsMagicImmune()
				and Ally:WasRecentlyDamagedByAnyHero(2.0)
			    and (( Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 )  or 
				IsDisabled(Ally))
			then
				bot:Action_UseAbilityOnEntity(lotus,Ally);
				return;
			end
		end
	end
	
	local hurricanpike = IsItemAvailable("item_hurricane_pike");
	if hurricanpike~=nil and hurricanpike:IsFullyCastable() 
	then
		if ( mode == BOT_MODE_RETREAT and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH )
		then
			for _,npcEnemy in pairs( tableNearbyEnemyHeroes )
			do
				if ( GetUnitToUnitDistance( npcEnemy, bot ) < 400 and CanCastOnTarget(npcEnemy) )
				then
					bot:Action_UseAbilityOnEntity(hurricanpike,npcEnemy);
					return
				end
			end
			if bot:IsFacingLocation(GetAncient(GetTeam()):GetLocation(),10) and bot:DistanceFromFountain() > 0 
			then
				bot:Action_UseAbilityOnEntity(hurricanpike,bot);
				return;
			end
		end
	end
	
	local glimer=IsItemAvailable("item_glimmer_cape");
	if glimer~=nil and glimer:IsFullyCastable() then
		if  not bot:HasModifier('modifier_item_glimmer_cape') 
			and not bot:IsMagicImmune()
			and ( bot:IsSilenced() or ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 and bot:GetHealth()/bot:GetMaxHealth() < 0.35 + (0.05*#tableNearbyEnemyHeroes) ) )
	    then	
			bot:Action_UseAbilityOnEntity(glimer,bot);
			return;
		end
	end
	
	if glimer~=nil and glimer:IsFullyCastable() then
		local Allies=bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE);
		for _,Ally in pairs(Allies) do
			if not Ally:HasModifier('modifier_item_glimmer_cape') 
			   and not Ally:IsMagicImmune()
			   and Ally:WasRecentlyDamagedByAnyHero(2.0)
			   and (( Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 0 ) or IsDisabled(Ally))
			then
				bot:Action_UseAbilityOnEntity(glimer,Ally);
				return;
			end
		end
	end
	
	local hod=IsItemAvailable("item_helm_of_the_dominator");
	if hod~=nil and hod:IsFullyCastable() 
	then
		local maxHP = 0;
		local NCreep = nil;
		local tableNearbyCreeps = bot:GetNearbyCreeps( 1000, true );
		if #tableNearbyCreeps >= 2 then
			for _,creeps in pairs(tableNearbyCreeps)
			do
				local CreepHP = creeps:GetHealth();
				if CreepHP > maxHP and ( creeps:GetHealth() / creeps:GetMaxHealth() ) > .75  and not creeps:IsAncientCreep()
				then
					NCreep = creeps;
					maxHP = CreepHP;
				end
			end
		end
		if NCreep ~= nil then
			bot:Action_UseAbilityOnEntity(hod,NCreep);
			return
		end	
	end
	
	local hom=IsItemAvailable("item_hand_of_midas");
	if hom~=nil and hom:IsFullyCastable() then
		local range = 600+200;
		local tableNearbyCreeps = bot:GetNearbyCreeps( range, true );
		if #tableNearbyCreeps > 0 
			and tableNearbyCreeps[1] ~= nil 
			and tableNearbyCreeps[1]:IsMagicImmune() == false 
			and tableNearbyCreeps[1]:IsAncientCreep() == false 
		then
			bot:Action_UseAbilityOnEntity(hom, tableNearbyCreeps[1]);
			return;
		end
	end
	
	local guardian=IsItemAvailable("item_guardian_greaves");
	if guardian~=nil and guardian:IsFullyCastable() then
		local Allies=bot:GetNearbyHeroes(1000,false,BOT_MODE_NONE);
		for _,Ally in pairs(Allies) do
			if  Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and tableNearbyEnemyHeroes~=nil and #tableNearbyEnemyHeroes > 0 
			then
				bot:Action_UseAbility(guardian);
				return;
			end
		end
	end
	
	local satanic=IsItemAvailable("item_satanic");
	if satanic~=nil and satanic:IsFullyCastable() then
		if  bot:GetHealth()/bot:GetMaxHealth() < 0.50 and 
			tableNearbyEnemyHeroes~=nil and #tableNearbyEnemyHeroes > 0 and 
			bot:GetActiveMode() == BOT_MODE_ATTACK
		then
			bot:Action_UseAbility(satanic);
			return;
		end
	end
	
	local cyclone=IsItemAvailable("item_cyclone");
	if cyclone~=nil and cyclone:IsFullyCastable() then
		if npcTarget ~= nil and ( npcTarget:HasModifier('modifier_teleporting') or npcTarget:HasModifier('modifier_abaddon_borrowed_time') ) 
		   and CanCastOnTarget(npcTarget) and GetUnitToUnitDistance(bot, npcTarget) < 775
		then
			bot:Action_UseAbilityOnEntity(cyclone, npcTarget);
			return;
		end
	end
	
	local metham=IsItemAvailable("item_meteor_hammer");
	if metham~=nil and metham:IsFullyCastable() then
		if mutil.IsPushing(bot) then
			local towers = bot:GetNearbyTowers(800, true);
			if #towers > 0 and towers[1] ~= nil and  towers[1]:IsInvulnerable() == false then 
				bot:Action_UseAbilityOnLocation(metham, towers[1]:GetLocation());
				return;
			end
		elseif  mutil.IsInTeamFight(bot, 1200) then
			local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), 600, 300, 0, 0 );
			if ( locationAoE.count >= 2 ) 
			then
				bot:Action_UseAbilityOnLocation(metham, locationAoE.targetloc);
				return;
			end
		elseif mutil.IsGoingOnSomeone(bot) then
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, bot, 800) 
			   and mutil.IsDisabled(true, npcTarget) == true	
			then
				bot:Action_UseAbilityOnLocation(metham, npcTarget:GetLocation());
				return;
			end
		end
	end
	
	local sv=IsItemAvailable("item_spirit_vessel");
	if sv~=nil and sv:IsFullyCastable() and sv:GetCurrentCharges() > 0
	then
		if mutil.IsGoingOnSomeone(bot)
		then
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, bot, 900) 
			   and npcTarget:HasModifier("modifier_item_spirit_vessel_damage") == false and npcTarget:GetHealth()/npcTarget:GetMaxHealth() < 0.65
			then
			    bot:Action_UseAbilityOnEntity(sv, npcTarget);
				return;
			end
		else
			local Allies=bot:GetNearbyHeroes(1150,false,BOT_MODE_NONE);
			for _,Ally in pairs(Allies) do
				if Ally:HasModifier('modifier_item_spirit_vessel_heal') == false and mutil.CanCastOnNonMagicImmune(Ally) and
				   Ally:GetHealth()/Ally:GetMaxHealth() < 0.35 and #tableNearbyEnemyHeroes == 0 and Ally:WasRecentlyDamagedByAnyHero(2.5) == false   
				then
					bot:Action_UseAbilityOnEntity(sv,Ally);
					return;
				end
			end
		end
	end
	
	local null=IsItemAvailable("item_nullifier");
	if null~=nil and null:IsFullyCastable() 
	then
		if mutil.IsGoingOnSomeone(bot)
		then	
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, bot, 800) 
			   and npcTarget:HasModifier("modifier_item_nullifier_mute") == false 
			then
			    bot:Action_UseAbilityOnEntity(null, npcTarget);
				return;
			end
		end
	end
	
	--Neutral Item Usage
	-- --item_ironwood_tree
	-- local ironwood = uItem.CanCastNeutralItem(bot, "item_ironwood_tree");
	-- if ironwood ~= nil and ironwood:IsFullyCastable() then
	-- 	local nCastRange = 600;
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
	-- 		bot:WasRecentlyDamagedByAnyHero(3.0) )
	-- 	then
	-- 		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	-- 		if #enemies > 0 and enemies[1] ~= nil and GetUnitToUnitDistance(bot, enemies[1]) > 150 then
	-- 			bot:Action_UseAbilityOnLocation(ironwood, bot:GetXUnitsTowardsLocation(enemies[1]:GetLocation(), 75));
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	-- --item_iron_talon
	-- local irontalon = uItem.CanCastNeutralItem(bot, "item_iron_talon");
	-- if irontalon ~= nil and irontalon:IsFullyCastable() then
	-- 	if bot:GetActiveMode() == BOT_MODE_FARM or mutil.IsDefending(bot) or mutil.IsPushing(bot) 
	-- 	then
	-- 		local neutrals = bot:GetNearbyCreeps(500, true);
	-- 		local maxHP = 0;
	-- 		local target = nil;
	-- 		for _,c in pairs(neutrals) do
	-- 			local cHP = c:GetHealth();
	-- 			if cHP > maxHP and not c:IsAncientCreep() then
	-- 				maxHP = cHP;
	-- 				target = c;
	-- 			end
	-- 		end
	-- 		if target ~= nil then
	-- 			bot:Action_UseAbilityOnEntity(irontalon, target);
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	--item_arcane_ring
	local arc_ring = uItem.CanCastNeutralItem(bot, "item_arcane_ring");
	if arc_ring ~= nil and arc_ring:IsFullyCastable() then
		local nRadius = 1200;
		local nRestore = 75;
		if bot:GetMana() + nRestore <= bot:GetMaxMana() then
			local allies = bot:GetNearbyHeroes(nRadius, false, BOT_MODE_NONE);
			if #allies >= 2 then
				bot:Action_UseAbility(arc_ring);
				return;
			end
		end	
		if bot:GetMana() < 100 + 10 * bot:GetLevel() then
			bot:Action_UseAbility(arc_ring);
			return;
		end
	end
	--[[
		--item_elixir
		local elix = uItem.CanCastNeutralItem(bot,"item_elixer");
		if elix ~= nil and elix:IsFullyCastable() then
			local hpRes = 500;
			local mnRes = 250;
			local nCastRange = 250 + 200;
			local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
			for i=1, #allies do
				if allies[i]:WasRecentlyDamagedByAnyHero(4.0) == false and allies[i]:HasModifier('modifier_elixer_healing') == false 
				and ( allies[i]:GetHealth() + hpRes < allies[i]:GetMaxHealth() or allies[i]:GetMana() + mnRes < allies[i]:GetMaxMana() )
				and mutil.CanCastOnNonMagicImmune(allies[i]) 
				then
					bot:Action_UseAbilityOnEntity(elix, allies[i]);
					return;
				end
			end
		end
	--]]
	
	-- --item_mango_tree
	-- local mang_tree = uItem.CanCastNeutralItem(bot,"item_mango_tree");
	-- if mang_tree ~= nil and mang_tree:IsFullyCastable() then
	-- 	local nCastRange = 200;
	-- 	bot:Action_UseAbilityOnLocation(mang_tree, bot:GetLocation() + RandomVector(nCastRange));
	-- 	return;
	-- end
	
	-- --item_royal_jelly
	-- local royal = uItem.CanCastNeutralItem(bot,"item_royal_jelly");
	-- if royal ~= nil and royal:IsFullyCastable() then
	-- 	local nCastRange = 250 + 200;
	-- 	local allies = bot:GetNearbyHeroes(nCastRange, false, BOT_MODE_NONE);
	-- 	for i=1, #allies do
	-- 		if allies[i]:HasModifier("modifier_royal_jelly") == false
	-- 		and mutil.CanCastOnNonMagicImmune(allies[i]) 
	-- 		then
	-- 			bot:Action_UseAbilityOnEntity(royal, allies[i]);
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	--item_trusty_shovel
	local shov = uItem.CanCastNeutralItem(bot,"item_trusty_shovel");
	if shov ~= nil and shov:IsFullyCastable() and bot:WasRecentlyDamagedByAnyHero(5.0) == false then
		local nCastRange = 250;
		local enemies = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE);
		if #enemies == 0 then
			bot:Action_UseAbilityOnLocation(shov, bot:GetLocation() + RandomVector(nCastRange));
			return;
		end
	end
	
	-- --item_clumsy_net
	-- local clum = uItem.CanCastNeutralItem(bot,"item_clumsy_net");
	-- if clum ~= nil and clum:IsFullyCastable() then
	-- 	local nCastRange = 650;
	-- 	if mutil.IsGoingOnSomeone(bot)
	-- 	then	
	-- 		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) 
	-- 		and mutil.IsInRange(npcTarget, bot, nCastRange+200) 
	-- 		and mutil.IsDisabled(true, npcTarget) == false
	-- 		then
	-- 		    bot:Action_UseAbilityOnEntity(clum, npcTarget);
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	--item_essence_ring
	local ess_ring = uItem.CanCastNeutralItem(bot,"item_essence_ring");
	if ess_ring ~= nil and ess_ring:IsFullyCastable() then
		local hpRes = 425;
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			( bot:GetHealth() / bot:GetMaxHealth() ) < 0.25 ) and
			bot:WasRecentlyDamagedByAnyHero(3.0)
		then
			bot:Action_UseAbility(ess_ring);
			return;
		end
	end
	
	-- --item_greater_faerie_fire
	-- local gff = uItem.CanCastNeutralItem(bot,"item_greater_faerie_fire");
	-- if gff~=nil and gff:IsFullyCastable() then
	-- 	local hpRes = 500;
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and 
	-- 		bot:DistanceFromFountain() > 0 and
	-- 		bot:WasRecentlyDamagedByAnyHero(3.0) and
	-- 		( bot:GetHealth() / bot:GetMaxHealth() ) < 0.20 ) 
	-- 	then
	-- 		bot:Action_UseAbility(gff);
	-- 		return;
	-- 	end
	-- end
	
	-- --item_repair_kit
	-- local rep_kit = uItem.CanCastNeutralItem(bot,"item_repair_kit");
	-- if rep_kit ~= nil and rep_kit:IsFullyCastable() then
	-- 	local nCastRange = 600;
	-- 	local towers = bot:GetNearbyTowers(nCastRange, false);
	-- 	for i=1, #towers do
	-- 		if towers[i]:GetHealth() <= 0.6 * towers[i]:GetMaxHealth() and towers[i]:HasModifier("modifier_repair_kit") == false then
	-- 			bot:Action_UseAbilityOnEntity(rep_kit, towers[i]);
	-- 			return;
	-- 		end
	-- 	end
	-- end
	
	--item_spider_legs
	local slegs = uItem.CanCastNeutralItem(bot,"item_spider_legs");
	if slegs ~= nil and slegs:IsFullyCastable() then
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(3.0) )
		then
			bot:Action_UseAbility(slegs);
			return;
		end
	end
	
	--item_flicker
	local flick = uItem.CanCastNeutralItem(bot,"item_flicker");
	if flick~= nil and flick:IsFullyCastable() then
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(3.0) and bot:IsRooted() == false )
		then
			bot:Action_UseAbility(flick);
			return;
		end
	end
	
	-- --item_havoc_hammer
	-- local hav_ham = uItem.CanCastNeutralItem(bot,"item_havoc_hammer");
	-- if hav_ham ~= nil and hav_ham:IsFullyCastable() then
	-- 	local nCastRange = 300;
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
	-- 		bot:WasRecentlyDamagedByAnyHero(3.0) )
	-- 	then
	-- 		local enemies = bot:GetNearbyHeroes(nCastRange, true, BOT_MODE_NONE);
	-- 		if #enemies >= 1 then
	-- 			bot:Action_UseAbility(hav_ham);
	-- 			return;	
	-- 		end
	-- 	end
	-- end
	
	-- --item_illusionsts_cape
	-- local ill_cape = uItem.CanCastNeutralItem(bot,"item_illusionsts_cape");
	-- if ill_cape ~= nil and ill_cape:IsFullyCastable() then
	-- 	local nCastRange = bot:GetAttackRange();
	-- 	if mutil.IsGoingOnSomeone(bot)
	-- 	then	
	-- 		if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) 
	-- 		and mutil.IsInRange(npcTarget, bot, nCastRange+200) 
	-- 		then
	-- 		    bot:Action_UseAbility(ill_cape);
	-- 			return;
	-- 		end
	-- 	end
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
	-- 		bot:WasRecentlyDamagedByAnyHero(1.0) )
	-- 	then
	-- 		bot:Action_UseAbility(ill_cape);
	-- 		return;
	-- 	end
	-- end
	
	--item_minotaur_horn
	local min_horn = uItem.CanCastNeutralItem(bot,"item_minotaur_horn");
	if min_horn ~= nil and min_horn:IsFullyCastable() and bot:IsMagicImmune() == false then
		local nCastRange = bot:GetAttackRange();
		if mutil.IsGoingOnSomeone(bot) and bot:WasRecentlyDamagedByAnyHero(2.0)
		then	
			if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange+200) 
			then
			    bot:Action_UseAbility(min_horn);
				return;
			end
		end
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(1.0) )
		then
			bot:Action_UseAbility(min_horn);
			return;
		end
	end
	
	--item_ninja_gear
	local nin_gear = uItem.CanCastNeutralItem(bot,"item_ninja_gear");
	if nin_gear ~= nil and nin_gear:IsFullyCastable() then
		local nCastRange = 1025
		if mutil.IsGoingOnSomeone(bot)
		then	
			if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange+200) == false 
			and mutil.IsInRange(npcTarget, bot, 2500) == true 
			then
			    bot:Action_UseAbility(nin_gear);
				return;
			end
		end
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(3.0) )
		then
			local enemies = bot:GetNearbyHeroes(nCastRange+200, true, BOT_MODE_NONE);
			if #enemies == 0 then
				bot:Action_UseAbility(nin_gear);
				return;
			end
		end
	end
	
	--item_demonicon
	local dem = uItem.CanCastNeutralItem(bot,"item_demonicon");
	if dem ~= nil and dem:IsFullyCastable() then
		local nCastRange = bot:GetAttackRange()
		if mutil.IsGoingOnSomeone(bot)
		then	
			if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange+200) == true
			then
			    bot:Action_UseAbility(dem);
				return;
			end
		end
	end
	
	--item_ex_machina
	local ex_mac = uItem.CanCastNeutralItem(bot,"item_ex_machina");
	if ex_mac ~= nil and ex_mac:IsFullyCastable() then
		local nCastRange = bot:GetAttackRange()
		if mutil.IsGoingOnSomeone(bot)
		then	
			if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange+200) == true
			then
				local nCdItem = 0;
				for i=0, 5 do
					local cdIt = bot:GetItemInSlot(i);
					if cdIt ~= nil and cdIt:GetCooldownTimeRemaining() > 10 then
						nCdItem = nCdItem + 1;
					end
				end
				if nCdItem >= 2 then
					bot:Action_UseAbility(ex_mac);
					return;
				end
			end
		end
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(1.0) )
		then
			local nCdItem = 0;
			for i=0, 5 do
				local cdIt = bot:GetItemInSlot(i);
				if cdIt ~= nil and cdIt:GetCooldownTimeRemaining() > 10 then
					nCdItem = nCdItem + 1;
				end
			end
			if nCdItem >= 2 then
				bot:Action_UseAbility(ex_mac);
				return;
			end
		end
	end
	
	--item_force_boots
	local fboot = uItem.CanCastNeutralItem(bot,"item_force_boots");
	if fboot ~= nil and fboot:IsFullyCastable() then
		if ( mode == BOT_MODE_RETREAT and 
			bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
			bot:WasRecentlyDamagedByAnyHero(1.0) and
			bot:IsFacingUnit(GetAncient(GetTeam()), 30) )
		then
			bot:Action_UseAbility(fboot);
			return;
		end
	end
	
	-- --item_woodland_striders
	-- local wood_str = uItem.CanCastNeutralItem(bot,"item_woodland_striders");
	-- if wood_str ~= nil and wood_str:IsFullyCastable() then
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
	-- 		bot:WasRecentlyDamagedByAnyHero(0.5) )
	-- 	then
	-- 		bot:Action_UseAbility(wood_str);
	-- 		return;
	-- 	end
	-- end
	
	-- --item_fusion_rune
	-- local fus_rune = uItem.CanCastNeutralItem(bot,"item_fusion_rune");
	-- if fus_rune ~= nil and fus_rune:IsFullyCastable() and DotaTime() > castFusionRuneTime + 50 then
	-- 	local nCastRange = bot:GetAttackRange();
	-- 	if mutil.IsGoingOnSomeone(bot)
	-- 	then	
	-- 		if mutil.IsValidTarget(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange+200) 
	-- 		then
	-- 			castFusionRuneTime = DotaTime();
	-- 		    bot:Action_UseAbilityOnEntity(fus_rune, bot);
	-- 			return;
	-- 		end
	-- 	end
	-- 	if ( mode == BOT_MODE_RETREAT and 
	-- 		bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH and
	-- 		bot:WasRecentlyDamagedByAnyHero(1.0) )
	-- 	then
	-- 		castFusionRuneTime = DotaTime();
	-- 		bot:Action_UseAbilityOnEntity(fus_rune, bot);
	-- 		return;
	-- 	end
	-- end
	
	--item_fallen_sky
	local fsky = uItem.CanCastNeutralItem(bot,"item_fallen_sky");
	if fsky~=nil and fsky:IsFullyCastable() then
		local nCastRange = 1600
		local nRadius = 315;
		if mutil.IsPushing(bot) then
			local towers = bot:GetNearbyTowers(800, true);
			if #towers > 0 and towers[1] ~= nil and  towers[1]:IsInvulnerable() == false then 
				bot:Action_UseAbilityOnLocation(fsky, towers[1]:GetLocation());
				return;
			end
		elseif  mutil.IsInTeamFight(bot, 1200) then
			local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius/2, 0, 0 );
			if ( locationAoE.count >= 2 ) 
			then
				bot:Action_UseAbilityOnLocation(fsky, locationAoE.targetloc);
				return;
			end
		elseif mutil.IsGoingOnSomeone(bot) then
			if mutil.IsValidTarget(npcTarget) and mutil.CanCastOnNonMagicImmune(npcTarget) and mutil.IsInRange(npcTarget, bot, nCastRange) 
			   and mutil.IsDisabled(true, npcTarget) == false	
			then
				bot:Action_UseAbilityOnLocation(fsky, npcTarget:GetLocation());
				return;
			end
		elseif mutil.IsStuck(bot)
		then
			local loc = mutil.GetEscapeLoc();
			bot:Action_UseAbilityOnLocation(fsky, bot:GetXUnitsTowardsLocation( loc, nCastRange ));
			return;
		elseif mutil.IsRetreating(bot)
		then
			local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( 1000, true, BOT_MODE_NONE );
			if ( bot:WasRecentlyDamagedByAnyHero(2.0) or bot:WasRecentlyDamagedByTower(2.0) or ( tableNearbyEnemyHeroes ~= nil and #tableNearbyEnemyHeroes > 1  ) )
			then
				local loc = mutil.GetEscapeLoc();
				bot:Action_UseAbilityOnLocation(fsky, bot:GetXUnitsTowardsLocation( loc, nCastRange ));
				return;
			end	
		end
	end
	
end

function IsItemAvailable(item_name, neutral)
    --[[for i = 0, 5 do
        local item = bot:GetItemInSlot(i);
		if item~=nil and item:GetName() == item_name then
			return item;
		end
    end]]--
	local slot = bot:FindItemSlot(item_name);
	if bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN then
		return bot:GetItemInSlot(slot);
	end
    return nil;
end

function IsTargetedByEnemy(building)
	local heroes = GetUnitList(UNIT_LIST_ENEMY_HEROES);
	for _,hero in pairs(heroes)
	do
		if ( GetUnitToUnitDistance(building, hero) <= hero:GetAttackRange() + 200 and hero:GetAttackTarget() == building ) then
			return true;
		end
	end
	return false;
end

function UseGlyph()

	if GetGlyphCooldown( ) > 0 then
		return
	end	
	
	local T1 = {
		TOWER_TOP_1,
		TOWER_MID_1,
		TOWER_BOT_1,
		TOWER_TOP_3,
		TOWER_MID_3, 
		TOWER_BOT_3, 
		TOWER_BASE_1, 
		TOWER_BASE_2
	}
	
	for _,t in pairs(T1)
	do
		local tower = GetTower(GetTeam(), t);
		if  tower ~= nil and tower:GetHealth() > 0 and tower:GetHealth()/tower:GetMaxHealth() < 0.15 and tower:GetAttackTarget() ~=  nil
		then
			bot:ActionImmediate_Glyph( )
			return
		end
	end
	

	local MeleeBarrack = {
		BARRACKS_TOP_MELEE,
		BARRACKS_MID_MELEE,
		BARRACKS_BOT_MELEE
	}
	
	for _,b in pairs(MeleeBarrack)
	do
		local barrack = GetBarracks(GetTeam(), b);
		if barrack ~= nil and barrack:GetHealth() > 0 and barrack:GetHealth()/barrack:GetMaxHealth() < 0.5 and IsTargetedByEnemy(barrack)
		then
			bot:ActionImmediate_Glyph( )
			return
		end
	end
	
	local Ancient = GetAncient(GetTeam())
	if Ancient ~= nil and Ancient:GetHealth() > 0 and Ancient:GetHealth()/Ancient:GetMaxHealth() < 0.5 and IsTargetedByEnemy(Ancient)
	then
		bot:ActionImmediate_Glyph( )
		return
	end

end

--ITEM USAGE
bot.mainSlotItem = {
	bot:GetItemInSlot(0),
	bot:GetItemInSlot(1),
	bot:GetItemInSlot(2),
	bot:GetItemInSlot(3),
	bot:GetItemInSlot(4),
	bot:GetItemInSlot(5),
	bot:GetItemInSlot(15),
}

function GetTheItem(sItem)
	for i = 1, #bot.mainSlotItem do
		if bot.mainSlotItem[i] ~=  nil and bot.mainSlotItem[i]:GetName() == sItem then
			return bot.mainSlotItem[i];
		end	
	end	
	return nil;
end	

function CanUseItem(sItem)
	local item = GetTheItem(sItem);
	if item ~= nil and item:IsFullyCastable() then
		return item;
	end	
	return false;
end

function IsItemCanBeUsed(hItem)
	return hItem ~= nil and hItem:IsFullyCastable();
end	

function UpdateBotItemTable()
	bot.mainSlotItem = {
		bot:GetItemInSlot(0),
		bot:GetItemInSlot(1),
		bot:GetItemInSlot(2),
		bot:GetItemInSlot(3),
		bot:GetItemInSlot(4),
		bot:GetItemInSlot(5),
		bot:GetItemInSlot(15),
	}
end	 

function HaveHealthRegenBuff()
	return bot:HasModifier('modifier_fountain_aura_buff') 
			or bot:HasModifier('modifier_bottle_regeneration')  
			or bot:HasModifier('modifier_flask_healing')  
			or bot:HasModifier('modifier_tango_heal')  
end

function HaveManaRegenBuff()
	return bot:HasModifier('modifier_fountain_aura_buff') 
			or bot:HasModifier('modifier_bottle_regeneration')  
			or bot:HasModifier('modifier_clarity_potion') 
end

local itemToUse = nil;

local lastToggle = -90; 
function ItemUsageThinks()
	UpdateBotItemTable();

	if 	bot:IsChanneling() 
		or bot:IsUsingAbility() 
		or bot:IsInvisible() 
		or bot:IsMuted( ) 
		or bot:HasModifier("modifier_doom_bringer_doom") 
	then
		return;
	end

	local tableNearbyEnemyHeroes = bot:GetNearbyHeroes( 1300, true, BOT_MODE_NONE );
	local mode = bot:GetActiveMode();
	local modeDesire = bot:GetActiveModeDesire();
	
	--item_courier
	itemToUse = CanUseItem('item_courier');
	if itemToUse ~= false then
		bot:Action_UseAbility(itemToUse);
		return;
	end

	--item_clarity
	itemToUse = CanUseItem('item_clarity');
	if itemToUse ~= false 
		and HaveManaRegenBuff() == false 
		and bot:GetMana() + 225 <= bot:GetMaxMana() 
		and mutil.IsGoingOnSomeone(bot) == false
	then
		bot:Action_UseAbility(itemToUse);
		return;
	end
	
	--item_tp_scroll
	itemToUse = CanUseItem('item_tpscroll');
	if itemToUse ~= false 
	then
	
	end
	
	--item_enchanted_mango
	itemToUse = CanUseItem('item_enchanted_mango');
	if itemToUse ~= false and bot:GetMana() < 0.25*bot:GetMaxMana() and mode == BOT_MODE_ATTACK 
	then
		bot:Action_UseAbility(itemToUse);
		return;
	end
	
	--item_faerie_fire
	itemToUse = CanUseItem('item_faerie_fire');
	if itemToUse ~= false 
	then
		if ( mode == BOT_MODE_RETREAT and modeDesire >= BOT_MODE_DESIRE_HIGH 
		     and bot:DistanceFromFountain() > 0 and bot:GetHealth() < 0.15*bot:GetMaxHealth() ) 
			 or DotaTime() > 10*60 
		then
			bot:Action_UseAbility(itemToUse);
			return;
		end
	end
	
	
	
	local test = CanUseItem('item_armlet');
	
	if test ~= false then
		if test:GetToggleState() == true and bot:GetHealth() <= 150 and DotaTime() > lastToggle + 0.5 then
			bot:ActionPush_UseAbility(test)
			bot:ActionPush_UseAbility(test)
			lastToggle = DotaTime()
			return
		elseif test:GetToggleState() == false then	
			bot:Action_UseAbility(test);
			return;	
		end	
	end	



end	

bot.castAmuletTime = DotaTime();
local backpack_item = {};
local update_bi_time = -90;

function UpdateBackPackItem(bot)
	local curr_time = DotaTime();
	for i=6, 8 do
		local bp_item = bot:GetItemInSlot(i);
		if bp_item ~= nil then
			backpack_item[bp_item:GetName()] = curr_time;
		end
	end
	
	if curr_time > update_bi_time + 7.0 then
		for k,v in pairs(backpack_item) do
			if v ~= nil and v + 7.0 < curr_time then
				backpack_item[k] = nil;
			end
		end
		update_bi_time = curr_time;
	end
end

function JustSwapped(item_name)
	return backpack_item[item_name] ~= nil and backpack_item[item_name] + 6.5 > DotaTime();
end

function ShouldNotUseNeutralItemFromMainSlot(item_name, slot)
	return uItem.GetNeutralItemTier(item_name) > 0 and bot:GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN
end

function ItemUsageThink()

	if bot:IsAlive() == false 
	   or bot:IsHero() == false 
	   or bot:IsMuted() == true 
	   or bot:IsHexed() == true
	   or bot:IsStunned() == true
	   or bot:IsChanneling() == true
	   or bot:IsInvulnerable() == true
	   or bot:IsUsingAbility() == true
	   or bot:IsCastingAbility() == true
	   or bot:NumQueuedActions() > 0 
	   or mutil.IsTaunted(bot) == true
	   or bot:HasModifier('modifier_teleporting') == true
	   or bot:HasModifier('modifier_doom_bringer_doom') == true
	   or bot:HasModifier('modifier_phantom_lancer_phantom_edge_boost') == true
	   or ( bot:IsInvisible() == true and not bot:HasModifier("modifier_phantom_assassin_blur_active") == true )
    then 
		return	BOT_ACTION_DESIRE_NONE 
	end
	
	local extra_range = 0;
	local aether_lens_slot_type = bot:GetItemSlotType(bot:FindItemSlot('item_aether_lens'));
	if aether_lens_slot_type == ITEM_SLOT_TYPE_MAIN 
	then
		extra_range = extra_range + 225;
	end

	local item_slot = {0,1,2,3,4,5,15,16};
	local mode = bot:GetActiveMode();
	for i=1, #item_slot do
		local item = bot:GetItemInSlot(item_slot[i]);
		if itemUseUtils.CanCastItem(item) == true 
			and JustSwapped(item:GetName()) == false
			and ShouldNotUseNeutralItemFromMainSlot(item:GetName(), item_slot[i]) == false
			and itemUseUtils.Use[item:GetName()] ~= nil
		then
			local desire, target, target_type = itemUseUtils.Use[item:GetName()](item, bot, mode, extra_range);
			if desire > BOT_ACTION_DESIRE_NONE 
			then
				if target_type == 'no_target' then
					bot:Action_UseAbility(item);
					return;
				elseif target_type == 'point' then
					bot:Action_UseAbilityOnLocation(item, target)
					return;	
				elseif target_type == 'unit' then
					bot:Action_UseAbilityOnEntity(item, target)
					return;	
				elseif target_type == 'tree' then
					bot:Action_UseAbilityOnTree(item, target)
					return;	
				end
			end
		end	
	end
end

return MyModule;

