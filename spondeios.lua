local serialize = require "serialize"

module(..., package.seeall)

local defaultspheres = {"flagging"}

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


--  behavior library  --------------------------------------------------------------------------------------------------

local net = {friends={}, desires={}}

local spaces = {
    trivial = function ()
        return function(type, parameter, author, space)
            return ("answer to "..serialize.data(parameter).." from "..author.."@"..space.."\n")
        end
    end,
    memory = function ()
        local memory = {}
        return function (type, parameter, author, space)
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
    id = function (continuation)
        return function (...)
            return continuation(...)
        end
    end,
    verbose = function (continuation)
        return function (type, parameter, author, space)
            print("--  [received "..type.."]  ", serialize.literal(parameter))
            print("--                  @", space, " from ", author)
            return continuation(type, parameter, author, space)
        end
    end,
    flagging = function (continuation)
        return function (msgtype, parameter, author, space)
            local response = {}
            local requested = false
            local answered = false
            for i,item in ipairs(parameter) do
                requested = true
                local newitem, flags = filter(item, "^#")
                local answers = continuation(msgtype, {newitem}, author, space)
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
                return continuation(msgtype, parameter, author, space)
            end
        end
    end,
    networking = function (continuation)
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
    end,
    forwarding = function (continuation)
        return function (msgtype, parameter, author, space)
            local response = {}
            local requested = false
            local answered = false
            for i,item in ipairs(parameter) do
                local newitem, directions = filter(item, "^!")
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
                return continuation(msgtype, parameter, author, space)
            end
        end
    end
}


--  external interface  ------------------------------------------------------------------------------------------------

local processor = function () error("spondeios processing not initialized!") end

function init(name, msg, character, wrappers)
    self = name or "localhost"
    message = msg or function (type, recipient, space, parameter)
        process(type, parameter, recipient, space)
        return true
    end
    processor = (spaces[character] or (type(character) == "function" and character) or spaces.memory)()
    wrappers = wrappers or defaultspheres
    for i,wrapper in ipairs(wrappers) do
        processor = (spheres[wrapper] or (type(wrapper) == "function" and wrapper) or spheres.id)(processor)
    end
end

function process(...)
    return processor(unpack(arg))
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

function me()
    return self
end