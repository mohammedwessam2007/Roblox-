-- Minimal Roblox Studio CLI baseline. No credentials, no published experience.
-- This runs in Studio EDIT mode, NOT a Play test or networked server.
local ok, err = pcall(function()
    assert(game:GetService("RunService"):IsStudio(), "not a Studio runtime")
    local part = Instance.new("Part")
    part.Name = "TemporaryOfflineSmoke"
    part.Parent = workspace
    assert(part:IsDescendantOf(workspace), "cannot create instances")
    part:Destroy()
end)
if ok then
    print("BASEPLATE_OFFLINE_ENGINE: 1 passed, 0 failed")
else
    warn("BASEPLATE_OFFLINE_ENGINE: 0 passed, 1 failed: " .. tostring(err))
end
