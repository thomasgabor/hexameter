require "serialize"
local show = serialize.presentation

local settings = {
    rates = {
        invent = 0.5,
        combine = 0.5,
        praiseshare = 0.1
    }
}

-- static world description library

statics = {}

local function place(object, x, y)
    statics[x] = statics[x] or {}
    statics[x][y] = statics[x][y] or {}
    table.insert(statics[x][y], object)
end

local function nest()
    return {
        class = "nest"
    }
end

local function resource()
    return {
        class = "resource"
    }
end


-- sensor/motor library

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
        return {goal=me.state.goal, features={}}
    end
}

local look = {
    type = "look",
    class = "sensor",
    measure = function (me, world, control)
        if statics[me.state.x] and statics[me.state.x][me.state.y] then
            return statics[me.state.x][me.state.y]
        else
            return {}
        end
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
                if can(world[name], listen) then
                    world[name].state.attention = control.content
                end
            end
        end
        return me
    end
}

local strive = {
    type = "strive",
    class = "motor",
    run = function(me, _, control)
        me.state.goal = control.goal or me.state.goal
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


-- static world configuration

place(nest(),      0,  0)
place(resource(),  9,  7)
place(resource(), -5, -7)


-- dynamic world configuration

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
        sensors = {spot, guts, look},
        motors = {move, shout, procrastinate, strive},
        state = {
            x = 1,
            y = 1,
            goal = "live"
        }
    },
    math1 = {
        sensors = {spot, listen, guts, look},
        motors = {move, forget, procrastinate, strive},
        state = {
            x = 5,
            y = 5,
            goal = "live"
        }
    },
    math2 = {
        sensors = {spot, listen, guts, look},
        motors = {move, forget, procrastinate, strive},
        state = {
            x = 7,
            y = 7,
            goal = "live"
        }
    }
}

return world --not necessary at the time of writing this, but could become part of the specification