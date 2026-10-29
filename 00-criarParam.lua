function create_parameter()
    -- define the table key
    local TABLE_KEY = 102

    -- create parameter table
    if not param:add_table(TABLE_KEY, "CoAv_", 7) then
        gcs:send_text(7, "Unable to add CoAv_ table")
        return
    end
    gcs:send_text(7, "Successfully added CoAv_ table")

    -- add first parameter
    if not param:add_param(TABLE_KEY, 1, "DIST_LIM", 30) then
        gcs:send_text(7, "Unable to add DIST_LIM parameter")
        return
    end
    gcs:send_text(7, "Added DIST_LIM parameter successfully")

    -- add second parameter
    if not param:add_param(TABLE_KEY, 2, "SPD_DBL", 40) then
        gcs:send_text(7, "Unable to add SPD_DBL parameter")
        return
    end
    gcs:send_text(7, "Added SPD_DBL parameter successfully")

    -- add third parameter
    if not param:add_param(TABLE_KEY, 3, "JERK_XY", 5) then
        gcs:send_text(7, "Unable to add JERK_XY parameter")
        return
    end
    gcs:send_text(7, "Added JERK_XY parameter successfully")

    -- add fourth parameter
    if not param:add_param(TABLE_KEY, 4, "ANGLE_MAX", 3000) then
        gcs:send_text(7, "Unable to add ANGLE_MAX parameter")
        return
    end
    gcs:send_text(7, "Added ANGLE_MAX parameter successfully")

    -- add fifth parameter
    if not param:add_param(TABLE_KEY, 5, "DBG_MODE", 0) then
        gcs:send_text(7, "Unable to add DBG_MODE parameter")
        return
    end
    gcs:send_text(7, "Added DBG_MODE parameter successfully")

    -- add sixth parameter
    if not param:add_param(TABLE_KEY, 6, "ON_OFF", 1) then
        gcs:send_text(7, "Unable to add ON_OFF parameter")
        return
    end
    gcs:send_text(7, "Added ON_OFF parameter successfully")

    -- add seventh parameter
    if not param:add_param(TABLE_KEY, 7, "DIST_MIN", 2) then
        gcs:send_text(7, "Unable to add DIST_MIN parameter")
        return
    end
    gcs:send_text(7, "Added DIST_MIN parameter successfully")
    
end

return create_parameter()
