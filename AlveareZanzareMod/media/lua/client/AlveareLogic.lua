-- ================================
-- Configurazione
-- ================================
local alveareType = "Base.Alveare"   -- Nome item
local distanzaSuono = 5              -- Tile per sentire il suono
local distanzaDanno = 2              -- Tile per subire danno
local dannoPerTick = 0.1             -- HP persi per tick
local suonoNome = "BeeBuzz"          -- Nome file .ogg senza estensione

-- Variabile per controllare se il suono è in riproduzione
local suonoAttivo = false
local suonoLoop = nil

-- Tabella per tenere traccia se il player ha detto la frase
local saidBeePlayers = {}

-- ================================
-- Funzione di controllo
-- ================================
local function ControllaAlveari(player)
    if not player or player:isDead() then return end

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local cell = getCell()
    if not cell then return end

    local alveareVicino = false
    local alveareMoltoVicino = false

    for x = px - distanzaSuono, px + distanzaSuono do
        for y = py - distanzaSuono, py + distanzaSuono do
            local square = cell:getGridSquare(x, y, pz)
            if square then
                local worldObjects = square:getWorldObjects()
                for i = 0, worldObjects:size()-1 do
                    local obj = worldObjects:get(i)
                    if instanceof(obj, "IsoWorldInventoryObject") and obj:getItem() and obj:getItem():getFullType() == alveareType then
                        local dist = player:DistToProper(obj)

                        if dist <= distanzaSuono then
                            alveareVicino = true
                        end
                        if dist <= distanzaDanno then
                            alveareMoltoVicino = true
                        end
                    end
                end
            end
        end
    end

    -- Gestione suono
    if alveareVicino and not suonoAttivo then
        local playerSquare = player:getSquare()
        if playerSquare then
            suonoLoop = getSoundManager():PlayWorldSound(suonoNome, playerSquare, 0, distanzaSuono, 1.0, true)
            suonoAttivo = true
        end
    elseif not alveareVicino and suonoAttivo then
        if suonoLoop then
            getSoundManager():StopSound(suonoLoop)
            suonoLoop = nil
        end
        suonoAttivo = false
    end

    -- Danno e frase
    local playerId = player:getOnlineID() or 0
    if alveareMoltoVicino then
        player:getBodyDamage():AddDamage(BodyPartType.Hand_L, dannoPerTick)
        player:getBodyDamage():AddDamage(BodyPartType.Hand_R, dannoPerTick)
        player:getBodyDamage():AddDamage(BodyPartType.ForeArm_L, dannoPerTick)
        player:getBodyDamage():AddDamage(BodyPartType.ForeArm_R, dannoPerTick)

        if not saidBeePlayers[playerId] then
            player:Say("Ahi! Le api mi stanno pungendo!")
            saidBeePlayers[playerId] = true
        end
    else
        saidBeePlayers[playerId] = false
    end
end

Events.OnPlayerUpdate.Add(function(player) ControllaAlveari(player) end)
