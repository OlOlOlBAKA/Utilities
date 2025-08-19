
local HttpService = game:GetService("HttpService")

local JoinLogWebhook = "https://discord.com/api/webhooks/1407327551092949094/gb1tGaFkepie8povvZA60IT3B27BB9Er9B7DQXzCLlSKn8Df7W9wGznocqvZvytieMBQ"

local function SendJoinLogWebhook(title, webhookURL, displayName, Username)
   local Response = request({
Url = webhookURL,
Method = "POST",
Headers = {
["Content-Type"] = "application/json"
},
Body = HttpService:JSONEncode({
["content"] = "",
["embeds"] = {{
["title"] = title,
["description"] = "",
["type"] = "rich",
["color"] = tonumber(0xFFFFFF),
["fields"] = {
{
["name"] = "Time",
["value"] = "<t:" .. os.time() .. ":F>",
["inline"] = true,
},
{
["name"] = "Display Name",
["value"] = displayName,
["inline"] = true,
},
{
["name"] = "Username",
["value"] = Username,
["inline"] = true,
},
}
}}
})
}
)
end

game:GetService("Players").PlayerAdded:Connect(function(player)
    SendJoinLogWebhook(player.DisplayName.."** Has Joined The Server.**", JoinLogWebhook, player.DisplayName, player.Name)
end)

game:GetService("Players").PlayerRemoved:Connect(function(player)
    SendJoinLogWebhook(player.DisplayName .."** Has Left The Server.**", JoinLogWebhook, player.DisplayName, player.Name)
end)
