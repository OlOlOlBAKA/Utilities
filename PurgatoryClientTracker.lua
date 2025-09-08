
local EventWrapper = {}

function EventWrapper.Connect(remoteEvent, callback)
    return remoteEvent.OnClientEvent:Connect(function(...)
        print("Script '" .. script.Name .. "' has fired event: " .. remoteEvent.Name)
        callback(...)
    end)
end

return EventWrapper
