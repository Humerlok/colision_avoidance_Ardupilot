--Colision Avoidance v0.1.0
-- set SCR_USER1 to the desired limit distance in cm

local distance
local threshold -- configure a distância de segurança em cm no parametro SCR_USER1
local droneMode

local colisionTime = nil
local now = 0

function update()
    threshold = param:get("SCR_USER1") or 0
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    droneMode = vehicle:get_mode()

    now = millis()

    if distance ~= nil then
        if distance < threshold then
            if not colisionTime then
                colisionTime = now
            end

            if now - colisionTime >= 1000 then
                gcs:send_text(6, "Obstacle detected")
                gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
                if droneMode ~= 17 then
                    vehicle:set_mode(17) -- change to Brake
                end
            end
        elseif distance <= threshold + threshold / 2 and distance > threshold then
            gcs:send_text(6, "Obstacle close")
            gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
        end
    else
        gcs:send_text(6, "no lidar data")
    end

    return update, 500
end

gcs:send_text(6, "Colision Avoidance is running v0.1.0")
return update()

--code by Renan Mandelo Oliveira
