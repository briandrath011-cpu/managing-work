--[[
	FXService (ModuleScript)
	Location: ServerScriptService.Services.FXService
	Server -> client effect broadcasting. Effects are only sent to players close enough
	to see them (distance based VFX), clients further cull by their quality setting.
	Remote: FX (RemoteEvent)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Modules.Shared.Net)

local FXService = {}

local BROADCAST_RANGE = 420
local fxRemote: RemoteEvent

function FXService:Init()
	fxRemote = Net.Event("FX")
end

-- position: where the effect happens (nil = send to everyone)
function FXService:Play(effect: string, params: { [string]: any }, position: Vector3?)
	if not position then
		fxRemote:FireAllClients(effect, params)
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and ((root :: BasePart).Position - position).Magnitude <= BROADCAST_RANGE then
			fxRemote:FireClient(player, effect, params)
		end
	end
end

function FXService:PlayFor(player: Player, effect: string, params: { [string]: any })
	fxRemote:FireClient(player, effect, params)
end

function FXService:Notify(player: Player?, kind: string, text: string, extra: any?)
	local remote = Net.Event("Notify")
	if player then
		remote:FireClient(player, kind, text, extra)
	else
		remote:FireAllClients(kind, text, extra)
	end
end

return FXService
