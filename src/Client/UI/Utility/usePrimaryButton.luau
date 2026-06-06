local TweenService = game:GetService("TweenService")

local TWEEN_IN = TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function usePrimaryButton(button, callback)
	local uiScale = button.Parent:FindFirstChildOfClass("UIScale")
	if not uiScale then
		warn("No UIScale found in parent of", button:GetFullName())
		return
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TWEEN_IN, { Scale = 1.06 }):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TWEEN_OUT, { Scale = 1 }):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TWEEN_IN, { Scale = 0.94 }):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(uiScale, TWEEN_IN, { Scale = 1.06 }):Play()
	end)

	button.MouseButton1Click:Connect(function()
		TweenService:Create(uiScale, TWEEN_OUT, { Scale = 1 }):Play()
		callback()
	end)
end

return usePrimaryButton
