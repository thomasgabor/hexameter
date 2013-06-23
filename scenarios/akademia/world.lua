require "serialize"
local show = serialize.presentation

local settings = {
    rates = {
        invent = 0.5,
        combine = 0.5,
        praiseshare = 0.1
    }
}

local direct = function(me, world, control) --using this function makes you use "spot" sensor!
    local targets
    if control.target and world[control.target] then
        targets = {control.target}
    elseif control.targets then
        targets = control.targets
    else
        targets = sensor(me, "spot", {horizon = control.horizon or nil})
    end
    return targets
end

local remember = {
    type = "remember",
    class = "sensor",
    measure = function (me, world)
        return me.state.methexis or {}
    end
}

local spot = {
    type = "spot",
    class = "sensor",
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

local teach = {
    type = "teach",
    class = "motor",
    using = {spot},
    run = function (me, world, control)
        if not control.idea then --could also default to "teaching nothing", i.e. {procrastinate}
            return me
        end
        local targets = direct(me, world, control)
        for t,target in ipairs(targets) do
            local disciple = world[target]
            disciple.state.methexis = disciple.state.methexis or {}
            table.insert(disciple.state.methexis, 1, {topic=control.idea, fame=me.state.fame or 0})
        end
        return me
    end
}

local function combine(idea1, idea2)
    local newidea = {fame = (idea1.fame + idea2.fame)/2, topic = {}}
    local used1 = false
    local usednotall1 = false
    local used2 = false
    local usednotall2 = false
    for c,command in ipairs(idea1.topic) do
        if math.random() < settings.rates.combine then --TODO: adjust stochastic process (RNG!! Lua's sucks!)
            table.insert(newidea.topic, command)
            used1 = true
        else
            usednotall1 = true
        end
    end
    for c,command in ipairs(idea2.topic) do
        if math.random() < settings.rates.combine then
            table.insert(newidea.topic, command) --TODO: handle mutliple, identical commands
            used2 = true
        else
            usednotall2 = true
        end
    end
    if (used1 and used2) or notusedall1 or notusedall2 then
        return newidea
    else
        return nil --process fails here, consider just restrating it?
    end
end

local invent = {
    type = "invent",
    class = "motor",
    run = function (me, world, control)
        me.state.methexis = me.state.methexis or {}
        local newideas = {}
        for _,one in ipairs(me.state.methexis) do
            for _,another in ipairs(me.state.methexis) do
                if math.random() < settings.rates.invent then
                    local newidea = combine(one,another)
                    if newidea and (#(newidea.topic) > 0) then
                        --print("$$  combined: ", show(newidea))
                        table.insert(newideas, 1, newidea)
                    end
                end
            end
        end
        --table.insert(me.state.methexis, 1, {topic={{action="procrastinate"}}, fame=100})
        for _,newidea in ipairs(newideas) do
            table.insert(me.state.methexis, 1, newidea)
        end
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

local applaud = {
    type = "applaud",
    class = "motor",
    run = function (me, world, control)
        local targets = direct(me, world, control)
        for t,target in ipairs(targets) do
            local recipient = world[target]
            recipient.state.fame = recipient.state.fame + math.ceil(me.state.fame * settings.rates.praiseshare)
        end
        return me
    end
}

world = {
    platon = {
        sensors = {remember, spot},
        motors = {move, teach, invent, procrastinate, applaud},
        state = {
            x = 1,
            y = 1,
            fame = 10
        },
        time = {{run=function(me,world,period) me.state.fame = me.state.fame + 1 end}}
    },
    math1 = {
        sensors = {remember, spot},
        motors = {move, teach, invent, procrastinate, applaud},
        state = {
            x = 5,
            y = 5,
            fame = 1
        }
    },
    math2 = {
        sensors = {remember, spot},
        motors = {move, teach, invent, procrastinate, applaud},
        state = {
            x = 7,
            y = 7,
            fame = 1
        }
    }
}

return world --not necessary at the time of writing this, but could become part of the specification