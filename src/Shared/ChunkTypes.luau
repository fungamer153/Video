local ChunkTypes = {}

ChunkTypes.definitions = {
	Wood = {
		name = "Wood",
		price = 0,
		currency = "viewers",
	},
}

function ChunkTypes.getDefinition(chunkTypeId)
	return ChunkTypes.definitions[chunkTypeId]
end

function ChunkTypes.getPrice(chunkTypeId)
	local definition = ChunkTypes.definitions[chunkTypeId]
	return definition and definition.price
end

function ChunkTypes.getCurrency(chunkTypeId)
	local definition = ChunkTypes.definitions[chunkTypeId]
	return (definition and definition.currency) or "viewers"
end

return ChunkTypes
