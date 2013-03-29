local print = print
local string = string

local medium = require "daktylos"
local behavior = require "spondeios"

module(..., package.seeall)

-- network management --------------------------------------------------------------------------------------------------

local net = {friends={}, desires={}}
local networking = function (continuation)
    return function (type, parameter, author, space)
        if type == "ack" then
            local answered = false
            for desire,answers in pairs(net.desires) do
                if desire(parameter, author, space) then
                    table.insert(answers, parameter)
                end
            end
            return nil
        end
        if space == "net.friends" then
            if type == "qry" or type == "get" then
                local response = {}
                for i,filter in ipairs(parameter) do
                    for component,active in pairs(net.friends) do
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
                    if item.name then
                        net.friends[item.name] = item.active or nil
                    end
                end
                return parameter
            end
        end
        return continuation(type, parameter, author, space)
    end
end

local forwarding = function (continuation)
    return function (msgtype, parameter, author, space)
        local response = {}
        local requested = false
        local answered = false
        for i,item in ipairs(parameter) do
            local newitem, directions = behavior.filter(item, "^!") --fill in filter function
            if directions["!recipient"] then
                requested = true
                if directions["!recipient"] == me() then
                    local answer = continuation(msgtype, {newitem}, author, space)
                    if answer then
                        answered = true
                        response[i] = answer
                        response[i]["!author"] = me()
                        response[i]["!recipient"] = item["!author"]
                        response[i]["!visited"] = {}
                    end
                else
                    item["!visited"] = (type(item["!visited"]) == "table") and item["!visited"] or {}
                    item["!visited"][me()] = true
                    for friend,active in pairs(net.friends) do
                        if active and not item["!visited"][friend] then
                            local success = medium.message(msgtype, friend, space, {item})
                        end
                    end
                end
            end
        end
        if requested then
            if answered then
                return response
            else
                return nil
            end
        else
            return continuation(msgtype, parameter, author, space)
        end
    end
end

--  basic functionality  -----------------------------------------------------------------------------------------------

function init(name, callback, codename)
    behavior.init(callback, {networking, forwarding, "flagging", "verbose"}) --make this more flexible!
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

function friends()
    return net.friends
end

function await(predicate)
    net.desires[predicate] = {}
    return predicate
end

function fetch(key)
    return net.desires[key]
end

function giveup(key)
    net.desires[key] = nil
end

function ask(type, recipient, space, parameter) --enjambement
    local key = await(function(_, author, respace)
        return recipient == author and space == respace --insert better check for match
    end)
    local sent = tell(type, recipient, space, parameter)
    local response = false
    while sent and not response do
        respond()
        for a,answer in ipairs(fetch(key)) do
            response = answer --collect answers later
        end
    end
    giveup(key)
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
