--evolutionary programming over scel

require "hexameter"

local realm, me, body

if arg[1] then
    realm = arg[1]
else
    io.write("Enter an address:port for the world simulator: ")
    realm = io.read("*line")
end

if arg[2] then
    me = arg[2]
else
    io.write("Enter an address:port for this component: ")
    me = io.read("*line")
end

if arg[3] then
    body = arg[3]
else
    io.write("Enter the name of this component's body: ")
    body = io.read("*line")
end

local story = function ()
    return function(msgtype, parameter, author, space)
        if msgtype == "put" and space == "hades.ticks" then
            --react and stuff
        end
    end
end

hexameter.init(me)
hexameter.meet(realm)
hexameter.converse()
hexameter.put(realm, "ticks", {{body=body, soul=me}})

local continue = true
while continue do
    hexameter.converse()
    local command = io.read("*line")
    if string.match(command, "^q") then
        continue = false
    end
    hexameter.put(realm, "tocks", {{body=body}})
end
