-- Roblox Studio's documented --task RunScript command executes this against a LOCAL RBXL.
-- No Universe ID, Place ID, browser auth cookie, Open Cloud key, or publish action.
-- This is an edit-mode engine smoke test, NOT proof of a played match or networking.
local passed, failed = 0, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed += 1
        print('PASS OFFLINE_STUDIO ' .. name)
    else
        failed += 1
        print('FAIL OFFLINE_STUDIO ' .. name .. ': ' .. tostring(err))
    end
end

check('DataModel contains expected real Roblox services and modules', function()
    local shared = game:GetService('ReplicatedStorage'):FindFirstChild('Shared')
    assert(shared and shared:FindFirstChild('Config'), 'Shared.Config missing')
    local server = game:GetService('ServerScriptService'):FindFirstChild('Server')
    assert(server and server:FindFirstChild('WorldBuilder'), 'Server.WorldBuilder missing')
end)

check('Law Sport arena builds as real Instances', function()
    local WB = require(game:GetService('ServerScriptService').Server.WorldBuilder)
    local Config = require(game:GetService('ReplicatedStorage').Shared.Config)
    local arena = WB.buildLawArena(Vector3.new(90000, 0, 0), 'OfflineCliSmoke')
    assert(arena and arena.folder and arena.chicken and arena.chicken.PrimaryPart, 'Law arena incomplete')
    local vault = arena.folder:FindFirstChild('VaultVolume')
    assert(vault and math.abs(vault.Size.X - Config.Law.vault.hx * 2) < 0.001, 'Vault width mismatch')
    arena.folder:Destroy()
end)

check('Grid Heist arena builds as real Instances', function()
    local WB = require(game:GetService('ServerScriptService').Server.WorldBuilder)
    local arena = WB.buildHeistArena(Vector3.new(-90000, 0, 0), 'OfflineCliSmoke')
    assert(arena and arena.folder and arena.vision, 'Heist arena incomplete')
    assert(arena.vision:GetAttribute('Essential') == true, 'Heist vision disc not essential')
    arena.folder:Destroy()
end)

print(string.format('LOCAL_GAME_EDIT_SMOKE: %d passed, %d failed', passed, failed))
