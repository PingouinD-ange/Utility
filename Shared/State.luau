--!strict

local StateMachine = {}
StateMachine.__index = StateMachine

export type StateExitCallback = () -> ()

export type StateBase<T> = {
	OnEnter: (blackboard: T, ...any) -> StateExitCallback,
	OnUpdate: (dt: number) -> (),
}

export type EventTransition = {
	toState: string,
	fromStates: { string },
	defaultArgs: { any },
}

export type StateMachineType<T> = {
	currentCleanup: StateExitCallback?,
	currentName: string?,
	currentUpdate: ((dt: number) -> ())?,
	blackboard: T,

	registeredStates: { [string]: StateBase<T> },
	registeredEventTransitions: { [string]: EventTransition },

	registerState: (
		self: StateMachineType<T>,
		name: string,
		stateInstance: StateBase<T>
	) -> (),

	registerEventTransition: (
		self: StateMachineType<T>,
		eventName: string,
		toStateName: string,
		allowedFromStates: { string }, 
		...any
	) -> (),

	changeState: (
		self: StateMachineType<T>,
		fromName: string,
		toName: string,
		...any
	) -> boolean,

	triggerEvent: (
		self: StateMachineType<T>,
		eventName: string,
		...any
	) -> boolean,

	update: (
		self: StateMachineType<T>,
		dt: number
	) -> (),
}

function StateMachine.new<T>(blackboard: T): StateMachineType<T>
	local self = setmetatable({
		currentCleanup = nil,
		currentName = nil,
		currentUpdate = nil,
		blackboard = blackboard,
		registeredStates = {},
		registeredEventTransitions = {},
	}, StateMachine)

	return self :: StateMachineType<T>
end

function StateMachine.registerState<T>(
	self: StateMachineType<T>,
	name: string,
	stateInstance: StateBase<T>
)
	self.registeredStates[name] = stateInstance
end

function StateMachine.registerEventTransition<T>(
	self: StateMachineType<T>,
	eventName: string,
	toStateName: string,
	allowedFromStates: { string },
	...: any
)
	local defaultArgs = { ... }
	self.registeredEventTransitions[eventName] = {
		toState = toStateName,
		fromStates = allowedFromStates,
		defaultArgs = defaultArgs,
	}
end

function StateMachine.changeState<T>(
	self: StateMachineType<T>,
	fromName: string,
	toName: string,
	...: any
): boolean
	if self.currentName ~= nil and self.currentName ~= fromName then
		return false
	end

	if self.currentName == toName then
		return false
	end

	local targetState = self.registeredStates[toName]
	if targetState == nil then
		warn(`[StateMachine] State '{toName}' is not registered!`)
		return false
	end

	local cleanup = self.currentCleanup
	if cleanup ~= nil then
		cleanup()
		self.currentCleanup = nil
	end

	self.currentCleanup = targetState.OnEnter(
		self.blackboard,
		...
	)

	self.currentName = toName
	self.currentUpdate = function(dt: number)
		targetState.OnUpdate(dt)
	end

	return true
end

function StateMachine.triggerEvent<T>(
	self: StateMachineType<T>,
	eventName: string,
	...: any
): boolean
	local transition = self.registeredEventTransitions[eventName]
	if transition == nil then
		return false
	end

	local currentFromState = self.currentName or "None"
	local isAllowed = false

	for _, stateName in ipairs(transition.fromStates) do
		if stateName == "*" or stateName == currentFromState then
			isAllowed = true
			break
		end
	end

	if not isAllowed then
		return false
	end

	local args = { ... }
	local finalArgs = if #args > 0
		then args
		else transition.defaultArgs

	return self:changeState(
		currentFromState,
		transition.toState,
		table.unpack(finalArgs)
	)
end

function StateMachine.update<T>(
	self: StateMachineType<T>,
	dt: number
)
	local update = self.currentUpdate
	if update ~= nil then
		update(dt)
	end
end

return StateMachine
