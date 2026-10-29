--Collision Avoidance v1.1.4

--variáveis de leitura (serão atualizadas no update)
local distance_threshold
local distance_min
local speed_threshold
local distance = 0
local droneMode             --modo de voo do drone
local flyingState           -- drone voando
local movingState = false   --se o drone se move
local brakeMode = false     --se o drone está em brake
local debugMode = false     -- use o COLLA_DBG_MODE = 1 para ativar o debug
local runAvoidance = false
local debugLevel = 0        -- 1 = distancia, 2 = velocidade, 3 = drone stats, 4 = timers, 5 = all
local groundSpeed = 0       -- em m/s
local jerkDefault = 2.5     --jerk padrão
local jerkBrake = 5         --jerk de frenagem
local angle_max = 3500      --ângulo para o drone freiar
local angle_default = 2500  --ângulo padrão do drone
local lidar_health          --status de saúde do lidar

--variáveis de tempo
local collisionTime = nil
local now = 0
local last_msg_time = 0
local loopTime = 500      --intervalo entre as atualizações
local msg_interval = 3000 --intervalo entre as menssagens

--modos de voo do drone
local MODES = {
    STABILIZE    = 0,
    ACRO         = 1,
    ALTHOLD      = 2,
    AUTO         = 3,
    GUIDED       = 4,
    LOITER       = 5,
    RTL          = 6,
    LAND         = 9,
    POSHOLD      = 16,
    BRAKE        = 17,
    AVOID_ADSB   = 19,
    GUIDED_NOGPS = 20,
    SMART_RTL    = 21,
    FLOWHOLD     = 22,
    FOLLOW       = 23,
    SYSTEMID     = 25,
    AUTO_RTL     = 27
}

--níveis de mensagem para o GCS
local MSG_lvl = {
    emergency   = 0,
    alert       = 1,
    critical    = 2,
    error       = 3,
    warning     = 4,
    notice      = 5,
    info        = 6,
    debug       = 7
}
------------------------------------------------------------------------------------------------------------------
function debug()
    if debugLevel == 1 then
        gcs:send_text(MSG_lvl.debug, "distance: " .. tostring(distance))
        gcs:send_text(MSG_lvl.debug, "distance_threshold: " .. tostring(distance_threshold))
        gcs:send_text(MSG_lvl.debug, "Lidar health: " .. tostring(lidar_health))
    elseif debugLevel == 2 then
        gcs:send_text(MSG_lvl.debug, "groundSpeed: " .. tostring(groundSpeed))
        gcs:send_text(MSG_lvl.debug, "speed_threshold: " .. tostring(speed_threshold))
    elseif debugLevel == 3 then
        gcs:send_text(MSG_lvl.debug, "droneMode: " .. tostring(droneMode))
        gcs:send_text(MSG_lvl.debug, "flyingState: " .. tostring(flyingState))
        gcs:send_text(MSG_lvl.debug, "movingState: " .. tostring(movingState))
    elseif debugLevel == 4 then
        gcs:send_text(MSG_lvl.debug, "now: " .. tostring(now))
        gcs:send_text(MSG_lvl.debug, "collisionTime: " .. tostring(collisionTime))
        gcs:send_text(MSG_lvl.debug, "brakeMode: " .. tostring(brakeMode))
    elseif debugLevel == 5 then
        gcs:send_text(MSG_lvl.debug, "flyingState: " .. tostring(flyingState))
        gcs:send_text(MSG_lvl.debug, "movingState: " .. tostring(movingState))
        gcs:send_text(MSG_lvl.debug, "now: " .. tostring(now))
        gcs:send_text(MSG_lvl.debug, "groundSpeed: " .. tostring(groundSpeed))
        gcs:send_text(MSG_lvl.debug, "speed_threshold: " .. tostring(speed_threshold))
        gcs:send_text(MSG_lvl.debug, "distance: " .. tostring(distance))
        gcs:send_text(MSG_lvl.debug, "distance_threshold: " .. tostring(distance_threshold))
        gcs:send_text(MSG_lvl.debug, "Lidar health: " .. tostring(lidar_health))
    end
end
----------------------------------------------------------------------------------------------------------------
function avoidance()
    -- Ignora leituras muito baixas (ex: neblina ou sujeira no sensor)
    -- Retornar aqui impede que essas falsas leituras ativem freios indevidos 
    -- ou resetem os timers de colisões reais.
    if distance <= distance_min then
        return
    end

    --verifica se está se movendo
    if groundSpeed > 1 then
        movingState = true
    else
        movingState = false
    end

    --verifica se a distância é menor que o threshold
    if distance < distance_threshold then
        --timer para filtrar leituras falsas
        if not collisionTime then
            collisionTime = now
        end
        --timer para filtrar leituras falsas
        if now - collisionTime >= 250 then
            --verifica se o drone não está em modo brake
            if brakeMode == false and movingState then
                -- change to brake mode
                vehicle:set_mode(MODES.BRAKE)
                gcs:send_text(MSG_lvl.warning, "CoAv - BRAKE! - Obstacle detected")
                gcs:send_text(MSG_lvl.notice, "CoAv - Take manual control")
                brakeMode = true
            end
            --timer para mensagem não floodar
            if now - last_msg_time >= msg_interval then
                last_msg_time = now
            end
        end
    --Caso o drone esteja se aproximando de algo ele começa a avisar antes
    elseif distance <= distance_threshold + distance_threshold / 2 and distance > distance_threshold then
        collisionTime = nil
        --timer para mensagem não floodar
        if now - last_msg_time >= msg_interval then
            gcs:send_text(MSG_lvl.notice, "CoAv- Obstacle close")
            param:set("PSC_JERK_XY", jerkBrake) -- deixa a frenagem mais brusca
            param:set("ANGLE_MAX", angle_max) --deixa o ângulo máximo maior para frear mais forte
            last_msg_time = now
        end
    else
        collisionTime = nil
        local jerk = param:get("PSC_JERK_XY")
        if jerk ~= jerkDefault then
            param:set("PSC_JERK_XY", jerkDefault) --retorna o jerk x y ao valor padrão
            param:set("ANGLE_MAX", angle_default) --retorna o ângulo máximo ao valor padrão
        end
    end
end
-------------------------------------------------------------------------------------------------------------------
function update()

    -- atualiza as configurações dos parâmetros em tempo real
    distance_threshold = ((param:get("CoAv_DIST_LIM") or 60) * 100)
    distance_min       = ((param:get("CoAv_DIST_MIN") or 2) * 100) -- padrão de 2 metros para ignorar neblina
    speed_threshold    = ((param:get("CoAv_SPD_DBL") or 40) / 3.6)
    jerkDefault        = param:get("PSC_JERK_XY") or 2.5
    jerkBrake          = param:get("CoAv_JERK_XY") or 5
    angle_max          = param:get("CoAv_ANGLE_MAX") or 3500
    angle_default      = param:get("ANGLE_MAX") or 3500
    local on_off       = param:get("CoAv_ON_OFF") or 1 -- liga ou desliga o funcionamento da logica via parametro

    --modo debug
    debugLevel         = param:get("CoAv_DBG_MODE") or 0
    if debugLevel > 0 then
        debugMode = true
    else
        debugMode = false
    end

    --atualiza as variáveis
    now = millis()
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    flyingState = vehicle:get_likely_flying()
    droneMode = vehicle:get_mode()
    groundSpeed = ahrs:groundspeed_vector():length()

    -- variável que verifica se o drone está em condições de rodar o script
    runAvoidance = flyingState and not vehicle:is_taking_off() and not vehicle:is_landing() and (on_off == 1)

    -- verifica se o drone está se movendo rápido o suficiente para dobrar o threshold
    if groundSpeed and groundSpeed > speed_threshold then
        distance_threshold = distance_threshold * 2
    end

    --verifica se o drone ainda está em brake
    if brakeMode and droneMode ~= MODES.BRAKE then
        brakeMode = false
    end

    --verifica se há dados de lidar
    lidar_health = rangefinder:has_data_orient(0)

    if lidar_health then
        --verifica se está em condições de rodar o script
        if runAvoidance then
            --chama a função de anti colisão
            avoidance()
        end
        --se não houver lidar ele avisa
    else
        --timer para mensagem não floodar
        if now - last_msg_time >= msg_interval then
            gcs:send_text(MSG_lvl.error, "CoAv - Caution: No lidar data for avoidance")
            last_msg_time = now
        end
    end

    -- manda o printão pra nós
    if debugMode then
        debug()
    end

    --retorna a função principal
    return update, loopTime
end
------------------------------------------------------------------------------------------------------------
gcs:send_text(MSG_lvl.info, "Collision Avoidance is running v1.1.4")
return update(), 1000 -- inicia 1 segundo após o boot para dar tempo para o script de criação de parâmetros

--Nossa Senhora das 6 hélices, protetora dos drones,
--que atravessam o cerrado as 6 horas da tarde,
--Fazei com que eu chegue do outro lado,
--sem crashes com árvores.
--Amém.

--code by Renan Mandelo Oliveira