--evolutionary programming over scel

require "hexameter"
require "serialize"
local show = serialize.presentation

local realm, me, body, clock

if arg[1] then
    realm = arg[1]
else
    io.write("??  Enter an address:port for the world simulator: ")
    realm = io.read("*line")
end

if arg[2] then
    me = arg[2]
else
    io.write("??  Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[3] then
    body = arg[3]
else
    io.write("??  Enter the name of this component's body: ")
    body = io.read("*line")
end

clock = 0 --TODO: perhaps put this inside the "story" below?
local story = function ()
    local repertoire = {}
    --local aspiration = 0
    return function(msgtype, parameter, author, space)
        if msgtype == "put" and space == "hades.ticks" then
            for _,item in pairs(parameter) do
                clock = item.period > clock and item.period or clock
            end
            --<experimental behavior>
            local observations = hexameter.ask("qry", realm, "sensors", {{body=body, type="conversation"}})
            local excitement   = hexameter.ask("qry", realm, "sensors", {{body=body, type="excitement"}})[1].value
            print("**  [observed excite]  ", show(excitement))
            print("**  [observed action]  ", show(observations))
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
            os.execute("sleep 1") --TODO: WHY is this necessary???
            hexameter.tell("put", realm, "tocks", {{body=body}})
            --</experimental behavior>
        end
    end
end

hexameter.init(me, story)

io.write("::  Epos running. Please exit with Ctrl+C.\n")

hexameter.meet(realm)
hexameter.converse()
hexameter.put(realm, "ticks", {{body=body, soul=me}})
hexameter.converse()
hexameter.put(realm, "tocks", {{body=body}})


local continue = false
while continue do
    hexameter.converse()
    --io.write(clock, "> ")
    --local command = io.read("*line")
    --if string.match(command, "^q") then
    --    continue = false
    --end
    local observations = hexameter.ask("qry", realm, "sensors", {{body=body, type="conversation"}})
    print(show(observations))
    for _,observation in pairs(observations) do
        if observation.value.type then
            hexameter.tell("put", realm, "motors", {
                {body=body, type=observation.value.type, control=observation.value.control}
            })
        end
    end
    --io.write("Please press enter...") --TODO: Do not use this workaround to send batch messages!
    --io.read("*line")
    hexameter.put(realm, "tocks", {{body=body}})
end

while true do
    hexameter.respond(0)
end