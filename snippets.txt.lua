-- this file contains usage patterns for the hexameter protocol stack that are not shown in standard files

-- old ask function of hexameter ---------------------------------------------------------------------------------------
-- shows how to use the additional interface of spondeios to register predicates which then filter incoming traffic for
-- a certain message and thus allow for much finer control than the net.lust mechanism (only matching auhtor and space)
function ask(type, recipient, space, parameter) --deprecated
    local key = behavior.await(function(author, respace, _)
        return recipient == author and space == respace --rough match, for guaranteed unique match use unique space flag
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

-- unique ask for hexameter --------------------------------------------------------------------------------------------
-- when asking a question, hexameter treats any message from the asked component and the same space as an answer, which
-- is usually what you want (other components dynamically acting as said component is a feature in a trusted network!)
-- however, there is a quick solution to make sure the answer you get really belongs to the quesion you asked:
-- first make sure hexameter is using the "flagging" sphere, then you can use a technique called "space flagging".
local questionid = some_function_that_generates_a_unique_string()
local question = {{your=12}, {question=34}, {params=56}}
local sure_answer = hexameter.ask("qry", recipient, "originalspace#"..questionid, question)
-- there may be a shortcut for this in future hexameter versions, however generating the unique ID really has no place
-- in hexameter right now (so watch out for a library related to that stuff!)
-- [note: the shebang "#!" instead of the simple hash "#" marks flags used by hexameter then]