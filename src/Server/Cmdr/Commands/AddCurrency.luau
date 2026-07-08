return {
	Name = "add_currency",
	Aliases = { "add_money", "give_currency" },
	Description = "Give an amount of currency to a player",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "The player",
		},
		{
			Type = "currency",
			Name = "item",
			Description = "The currency to give",
		},
		{
			Type = "number",
			Name = "amount",
			Description = "The ammount of currency to give",
		},
	},
}
