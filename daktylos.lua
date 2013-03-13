local print = print
local string = string

local zmq = require "zmq"

local json = require ("dkjson")
local serialize = require ("serialize")

module(..., package.seeall)

local context, self, port, processor, resolver, coder

local recvtries  = 100000 --magic number achieved through tests
local defaultport = 55555
local defaultcode = "json"

local function address(component)
	if type(component) == "string" then
		return component
	end
	if type(component) == "number" then
		return "localhost:"..component
	end
	error()
end

local codes = {
    lua = {
        encode = serialize.data,
        decode = function (message)
            return loadstring(message)()
        end
    },
    json = json
}

function init(name, callback, network, codename)
    context = zmq.init(1)
    self = name or "localhost:"..defaultport
    port = string.match(self, "[%w%p]*:") and string.gsub(self, "[%w%p]*:", "") or defaultport
    processor = callback or function (type, parameter, author, space)
        if type == "ack" then
            return nil
		elseif type == "syn" then
			return parameter
        else
            return ("answer to "..serialize.data(parameter))
        end
    end
	resolver = network or address
    codename = codename or defaultcode
    coder = codes[codename]
    coder.name = codename
end

function term()
	context:term()
end

function message(type, recipient, space, parameter)
    local msg = coder.name.."\n"
    msg = msg..coder.encode({
		recipient=resolver(recipient),
		author=resolver(self),
		type=type,
		parameter=parameter,
		space=space
	})
    local socket = context:socket(zmq.REQ)
    --socket:setopt(zmq.LINGER, 0) --no idea why this doesn't work
	socket:connect("tcp://"..resolver(recipient))
	local success = socket:send(msg)
	socket:close()
    return success
end

function syn(recipient, space, parameter)
    return message("syn", recipient, space, parameter)
end

function ack(recipient, space, parameter)
    return message("ack", recipient, space, parameter)
end

function respond(tries)
    tries = tries or recvtries
	local socket = context:socket(zmq.REP)
	socket:bind("tcp://*:"..port)
	local msg = nil
	local i = 0
	while not msg and i < tries do
		msg = socket:recv(zmq.NOBLOCK)
		i = i + 1
	end
    socket:close()
	if msg then
		local codename = string.match(msg, "^(%w*)\n") or ""
		assert(codes[codename], "received message with invalid encoding \""..codename.."\"") --make more tolerant later
		if msg then
			--print(">>>>", msg)
			local mess = codes[codename].decode(string.gsub(msg, "^(%w*)\n", ""))
			local resp = processor(mess.type, mess.parameter, mess.author, mess.space, mess.recipient)
			if resp then
				return ack(mess.author, mess.space, resp)
			end
		end
	    return true
	else
		return false
	end
end

function me()
    return self
end