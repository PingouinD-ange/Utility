--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GoodSignal = require(ReplicatedStorage.Packages.GoodSignal)

local Value = {}
Value.__index = Value

export type ValueStore = typeof(setmetatable({} :: {
	values: { [string]: { any } },
}, Value))

function Value.new(): ValueStore
	local self = setmetatable({
		values = {},
	}, Value)
	return (self :: any) :: ValueStore
end

function Value.newValue<T>(self: ValueStore, name: string, initialValue: T): (() -> T, (newValue: T) -> (), typeof(GoodSignal.new()))
	local currentValue = initialValue
	local changed = GoodSignal.new()

	local function get(): T
		return currentValue
	end

	local function set(newValue: T)
		if currentValue == newValue then
			return
		end
		currentValue = newValue
		changed.Fire(currentValue)
	end

	self.values[name] = { get, set, changed }
	return get, set, changed
end

function Value.destroyValue(self: ValueStore, name: string): boolean
	local entry = self.values[name]
	if entry then
		local changedSignal = entry[3]
		changedSignal:DisconnectAll()
		self.values[name] = nil
		return true
	end
	return false
end

function Value.getValue<T>(self: ValueStore, name: string): (() -> T)?
	local entry = self.values[name]
	if entry then
		return entry[1]
	end
	return nil
end

return Value
