require "serialize"
local show = serialize.presentation

local settings = {
    rates = {
        invent = 0.5,
        combine = 0.5,
        praiseshare = 0.1
    }
}

local spot = {
    type = "spot",
    class = "sensor",
    measure = function (me, world, control)
        local horizon = control.horizon or 10
        local spotted = {}
        for name,body in pairs(world) do
            --TODO: spotting shouldn't work in squares, but it's a fine approximation for now
            if not (body == me) then
                if (math.abs(body.state.x - me.state.x) <= horizon) or (math.abs(body.state.y - me.state.y) <= horizon) then
                    table.insert(spotted, name)
                end
            end
        end
        return spotted
    end
}

local listen = {
    type = "listen",
    class = "sensor",
    measure = function (me, world, control)
        return me.state.attention
    end
}

local guts = {
    type = "guts",
    class = "sensor",
    measure = function (me, world, control)
        return {goal="live", features={}}
    end
}

local move = {
    type = "move",
    class = "motor",
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

local shout = {
    type = "shout",
    class = "motor",
    run = function(me, _, control)
        if control.name and world[control.name] then
            world[control.name].state.attention = control.content
        else
            for _,name in pairs(sensor(me, "spot")) do
                world[name].state.attention = control.content
            end
        end
        return me
    end
}

local forget = {
    type = "forget",
    class = "motor",
    run = function(me, _, control)
        me.state.attention = nil
        return me
    end
}

local procrastinate = {
    type = "procrastinate",
    class = "motor",
    run = function (me, world, control)
        return me
    end
}

world = {
    observ = {
        sensors = {},
        motors = {move},
        state = {
            x = 0,
            y = 0
        }
    },
    platon = {
        sensors = {spot, guts},
        motors = {move, shout, procrastinate},
        state = {
            x = 1,
            y = 1
        }
    },
    math1 = {
        sensors = {spot, listen, guts},
        motors = {move, forget, procrastinate},
        state = {
            x = 5,
            y = 5
        }
    },
    math2 = {
        sensors = {spot, listen, guts},
        motors = {move, forget, procrastinate},
        state = {
            x = 7,
            y = 7
        }
    }
}

return world --not necessary at the time of writing this, but could become part of the specification