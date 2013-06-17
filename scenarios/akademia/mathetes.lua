--TODO: do something about the RNG, Lua's one sucks

local rates = {
    recombination = 0.1
}

require "serialize"
local show = serialize.presentation

return function(realm, me)
    return function(clock, body)
        local ideas = hexameter.ask("qry", realm, "sensors", {{body=body, type="remember"}})[1].value --TODO: collect values over multiple tuples
        print("**  [remembered]  ", show(ideas))

        --choose action
        local famesum = 0
        for i,idea in ipairs(ideas) do
            famesum = famesum + (idea.fame or 0)
        end
        famesum = (famesum == 0) and 1 or famesum
        local done = false
        for i,idea in ipairs(ideas) do
            if math.random() < (idea.fame / famesum) then
                local commands = {}
                for c,command in ipairs(idea.topic) do --NOTE: spec also allows pairs() here, don't get tricked thinking that the sequence is guaranteed
                    commands[c] = {body=body, type=command.action, control=command.control}
                end
                if math.random() < rates.recombination then
                    table.insert(commands, {body=body, type="invent"})
                end
                hexameter.tell("put", realm, "motors", commands)
                done = true
            end
        end
    end
end