--!strict
-- Weighted picks for food spawns, egg hatches, title rolls and events.

export type Entry = { Weight: number, [any]: any }

local WeightedRandom = {}

local function defaultWeight(entry: any): number
	return entry.Weight
end

-- Picks one entry. `weightOf` lets callers change weights (e.g. luck boosts)
-- without copying the table.
function WeightedRandom.Pick<T>(entries: { T }, rng: Random?, weightOf: ((T) -> number)?): T
	local getWeight: (T) -> number = if weightOf then weightOf else defaultWeight
	local total = 0
	for _, entry in entries do
		total += math.max(0, getWeight(entry))
	end
	assert(total > 0, "WeightedRandom.Pick needs at least one positive weight")

	local roll = (if rng then rng:NextNumber() else math.random()) * total
	for _, entry in entries do
		roll -= math.max(0, getWeight(entry))
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

-- Chance (0-1) of each entry, in the same order. Used for odds displays.
function WeightedRandom.Chances<T>(entries: { T }, weightOf: ((T) -> number)?): { number }
	local getWeight: (T) -> number = if weightOf then weightOf else defaultWeight
	local total = 0
	for _, entry in entries do
		total += math.max(0, getWeight(entry))
	end
	local chances = {}
	for index, entry in entries do
		chances[index] = if total > 0 then math.max(0, getWeight(entry)) / total else 0
	end
	return chances
end

return WeightedRandom
