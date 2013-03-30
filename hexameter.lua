local print = print
local string = string

local medium = require "daktylos"
local behavior = require "spondeios"

module(..., package.seeall)

--  basic functionality  -----------------------------------------------------------------------------------------------

function init(name, callback, codename)
    behavior.init(me, medium.message, callback, {"networking", "forwarding", "flagging", "verbose"}) --make this more flexible!
    return medium.init(name, behavior.process, nil, codename)
end

function term()
	return medium.term()
end

function tell(type, recipient, space, parameter)
    assert(type == "get" or type == "qry" or type == "put", "Wrong message type \""..type.."\"")
    return medium.message(type, recipient, space, parameter)
end

respond = medium.respond

process = function(type, recipient, space, parameter)
    return behavior.process(type, parameter, recipient, space)
end


--  patterns  ----------------------------------------------------------------------------------------------------------

function me()
    return medium.me()
end

function meet(component)
    put(me(), "net.friends", {{name=component, active=true}})
    local friends = ask("qry", component, "net.friends", {{name="", active=true}})
    put(me(), "net.friends", friends)
    put(component, "net.friends", {{name=me(), active=true}})
end

friends = behavior.friends

function ask(type, recipient, space, parameter) --enjambement
    local key = behavior.await(function(_, author, respace)
        return recipient == author and space == respace --TODO: insert better check for match
    end)
    local sent = tell(type, recipient, space, parameter)
    local response = false
    while sent and not response do
        respond()
        for a,answer in ipairs(behavior.fetch(key)) do
            response = answer --collect answers later
        end
    end
    behavior.giveup(key)
    return response
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
