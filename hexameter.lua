local medium   = require "daktylos"
local behavior = require "spondeios"
local serialize = require "serialize"


local string = string

local type = type
local assert = assert
local pairs = pairs
local ipairs = ipairs
--local print = print

module(...)

local defaultport    = 55555
local defaultspheres = {"networking", "forwarding", "flagging"}
-- "networking" is necessary for hexameter! "flagging" is highly recommended! "verbose" is useful for testing!

local self


--  basic functionality  -----------------------------------------------------------------------------------------------

function init(name, callback, spheres, codename, options)
    local network
    if type(name) == "string" then
        if string.match(name, ":") then
            self = name
            network = nil
        else
            self = name..":"..defaultport
            network = nil
        end
    elseif type(name) == "number" then
        self = "localhost:"..name
        network = nil
    elseif type(name) == "function" then
        self = name()
        network = name
    else
        self = "localhost:"..defaultport
        network = nil
    end
    local bsuccess = behavior.init(self,   medium.message, callback, spheres or defaultspheres, options)
    local msuccess =   medium.init(self, behavior.process, codename, network, options)
    return msuccess, bsuccess
end

function term()
    local bsuccess = behavior.term()
    local msuccess =   medium.term()
    return msuccess, bsuccess
end

function me()
    return self
end

tell = behavior.act  --send over medium, return success

process = behavior.process  --react to given transmission locally, return result item list

respond = medium.respond  --react to medium traffic, return if reaction took place


--  communication patterns  --------------------------------------------------------------------------------------------

function ask(type, recipient, space, parameter) --formerly known as "enjambement"
    process("put", me(), "net.lust", {{author=recipient, space=space}})
    local sent = tell(type, recipient, space, parameter)
    local response = false
    while sent and not response do
        respond(0)
        response = process("get", me(), "net.lust", {{author=recipient, space=space}})
    end
    return response
end

function wonder(type, recipient, space, parameter, estimate)
    process("put", me(), "net.lust", {{author=recipient, space=space}})
    local sent = tell(type, recipient, space, parameter)
    local response = false
    converse(estimate)
    response = process("get", me(), "net.lust", {{author=recipient, space=space}})
    return response
end

function meet(component)
    put(me(), "net.friends", {{name=component, active=true}})
    local friends = ask("qry", component, "net.friends", {{name="", active=true}})
    --print(serialize.literal(friends))
    put(me(), "net.friends", friends)
    put(component, "net.friends", {{name=me(), active=true}})
    for f,friend in pairs(friends) do
        if friend.active then
            put(friend.name, "net.friends", {{name=me(), active=true}})
        end
    end
end

function friends()
    return process("qry", me(), "net.friends", {{active=true}}) 
end

function converse(estimate) --this function is a relict and may be removed form future versions, use with care!
    estimate = estimate or 10
    for i=1,10 do
        respond()
    end
end


--  shortcuts  ---------------------------------------------------------------------------------------------------------

function get(recipient, space, parameter)
    return tell("get", recipient, space, parameter)
end

function qry(recipient, space, parameter)
    return tell("qry", recipient, space, parameter)
end

function put(recipient, space, parameter)
    return tell("put", recipient, space, parameter)
end

function tell1(type, recipient, space, parameter)
    return tell(type, recipient, space, {parameter})
end

function ask1(type, recipient, space, parameter)
    return ask(type, recipient, space, {parameter})
end
