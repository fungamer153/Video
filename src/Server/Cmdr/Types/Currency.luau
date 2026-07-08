return function(registry)
	registry:RegisterType(
		"currency",
		registry.Cmdr.Util.MakeEnumType("currency", {
			"Views",
			"Subscribers",
		})
	)
end
