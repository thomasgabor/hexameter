local serialize = require "serialize"

local string = string
local table = table

local error = error
local type = type
local assert = assert
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local print = print

module(...)

local defaultspheres = {"networking", "flagging"}

local self, message


--  tool functions  ----------------------------------------------------------------------------------------------------

local function equal(a, b)
    if type(a) == type(b) then
        if type(a) == "table" then
            for key,val in pairs(a) do
                if not equal(b[key], val) then
                    return false
                end
            end
            return true
        end
        return a == b
    end
    return false
end

local function filter(item, pattern)
    local meta = {}
    local newitem = {}
    if type(item) == "table" then
        for key,val in pairs(item) do
            if type(key) == "string" and string.match(key, pattern) then
                meta[key] = val
            else
                newitem[key] = val
            end
        end
    end
    return newitem, meta
end

local function reverse(t)
    local r = {}
    for i,value in ipairs(t) do
        r[#t-i+1] = value
    end
    return r
end


--  behavior library  --------------------------------------------------------------------------------------------------

local net = {friends={}, desires={}, lust={}}

local spaces = {
    trivial = function ()
        return function(type, author, space, parameter)
            return ("answer to "..serialize.data(parameter).." from "..author.."@"..space.."\n")
        end
    end,
    memory = function ()
        local memory = {}
        return function (type, author, space, parameter)
            memory[space] = memory[space] or {}
            if type == "get" or type == "qry" then
                local response = {}
                for i,item in ipairs(parameter) do
                    for t,tuple in ipairs(memory[space]) do
                        if equal(item, tuple) then
                            if type == "get" then
                                table.remove(memory[space], t)
                            end
                            table.insert(response, tuple)
                        end
                    end
                end
                return response
            end
            if type == "put" then
                for i,item in ipairs(parameter) do
                    for t,tuple in ipairs(memory[space]) do
                        if equal(tuple, parameter) then
                            table.remove(memory[space], t)
                        end
                    end
                    table.insert(memory[space], item)
                end
                return parameter
            end
        end
    end
}

local spheres = {
    id = function (continuation, _)
        return function (msgtype, author, space, parameter, recipient)
            return continuation(msgtype, author, space, parameter, recipient)
        end
    end,
    verbose = function (continuation, direction)
        if direction == "in" then
            return function (type, author, space, parameter)
                print("--  [received "..type.."]  ", serialize.literal(parameter))
                print("--                  @", space, " from ", author)
                return continuation(type, author, space, parameter)
            end
        else
            return function (type, recipient, space, parameter)
                print("++  [sent "..type.."]  ", serialize.literal(parameter))
                print("++                  @", space, " to ", recipient)
                return continuation(type, recipient, space, parameter)
            end
        end
    end,
    flagging = function (continuation, direction)
        if direction == "in" then
            return function (msgtype, author, space, parameter)
                local newspace, _ = string.match(space, "^([^#]*)(.*)$")
                local response = {}
                local requested = false
                local answered = false
                for i,item in ipairs(parameter) do
                    requested = true
                    local newitem, flags = filter(item, "^#")
                    local answers = continuation(msgtype, author, newspace, {newitem})
                    if answers then
                        answered = true
                        for a,answer in ipairs(answers) do
                            local newanswer = {}
                            for key,val in pairs(answer) do
                                newanswer[key] = val
                            end
                            for key,val in pairs(flags) do
                                newanswer[key] = val
                            end
                            table.insert(response, newanswer)
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
                    return continuation(msgtype, author, newspace, parameter)
                end
            end
        end
    end,
    networking = function (continuation, direction)
        if direction == "in" then
            return function (type, author, space, parameter)
                if type == "ack" then
                    local answered = false
                    for desire,answers in pairs(net.desires) do
                        if desire(author, space, parameter) then
                            net.desires[desire] = answers or {}
                            for i,item in ipairs(parameter) do
                                table.insert(net.desires[desire], item)
                            end
                        end
                    end
                    if net.lust[author] and net.lust[author][space] ~= nil then
                        net.lust[author][space] = net.lust[author][space] or {}
                        for i,item in ipairs(parameter) do
                            table.insert(net.lust[author][space], item)
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
                                    if string.match(component, filter.name or "") then
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
                if space == "net.lust" then
                    if type == "get" then
                        local response = {}
                        local answered = false
                        for i,item in ipairs(parameter) do
                            if item.author and item.space and net.lust[item.author] and net.lust[item.author][item.space] then
                                answered = true
                                for a,answer in ipairs(net.lust[item.author][item.space]) do
                                    table.insert(response, answer)
                                end
                            end
                        end
                        if answered then
                            return response
                        else
                            return nil
                        end
                    end
                    if type == "put" then
                        for i,item in ipairs(parameter) do
                            if item.author and item.space then
                                net.lust[item.author] = net.lust[item.author] or {}
                                net.lust[item.author][item.space] = false
                            end
                        end
                        return parameter
                    end
                end
                if space == "net.life" then
                    return parameter
                end
                return continuation(type, author, space, parameter)
            end
        end
    end,
    forwarding = function (continuation, direction)
        if direction == "in" then
            return function (msgtype, author, space, parameter)
                local response = {}
                local requested = false
                local answered = false
                for i,item in ipairs(parameter) do
                    local newitem, directions = filter(item, "^!")
                    if directions["!recipient"] then
                        requested = true
                        if directions["!recipient"] == me() then
                            local answer = continuation(msgtype, author, space, {newitem})
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
                                    local success = message(msgtype, friend, space, {item})
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
                    return continuation(msgtype, author, space, parameter)
                end
            end
        end
    end
}


--  hexameter interface  -----------------------------------------------------------------------------------------------

local processor = function () error("spondeios processing not initialized!") end
local actor = function () error("spondeios acting not initialized!") end

local function getsphere(wrapper)
    return (spheres[wrapper] or (type(wrapper) == "function" and wrapper) or spheres.id)
end

function init(name, msg, character, wrappers)
    self = name or "localhost"
    message = msg or function (type, recipient, space, parameter)
        process(type, recipient, space, parameter)
        return true
    end
    processor = (spaces[character] or (type(character) == "function" and character) or spaces.memory)()
    wrappers = wrappers or defaultspheres
    for i,wrapper in ipairs(wrappers) do
        processor = getsphere(wrapper)(processor, "in") or spheres.id(processor)
    end
    actor = message
    for i,wrapper in ipairs(reverse(wrappers)) do
        actor = getsphere(wrapper)(actor, "out") or spheres.id(actor)
    end
    return true
end

function term()
    self = nil
    net = {friends={}, desires={}, lust={}}
    processor = function () error("spondeios processing not initialized!") end
    actor = function () error("spondeios acting not initialized!") end
    return true
end

function me()
    return self
end

function process(...)
    local arg = {...}
    return processor(unpack(arg))
end

function act(type, recipient, space, parameter)
    assert(type == "get" or type == "qry" or type == "put", "Wrong message type \""..type.."\"")
    if recipient == me() then
        process(type, recipient, space, parameter)
        return true
    end
    return actor(type, recipient, space, parameter)
end


--  additional interface  ----------------------------------------------------------------------------------------------

function await(predicate) --possibly deprecated
    net.desires[predicate] = false
    return predicate
end

function fetch(key) --possibly deprecated
    return net.desires[key]
end

function giveup(key) --possibly deprecated
    net.desires[key] = nil
end