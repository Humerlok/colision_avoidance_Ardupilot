--Collision Avoidance v0.1.6
-- set SCR_USER1 to the desired limit distance in m
-- set SCR_USER2 to the desired speed threshold in km/h

--variáveis de leitura
local distance_threshold = 6000 -- configure a distância de segurança em metros (configurar em SCR_USER1)
local speed_threshold = 11      -- velocidade para dobrar o threshold em m/s (configurar em SCR_USER2)
local altitude_threshold = 20   -- altitude minima em metros para o script funcionar (configurar em SCR_USER3)
local distance = 0
local altitude = 0
local droneMode           --modo de voo do drone
local flyingState         -- drone voando
local movingState = false --se o drone se move
local brakeMode = false   --se o drone está em brake
local rtlMode = false
local debugMode = false   -- use o SCR_USER5 = 1 para ativar o debug
local groundSpeed = 0     -- em m/s

local runAvoidance = false

--variáveis de tempo
local colisionTime = nil
local now = 0
local last_msg_time = 0
local msg_interval = 1000    --intervalo entra as menssagens
local last_brake_time = 0
local brake_interval = 10000 --intervalo entre o Brake e RTL

function debug()
    gcs:send_text(7, "flyingState: " .. tostring(flyingState))
    gcs:send_text(7, "movingState: " .. tostring(movingState))
    gcs:send_text(7, "now: " .. tostring(now))
    gcs:send_text(7, "altitude: " .. tostring(altitude))
    gcs:send_text(7, "altitude_threshold: " .. tostring(altitude_threshold))
    gcs:send_text(7, "groundSpeed: " .. tostring(groundSpeed))
    gcs:send_text(7, "speed_threshold: " .. tostring(speed_threshold))
    gcs:send_text(7, "distance: " .. tostring(distance))
    gcs:send_text(7, "distance_threshold: " .. tostring(distance_threshold))
end

function avoidance()
    --verifica se está se movendo
    if groundSpeed > 1 then
        movingState = true
    else
        movingState = false
    end

    --verifica se a distância é menor que o threshold
    if distance < distance_threshold then
        --timer para filtrar leituras falsas
        if not colisionTime then
            colisionTime = now
        end
        --timer para filtrar leituras falsas
        if now - colisionTime >= 250 then
            --verifica se o drone não está em modo brake
            if brakeMode == false and rtlMode == false and movingState then
                -- change to brake mode
                vehicle:set_mode(17)
                gcs:send_text(4, "BRAKE! - Obstacle detected")
                last_brake_time = now
                brakeMode = true
            end
            --timer para menssagem não floodar
            if now - last_msg_time >= msg_interval then
                gcs:send_text(7, "Obstacle Distance: " .. tostring(distance))
                last_msg_time = now
            end
        end
        --Caso o drone esteja se aproximando de algo ele começa a avisar antes
    elseif distance <= distance_threshold + distance_threshold / 2 and distance > distance_threshold then
        --timer para menssagem não floodar
        if now - last_msg_time >= msg_interval then
            gcs:send_text(5, "Obstacle close")
            gcs:send_text(7, "Obstacle Distance: " .. tostring(distance))
            last_msg_time = now
            colisionTime = nil
        end
    else
        colisionTime = nil
    end

    --verifica se o drone está em modo brake e muda para smartRTL depois de 10s
    if brakeMode and now - last_brake_time >= brake_interval then
        --smartRTL
        vehicle:set_mode(21)
        gcs:send_text(4, "Returning to Home - Collision Avoidance")
        brakeMode = false
        rtlMode = true
    end
end

function update()
    --atualiza as variáveis
    now = millis()
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    flyingState = vehicle:get_likely_flying()
    droneMode = vehicle:get_mode()
    groundSpeed = ahrs:groundspeed_vector():length()
    --atualiza a altitude do drone
    local loc = ahrs:get_location()
    if loc then
        altitude = loc:alt() / 100 --altitude em metros
    else
        altitude = 0
    end

    -- variável que verifica se o drone está em condições de rodar o script
    runAvoidance = flyingState and altitude >= altitude_threshold and not vehicle:is_taking_off() and
        not vehicle:is_landing()

    -- verifica se o drone está se movendo rápido o suficiente para dobrar o threshold
    if groundSpeed ~= nil and groundSpeed > speed_threshold then
        distance_threshold = distance_threshold * 2
    else
        distance_threshold = (param:get("SCR_USER1") or 60) * 100
    end

    --verifica se o drone ainda está em brake
    if brakeMode and droneMode ~= 17 then
        brakeMode = false
    end

    --verifica se o drone ainda está em RTL
    if rtlMode and droneMode ~= 21 then
        rtlMode = false
    end

    --verifica se há dados de rangefinder
    if distance ~= nil then
        --verifica se está em condições de rodar o script
        if runAvoidance then
            --chama a função de anti colisão
            avoidance()
        end
        --se não houver lider ele avisa
    else
        --timer para menssagem não floodar
        if now - last_msg_time >= msg_interval then
            gcs:send_text(4, "Caution: No lidar data for avoidance")
            last_msg_time = now
        end
    end

    -- manda o printão pra nós
    if debugMode then
        debug()
    end

    if param:get("SCR_USER5") == 1 then
        debugMode = true
    else
        debugMode = false
    end

    --retorna a função principal
    return update, 500
end

gcs:send_text(6, "Collision Avoidance is running v0.1.6")
distance_threshold = (param:get("SCR_USER1") or 60) * 100 --usuário define em metros e é convertido para centimetros
speed_threshold = (param:get("SCR_USER2") or 40) / 3.6    -- usuário define em km/h e é convertido para m/s
altitude_threshold = param:get("SCR_USER3") or 20         -- usuário define em metros
return update()

--Nossa Senhora das 6 hélices, protetora dos drones,
--que atravessam o cerrado as 6 horas da tarde,
--Fazei com que eu chegue do outro lado,
--sem crashes com árvores.
--Amém.

--code by Renan Mandelo Oliveira
