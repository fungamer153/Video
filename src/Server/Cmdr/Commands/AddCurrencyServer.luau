local AnalyticsService = game:GetService("AnalyticsService")

return function(_context, player: Player, currency: string, amount: number)
	local stats = player:WaitForChild("stats")
	local valueInstance = stats:WaitForChild(currency) :: ValueBase
	valueInstance.Value += amount

	AnalyticsService:LogEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Source,
		currency,
		amount,
		valueInstance.Value,
		"ModeratorAction"
	)
end
