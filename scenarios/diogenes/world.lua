local conversation = {
    type = "conversation",
    measure = function (me, world)
        for _,thing in pairs(world) do
            if not (thing == me) then
                return thing.state.performed or {}
            end
        end
        return {}
    end
}

local excitement = {
    type = "excitement",
    measure = function (me, world)
        for _,thing in pairs(world) do
            if not (thing == me) then
                local POI = {x = 10, y = 10}
                local d = math.abs(thing.state.x - POI.x) + math.abs(thing.state.y - POI.y)
                return (100-d)
            end
        end
    end
}

local perform = {
    type = "perform",
    run = function (me, _, control)
        me.state.performed = control.actions or {}
        return me
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

world = {
    diogenes = {
        sensors = {conversation, excitement},
        motors = {move, perform},
        state = {
            x = 1,
            y = 1
        },
        tick = {},
        tocked = false
    },
    alexander = {
        sensors = {conversation, excitement},
        motors = {move, perform},
        state = {
            x = 5,
            y = 5
        },
        tick = {},
        tocked = false
    }
}

return world --not necessary at this point.