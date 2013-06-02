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

local social = {
    type = "social",
    measure = function (me, world)
        local observations = {}
        for name,thing in pairs(world) do
            if not (thing == me)
                table.insert(observations, {body=name, action=thing.state.performed or {}})
            end
        end
        return observations
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

local teach = {
    type = "teach",
    run = function(me, world, control)
        if control.target then
            world[control.target].state.repertoire = world[control.target].state.repertoire or {}
            table.insert(world[control.target].state.repertoire, 1, control.action)
        end
        return me
    end
}

local act = {
    type = "act",
    run = function(me, world, control)
        if me.state.repertoire and me.state.repertoire[1] then
            local acted = false
            local i = 1
            while not acted do
                if not me.state.repertoire[i] then
                    i = 1
                end
                if math.random() < 0.5 then
                    acted = me.state.repertoire[i]()
                end
                i = i + 1
            end
        end
        return me
    end
}

world = {
    platon = {
        sensors = {social, conversation, excitement},
        motors = {move, perform, teach, act},
        state = {
            x = 1,
            y = 1
        },
        --tick = {},
        --tocked = false
    },
    math1 = {
        sensors = {social, conversation, excitement},
        motors = {move, perform, teach, act},
        state = {
            x = 5,
            y = 5
        },
        --tick = {},
        --tocked = false
    }
}

return world --not necessary at the time of writing this, but could become part of the specification