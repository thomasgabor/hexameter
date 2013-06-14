--local repertoire = {}

require "serialize"
local show = serialize.presentation

return function(realm, me)
    return function(clock, body)
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
    end
end