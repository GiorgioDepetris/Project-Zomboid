-- ================================  
-- CLIENT/BeehiveClient.lua (ESTRATTO)
-- ================================

BeehiveClient = BeehiveClient or {}

local ClientState = {
    playerCache = {},
    hivePositions = {},
    tickCounter = 0,
}

function BeehiveClient.updateHivePositions(hives)
    -- Riceve sync dal server
    ClientState.hivePositions = {}
    for _, hiveKey in ipairs(hives) do
        ClientState.hivePositions[hiveKey] = true
    end
end

function BeehiveClient.processPlayer(player)
    -- Solo effetti client:
    -- - Scan alveari nearby
    -- - Calcola modificatori
    -- - Audio effects  
    -- - Damage application
    -- - UI feedback
end

function BeehiveClient.playBeeSound(player, volume, range)
    -- Solo audio logic
end

function BeehiveClient.applyBeeDamage(player, damage)
    -- Solo damage logic
end

-- Eventi CLIENT-ONLY
Events.OnPlayerUpdate.Add(BeehiveClient.processPlayer)
