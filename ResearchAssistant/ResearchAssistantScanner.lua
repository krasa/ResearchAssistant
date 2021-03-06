ResearchAssistantScanner = ZO_Object:Subclass()
local libResearch = LibResearch
if libResearch == nil and LibStub then libResearch = LibStub("LibResearch", true) end
if libResearch == nil then d("[ResearchAssistant]Needed library \"LibResearch\" was not loaded. This addon won't work without this library!") return end

local BLACKSMITH = CRAFTING_TYPE_BLACKSMITHING
local CLOTHIER = CRAFTING_TYPE_CLOTHIER
local WOODWORK = CRAFTING_TYPE_WOODWORKING
local JEWELRY_CRAFTING = CRAFTING_TYPE_JEWELRYCRAFTING


function ResearchAssistantScanner:Initialize(settings)
	self.ownedTraits = {}
	self.ownedTraits_Bank = nil
	self.ownedTraits_SubscriberBank = nil
	self.isScanning = false
	self.scanMore = 0
	self.settingsPtr = settings
	self.bankScanEnabled = false
	self.debug = false

	self:RescanBags()
end

function ResearchAssistantScanner:SetBankScanEnabled(value)
	self.bankScanEnabled=value
end

function ResearchAssistantScanner:GetBankScanEnabled()
	return self.bankScanEnabled
end

function ResearchAssistantScanner:SetDebug(value)
	self.debug=value
end

function ResearchAssistantScanner:GetDebug()
	return self.debug
end

function ResearchAssistantScanner:New(...)
	local obj = ZO_Object.New(self)
	obj:Initialize(...)
	return obj
end

function ResearchAssistantScanner:IsScanning()
	return self.isScanning
end

function ResearchAssistantScanner:CreateItemPreferenceValue(itemLink, bagId, slotIndex)
	local quality = GetItemLinkQuality(itemLink)
	if not quality then
		quality = 1
	end

	local level = GetItemLinkRequiredLevel(itemLink)
	if not level then
		level = 1
	end

	local where = 4
	if bagId == BAG_BACKPACK then
		where = 2
	elseif bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK then
		where = 1
	elseif bagId == BAG_GUILDBANK then
		where = 3
	end

	--wxxxyzzz
	--the lowest preference value is the "preferred" value
	--bank is lowest number, will be orange if you have a dupe in your inventory
	--bag is middle number, will be yellow if you have a dupe in the inventory
	--gbank is highest number, will be yellow if you have a dupe in the inventory
	return quality * 10000000 + level * 10000 + where * 1000 + (slotIndex or 0)
end

function ResearchAssistantScanner:ScanBag(bagId)
	local traits = {}
	local numSlots = GetBagSize(bagId)
	for i = 0, numSlots do
		local itemLink = GetItemLink(bagId, i)
		if itemLink ~= "" then
			local traitKey, isResearchable, reason = self:CheckIsItemResearchable(itemLink)
			local prefValue = self:CreateItemPreferenceValue(itemLink, bagId, i)
			if self.debug == true then
				d(bagId,i)
				if bagId == BAG_BACKPACK and reason ~= "WrongItemType" then
					d(i..". "..GetItemLinkName(itemLink)..": trait "..tostring(traitKey).." can? "..tostring(isResearchable).." why? "..tostring(reason).." pref "..prefValue)
				end
			end
			--is this item researchable?
			if isResearchable then
				-- if so, is this item preferable to the one we already have on record?
				if prefValue < (traits[traitKey] or 999999999999999999) then
					traits[traitKey] = prefValue
				end
			else
				--if we're here,
				if reason == "AlreadyKnown" then
					--either we already know it
					traits[traitKey] = true
				else
					--or it has no trait, in which case we ignore it
					traits[traitKey] = nil
				end
			end
		end
	end
	return traits
end

function ResearchAssistantScanner:JoinCachedOwnedTraits(traits)
	if not traits then return end
	for traitKey, value in pairs(traits) do
		if value or value < (self.ownedTraits[traitKey] or 999999999999999999)  then
			self.ownedTraits[traitKey] = value
		end
	end
end

function ResearchAssistantScanner:ScanKnownTraits()
	for researchLineIndex = 1, GetNumSmithingResearchLines(BLACKSMITH) do
		for traitIndex = 1, 9 do
			if self:WillCharacterKnowTrait(BLACKSMITH, researchLineIndex, traitIndex) then
				self.ownedTraits[self:GetTraitKey(BLACKSMITH, researchLineIndex, traitIndex)] = true
			end
		end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(CLOTHIER) do
		for traitIndex = 1, 9 do
			if self:WillCharacterKnowTrait(CLOTHIER, researchLineIndex, traitIndex) then
				self.ownedTraits[self:GetTraitKey(CLOTHIER, researchLineIndex, traitIndex)] = true
			end
		end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(WOODWORK) do
		for traitIndex = 1, 9 do
			if self:WillCharacterKnowTrait(WOODWORK, researchLineIndex, traitIndex) then
				self.ownedTraits[self:GetTraitKey(WOODWORK, researchLineIndex, traitIndex)] = true
			end
		end
	end
	for researchLineIndex = 1, GetNumSmithingResearchLines(JEWELRY_CRAFTING) do
		for traitIndex = 1, 9 do
			if self:WillCharacterKnowTrait(JEWELRY_CRAFTING, researchLineIndex, traitIndex) then
				self.ownedTraits[self:GetTraitKey(JEWELRY_CRAFTING, researchLineIndex, traitIndex)] = true
			end
		end
	end
end

function ResearchAssistantScanner:RescanBags()
	if self.isScanning then
		self.scanMore = self.scanMore + 1
		return
	end
	self.isScanning = true

	local startTime
	if self.debug == true then
		d("[ReasearchAssistant]Scanner:ScanBags()")
		startTime = GetGameTimeMilliseconds()
	end
	self.ownedTraits = self:ScanBag(BAG_BACKPACK)
	if self.debug == true then
		d(">backpack scan elapsed: ".. (GetGameTimeMilliseconds()-startTime))
	end

	if(self.bankScanEnabled or self.ownedTraits_Bank==nil) then
		if self.debug == true then
			startTime = GetGameTimeMilliseconds()
		end
		self.ownedTraits_Bank = {}
		self.ownedTraits_Bank = self:ScanBag(BAG_BANK)
		if self.debug == true then
			d(">bank scan elapsed: ".. (GetGameTimeMilliseconds()-startTime))
			startTime = GetGameTimeMilliseconds()
		end
		self.ownedTraits_SubscriberBank = {}
		self.ownedTraits_SubscriberBank = self:ScanBag(BAG_SUBSCRIBER_BANK)
		if self.debug == true then
			d(">subscriber bank scan elapsed: ".. (GetGameTimeMilliseconds()-startTime))
		end

		--Todo: House banks 1 to 10

		self:JoinCachedOwnedTraits(self.ownedTraits_Bank)
		self:JoinCachedOwnedTraits(self.ownedTraits_SubscriberBank)
	end

	self:ScanKnownTraits()
	self.settingsPtr:SetKnownTraits(self.ownedTraits)

	if self.scanMore ~= 0 then
		self.scanMore = self.scanMore - 1
		self.isScanning = false
		self:RescanBags()
	else
		self.isScanning = false
	end
end

function ResearchAssistantScanner:GetTrait(traitKey)
	return self.ownedTraits[traitKey]
end

-- returns int traitKey, bool isResearchable, string reason ["WrongItemType" "Ornate" "Intricate" "Traitless" "AlreadyKnown"]
function ResearchAssistantScanner:CheckIsItemResearchable(itemLink)
	return libResearch:GetItemTraitResearchabilityInfo(itemLink)
end

function ResearchAssistantScanner:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
	return libResearch:GetTraitKey(craftingSkillType, researchLineIndex, traitIndex)
end

function ResearchAssistantScanner:GetItemCraftingSkill(itemLink)
	return libResearch:GetItemCraftingSkill(itemLink)
end

function ResearchAssistantScanner:GetResearchTraitIndex(itemLink)
	return libResearch:GetResearchTraitIndex(itemLink)
end

function ResearchAssistantScanner:GetResearchLineIndex(itemLink)
	return libResearch:GetResearchLineIndex(itemLink)
end

function ResearchAssistantScanner:GetItemResearchInfo(itemLink)
	return libResearch:GetItemResearchInfo(itemLink)
end

function ResearchAssistantScanner:IsBigThreeCrafting(craftingSkillType)
	return libResearch:IsBigThreeCrafting(craftingSkillType)
end

function ResearchAssistantScanner:WillCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
	return libResearch:WillCharacterKnowTrait(craftingSkillType, researchLineIndex, traitIndex)
end