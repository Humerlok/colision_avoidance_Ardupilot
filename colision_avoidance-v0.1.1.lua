--Colision Avoidance v0.1.1
-- set SCR_USER1 to the desired limit distance in cm

local distance
local threshold -- configure a distância de segurança em cm no parametro SCR_USER1
local droneMode
local armingState
local velocity

local colisionTime = nil
local now = 0


function avoidance()
    now = millis()

    if distance ~= nil then
        if distance < threshold then
            if not colisionTime then
                colisionTime = now
            end

            if now - colisionTime >= 500 then
                gcs:send_text(6, "Obstacle detected")
                gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
                if droneMode ~= 6 then
                    vehicle:set_mode(6) -- change to RTL
                end
            end
        elseif distance <= threshold + threshold / 2 and distance > threshold then
            gcs:send_text(6, "Obstacle close")
            gcs:send_text(6, "Obstacle Distance: " .. tostring(distance))
        else
            colisionTime = nil
        end
    else
        gcs:send_text(6, "no lidar data")
    end
end

function update()
    threshold = param:get("SCR_USER1") or 0
    distance = rangefinder:distance_cm_orient(0) -- 0 = Frente (Forward). Altere se for outra direção.
    droneMode = vehicle:get_mode()
    armingState = vehicle:get_arming_state()
    velocity = ahrs:get_groundspeed()

    if velocity > 1 and armingState == 1 then
        avoidance()
    end

    return update, 500
end

gcs:send_text(6, "Collision Avoidance is running v0.1.1")
return update()

--code by Renan Mandelo Oliveira
