--[[
	Sound.luau — toca os efeitos sonoros e a música (IDs em Config.Sounds).
	ID 0 = silêncio. Sons longos são cortados em Config.SoundTrim.
]]
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)

local Sound = {}

local group = Instance.new("SoundGroup")
group.Name = "SFX"
group.Volume = 1
group.Parent = SoundService

local templates: { [string]: Sound } = {}

local function template(key: string): Sound?
	local id = Config.Sounds[key]
	if key == "Volume" or type(id) ~= "number" or id < 1 or id % 1 ~= 0 then
		return nil
	end
	local s = templates[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = key
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.SoundGroup = group
		s.Parent = SoundService
		templates[key] = s
	end
	return s
end

-- Pré-carrega (evita o primeiro som atrasado)
task.defer(function()
	for key in pairs(Config.Sounds) do
		template(key)
	end
end)

function Sound.play(key: string, volumeMul: number?, pitch: number?)
	local base = template(key)
	if not base then
		return
	end
	local s = base:Clone()
	s.Volume = Config.Sounds.Volume * (volumeMul or 1)
	s.PlaybackSpeed = pitch or (0.95 + math.random() * 0.1)
	s.Parent = SoundService
	s:Play()
	local trim = Config.SoundTrim and Config.SoundTrim[key]
	task.delay(trim or 6, function()
		s:Destroy()
	end)
end

-- Música de fundo (volume ajustável em Ajustes)
local music = template("Music")
if music then
	music.Looped = true
	music.Volume = 0.15
	music:Play()
end
State.onReady(function(data)
	if music and data.Settings then
		music.Volume = 0.3 * data.Settings.MusicVolume
	end
end)

return Sound
