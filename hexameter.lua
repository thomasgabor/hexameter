local print = print
local string = string

local medium = require "daktylos"
local behavior = require "spondeios"

module(..., package.seeall)

-- network management --------------------------------------------------------------------------------------------------

local net = {friends={}, acks={}}
local networking = function (continuation)
    return function (type, parameter, author, space)
        if type == "ack" then
            net.acks[author] = net.acks[author] or {}
            net.acks[author][space] = net.acks[author][space] or {}
            table.insert(net.acks[author][space], parameter)
            return nil
        end
        if space == "net.friends" then
            if type == "qry" or type == "get" then
                local response = {}
                for i,filter in ipairs(parameter) do
                    for component,active in ipairs(net.friends) do
                        if active == filter.active then 
                            if string.match(component, filter.name) then
                                if type == "get" then
                                    net.friends[component] = nil
                                end
                                table.insert(response, {name=component, active=true})
                            end
                        end
                    end
                end
                return response
            end
            if type == "put" then
                for i,item in ipairs(parameter) do
                    net.friends[item.name] = item.active or nil
                end
                return parameter
            end
        end
        return continuation(type, parameter, author, space)
    end
end

--  basic functionality  -----------------------------------------------------------------------------------------------

function init(name, callback, codename)
    behavior.init(callback, {networking, "flagging", "verbose"}) --make this more flexible!
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

function friends()
    return net.friends
end

function ask(type, recipient, space, parameter) --enjambement
    local sent = tell(type, recipient, space, parameter)
    local response = false
    while sent and not response do
        respond()
        if net.acks[recipient] and net.acks[recipient][space] then
            for i,answer in ipairs(net.acks[recipient][space]) do
                if true then --insert check for match
                    net.acks[recipient][space][i] = nil
                    response = answer --change, should also be able to collect ALL answers
                end
            end
        end
    end
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
