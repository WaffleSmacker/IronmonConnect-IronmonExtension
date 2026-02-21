local function IronmonConnect()
	local self = {
		version = "2.1",
		name = "IronmonConnect",
		author = "WaffleSmacker",
		description = "Created for IronmonConnect. Used to send data to the website. Click options to launch the IronmonConnect application.",
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

	-- Executed when the user clicks the "Options" button while viewing the extension details within the Tracker's UI
	function self.configureOptions()
		if not Main.IsOnBizhawk() then return end

		-- Get the ironmonConnect folder path (one level deeper from extensions folder)
		local extFolderPath = FileManager.getCustomFolderPath() .. "ironmonConnect" .. FileManager.slash
		local exePath = extFolderPath .. "ironmonConnect.exe"
		
		-- Try to launch the exe program directly
		-- If it doesn't exist, open the folder instead so user can see what's there
		local file = io.open(exePath, "r")
		if file then
			-- Exe exists, launch it
			file:close()
			-- Use start command on Windows to launch the exe
			os.execute('start "" "' .. exePath .. '"')
		else
			-- Exe doesn't exist, open the folder in explorer
			os.execute('explorer "' .. extFolderPath .. '"')
		end
	end

	self.DATA_OUTPUT_FILE = "tracker_output.json"
	self.DEBUG_OUTPUT_FILE = "ironmonconnect_debug.txt"

	self.Paths = {
		DataOutput = "",
		DebugOutput = "",
	}

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
	local getRandomSeed
	local getBadgeCount
	
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

		if GameSettings.game == 3 then
			addMap(149); addMap(150); addMap(151); addMap(152)
		end
		
		if self.PerSeedVars and self.PerSeedVars.fishingEncounters then
			for mapId, _ in pairs(self.PerSeedVars.fishingEncounters) do
				addMap(mapId)
			end
		end
		
		for _, mapId in ipairs(allMapIds) do
			local encountersByMethod = {}

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
			
			if next(encountersByMethod) then
				pivotData[mapId] = {}
				for pokemonId, methods in pairs(encountersByMethod) do
					local methodList = {}
					for method, _ in pairs(methods) do
						if method ~= "_encountered" then table.insert(methodList, method) end
					end
					table.sort(methodList)
					
					local entry
					if #methodList > 0 then
						entry = { id = pokemonId, method = methodList[1] }
					else
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

	getBadgeCount = function()
		local badgeCount = 0
		if Program.hasDefeatedTrainer(414) then badgeCount = badgeCount + 1 end -- Brock
		if Program.hasDefeatedTrainer(415) then badgeCount = badgeCount + 1 end -- Misty
		if Program.hasDefeatedTrainer(416) then badgeCount = badgeCount + 1 end -- Surge
		if Program.hasDefeatedTrainer(417) then badgeCount = badgeCount + 1 end -- Erika
		if Program.hasDefeatedTrainer(418) then badgeCount = badgeCount + 1 end -- Koga
		if Program.hasDefeatedTrainer(420) then badgeCount = badgeCount + 1 end -- Sabrina
		if Program.hasDefeatedTrainer(419) then badgeCount = badgeCount + 1 end -- Blaine
		if Program.hasDefeatedTrainer(350) then badgeCount = badgeCount + 1 end -- Giovanni
		return badgeCount
	end

	getRandomSeed = function()
		local randomSeed = nil
		local success, result = pcall(function()
			if type(RandomizerLog) == "table" and type(RandomizerLog.Data) == "table" then
				-- Check if already parsed
				if type(RandomizerLog.Data.Settings) == "table" then
					local seed = RandomizerLog.Data.Settings.RandomSeed
					if seed then
						if type(seed) == "string" and seed ~= "" then
							local numSeed = tonumber(seed)
							if numSeed then return numSeed end
						elseif type(seed) == "number" then
							return seed
						end
					end
				end

				-- Try to find and read the log file
				local logPath = nil
				if type(RandomizerLog.loadedLogPath) == "string" and RandomizerLog.loadedLogPath ~= "" then
					logPath = RandomizerLog.loadedLogPath
				end
				if (not logPath or not FileManager.fileExists(logPath)) and type(LogOverlay) == "table" and type(LogOverlay.getLogFileAutodetected) == "function" then
					logPath = LogOverlay.getLogFileAutodetected()
				end
				if (not logPath or not FileManager.fileExists(logPath)) then
					local customFolderPath = FileManager.getCustomFolderPath()
					if customFolderPath and customFolderPath ~= "" then
						local trimmedPath = customFolderPath:match("^(.+)[/\\]$") or customFolderPath
						local trackerFolder = trimmedPath:match("^(.+)[/\\][^/\\]+$") or trimmedPath
						if trackerFolder and trackerFolder ~= "" then
							local possibleLogs = FileManager.getFilesInDirectory(trackerFolder, "*.log")
							if possibleLogs and #possibleLogs > 0 then
								for _, logFile in ipairs(possibleLogs) do
									local fullPath = trackerFolder .. FileManager.slash .. logFile
									if FileManager.fileExists(fullPath) then
										logPath = fullPath
										break
									end
								end
							end
						end
					end
				end

				if logPath and FileManager.fileExists(logPath) then
					local logLines = FileManager.readLinesFromFile(logPath)
					if logLines and #logLines >= 2 then
						if type(RandomizerLog.parseRandomizerSettings) == "function" then
							RandomizerLog.parseRandomizerSettings(logLines)
							if type(RandomizerLog.Data.Settings) == "table" then
								local seed = RandomizerLog.Data.Settings.RandomSeed
								if seed then
									if type(seed) == "string" and seed ~= "" then
										local numSeed = tonumber(seed)
										if numSeed then return numSeed end
									elseif type(seed) == "number" then
										return seed
									end
								end
							end
						end
						if type(RandomizerLog.Patterns) == "table" and type(RandomizerLog.Patterns.RandomizerSeed) == "string" then
							local seedMatch = string.match(logLines[2] or "", RandomizerLog.Patterns.RandomizerSeed)
							if seedMatch then
								local numSeed = tonumber(seedMatch)
								if numSeed then return numSeed end
							end
						end
						local seedMatch = string.match(logLines[2] or "", "Random Seed:%s*(%d+)")
						if seedMatch then
							local numSeed = tonumber(seedMatch)
							if numSeed then return numSeed end
						end
					end
				end
			end
			return nil
		end)
		if success and result then randomSeed = result end
		return randomSeed
	end

	local function getRouteName()
		local mapId = nil
		if TrackerAPI and TrackerAPI.getMapId then mapId = TrackerAPI.getMapId() end
		if mapId and RouteData.Info and RouteData.Info[mapId] then
			return RouteData.Info[mapId].name or "Unknown Area"
		end
		return "Unknown Area"
	end

	local function checkIsNatDex()
		-- Check the NatDex pokemon count at the known ROM address
		local success, result = pcall(function()
			local natDexMonCount = Memory.read32(0x08000170)
			return (natDexMonCount == 1210)
		end)
		if success then return result end
		return false
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

	local function getHighestMilestone()
		-- Champ
		if Program.hasDefeatedTrainer(438) or Program.hasDefeatedTrainer(439) or Program.hasDefeatedTrainer(440) then return "champ" end
		-- Elite Four (reverse order)
		if Program.hasDefeatedTrainer(413) then return "lance" end
		if Program.hasDefeatedTrainer(412) then return "agatha" end
		if Program.hasDefeatedTrainer(411) then return "bruno" end
		if Program.hasDefeatedTrainer(410) then return "lorelei" end
		-- Gym Leaders (reverse order)
		if Program.hasDefeatedTrainer(350) then return "giovanni" end
		if Program.hasDefeatedTrainer(419) then return "blaine" end
		if Program.hasDefeatedTrainer(420) then return "sabrina" end
		if Program.hasDefeatedTrainer(418) then return "koga" end
		if Program.hasDefeatedTrainer(417) then return "erika" end
		if Program.hasDefeatedTrainer(416) then return "surge" end
		if Program.hasDefeatedTrainer(415) then return "misty" end
		if Program.hasDefeatedTrainer(414) then return "brock" end
		-- Lab rival
		if Program.hasDefeatedTrainer(326) or Program.hasDefeatedTrainer(327) or Program.hasDefeatedTrainer(328) then return "lab" end
		return nil
	end

	local function getCurrentValues(pokemon)
		if not PokemonData.isValid(pokemon.pokemonID) then return nil end
		local values = {}
		values.pokemonId = PokemonData.Pokemon[pokemon.pokemonID].pokemonID
		values.pokemonName = PokemonData.Pokemon[pokemon.pokemonID].name or "Unknown"
		values.nickname = pokemon.nickname or ""
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
		values.milestone = getHighestMilestone()
		values.badgeCount = getBadgeCount()
		values.routeName = getRouteName()
		values.randomSeed = getRandomSeed()
		values.items = getTrackedItems()
		values.pivots = getPivotData()
		local gachaStars = 0
		if GachaMonData and GachaMonData.playerViewedMon then
			gachaStars = GachaMonData.playerViewedMon:getStars() or 0
		end
		values.stars = gachaStars
		values.isNatDex = checkIsNatDex()
		return values
	end

	local function valuesChanged(current, previous)
		if not previous then return true end
		return current.pokemonId ~= previous.pokemonId or
		       current.abilityName ~= previous.abilityName or
			   current.level ~= previous.level or
			   current.nickname ~= previous.nickname or
			   (current.level ~= previous.level and (
			       current.hp ~= previous.hp or
			       current.atk ~= previous.atk or
			       current.def ~= previous.def or
			       current.spa ~= previous.spa or
			       current.spd ~= previous.spd or
			       current.spe ~= previous.spe)) or
			   current.move_1 ~= previous.move_1 or
			   current.move_2 ~= previous.move_2 or
			   current.move_3 ~= previous.move_3 or
			   current.move_4 ~= previous.move_4 or
			   current.trainersDefeated ~= previous.trainersDefeated or
		       itemsChanged(current.items, previous.items) or
		       pivotsChanged(current.pivots, previous.pivots)
	end

	local function writeSimplifiedDataToFile(values, recordRun, isFaint)
		local file = io.open(self.Paths.DataOutput, "w")
		if not file then return false end

		local jsonContent = "{\n"
		jsonContent = jsonContent .. '  "pokemonId": ' .. tostring(values.pokemonId) .. ",\n"
		jsonContent = jsonContent .. '  "pokemonName": "' .. escapeJson(values.pokemonName or "Unknown") .. '",\n'
		jsonContent = jsonContent .. '  "nickname": "' .. escapeJson(values.nickname or "") .. '",\n'
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
		jsonContent = jsonContent .. '  "milestone": ' .. (values.milestone and ('"' .. escapeJson(values.milestone) .. '"') or "null") .. ",\n"
		jsonContent = jsonContent .. '  "stars": ' .. tostring(values.stars or 0) .. ",\n"
		jsonContent = jsonContent .. '  "badgeCount": ' .. tostring(values.badgeCount or 0) .. ",\n"
		jsonContent = jsonContent .. '  "routeName": "' .. escapeJson(values.routeName or "Unknown Area") .. '",\n'
		jsonContent = jsonContent .. '  "randomSeed": ' .. (values.randomSeed and tostring(values.randomSeed) or "null") .. ",\n"
		jsonContent = jsonContent .. '  "recordRun": ' .. tostring(recordRun and true or false) .. ",\n"
		jsonContent = jsonContent .. '  "isFaint": ' .. tostring(isFaint and true or false) .. ",\n"
		jsonContent = jsonContent .. '  "isNatDex": ' .. tostring(values.isNatDex and true or false) .. ",\n"

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
		PokemonDead = false,
		LastValues = nil,
		fishingCountdown = 0,
		fishingMapId = nil,
		fishingEncounters = {},
		lastValidMapId = nil,
		lastMilestoneUpdate = nil,
		milestoneWriteCooldown = 0,
	}

	function self.resetSeedVars()
		local V = self.PerSeedVars
		V.FirstPokemonChosen = false
		V.PokemonDead = false
		V.LastValues = nil
		V.fishingCountdown = 0
		V.fishingMapId = nil
		V.fishingEncounters = {}
		V.lastValidMapId = nil
		V.lastMilestoneUpdate = nil
		V.milestoneWriteCooldown = 0
	end

	local loadedVarsThisSeed
	local function isPlayingFRLG() return GameSettings.game == 3 end

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

		-- Only trigger fishing if stat increases by exactly 1 (filters out save state loads)
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

				local enemyPokemon = Tracker.getPokemon(1, false)
			
			if enemyPokemon and PokemonData.isValid(enemyPokemon.pokemonID) then
				if V.fishingMapId then
					local currentMapId = tonumber(V.fishingMapId) or V.fishingMapId
					local pokemonId = enemyPokemon.pokemonID

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
			-- Reset milestone tracking on new run (seed change or fresh start)
			local currentValues = getCurrentValues(leadPokemon)
			if currentValues then
				local previousSeed = V.LastValues and V.LastValues.randomSeed or nil
				local currentSeed = currentValues.randomSeed

				if not V.LastValues or (currentSeed and (not previousSeed or previousSeed ~= currentSeed)) then
					V.lastMilestoneUpdate = nil
					V.PokemonDead = false
				end
			end

			-- Faint detection
			local hpPercentage = (leadPokemon.curHP or 0) / (leadPokemon.stats.hp or 100)
			if hpPercentage == 0 and not V.PokemonDead then
				V.PokemonDead = true
				local currentValues = getCurrentValues(leadPokemon)
				if currentValues then
					writeSimplifiedDataToFile(currentValues, true, true)
					V.LastValues = currentValues
					V.lastMilestoneUpdate = currentValues.milestone
				end
				return
			end

			-- Normal update (only when alive)
			if not V.PokemonDead then
				-- Decrement milestone write cooldown each frame
				if V.milestoneWriteCooldown > 0 then
					V.milestoneWriteCooldown = V.milestoneWriteCooldown - 1
				end

				local currentValues = getCurrentValues(leadPokemon)
				if currentValues then
					local shouldUpdatePastRuns = false
					local currentMilestone = currentValues.milestone
					local currentBadgeCount = currentValues.badgeCount or 0
					local previousBadgeCount = V.LastValues and (V.LastValues.badgeCount or 0) or 0

					-- Milestone checks: update on every new badge and champion
					if currentBadgeCount > previousBadgeCount and currentBadgeCount >= 1 and V.lastMilestoneUpdate ~= currentMilestone then
						shouldUpdatePastRuns = true
					elseif currentMilestone == "champ" and V.lastMilestoneUpdate ~= "champ" then
						shouldUpdatePastRuns = true
					end

					local needsNormalUpdate = not V.LastValues or valuesChanged(currentValues, V.LastValues)

					if shouldUpdatePastRuns then
						writeSimplifiedDataToFile(currentValues, true, false)
						V.lastMilestoneUpdate = currentMilestone
						-- Cooldown: suppress normal writes for ~3s so Python can read the milestone
						V.milestoneWriteCooldown = 180
						V.LastValues = currentValues
					elseif needsNormalUpdate and V.milestoneWriteCooldown <= 0 then
						writeSimplifiedDataToFile(currentValues, false, false)
						V.LastValues = currentValues
					end
				end
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