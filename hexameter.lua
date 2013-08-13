local medium   = require "daktylos"
local behavior = require "spondeios"
local serialize = require "serialize"


local string = string

local type = type
local assert = assert
local pairs = pairs
local ipairs = ipairs
local print = print

module(...)

local defaultport    = 55555
local defaultspheres = {"networking", "forwarding", "flagging", "verbose"}

--  basic functionality  -----------------------------------------------------------------------------------------------

local self

function init(name, callback, spheres, codename)
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
    local bsuccess = behavior.init(self,   medium.message, callback, spheres or defaultspheres)
    local msuccess =   medium.init(self, behavior.process, codename, network)
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

tell = behavior.act

respond = medium.respond

process = behavior.process -- works as a shortcut for tell(me(), ...)


--  communication patterns  --------------------------------------------------------------------------------------------

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

friends = behavior.friends

function ask(type, recipient, space, parameter) --enjambement
    local key = behavior.await(function(_, author, respace)
        return recipient == author and space == respace --TODO: insert better check for match(?)
    end)
    local sent = tell(type, recipient, space, parameter)
    local response = false
    while sent and not response do
        respond(0)
        response = behavior.fetch(key)
    end
    behavior.giveup(key)
    return response
end

function converse(estimate) --this function is a relict and should probably not be used
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
