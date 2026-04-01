--Colision Avoidance v0.1.3
-- set SCR_USER1 to the desired limit distance in cm

--variáveis de leitura
local distance
local threshold           -- configure a distância de segurança em cm no parametro SCR_USER1
local droneMode           --modo de voo do drone
local armingState         -- drone armado
local movingState = false --se o drone se move
local brakeMode = false   --se o drone está em brake
local rtlMode = false

--variáveis de tempo
local colisionTime = nil
local now = 0
local last_msg_time = 0
local msg_interval = 1000    --intervalo entra as menssagens
local last_brake_time = 0
local brake_interval = 10000 --intervalo entre o Brake e RTL


function avoidance()
    --verifica se está se movendo
    if ahrs:groundspeed_vector():length() > 1 then
        movingState = true
    else
        movingState = false
    end
    --verifica se a distância é menor que o threshold
    if distance < threshold then
        --timer para filtrar leituras falsas
        if not colisionTime then
            colisionTime = now
        end
        --timer para filtrar leituras falsas
        if now - colisionTime >= 250 then
            --verifica se o drone não está em modo break
            if brakeMode == false and rtlMode == false and movingState then
                -- change to break mode
                vehicle:set_mode(17)
                gcs:send_text(4, "BREAK! - Obstacle detected")
                last_break_time = now
                brakeMode = true
            end
            --timer para menssagem não floodar
            if now - last_msg_time >= msg_interval then
                gcs:send_text(7, "Obstacle Distance: " .. tostring(distance))
                last_msg_time = now
            end
        end
        --Caso o drone esteja se aproximando de algo ele começa a avisar antes
    elseif distance <= threshold + threshold / 2 and distance > threshold then
        --timer para menssagem não floodar
        if now - last_msg_time >= msg_interval then
            gcs:send_text(6, "Obstacle close")
            gcs:send_text(7, "Obstacle Distance: " .. tostring(distance))
            last_msg_time = now
            colisionTime = nil
        end
    else
        colisionTime = nil
    end
    --verifica se o drone está em modo break e muda para RTL depois de 10s
    if brakeMode and now - last_brake_time >= brake_interval then
        --RTL
        vehicle:set_mode(6)
        gcs:send_text(4, "Returning to Home - Collision Avoidance")
        brakeMode = false
        rtlMode = true
    end
end

function update()
    now = millis()
    threshold = param:get("SCR_USER1") or 0
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    armingState = arming:is_armed()
    droneMode = vehicle:get_mode()
    --verifica se o drone ainda está em break
    if breakMode and droneMode ~= 17 then
        breakMode = false
    end
    --verifica se o drone ainda está em RTL
    if rtlMode and droneMode ~= 6 then
        rtlMode = false
    end
    --verifica se há dados de lidar
    if distance ~= nil then
        --verifica se o drone está armado
        if armingState then
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
    --retorna a função principal
    return update, 250
end

gcs:send_text(6, "Collision Avoidance is running v0.1.3")
return update()
--Nossa Senhora das 6 hélices, protetora dos drones,
--que atravessam o cerrado as 6 horas da tarde,
--Fazei com que eu chegue do outro lado,
--sem crashes com árvores.
--Amém.

--code by Renan Mandelo Oliveira
