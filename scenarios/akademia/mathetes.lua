--local repertoire = {}

require "serialize"
local show = serialize.presentation

return function(realm, me, body)
    return function(clock)
        local ideas = hexameter.ask("qry", realm, "sensors", {{body=body, type="remember"}})[1].value --TODO: collect values over multiple tuples
        print("**  [remembered]  ", show(ideas))
        local famesum = 0
        for i,idea in ipairs(ideas) do
            famesum = famesum + (idea.fame or 0)
        end
        famesum = (famesum == 0) and 1 or famesum
        local done = false
        for i,idea in ipairs(ideas) do
            if math.random() < (idea.fame / famesum) then
                hexameter.tell("put", realm, "motors", {{body=body, type=idea.topic.action, control=idea.topic.control}})
                done = true
            end
        end
        --<old code>
        if false then
            local observations = hexameter.ask("qry", realm, "sensors", {{body=body, type="conversation"}})
            local excitement   = hexameter.ask("qry", realm, "sensors", {{body=body, type="excitement"}})[1].value
            --print("**  [observed excite]  ", show(excitement)) --TODO: show is lexically not available here, provide a workaround!
            --print("**  [observed action]  ", show(observations))
            for _,observation in pairs(observations) do
                if observation.value.type then
                    if excitement > (repertoire[1] and repertoire[1].excitement or 0) then
                        table.insert(repertoire, 1, {
                            action = {body=body, type=observation.value.type, control=observation.value.control},
                            excitement = excitement
                        })
                    end
                end
            end
            --TODO: add missing functionality to check for excitement of own position.
            if repertoire[1] then
                hexameter.tell("put", realm, "motors", {repertoire[1].action})
            end
        end
        --</old code>
    end
end