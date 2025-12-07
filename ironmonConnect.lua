local function IronmonConnect()
	local self = {
		version = "1.0",
		name = "ironmonConnect",
		author = "WaffleSmacker",
		description = "Created for ironmonConnect. Used to send data to the website.",
		github = "WaffleSmacker/ironmonConnect-IronmonExtension",
	}

	self.url = string.format("https://github.com/%s", self.github)

	-- Executed when the user clicks the "Check for Updates" button while viewing the extension details within the Tracker's UI
	function self.checkForUpdates()
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github)
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+)"' -- matches "1.0" in "tag_name": "v1.0"
		local downloadUrl = string.format("https://github.com/%s/releases/latest", self.github)
		local compareFunc = function(a, b) return a ~= b and not Utils.isNewerVersion(a, b) end -- if current version is *older* than online version
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	-- Data output file path
	self.DATA_OUTPUT_FILE = "tracker_output.json"
	self.DEBUG_OUTPUT_FILE = "ironmonconnect_debug.txt"

	self.Paths = {
		DataOutput = "",
		DebugOutput = "",
	}

	-- Function to escape JSON strings
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

	-- Function to get total defeated trainers
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

	-- Function to serialize a table for debugging
	local function serializeTable(t, indent, visited)
		indent = indent or 0
		visited = visited or {}
		local str = ""
		local indentStr = string.rep("  ", indent)
		
		if type(t) == "table" then
			-- Check for circular references
			if visited[t] then
				return indentStr .. "[circular reference]\n"
			end
			visited[t] = true
			
			str = str .. indentStr .. "{\n"
			for k, v in pairs(t) do
				local key = tostring(k)
				if type(v) == "table" then
					str = str .. indentStr .. "  [" .. key .. "] = \n"
					str = str .. serializeTable(v, indent + 2, visited)
				else
					str = str .. indentStr .. "  [" .. key .. "] = " .. tostring(v) .. "\n"
				end
			end
			str = str .. indentStr .. "}\n"
			visited[t] = nil
		else
			str = str .. indentStr .. tostring(t) .. "\n"
		end
		
		return str
	end
	
	-- Valid item IDs from database (Balls, Healing, Status, PP, Evolution, Gym TM, Others)
	-- Defined early so it can be used in debug function
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
	
	-- Helper function to check if item ID is valid (exists in database)
	-- Defined early so it can be used in debug function
	local function isValidItemId(itemID)
		if type(itemID) == "number" then
			return validItemIds[itemID] == true
		elseif type(itemID) == "string" then
			local numId = tonumber(itemID)
			return numId and validItemIds[numId] == true
		end
		return false
	end
	
	-- Forward declaration for getTrackedItems and getPivotData (will be defined later)
	local getTrackedItems
	local getPivotData
	
	-- Function to write debug information to file
	-- NOTE: Disabled for soft release. To re-enable, uncomment this function
	--       and the call site in self.afterProgramDataUpdate().
	--[[
	local function writeDebugInfo(pokemon)
		local debugFile = io.open(self.Paths.DebugOutput, "w")
		if not debugFile then
			return
		end
		
		debugFile:write("=== DEBUG INFO ===\n\n")
		
		-- Debug pokemon data
		debugFile:write("pokemon.pokemonID: " .. tostring(pokemon.pokemonID) .. "\n\n")
		
		-- Debug PokemonData.Pokemon[pokemon.pokemonID]
		local pokemonData = PokemonData.Pokemon[pokemon.pokemonID]
		debugFile:write("PokemonData.Pokemon[pokemon.pokemonID]:\n")
		debugFile:write(serializeTable(pokemonData))
		debugFile:write("\n")
		
		-- Debug ability
		local abilityId = PokemonData.getAbilityId(pokemon.pokemonID, pokemon.abilityNum)
		debugFile:write("abilityId: " .. tostring(abilityId) .. "\n")
		local abilityData = AbilityData.Abilities[abilityId]
		debugFile:write("AbilityData.Abilities[abilityId]:\n")
		debugFile:write(serializeTable(abilityData))
		debugFile:write("\n")
		
		-- Debug moves
		for i = 1, 4 do
			if pokemon.moves[i] then
				debugFile:write("pokemon.moves[" .. i .. "]:\n")
				debugFile:write(serializeTable(pokemon.moves[i]))
				local moveData = MoveData.Moves[pokemon.moves[i].id]
				debugFile:write("MoveData.Moves[pokemon.moves[" .. i .. "].id]:\n")
				debugFile:write(serializeTable(moveData))
				debugFile:write("\n")
			end
		end
		
		-- Debug items
		debugFile:write("=== ITEMS DEBUG ===\n\n")
		
		-- Debug Program.GameData.Items structure
		if Program.GameData and Program.GameData.Items then
			debugFile:write("Program.GameData.Items structure:\n")
			debugFile:write(serializeTable(Program.GameData.Items))
			debugFile:write("\n")
			
			local function countItems(tbl, filterFn)
				local count = 0
				if tbl and type(tbl) == "table" then
					for itemID, qty in pairs(tbl) do
						if qty and qty > 0 and (not filterFn or filterFn(itemID)) then
							count = count + 1
						end
					end
				end
				return count
			end
			
			local gymTmIds = {
				[291] = true, [292] = true, [294] = true, [307] = true,
				[314] = true, [322] = true, [326] = true, [327] = true
			}

			local itemCounts = {
				balls = countItems(Program.GameData.Items.PokeBalls),
				evolution = countItems(Program.GameData.Items.EvoStones),
				hp = countItems(Program.GameData.Items.HPHeals),
				pp = countItems(Program.GameData.Items.PPHeals),
				status = countItems(Program.GameData.Items.StatusHeals),
				gymtm = countItems(Program.GameData.Items.Other, function(itemID)
					return gymTmIds[tonumber(itemID) or itemID]
				end)
			}

			debugFile:write("Item counts in bag (raw categories):\n")
			debugFile:write("  Balls: " .. itemCounts.balls .. " unique items\n")
			debugFile:write("  Evolution: " .. itemCounts.evolution .. " unique items\n")
			debugFile:write("  HP Heals: " .. itemCounts.hp .. " unique items\n")
			debugFile:write("  PP Heals: " .. itemCounts.pp .. " unique items\n")
			debugFile:write("  Status Heals: " .. itemCounts.status .. " unique items\n")
			debugFile:write("  Gym TM (from Other): " .. itemCounts.gymtm .. " unique items\n")
			debugFile:write("\n")
			
			local function writeSample(title, tbl, limit, filterFn)
				debugFile:write(title .. ":\n")
				local sampleCount = 0
				if tbl and type(tbl) == "table" then
					for itemID, quantity in pairs(tbl) do
						if quantity and quantity > 0 and (not filterFn or filterFn(itemID)) then
							local itemName = MiscData.Items[itemID] or "Unknown"
							debugFile:write(string.format("  ID %s (%s): %s\n", tostring(itemID), itemName, tostring(quantity)))
							sampleCount = sampleCount + 1
							if sampleCount >= limit then
								break
							end
						end
					end
				end
				if sampleCount == 0 then
					debugFile:write("  (none)\n")
				end
				debugFile:write("\n")
			end

			writeSample("Sample Balls (first 5)", Program.GameData.Items.PokeBalls, 5)
			writeSample("Sample Evolution items (first 5)", Program.GameData.Items.EvoStones, 5)
			writeSample("Sample HP Heals (first 5)", Program.GameData.Items.HPHeals, 5)
			writeSample("Sample PP Heals (first 5)", Program.GameData.Items.PPHeals, 5)
			writeSample("Sample Status Heals (first 5)", Program.GameData.Items.StatusHeals, 5)
			writeSample("Sample Gym TM (first 5)", Program.GameData.Items.Other, 5, function(itemID)
				return gymTmIds[tonumber(itemID) or itemID]
			end)
		else
			debugFile:write("Program.GameData.Items is nil or not available\n\n")
		end
		
		-- Debug processed items (from getTrackedItems)
		local processedItems = getTrackedItems()
		debugFile:write("Processed items (after filtering):\n")
		debugFile:write(serializeTable(processedItems))
		debugFile:write("\n")
		
		-- Count items in each processed category
		debugFile:write("Processed item counts:\n")
		debugFile:write("  Balls: " .. #processedItems.balls .. " items\n")
		debugFile:write("  Evolution: " .. #processedItems.evolution .. " items\n")
		debugFile:write("  Gym TM: " .. #processedItems.gymtm .. " items\n")
		debugFile:write("  HP: " .. #processedItems.hp .. " items\n")
		debugFile:write("  PP: " .. #processedItems.pp .. " items\n")
		debugFile:write("  Status: " .. #processedItems.status .. " items\n")
		debugFile:write("\n")

		-- Debug pivots
		debugFile:write("=== PIVOTS DEBUG ===\n\n")
		local pivotData = getPivotData()
		local routeCount = 0
		for _ in pairs(pivotData or {}) do
			routeCount = routeCount + 1
		end
		debugFile:write("Routes with tracked pivots: " .. tostring(routeCount) .. "\n")
		if pivotData and next(pivotData) then
			debugFile:write("Pivot data (routeId -> pokemonIDs):\n")
			debugFile:write(serializeTable(pivotData))
			debugFile:write("\n")
			debugFile:write("Sample pivots (first 10 routes):\n")
			local routeIds = {}
			for mapId in pairs(pivotData) do
				table.insert(routeIds, mapId)
			end
			table.sort(routeIds, function(a, b) return tostring(a) < tostring(b) end)
			for idx, mapId in ipairs(routeIds) do
				debugFile:write(string.format("  Route %s: %s\n", tostring(mapId), table.concat(pivotData[mapId] or {}, ", ")))
				if idx >= 10 then
					break
				end
			end
		else
			debugFile:write("No pivot encounters recorded.\n")
		end
		debugFile:write("\n")

		debugFile:close()
	end
	--]]

	-- Function to get all items from bag, categorized by type, filtered by database IDs
	getTrackedItems = function()
		local items = {
			balls = {},
			evolution = {},
			gymtm = {},
			hp = {},
			pp = {},
			status = {},
			others = {},
		}

		-- Helper function to add item to a specific category
		local function addItem(categoryKey, itemID, quantity)
			if not quantity or quantity <= 0 or not isValidItemId(itemID) then
				return
			end

			local itemId = tonumber(itemID) or itemID
			local category = items[categoryKey]
			if not category then
				return
			end

			table.insert(category, {
				id = itemId,
				quantity = quantity
			})
		end

		-- Helper function to read TMs directly from memory (since Program.lua skips them)
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
					if key ~= nil then
						quantity = Utils.bit_xor(quantity, key)
					end
					if quantity > 0 then
						tms[itemID] = quantity
					end
				end
			end
			return tms
		end

		if Program.GameData and Program.GameData.Items then
			-- Balls
			local pokeBalls = Program.GameData.Items.PokeBalls
			if pokeBalls and type(pokeBalls) == "table" then
				for itemID, quantity in pairs(pokeBalls) do
					addItem("balls", itemID, quantity)
				end
			end

			-- Evolution stones
			local evolutionStones = Program.GameData.Items.EvoStones
			if evolutionStones and type(evolutionStones) == "table" then
				for itemID, quantity in pairs(evolutionStones) do
					addItem("evolution", itemID, quantity)
				end
			end

			-- HP Heals
			local hpHeals = Program.GameData.Items.HPHeals
			if hpHeals and type(hpHeals) == "table" then
				for itemID, quantity in pairs(hpHeals) do
					addItem("hp", itemID, quantity)
				end
			end

			-- PP Heals
			local ppHeals = Program.GameData.Items.PPHeals
			if ppHeals and type(ppHeals) == "table" then
				for itemID, quantity in pairs(ppHeals) do
					addItem("pp", itemID, quantity)
				end
			end

			-- Status Heals
			local statusHeals = Program.GameData.Items.StatusHeals
			if statusHeals and type(statusHeals) == "table" then
				for itemID, quantity in pairs(statusHeals) do
					addItem("status", itemID, quantity)
				end
			end

			-- TMs (Read directly from memory as they are not in Program.GameData.Items)
			local gymTmIds = {
				[291] = true, [292] = true, [294] = true, [307] = true,
				[314] = true, [322] = true, [326] = true, [327] = true
			}
			local tmItems = getTMsFromBag()
			if tmItems and type(tmItems) == "table" then
				for itemID, quantity in pairs(tmItems) do
					if gymTmIds[tonumber(itemID) or itemID] then
						addItem("gymtm", itemID, quantity)
					end
				end
			end

			-- PP items from Other category (items 69 and 71 - PP Up and PP Max)
			local otherItems = Program.GameData.Items.Other
			if otherItems and type(otherItems) == "table" then
				local ppItemIds = {
					[69] = true,  -- PP Up
					[71] = true   -- PP Max
				}
				for itemID, quantity in pairs(otherItems) do
					if ppItemIds[tonumber(itemID) or itemID] then
						addItem("pp", itemID, quantity)
					end
				end
			end

			-- Others category (item 68 and other items that don't fit other categories)
			if otherItems and type(otherItems) == "table" then
				local othersItemIds = {
					[68] = true
				}
				for itemID, quantity in pairs(otherItems) do
					if othersItemIds[tonumber(itemID) or itemID] then
						addItem("others", itemID, quantity)
					end
				end
			end
		end

		return items
	end

	-- Function to get pivot encounters per route (Pokemon IDs indexed by route/map ID)
	getPivotData = function()
		local pivotData = {}
		
		-- Get both regular pivot routes AND Safari Zone routes
		local pivotMapIds = RouteData.getPivotOrSafariRouteIds(false) or {}
		local safariMapIds = RouteData.getPivotOrSafariRouteIds(true) or {}
		
		-- Combine both sets of routes (avoid duplicates)
		local allMapIds = {}
		local mapIdSet = {}
		for _, mapId in ipairs(pivotMapIds) do
			if not mapIdSet[mapId] then
				table.insert(allMapIds, mapId)
				mapIdSet[mapId] = true
			end
		end
		for _, mapId in ipairs(safariMapIds) do
			if not mapIdSet[mapId] then
				table.insert(allMapIds, mapId)
				mapIdSet[mapId] = true
			end
		end
		
		for _, mapId in ipairs(allMapIds) do
			local uniqueIds = {}
			
			-- Check multiple encounter areas to capture all encounters (LAND, WATER, etc.)
			-- This is important for Safari Zone which may have different encounter types
			local encounterAreas = {
				RouteData.EncounterArea.LAND,
				RouteData.EncounterArea.WATER,
			}
			
			-- Check if additional encounter areas exist (for Safari Zone or other special areas)
			if RouteData.EncounterArea.OLD_ROD then
				table.insert(encounterAreas, RouteData.EncounterArea.OLD_ROD)
			end
			if RouteData.EncounterArea.GOOD_ROD then
				table.insert(encounterAreas, RouteData.EncounterArea.GOOD_ROD)
			end
			if RouteData.EncounterArea.SUPER_ROD then
				table.insert(encounterAreas, RouteData.EncounterArea.SUPER_ROD)
			end
			
			-- Collect encounters from all areas
			for _, encounterArea in ipairs(encounterAreas) do
				local seenIds = Tracker.getRouteEncounters(mapId, encounterArea) or {}
				for _, pokemonId in ipairs(seenIds) do
					if PokemonData.isValid(pokemonId) then
						uniqueIds[pokemonId] = true
					end
				end
			end
			
			-- If we found any encounters, add them to pivotData
			if next(uniqueIds) then
				pivotData[mapId] = {}
				for pokemonId in pairs(uniqueIds) do
					table.insert(pivotData[mapId], pokemonId)
				end
				table.sort(pivotData[mapId])
			end
		end
		return pivotData
	end

	-- Function to compare item arrays by category
	local function compareItemCategory(current, previous)
		if not previous then
			return #current > 0
		end
		
		if #current ~= #previous then
			return true
		end
		
		-- Create lookup tables for easier comparison
		local currentLookup = {}
		for _, heal in ipairs(current) do
			local key = tostring(heal.id) .. "_" .. tostring(heal.quantity)
			currentLookup[key] = true
		end
		
		local previousLookup = {}
		for _, heal in ipairs(previous) do
			local key = tostring(heal.id) .. "_" .. tostring(heal.quantity)
			previousLookup[key] = true
		end
		
		-- Check if all current items exist in previous
		for key, _ in pairs(currentLookup) do
			if not previousLookup[key] then
				return true
			end
		end
		
		-- Check if all previous items exist in current
		for key, _ in pairs(previousLookup) do
			if not currentLookup[key] then
				return true
			end
		end
		
		return false
	end

	-- Function to compare item objects (with categories)
	local function itemsChanged(current, previous)
		if not previous then
			return true
		end

		local categoriesToCheck = {"balls", "evolution", "gymtm", "hp", "pp", "status", "others"}
		for _, category in ipairs(categoriesToCheck) do
			if compareItemCategory(current[category] or {}, previous[category] or {}) then
				return true
			end
		end
		return false
	end

	-- Function to compare pivot data tables
	local function pivotsChanged(current, previous)
		current = current or {}
		previous = previous or {}

		for mapId, currentList in pairs(current) do
			local previousList = previous[mapId]
			if not previousList then
				return true
			end
			if #currentList ~= #previousList then
				return true
			end
			for i = 1, #currentList do
				if currentList[i] ~= previousList[i] then
					return true
				end
			end
		end

		for mapId, _ in pairs(previous) do
			if current[mapId] == nil then
				return true
			end
		end

		return false
	end

	-- Function to get current values
	local function getCurrentValues(pokemon)
		if not PokemonData.isValid(pokemon.pokemonID) then
			return nil
		end
		
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

	-- Function to check if values have changed
	local function valuesChanged(current, previous)
		if not previous then
			return true -- First time, always write
		end
		
		return current.pokemonId ~= previous.pokemonId or
		       current.abilityName ~= previous.abilityName or
			   current.level ~= previous.level or
			   current.hp ~= previous.hp or
		       current.atk ~= previous.atk or
		       current.def ~= previous.def or
		       current.spa ~= previous.spa or
		       current.spd ~= previous.spd or
		       current.spe ~= previous.spe or
		       current.move_1 ~= previous.move_1 or
		       current.move_2 ~= previous.move_2 or
		       current.move_3 ~= previous.move_3 or
		       current.move_4 ~= previous.move_4 or
		       current.trainersDefeated ~= previous.trainersDefeated or
		       itemsChanged(current.items, previous.items) or
		       pivotsChanged(current.pivots, previous.pivots)
	end

	-- Function to write simplified data to JSON file
	local function writeSimplifiedDataToFile(values)
		local file = io.open(self.Paths.DataOutput, "w")
		if not file then
			return false, "Failed to open data file for writing"
		end
		
		-- Build simplified JSON object
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
		
		-- Add items by category
		jsonContent = jsonContent .. '  "items": {\n'
		
		-- Helper function to format a heal category array
		local function formatHealCategory(categoryName, healArray)
			jsonContent = jsonContent .. '    "' .. categoryName .. '": [\n'
			for i, heal in ipairs(healArray or {}) do
				local isLast = (i == #healArray)
				jsonContent = jsonContent .. '      {\n'
				
				-- Format ID - if it's a number, output as number; if string, output as quoted string
				local idValue = heal.id
				if type(idValue) == "number" then
					jsonContent = jsonContent .. '        "id": ' .. tostring(idValue) .. ",\n"
				else
					jsonContent = jsonContent .. '        "id": "' .. escapeJson(tostring(idValue)) .. '",\n'
				end
				
				jsonContent = jsonContent .. '        "quantity": ' .. tostring(heal.quantity) .. "\n"
				jsonContent = jsonContent .. '      }'
				if not isLast then
					jsonContent = jsonContent .. ","
				end
				jsonContent = jsonContent .. "\n"
			end
			jsonContent = jsonContent .. '    ]'
		end
		
		-- Format each category
		local items = values.items or { balls = {}, evolution = {}, gymtm = {}, hp = {}, pp = {}, status = {}, others = {} }
		formatHealCategory("balls", items.balls)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("evolution", items.evolution)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("gymtm", items.gymtm)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("hp", items.hp)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("pp", items.pp)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("status", items.status)
		jsonContent = jsonContent .. ",\n"
		formatHealCategory("others", items.others)
		jsonContent = jsonContent .. "\n"
		
		jsonContent = jsonContent .. '  },\n'

		-- Add pivots by route
		jsonContent = jsonContent .. '  "pivots": {\n'
		local pivotData = values.pivots or {}
		local routeIds = {}
		for mapId in pairs(pivotData) do
			table.insert(routeIds, mapId)
		end
		table.sort(routeIds, function(a, b) return tostring(a) < tostring(b) end)
		for index, mapId in ipairs(routeIds) do
			jsonContent = jsonContent .. string.format('    "%s": [\n', tostring(mapId))
			local pokemonList = pivotData[mapId] or {}
			for i, pokemonId in ipairs(pokemonList) do
				jsonContent = jsonContent .. string.format('      %s', tostring(pokemonId))
				if i < #pokemonList then
					jsonContent = jsonContent .. ","
				end
				jsonContent = jsonContent .. "\n"
			end
			jsonContent = jsonContent .. '    ]'
			if index < #routeIds then
				jsonContent = jsonContent .. ","
			end
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
		LastValues = nil, -- Store previous values to detect changes
	}

	function self.resetSeedVars()
		local V = self.PerSeedVars
		V.FirstPokemonChosen = false
		V.LastValues = nil
	end

	local loadedVarsThisSeed
	local function isPlayingFRLG() return GameSettings.game == 3 end

	-- Executed once every 30 frames, after most data from game memory is read in
	function self.afterProgramDataUpdate()
		-- Once per seed, when the player is able to move their character, initialize the seed variables
		if not isPlayingFRLG() or not Program.isValidMapLocation() then
			return
		elseif not loadedVarsThisSeed then
			self.resetSeedVars()
			loadedVarsThisSeed = true
		end

		local V = self.PerSeedVars
		local leadPokemon = Tracker.getPokemon(1, true) or Tracker.getDefaultPokemon()

		-- Check if this is the first pokemon chosen (only trigger once)
		if not V.FirstPokemonChosen and PokemonData.isValid(leadPokemon.pokemonID) then
			V.FirstPokemonChosen = true
		end

		-- Output simplified data every update after player gets a pokemon, but only if values changed
		if Program.isValidMapLocation() and PokemonData.isValid(leadPokemon.pokemonID) and V.FirstPokemonChosen then
			local currentValues = getCurrentValues(leadPokemon)
			if currentValues and valuesChanged(currentValues, V.LastValues) then
				-- Debug info file disabled for soft release (writeDebugInfo commented out)
				-- writeDebugInfo(leadPokemon)
				writeSimplifiedDataToFile(currentValues)
				V.LastValues = currentValues
			end
		end
	end

	-- Executed only once: When the extension is enabled by the user, and/or when the Tracker first starts up, after it loads all other required files and code
	function self.startup()
		-- Build out paths to files within the extension folder
		local extFolderPath = FileManager.getCustomFolderPath() .. "ironmonConnect" .. FileManager.slash
		self.Paths.DataOutput = extFolderPath .. self.DATA_OUTPUT_FILE
		self.Paths.DebugOutput = extFolderPath .. self.DEBUG_OUTPUT_FILE
		
		-- Create extension folder if it doesn't exist
		os.execute("mkdir \"" .. extFolderPath .. "\" 2>nul")
		
		-- Initialize data file with empty JSON object
		local file = io.open(self.Paths.DataOutput, "w")
		if file then
			file:write("{}")
			file:close()
		end
	end

	-- Executed only once: When the extension is disabled by the user, necessary to undo any customizations, if able
	function self.unload()
		-- Nothing to clean up
	end

	return self
end
return IronmonConnect
