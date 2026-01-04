local function IronmonConnect()
	local self = {
		version = "1.0",
		name = "ironmonConnect",
		author = "WaffleSmacker",
		description = "Created for ironmonConnect. Used to send data to the website.",
		github = "WaffleSmacker/IronmonConnect-IronmonExtension",
	}

	self.url = string.format("https://github.com/%s", self.github)
	
	local directoryCreated = false

	function self.checkForUpdates()
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github)
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+)"'
		local downloadUrl = string.format("https://github.com/%s/releases/latest", self.github)
		local compareFunc = function(a, b) return a ~= b and not Utils.isNewerVersion(a, b) end
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	self.DATA_OUTPUT_FILE = "tracker_output.json"
	self.DEBUG_OUTPUT_FILE = "ironmonconnect_debug.txt"

	self.Paths = {
		DataOutput = "",
		DebugOutput = "",
	}

	-- --- DEBUG LOGGING --- (Disabled)
	local function log(message)
		-- Debug logging disabled
	end

	local function escapeJson(str)
		if not str then return "" end
		str = tostring(str)
		str = string.gsub(str, "\\", "\\\\")
		str = string.gsub(str, '"', '\\"')
		str = string.gsub(str, "\n", "\\n")
		str = string.gsub(str, "\r", "\\r")
		str = string.gsub(str, "\t", "\\t")
		return str
	end

	local function getTotalDefeatedTrainers(includeSevii)
		includeSevii = includeSevii or false
		local saveBlock1Addr = Utils.getSaveBlock1Addr()
		local totalDefeated = 0

		for mapId, route in pairs(RouteData.Info or {}) do
			if mapId and (mapId < 230 or includeSevii) then
				if route.trainers and #route.trainers > 0 then
					local defeatedTrainers = Program.getDefeatedTrainersByLocation(mapId, saveBlock1Addr)
					if type(defeatedTrainers) == "table" then
						totalDefeated = totalDefeated + #defeatedTrainers
					end
				end
			end
		end
		return totalDefeated
	end
	
	local validItemIds = {
		[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true,
		[7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true,
		[13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true,
		[19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [26] = true,
		[27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true,
		[34] = true, [35] = true, [36] = true, [37] = true, [38] = true, [44] = true,
		[68] = true, [69] = true, [71] = true,
		[93] = true, [94] = true, [95] = true, [96] = true, [97] = true, [98] = true,
		[133] = true, [134] = true, [135] = true, [136] = true, [137] = true, [138] = true,
		[139] = true, [140] = true, [141] = true, [142] = true,
		[291] = true, [292] = true, [294] = true, [307] = true, [314] = true,
		[322] = true, [326] = true, [327] = true
	}
	
	local function isValidItemId(itemID)
		if type(itemID) == "number" then
			return validItemIds[itemID] == true
		elseif type(itemID) == "string" then
			local numId = tonumber(itemID)
			return numId and validItemIds[numId] == true
		end
		return false
	end
	
	local getTrackedItems
	local getPivotData
	
	getTrackedItems = function()
		local items = {
			balls = {}, evolution = {}, gymtm = {}, hp = {}, pp = {}, status = {}, others = {},
		}

		local function addItem(categoryKey, itemID, quantity)
			if not quantity or quantity <= 0 or not isValidItemId(itemID) then return end
			local itemId = tonumber(itemID) or itemID
			local category = items[categoryKey]
			if not category then return end
			table.insert(category, { id = itemId, quantity = quantity })
		end

		local function getTMsFromBag()
			local tms = {}
			local key = Utils.getEncryptionKey(2)
			local saveBlock1Addr = Utils.getSaveBlock1Addr()
			local address = saveBlock1Addr + GameSettings.bagPocket_TmHm_offset
			local size = GameSettings.bagPocket_TmHm_Size

			for i = 0, (size - 1), 1 do
				local itemid_and_quantity = Memory.readdword(address + i * 4)
				local itemID = Utils.getbits(itemid_and_quantity, 0, 16)
				if isValidItemId(itemID) then
					local quantity = Utils.getbits(itemid_and_quantity, 16, 16)
					if key ~= nil then quantity = Utils.bit_xor(quantity, key) end
					if quantity > 0 then tms[itemID] = quantity end
				end
			end
			return tms
		end

		if Program.GameData and Program.GameData.Items then
			local function processCategory(source, targetCat, idMap)
				if source and type(source) == "table" then
					for itemID, quantity in pairs(source) do
						if not idMap or idMap[tonumber(itemID) or itemID] then
							addItem(targetCat, itemID, quantity)
						end
					end
				end
			end

			processCategory(Program.GameData.Items.PokeBalls, "balls")
			processCategory(Program.GameData.Items.EvoStones, "evolution")
			processCategory(Program.GameData.Items.HPHeals, "hp")
			processCategory(Program.GameData.Items.PPHeals, "pp")
			processCategory(Program.GameData.Items.StatusHeals, "status")

			local gymTmIds = { [291]=true, [292]=true, [294]=true, [307]=true, [314]=true, [322]=true, [326]=true, [327]=true }
			local tmItems = getTMsFromBag()
			if tmItems then
				for itemID, quantity in pairs(tmItems) do
					if gymTmIds[tonumber(itemID) or itemID] then addItem("gymtm", itemID, quantity) end
				end
			end

			local ppItemIds = { [69]=true, [71]=true }
			processCategory(Program.GameData.Items.Other, "pp", ppItemIds)
			local othersItemIds = { [68]=true }
			processCategory(Program.GameData.Items.Other, "others", othersItemIds)
		end
		return items
	end

	local function getEncounterMethod(encounterArea)
		if encounterArea == RouteData.EncounterArea.SURFING then return "surf"
		elseif encounterArea == RouteData.EncounterArea.OLDROD or
		       encounterArea == RouteData.EncounterArea.GOODROD or
		       encounterArea == RouteData.EncounterArea.SUPERROD then
			return "rod"
		end
		return nil
	end

	getPivotData = function()
		local pivotData = {}
		local pivotMapIds = RouteData.getPivotOrSafariRouteIds(false) or {}
		local safariMapIds = RouteData.getPivotOrSafariRouteIds(true) or {}
		
		local allMapIds = {}
		local mapIdSet = {}
		local function addMap(id)
			id = tonumber(id)
			if id and not mapIdSet[id] then 
				table.insert(allMapIds, id)
				mapIdSet[id] = true 
			end
		end

		for _, mapId in ipairs(pivotMapIds) do addMap(mapId) end
		for _, mapId in ipairs(safariMapIds) do addMap(mapId) end
		
		-- Safely add Safari Zone maps
		if GameSettings.game == 3 then
			addMap(149); addMap(150); addMap(151); addMap(152)
		end
		
		-- Ensure we include any maps we found fishing encounters on
		if self.PerSeedVars and self.PerSeedVars.fishingEncounters then
			for mapId, _ in pairs(self.PerSeedVars.fishingEncounters) do
				addMap(mapId)
			end
		end
		
		for _, mapId in ipairs(allMapIds) do
			local encountersByMethod = {} 
			
			-- 1. Load Fishing Encounters
			local fishingEncounters = self.PerSeedVars and self.PerSeedVars.fishingEncounters
			if fishingEncounters then
				local fishingRouteData = fishingEncounters[mapId] or fishingEncounters[tostring(mapId)] or fishingEncounters[tonumber(mapId)]
				
				if fishingRouteData then
					for pokemonId, _ in pairs(fishingRouteData) do
						if PokemonData.isValid(pokemonId) then
							if not encountersByMethod[pokemonId] then encountersByMethod[pokemonId] = {} end
							encountersByMethod[pokemonId]["rod"] = true
						end
					end
				end
			end
			
			-- 2. Load Standard Encounters
			local encounterAreas = { RouteData.EncounterArea.LAND }
			if RouteData.EncounterArea.SURFING then table.insert(encounterAreas, RouteData.EncounterArea.SURFING) end
			if RouteData.EncounterArea.OLDROD then table.insert(encounterAreas, RouteData.EncounterArea.OLDROD) end
			if RouteData.EncounterArea.GOODROD then table.insert(encounterAreas, RouteData.EncounterArea.GOODROD) end
			if RouteData.EncounterArea.SUPERROD then table.insert(encounterAreas, RouteData.EncounterArea.SUPERROD) end
			
			for _, encounterArea in ipairs(encounterAreas) do
				local seenIds = Tracker.getRouteEncounters(mapId, encounterArea) or {}
				local method = getEncounterMethod(encounterArea)
				
				for _, pokemonId in ipairs(seenIds) do
					if PokemonData.isValid(pokemonId) then
						if not encountersByMethod[pokemonId] then encountersByMethod[pokemonId] = {} end
						if method then
							encountersByMethod[pokemonId][method] = true
						else
							encountersByMethod[pokemonId]._encountered = true
						end
					end
				end
			end
			
			-- 3. Build Output
			if next(encountersByMethod) then
				pivotData[mapId] = {}
				for pokemonId, methods in pairs(encountersByMethod) do
					local methodList = {}
					for method, _ in pairs(methods) do
						if method ~= "_encountered" then table.insert(methodList, method) end
					end
					table.sort(methodList)
					
					local entry
					-- If any special method (rod/surf) exists, use Object Format
					if #methodList > 0 then
						entry = { id = pokemonId, method = methodList[1] }
					else
						-- Otherwise standard integer
						entry = pokemonId
					end
					table.insert(pivotData[mapId], entry)
				end
				table.sort(pivotData[mapId], function(a, b) 
					local idA = type(a) == "table" and a.id or a
					local idB = type(b) == "table" and b.id or b
					return idA < idB 
				end)
			end
		end
		return pivotData
	end

	local function compareItemCategory(current, previous)
		if not previous then return #current > 0 end
		if #current ~= #previous then return true end
		local currentLookup = {}
		for _, heal in ipairs(current) do currentLookup[tostring(heal.id) .. "_" .. tostring(heal.quantity)] = true end
		local previousLookup = {}
		for _, heal in ipairs(previous) do previousLookup[tostring(heal.id) .. "_" .. tostring(heal.quantity)] = true end
		for key, _ in pairs(currentLookup) do if not previousLookup[key] then return true end end
		for key, _ in pairs(previousLookup) do if not currentLookup[key] then return true end end
		return false
	end

	local function itemsChanged(current, previous)
		if not previous then return true end
		local categoriesToCheck = {"balls", "evolution", "gymtm", "hp", "pp", "status", "others"}
		for _, category in ipairs(categoriesToCheck) do
			if compareItemCategory(current[category] or {}, previous[category] or {}) then return true end
		end
		return false
	end

	local function pivotsChanged(current, previous)
		current = current or {}
		previous = previous or {}
		for mapId, currentList in pairs(current) do
			local previousList = previous[mapId]
			if not previousList or #currentList ~= #previousList then return true end
			for i = 1, #currentList do
				local idC = type(currentList[i]) == "table" and currentList[i].id or currentList[i]
				local idP = type(previousList[i]) == "table" and previousList[i].id or previousList[i]
				local methC = type(currentList[i]) == "table" and currentList[i].method or nil
				local methP = type(previousList[i]) == "table" and previousList[i].method or nil
				if idC ~= idP or methC ~= methP then return true end
			end
		end
		for mapId, _ in pairs(previous) do if current[mapId] == nil then return true end end
		return false
	end

	local function getCurrentValues(pokemon)
		if not PokemonData.isValid(pokemon.pokemonID) then return nil end
		local values = {}
		values.pokemonId = PokemonData.Pokemon[pokemon.pokemonID].pokemonID
		values.abilityName = PokemonData.getAbilityId(pokemon.pokemonID, pokemon.abilityNum)
		values.level = pokemon.level or 0
		values.hp = pokemon.stats.hp or 0
		values.atk = pokemon.stats.atk or 0
		values.def = pokemon.stats.def or 0
		values.spa = pokemon.stats.spa or 0
		values.spd = pokemon.stats.spd or 0
		values.spe = pokemon.stats.spe or 0
		values.move_1 = MoveData.Moves[pokemon.moves[1].id].id
		values.move_2 = MoveData.Moves[pokemon.moves[2].id].id
		values.move_3 = MoveData.Moves[pokemon.moves[3].id].id
		values.move_4 = MoveData.Moves[pokemon.moves[4].id].id
		values.trainersDefeated = getTotalDefeatedTrainers(false)
		values.items = getTrackedItems()
		values.pivots = getPivotData()
		return values
	end

	local function valuesChanged(current, previous)
		if not previous then return true end
		return current.pokemonId ~= previous.pokemonId or
		       current.abilityName ~= previous.abilityName or
			   current.level ~= previous.level or
			   current.trainersDefeated ~= previous.trainersDefeated or
		       itemsChanged(current.items, previous.items) or
		       pivotsChanged(current.pivots, previous.pivots)
	end

	local function writeSimplifiedDataToFile(values)
		local file = io.open(self.Paths.DataOutput, "w")
		if not file then return false end
		
		local jsonContent = "{\n"
		jsonContent = jsonContent .. '  "pokemonId": ' .. tostring(values.pokemonId) .. ",\n"
		jsonContent = jsonContent .. '  "abilityName": ' .. tostring(values.abilityName) .. ",\n"
		jsonContent = jsonContent .. '  "level": ' .. tostring(values.level) .. ",\n"
		jsonContent = jsonContent .. '  "hp": ' .. tostring(values.hp) .. ",\n"
		jsonContent = jsonContent .. '  "atk": ' .. tostring(values.atk) .. ",\n"
		jsonContent = jsonContent .. '  "def": ' .. tostring(values.def) .. ",\n"
		jsonContent = jsonContent .. '  "spa": ' .. tostring(values.spa) .. ",\n"
		jsonContent = jsonContent .. '  "spd": ' .. tostring(values.spd) .. ",\n"
		jsonContent = jsonContent .. '  "spe": ' .. tostring(values.spe) .. ",\n"
		jsonContent = jsonContent .. '  "move_1": ' .. tostring(values.move_1) .. ",\n"
		jsonContent = jsonContent .. '  "move_2": ' .. tostring(values.move_2) .. ",\n"
		jsonContent = jsonContent .. '  "move_3": ' .. tostring(values.move_3) .. ",\n"
		jsonContent = jsonContent .. '  "move_4": ' .. tostring(values.move_4) .. ",\n"
		jsonContent = jsonContent .. '  "trainersDefeated": ' .. tostring(values.trainersDefeated) .. ",\n"
		
		jsonContent = jsonContent .. '  "items": {\n'
		local function formatHealCategory(categoryName, healArray)
			jsonContent = jsonContent .. '    "' .. categoryName .. '": [\n'
			for i, heal in ipairs(healArray or {}) do
				local isLast = (i == #healArray)
				local idValue = type(heal.id) == "number" and tostring(heal.id) or '"' .. escapeJson(tostring(heal.id)) .. '"'
				jsonContent = jsonContent .. '      {\n        "id": ' .. idValue .. ',\n        "quantity": ' .. tostring(heal.quantity) .. '\n      }' .. (isLast and "" or ",") .. "\n"
			end
			jsonContent = jsonContent .. '    ]'
		end
		
		local items = values.items or { balls = {}, evolution = {}, gymtm = {}, hp = {}, pp = {}, status = {}, others = {} }
		formatHealCategory("balls", items.balls); jsonContent = jsonContent .. ",\n"
		formatHealCategory("evolution", items.evolution); jsonContent = jsonContent .. ",\n"
		formatHealCategory("gymtm", items.gymtm); jsonContent = jsonContent .. ",\n"
		formatHealCategory("hp", items.hp); jsonContent = jsonContent .. ",\n"
		formatHealCategory("pp", items.pp); jsonContent = jsonContent .. ",\n"
		formatHealCategory("status", items.status); jsonContent = jsonContent .. ",\n"
		formatHealCategory("others", items.others); jsonContent = jsonContent .. "\n"
		jsonContent = jsonContent .. '  },\n'

		jsonContent = jsonContent .. '  "pivots": {\n'
		local pivotData = values.pivots or {}
		local routeIds = {}
		for mapId in pairs(pivotData) do table.insert(routeIds, mapId) end
		table.sort(routeIds, function(a, b) return tostring(a) < tostring(b) end)
		for index, mapId in ipairs(routeIds) do
			jsonContent = jsonContent .. string.format('    "%s": [\n', tostring(mapId))
			local pokemonList = pivotData[mapId] or {}
			for i, pokemonEntry in ipairs(pokemonList) do
				if type(pokemonEntry) == "table" and pokemonEntry.id then
					jsonContent = jsonContent .. string.format('      {\n        "id": %s', tostring(pokemonEntry.id))
					if pokemonEntry.method then
						jsonContent = jsonContent .. string.format(',\n        "method": "%s"', escapeJson(pokemonEntry.method))
					end
					jsonContent = jsonContent .. '\n      }'
				else
					jsonContent = jsonContent .. string.format('      %s', tostring(pokemonEntry))
				end
				if i < #pokemonList then jsonContent = jsonContent .. "," end
				jsonContent = jsonContent .. "\n"
			end
			jsonContent = jsonContent .. '    ]'
			if index < #routeIds then jsonContent = jsonContent .. "," end
			jsonContent = jsonContent .. "\n"
		end
		jsonContent = jsonContent .. '  }\n'
		jsonContent = jsonContent .. "}"
		
		file:write(jsonContent)
		file:close()
		return true, ""
	end

	self.PerSeedVars = {
		FirstPokemonChosen = false,
		LastValues = nil,
		fishingCountdown = 0,
		fishingMapId = nil,
		fishingEncounters = {},
		lastValidMapId = nil,
	}

	function self.resetSeedVars()
		local V = self.PerSeedVars
		V.FirstPokemonChosen = false
		V.LastValues = nil
		V.fishingCountdown = 0
		V.fishingMapId = nil
		V.fishingEncounters = {}
		V.lastValidMapId = nil
	end

	local loadedVarsThisSeed
	local function isPlayingFRLG() return GameSettings.game == 3 end

	-- Helper to robustly get Map ID
	local function getRobustMapId()
		local id = nil
		if TrackerAPI and TrackerAPI.getMapId then id = TrackerAPI.getMapId() end
		if not id and Program and Program.GameData and Program.GameData.mapId then id = Program.GameData.mapId end
		if not id and Battle and Battle.CurrentRoute and Battle.CurrentRoute.mapId then id = Battle.CurrentRoute.mapId end
		if id and id > 0 then return id end
		return nil
	end

	function self.afterProgramDataUpdate()
		if not isPlayingFRLG() or not Program.isValidMapLocation() then return
		elseif not loadedVarsThisSeed then self.resetSeedVars(); loadedVarsThisSeed = true end

		local V = self.PerSeedVars
		local leadPokemon = Tracker.getPokemon(1, true) or Tracker.getDefaultPokemon()

		if not V.FirstPokemonChosen and PokemonData.isValid(leadPokemon.pokemonID) then
			V.FirstPokemonChosen = true
		end

		local currentGoodMapId = getRobustMapId()
		if currentGoodMapId then V.lastValidMapId = currentGoodMapId end

		local fishingTriggered = false
		local triggerReason = ""
		
		-- FIXED TRIGGER LOGIC: Only trigger if stat increases by exactly 1.
		-- This filters out massive changes caused by loading save states or resets.
		if Constants and Constants.GAME_STATS and Constants.GAME_STATS.FISHING_CAPTURES then
			if not Tracker.Data then Tracker.Data = {} end
			local currentFishingStat = Utils.getGameStat(Constants.GAME_STATS.FISHING_CAPTURES)
			
			if Tracker.Data.gameStatsFishing == nil then
				Tracker.Data.gameStatsFishing = currentFishingStat
			else
				local diff = currentFishingStat - Tracker.Data.gameStatsFishing
				if diff == 1 then
					fishingTriggered = true
					triggerReason = "Stat Incremented"
				end
				Tracker.Data.gameStatsFishing = currentFishingStat
			end
		end

		if fishingTriggered then
			V.fishingCountdown = 300
			V.fishingMapId = nil
			
			local bestId = getRobustMapId() or V.lastValidMapId
			if bestId then
				V.fishingMapId = bestId
			end
		end

		if V.fishingCountdown > 0 then
			if not V.fishingMapId then
				local recoveredId = getRobustMapId() or V.lastValidMapId
				if recoveredId then
					V.fishingMapId = recoveredId
				end
			end

			-- FIXED: Correctly look for the ENEMY pokemon (isOwn=false, index=1)
			local enemyPokemon = Tracker.getPokemon(1, false)
			
			if enemyPokemon and PokemonData.isValid(enemyPokemon.pokemonID) then
				if V.fishingMapId then
					local currentMapId = tonumber(V.fishingMapId) or V.fishingMapId
					local pokemonId = enemyPokemon.pokemonID
					
					-- FORCE SAVE the encounter
					if not V.fishingEncounters[currentMapId] then V.fishingEncounters[currentMapId] = {} end
					if not V.fishingEncounters[currentMapId][pokemonId] then
						V.fishingEncounters[currentMapId][pokemonId] = true
						V.LastValues = nil -- Force write
						V.fishingCountdown = 0 -- Close window
					end
				end
			else
				V.fishingCountdown = V.fishingCountdown - 1
			end
		end

		if Program.isValidMapLocation() and PokemonData.isValid(leadPokemon.pokemonID) and V.FirstPokemonChosen then
			local currentValues = getCurrentValues(leadPokemon)
			if currentValues and valuesChanged(currentValues, V.LastValues) then
				writeSimplifiedDataToFile(currentValues)
				V.LastValues = currentValues
			end
		end
	end

	function self.startup()
		local extFolderPath = FileManager.getCustomFolderPath() .. "ironmonConnect" .. FileManager.slash
		self.Paths.DataOutput = extFolderPath .. self.DATA_OUTPUT_FILE
		self.Paths.DebugOutput = extFolderPath .. self.DEBUG_OUTPUT_FILE
		
		local file = io.open(self.Paths.DataOutput, "w")
		if not file then
			if not directoryCreated then
				os.execute("mkdir \"" .. extFolderPath .. "\" 2>nul")
				directoryCreated = true
				file = io.open(self.Paths.DataOutput, "w")
			end
		else
			directoryCreated = true
		end
		
		if file then file:write("{}"); file:close() end
	end

	function self.unload() end

	return self
end
return IronmonConnect