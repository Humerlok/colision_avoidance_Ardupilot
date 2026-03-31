--Colision Avoidance v0.1.2
-- set SCR_USER1 to the desired limit distance in cm

--variáveis de leitura
local distance
local threshold -- configure a distância de segurança em cm no parametro SCR_USER1
local droneMode
local armingState
local velocity

--variáveis de tempo
local colisionTime = nil
local now = 0
local last_msg_time = 0
local msg_interval = 1000    --1s
local last_break_time = 0
local break_interval = 10000 --10s


function avoidance()
    now = millis()

    if distance ~= nil then          --verifica se há dados de lidar
        if distance < threshold then --verifica se a distância é menor que o threshold
            if not colisionTime then --timer para filtrar leituras falsas
                colisionTime = now
            end

            if now - colisionTime >= 500 then --timer para filtrar leituras falsas
                droneMode = vehicle:get_mode()

                if droneMode ~= 17 then  --verifica se o drone não está em modo break
                    vehicle:set_mode(17) -- change to break mode
                    gcs:send_text(6, "BREAK! - Obstacle detected")
                    last_break_time = now
                end

                if droneMode == 17 and now - last_break_time >= break_interval then --verifica se o drone está em modo break e muda para RTL depois de 10s
                    vehicle:set_mode(6)
                    gcs:send_text(6, "Returning to Home - Collision Avoidance")
                end

                if now - last_msg_time >= msg_interval then --timer para menssagem não floodar
                    gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
                    last_msg_time = now
                end
            end
        elseif distance <= threshold + threshold / 2 and distance > threshold then
            if now - last_msg_time >= msg_interval then --timer para menssagem não floodar
                gcs:send_text(6, "Obstacle close")
                gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
                last_msg_time = now
                colisionTime = nil
            end
        else
            colisionTime = nil
        end
    else
        if now - last_msg_time >= msg_interval then --timer para menssagem não floodar
            gcs:send_text(6, "Caution: No lidar data for avoidance")
            last_msg_time = now
        end
    end
end

function update()
    threshold = param:get("SCR_USER1") or 0
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    armingState = vehicle:get_arming_state()
    velocity = ahrs:get_groundspeed()

    if velocity and velocity > 1 and armingState == 1 then
        avoidance()
    end

    return update, 250
end

gcs:send_text(6, "Collision Avoidance is running v0.1.2")
return update()

--code by Renan Mandelo Oliveira
