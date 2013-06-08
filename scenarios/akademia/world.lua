local remember = {
    type = "remember",
    measure = function (me, world)
        return me.state.methexis or {}
    end
}

local spot = {
    type = "spot",
    measure = function (me, world, control)
        local horizon = control.horizon or 10
        local spotted = {}
        for name,body in pairs(world) do
            --TODO: spotting should work in squares, but it's a fine approximation for now
            if not (body == me) then
                if (math.abs(body.state.x - me.state.x) <= horizon) or (math.abs(body.state.y - me.state.y) <= horizon) then
                    table.insert(spotted, name)
                end
            end
        end
        return spotted
    end
}

local move = {
    type = "move",
    run = function(me, _, control)
        if control.up then
            me.state.y = me.state.y + 1
        end
        if control.down then
            me.state.y = me.state.y - 1
        end
        if control.right then
            me.state.x = me.state.x + 1
        end
        if control.left then
            me.state.x = me.state.x - 1
        end
        return me
    end
}

local teach = {
    type = "teach",
    run = function (me, world, control)
        local targets
        if control.target and world[control.target] and control.idea then
            targets = {control.target}
        elseif control.targets and control.idea then
            targets = control.targets
        else --assumes every body with teach also has spot, TODO: make an API to efficiently check that
            targets = spot.measure(me, world, {horizon = control.horizon or nil})
        end
        for t,target in ipairs(targets) do
            local disciple = world[target]
            disciple.state.methexis = disciple.state.methexis or {}
            table.insert(disciple.state.methexis, 1, {topic=control.idea, fame=me.state.fame or 0})
        end
        return me
    end
}

world = {
    platon = {
        sensors = {remember},
        motors = {move, teach},
        state = {
            x = 1,
            y = 1,
            fame = 10
        }
    },
    math1 = {
        sensors = {remember},
        motors = {move, teach},
        state = {
            x = 5,
            y = 5,
            fame = 1
        }
    }
}

return world --not necessary at the time of writing this, but could become part of the specification