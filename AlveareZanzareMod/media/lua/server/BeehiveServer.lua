-- ================================
-- SISTEMA ALVEARE OTTIMIZZATO PER PROJECT ZOMBOID
-- Compatibile con PZ API
-- ================================

-- ================================
-- Configurazione Centralizzata
-- ================================
local CONFIG = {
    -- Alveare Base
    alveareType = "Base.Alveare",
    distanzaSuono = 5,
    distanzaDanno = 2,
    dannoPerTick = 0.1,
    suonoNome = "BeeBuzz",
    
    -- Spawning System
    favoItemType = "Base.Alveare",
    tempoSpawn = 72,                    -- 3 giorni in ore
    chanceSpawn = 1.0,
    distanzaMinima = 3,
    
    -- Performance Ottimizzazioni
    processInterval = 600,              -- 10 minuti (ticks)
    cleanupInterval = 1800,             -- 30 minuti
    maxCorpsesPerTick = 3,
    scanRadius = 60,                    -- Ridotto per compatibilità
    maxDatabaseSize = 100,              -- Ridotto per PZ
    
    -- Cache System
    cacheExpireTime = 900,              -- 15 minuti
    batchProcessSize = 2,
    
    -- Debug
    enableDebug = false,
    debugRadius = 12,
}

-- ================================
-- State Management Compatibile PZ
-- ================================
local GameState = {
    -- Audio
    suonoAttivo = false,
    suonoLoop = nil,
    saidBeePlayers = {},
    
    -- Database
    corpseDB = {},
    spawnedHives = {},
    hivePositions = {},
    
    -- Cache
    buildingCache = {},
    cacheTimestamps = {},
    
    -- Performance
    tickCounter = 0,
    performanceStats = {
        processTime = 0,
        processCount = 0,
        averageTime = 0
    }
}

-- ================================
-- Utility Functions Compatibili PZ
-- ================================
local Utils = {}

function Utils.log(msg, level)
    if not CONFIG.enableDebug then return end
    local player = getPlayer()
    if player then
        local prefix = level == "ERROR" and "[ERROR] " or "[BEE] "
        player:Say(prefix .. tostring(msg))
    end
end

function Utils.getCorpseKey(x, y, z)
    return math.floor(x) .. "_" .. math.floor(y) .. "_" .. math.floor(z)
end

function Utils.getHiveKey(x, y)
    return math.floor(x) .. "_" .. math.floor(y)
end

function Utils.getGameHours()
    local gameTime = getGameTime()
    if gameTime then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

function Utils.distance2D(x1, y1, x2, y2)
    return IsoUtils.DistanceTo(x1, y1, x2, y2)
end

function Utils.getCurrentTimestamp()
    -- Usa calendario del gioco invece di getTimestamp()
    local calendar = getGameTime():getCalender()
    if calendar then
        return calendar:getTimeInMillis()
    end
    return 0
end

-- ================================
-- Cache Management PZ Compatible
-- ================================
local CacheManager = {}

function CacheManager.isValid(key)
    local timestamp = GameState.cacheTimestamps[key]
    if not timestamp then return false end
    return (Utils.getGameHours() - timestamp) < (CONFIG.cacheExpireTime / 60)
end

function CacheManager.set(key, value)
    GameState.buildingCache[key] = value
    GameState.cacheTimestamps[key] = Utils.getGameHours()
end

function CacheManager.get(key)
    if CacheManager.isValid(key) then
        return GameState.buildingCache[key]
    end
    return nil
end

function CacheManager.cleanup()
    local currentTime = Utils.getGameHours()
    local cleaned = 0
    local expireThreshold = CONFIG.cacheExpireTime / 60
    
    for key, timestamp in pairs(GameState.cacheTimestamps) do
        if (currentTime - timestamp) > expireThreshold then
            GameState.buildingCache[key] = nil
            GameState.cacheTimestamps[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 5 then
        Utils.log("Cache cleanup: " .. cleaned .. " entries")
    end
end

-- ================================
-- Building Detection PZ Compatible
-- ================================
local function isInBuildingOrCovered(square)
    if not square then return false end
    
    local key = square:getX() .. "_" .. square:getY() .. "_" .. square:getZ()
    local cached = CacheManager.get(key)
    if cached ~= nil then return cached end
    
    local result = false
    
    -- Check PZ building system
    local building = square:getBuilding()
    if building then
        result = true
    elseif square:haveRoof() then
        result = true
    elseif square:HasStairs(true) then
        result = true
    else
        -- Check muri adiacenti
        local wallCount = 0
        local cell = getCell()
        if cell then
            local x, y, z = square:getX(), square:getY(), square:getZ()
            local dirs = {{0,-1}, {1,0}, {0,1}, {-1,0}}
            
            for _, dir in ipairs(dirs) do
                local checkSquare = cell:getGridSquare(x + dir[1], y + dir[2], z)
                if checkSquare then
                    if checkSquare:haveRoof() or checkSquare:getBuilding() then
                        wallCount = wallCount + 1
                        if wallCount >= 2 then
                            result = true
                            break
                        end
                    end
                end
            end
        end
    end
    
    CacheManager.set(key, result)
    return result
end

-- ================================
-- Alveare Proximity System PZ Compatible
-- ================================
local AlveareManager = {}

function AlveareManager.controllaAlveari(player)
    if not player or player:isDead() then return end
    
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local cell = getCell()
    if not cell then return end
    
    local alveareVicino = false
    local alveareMoltoVicino = false
    local playerId = player:getOnlineID() or player:getUsername() or 0
    
    -- Scansione area con step ottimizzato
    local scanRange = CONFIG.distanzaSuono
    for x = px - scanRange, px + scanRange, 1 do
        for y = py - scanRange, py + scanRange, 1 do
            local square = cell:getGridSquare(x, y, pz)
            if square then
                local worldObjects = square:getWorldObjects()
                if worldObjects then
                    for i = 0, worldObjects:size()-1 do
                        local obj = worldObjects:get(i)
                        if obj and instanceof(obj, "IsoWorldInventoryObject") then
                            local item = obj:getItem()
                            if item and item:getFullType() == CONFIG.alveareType then
                                -- Usa DistTo di PZ invece di custom
                                local dist = player:DistTo(obj:getX(), obj:getY())
                                
                                if dist <= CONFIG.distanzaSuono then
                                    alveareVicino = true
                                    if dist <= CONFIG.distanzaDanno then
                                        alveareMoltoVicino = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    if alveareMoltoVicino then break end
                end
            end
        end
        if alveareMoltoVicino then break end
    end
    
    -- Gestione audio PZ compatible
    if alveareVicino and not GameState.suonoAttivo then
        local playerSquare = player:getSquare()
        if playerSquare then
            local soundManager = getSoundManager()
            if soundManager then
                GameState.suonoLoop = soundManager:PlayWorldSound(
                    CONFIG.suonoNome, playerSquare, 0, CONFIG.distanzaSuono, 1.0, true
                )
                GameState.suonoAttivo = true
            end
        end
    elseif not alveareVicino and GameState.suonoAttivo then
        if GameState.suonoLoop then
            local soundManager = getSoundManager()
            if soundManager then
                soundManager:StopSound(GameState.suonoLoop)
            end
            GameState.suonoLoop = nil
        end
        GameState.suonoAttivo = false
    end
    
    -- Sistema danno PZ compatible
    if alveareMoltoVicino then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            bodyDamage:AddDamage(BodyPartType.Hand_L, CONFIG.dannoPerTick)
            bodyDamage:AddDamage(BodyPartType.Hand_R, CONFIG.dannoPerTick)
            bodyDamage:AddDamage(BodyPartType.ForeArm_L, CONFIG.dannoPerTick)
            bodyDamage:AddDamage(BodyPartType.ForeArm_R, CONFIG.dannoPerTick)
        end
        
        if not GameState.saidBeePlayers[playerId] then
            player:Say("Ahi! Le api mi stanno pungendo!")
            GameState.saidBeePlayers[playerId] = true
        end
    else
        GameState.saidBeePlayers[playerId] = false
    end
end

-- ================================
-- Spawning System PZ Compatible
-- ================================
local SpawnerManager = {}

function SpawnerManager.registerCorpse(corpse)
    if not corpse then return end
    
    local square = corpse:getSquare()
    if not square then return end
    
    local x, y, z = corpse:getX(), corpse:getY(), corpse:getZ()
    local key = Utils.getCorpseKey(x, y, z)
    
    if GameState.corpseDB[key] then return end
    
    GameState.corpseDB[key] = {
        x = x, y = y, z = z,
        spawnTime = Utils.getGameHours(),
        corpse = corpse,
        processed = false,
        lastCheck = 0
    }
    
    SpawnerManager.trimDatabase()
    Utils.log("Corpse registered: " .. x .. "," .. y)
end

function SpawnerManager.trimDatabase()
    local count = 0
    for _ in pairs(GameState.corpseDB) do count = count + 1 end
    
    if count <= CONFIG.maxDatabaseSize then return end
    
    local entries = {}
    for key, data in pairs(GameState.corpseDB) do
        table.insert(entries, {key = key, time = data.spawnTime})
    end
    
    table.sort(entries, function(a, b) return a.time < b.time end)
    
    local toRemove = count - CONFIG.maxDatabaseSize
    for i = 1, toRemove do
        GameState.corpseDB[entries[i].key] = nil
    end
    
    Utils.log("Database trimmed: " .. toRemove .. " entries")
end

function SpawnerManager.updateHivePositions()
    local player = getPlayer()
    if not player then return end
    
    GameState.hivePositions = {}
    local cell = getCell()
    if not cell then return end
    
    local px, py = player:getX(), player:getY()
    local radius = CONFIG.scanRadius
    
    for x = px - radius, px + radius, 10 do
        for y = py - radius, py + radius, 10 do
            local square = cell:getGridSquare(x, y, 0)
            if square then
                local objects = square:getWorldObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoWorldInventoryObject") then
                            local item = obj:getItem()
                            if item and item:getFullType() == CONFIG.favoItemType then
                                local key = Utils.getHiveKey(obj:getX(), obj:getY())
                                GameState.hivePositions[key] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

function SpawnerManager.canSpawnHiveAt(x, y)
    local minDist = CONFIG.distanzaMinima
    for dx = -minDist, minDist do
        for dy = -minDist, minDist do
            if dx ~= 0 or dy ~= 0 then
                local key = Utils.getHiveKey(x + dx, y + dy)
                if GameState.hivePositions[key] then
                    return false
                end
            end
        end
    end
    return true
end

function SpawnerManager.spawnHiveAtCorpse(data)
    local x, y, z = data.x, data.y, data.z
    local cell = getCell()
    if not cell then return false end
    
    local square = cell:getGridSquare(x, y, z)
    if not square or not isInBuildingOrCovered(square) then
        return false
    end
    
    if not SpawnerManager.canSpawnHiveAt(x, y) then
        return false
    end
    
    -- Rimuovi cadavere usando API PZ corretta
    if data.corpse and not data.corpse:isRemoved() then
        square:removeCorpse(data.corpse, false)
    end
    
    -- Spawna alveare usando PZ API
    local item = instanceItem(CONFIG.favoItemType)
    if item then
        square:AddWorldInventoryItem(item, 0, 0, 0)
        
        local hiveKey = Utils.getHiveKey(x, y)
        GameState.hivePositions[hiveKey] = true
        GameState.spawnedHives[hiveKey] = Utils.getGameHours()
        
        Utils.log("Hive spawned: " .. x .. "," .. y)
        
        -- Notifica player se vicino
        local player = getPlayer()
        if player then
            local dist = player:DistTo(x, y)
            if dist <= CONFIG.debugRadius then
                player:Say("Un ronzio inquietante riempie l'aria...")
            end
        end
        
        return true
    end
    
    return false
end

function SpawnerManager.processCorpsesBatch()
    local startTime = Utils.getCurrentTimestamp()
    local currentTime = Utils.getGameHours()
    local processed, spawned = 0, 0
    
    for key, data in pairs(GameState.corpseDB) do
        if processed >= CONFIG.batchProcessSize then break end
        
        if (currentTime - data.lastCheck) < 0.5 then
            goto continue
        end
        
        processed = processed + 1
        data.lastCheck = currentTime
        
        if data.processed then goto continue end
        
        -- Verifica se cadavere è stato rimosso
        if data.corpse and data.corpse:isRemoved() then
            GameState.corpseDB[key] = nil
            goto continue
        end
        
        -- Check tempo spawn (3 giorni)
        if (currentTime - data.spawnTime) >= CONFIG.tempoSpawn then
            if SpawnerManager.spawnHiveAtCorpse(data) then
                spawned = spawned + 1
            end
            data.processed = true
        end
        
        ::continue::
    end
    
    -- Performance tracking
    local processTime = Utils.getCurrentTimestamp() - startTime
    GameState.performanceStats.processCount = GameState.performanceStats.processCount + 1
    if GameState.performanceStats.processCount > 0 then
        GameState.performanceStats.averageTime = 
            (GameState.performanceStats.averageTime + processTime) / 2
    end
    
    if spawned > 0 then
        Utils.log("Batch: " .. spawned .. " spawned")
    end
end

function SpawnerManager.scanForCorpsesNearPlayer()
    local player = getPlayer()
    if not player then return end
    
    local cell = getCell()
    if not cell then return end
    
    local px, py = player:getX(), player:getY()
    local radius = CONFIG.scanRadius
    local found = 0
    
    for x = px - radius, px + radius, 5 do
        for y = py - radius, py + radius, 5 do
            local square = cell:getGridSquare(x, y, 0)
            if square then
                local corpses = square:getDeadBodys()
                if corpses then
                    for i = 0, corpses:size() - 1 do
                        local corpse = corpses:get(i)
                        if corpse then
                            local key = Utils.getCorpseKey(corpse:getX(), corpse:getY(), corpse:getZ())
                            if not GameState.corpseDB[key] then
                                SpawnerManager.registerCorpse(corpse)
                                found = found + 1
                                if found >= CONFIG.maxCorpsesPerTick then
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ================================
-- Main Game Loop
-- ================================
local function onTick()
    GameState.tickCounter = GameState.tickCounter + 1
    local player = getPlayer()
    if not player then return end
    
    -- Processing principale ogni 10 minuti
    if GameState.tickCounter % CONFIG.processInterval == 0 then
        CacheManager.cleanup()
        SpawnerManager.updateHivePositions()
        SpawnerManager.processCorpsesBatch()
    end
    
    -- Scan corpses ogni 20 minuti
    if GameState.tickCounter % (CONFIG.processInterval * 2) == 0 then
        SpawnerManager.scanForCorpsesNearPlayer()
    end
    
    -- Database cleanup ogni 30 minuti
    if GameState.tickCounter % CONFIG.cleanupInterval == 0 then
        SpawnerManager.trimDatabase()
    end
end

-- ================================
-- Debug System
-- ================================
local DebugCommands = {
    toggle = function(player)
        CONFIG.enableDebug = not CONFIG.enableDebug
        player:Say("Debug: " .. (CONFIG.enableDebug and "ON" or "OFF"))
    end,
    
    stats = function(player)
        local corpses, hives, cache = 0, 0, 0
        for _ in pairs(GameState.corpseDB) do corpses = corpses + 1 end
        for _ in pairs(GameState.hivePositions) do hives = hives + 1 end
        for _ in pairs(GameState.buildingCache) do cache = cache + 1 end
        
        player:Say("Corpses:" .. corpses .. " Hives:" .. hives .. " Cache:" .. cache)
    end,
    
    near = function(player)
        local px, py = player:getX(), player:getY()
        local nearCorpses, nearHives = 0, 0
        local currentTime = Utils.getGameHours()
        
        for key, data in pairs(GameState.corpseDB) do
            local dist = Utils.distance2D(px, py, data.x, data.y)
            if dist <= 15 then
                nearCorpses = nearCorpses + 1
                if nearCorpses <= 2 then
                    local days = (currentTime - data.spawnTime) / 24
                    player:Say("C: " .. data.x .. "," .. data.y .. " (" .. string.format("%.1f", days) .. "d)")
                end
            end
        end
        
        for key in pairs(GameState.hivePositions) do
            local coords = {}
            for coord in string.gmatch(key, "([^_]+)") do
                table.insert(coords, tonumber(coord))
            end
            if coords[1] and coords[2] then
                local dist = Utils.distance2D(px, py, coords[1], coords[2])
                if dist <= 15 then
                    nearHives = nearHives + 1
                end
            end
        end
        
        player:Say("Near - Corpses:" .. nearCorpses .. " Hives:" .. nearHives)
    end,
    
    clear = function(player)
        GameState.corpseDB = {}
        GameState.spawnedHives = {}
        GameState.hivePositions = {}
        GameState.buildingCache = {}
        GameState.cacheTimestamps = {}
        GameState.performanceStats = {processTime = 0, processCount = 0, averageTime = 0}
        player:Say("All data cleared!")
    end
}

local function onClientCommand(module, command, player, args)
    if module ~= "HiveDebug" then return end
    
    local cmd = DebugCommands[command]
    if cmd then
        -- Controllo permessi PZ
        local accessLevel = player:getAccessLevel()
        if accessLevel == "Admin" or accessLevel == "Moderator" or CONFIG.enableDebug then
            cmd(player)
        end
    end
end

-- ================================
-- Event Registration PZ Compatible
-- ================================
Events.OnPlayerUpdate.Add(AlveareManager.controllaAlveari)
Events.OnTick.Add(onTick)
Events.OnZombieDead.Add(SpawnerManager.registerCorpse)
Events.OnClientCommand.Add(onClientCommand)

Events.OnGameStart.Add(function()
    -- Reset stato all'avvio
    GameState.corpseDB = {}
    GameState.spawnedHives = {}
    GameState.hivePositions = {}
    GameState.buildingCache = {}
    GameState.cacheTimestamps = {}
    GameState.tickCounter = 0
    GameState.suonoAttivo = false
    GameState.suonoLoop = nil
    GameState.saidBeePlayers = {}
    
    Utils.log("Hive System Initialized - PZ Compatible")
end)

-- ================================
-- Public API
-- ================================
function HiveSystem_GetStats()
    local stats = {
        corpses = 0,
        hives = 0,
        cache = 0,
        performance = GameState.performanceStats.averageTime
    }
    
    for _ in pairs(GameState.corpseDB) do stats.corpses = stats.corpses + 1 end
    for _ in pairs(GameState.hivePositions) do stats.hives = stats.hives + 1 end
    for _ in pairs(GameState.buildingCache) do stats.cache = stats.cache + 1 end
    
    return stats
end