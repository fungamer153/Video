local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local ClientEvents = require(ReplicatedStorage.Client.Modules.ClientEvents)
local InterfaceController = require(ReplicatedStorage.Client.Controllers.InterfaceController)

local DEFAULT_FOV = 70
local SCREEN_FOV = 80
local FOV_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local BLUR_OPEN = 12
local BLUR_CLOSED = 0
local BLUR_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local FovController = {}

local camera = nil
local blur = nil
local fovTween = nil
local blurTween = nil

local function setFov(targetFov)
	if ClientAtoms.fov then
		ClientAtoms.fov(targetFov)
	end

	if not camera then
		camera = workspace.CurrentCamera
	end
	if not camera then
		return
	end

	if fovTween then
		fovTween:Cancel()
	end
	fovTween = TweenService:Create(camera, FOV_TWEEN, { FieldOfView = targetFov })
	fovTween:Play()
end

local function setBlur(targetSize)
	if not blur then
		return
	end

	if blurTween then
		blurTween:Cancel()
	end

	blurTween = TweenService:Create(blur, BLUR_TWEEN, { Size = targetSize })
	blurTween:Play()
end

function FovController.onStart()
	camera = workspace.CurrentCamera

	blur = Instance.new("BlurEffect")
	blur.Size = BLUR_CLOSED
	blur.Parent = Lighting

	InterfaceController.onScreenChanged(function(screenName)
		if screenName then
			setFov(SCREEN_FOV)
			setBlur(BLUR_OPEN)
		else
			setFov(DEFAULT_FOV)
			setBlur(BLUR_CLOSED)
		end
	end)

	-- Allow manual FOV override via ClientEvents
	ClientEvents.connect("SetFov", function(data)
		local fov = data and data.fov
		if type(fov) == "number" then
			setFov(fov)
		end
	end)
end

return FovController
