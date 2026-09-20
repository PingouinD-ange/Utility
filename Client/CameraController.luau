--!strict

-- Services
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Workspace = game:GetService("Workspace")

-- Dependencies
const Registry = require(ReplicatedStorage.Shared.registry)

-- Helpers
const function UniqueStr(): string
	return HttpService:GenerateGUID(false)
end

-- Controller
const CameraController = {}

export type CameraControllerCallback = (
	camera: Camera,
	dt: number
) -> ()

export type EffectFactory<T...> = (
	T...
) -> CameraControllerCallback

export type ActiveEffect = {
	instanceId: string,
	order: number,
	callback: CameraControllerCallback,
}

export type UnbindParameters = {
	unbindDelay: number,
	onUnbindCallback: (() -> ())?,
}

export type CameraControllerType = {
	registerEffect: <T...>(
		self: CameraControllerType,
		name: string,
		factory: EffectFactory<T...>
	) -> (),

	mount: <T...>(
		self: CameraControllerType,
		effectName: string,
		order: number,
		unbindParameters: UnbindParameters?,
		T...
	) -> string,

	unmount: (
		self: CameraControllerType,
		instanceId: string
	) -> (),
	
	onInit: (self: CameraControllerType) -> (),
	onStart: (self: CameraControllerType) -> (),
	onDestroy: (self: CameraControllerType) -> (),
}

type CameraControllerState = {
	effectFactories: { [string]: EffectFactory<any> },

	activeEffects: { [string]: ActiveEffect },
	sortedEffects: { ActiveEffect },

	unbindThreads: { [string]: thread },

	defaultCamera: Camera?,
	renderBound: boolean,
}

const state: CameraControllerState = {
	effectFactories = {},

	activeEffects = {},
	sortedEffects = {},

	unbindThreads = {},

	defaultCamera = nil,
	renderBound = false,
}

const function AddSorted(effect: ActiveEffect)
	const effects = state.sortedEffects
	local index = #effects + 1

	while index > 1 do
		const previous = effects[index - 1]
		if previous.order <= effect.order then
			break
		end
		effects[index] = previous
		index -= 1
	end

	effects[index] = effect
end

const function BindRenderStep()
	if state.renderBound then
		return
	end
	state.renderBound = true
	RunService:BindToRenderStep(
		"CameraController",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			const camera = Workspace.CurrentCamera

			if camera == nil then
				return
			end

			for _, effect in state.sortedEffects do
				effect.callback(camera, dt)
			end
		end
	)
end

const function UnbindRenderStep()
	if not state.renderBound then
		return
	end
	state.renderBound = false
	RunService:UnbindFromRenderStep(
		"CameraController"
	)
end

function CameraController.registerEffect<T...>(
	self: CameraControllerType,
	name: string,
	factory: EffectFactory<T...>
)
	state.effectFactories[name] = factory :: EffectFactory<any>
end

function CameraController.mount<T...>(
	self: CameraControllerType,
	effectName: string,
	order: number,
	unbindParameters: UnbindParameters?,
	...: T...
): string
	const instanceId = UniqueStr()
	const factory = state.effectFactories[effectName]
	if factory == nil then
		warn(
			`[CameraController] Effect blueprint "{effectName}" does not exist.`
		)
		return instanceId
	end

	const callback = factory(...)

	const effect: ActiveEffect = {
		instanceId = instanceId,
		order = order,
		callback = callback,
	}

	state.activeEffects[instanceId] = effect
	AddSorted(effect)

	if not state.renderBound then
		BindRenderStep()
	end

	if unbindParameters ~= nil then
		const parameters = unbindParameters
		const thread = task.delay(
			parameters.unbindDelay,
			function()
				state.unbindThreads[instanceId] = nil
				self:unmount(instanceId)
				const callback = parameters.onUnbindCallback
				if callback ~= nil then
					callback()
				end
			end
		)

		state.unbindThreads[instanceId] = thread
	end

	return instanceId
end

function CameraController.unmount(
	self: CameraControllerType,
	instanceId: string
)
	const thread = state.unbindThreads[instanceId]

	if thread ~= nil then
		task.cancel(thread)
		state.unbindThreads[instanceId] = nil
	end

	const effect = state.activeEffects[instanceId]
	if effect == nil then
		return
	end

	state.activeEffects[instanceId] = nil
	const index = table.find(
		state.sortedEffects,
		effect
	)

	if index ~= nil then
		table.remove(
			state.sortedEffects,
			index
		)
	end

	if #state.sortedEffects == 0 then
		UnbindRenderStep()
	end
end

function CameraController.onInit(
	self: CameraControllerType
)
	state.defaultCamera = Workspace.CurrentCamera
	Registry.register(
		"CameraController",
		self
	)
end

function CameraController.onDestroy(
	self: CameraControllerType
)
	UnbindRenderStep()
	for instanceId, thread in state.unbindThreads do
		task.cancel(thread)
		state.unbindThreads[instanceId] = nil
	end

	table.clear(state.activeEffects)
	table.clear(state.sortedEffects)
	table.clear(state.effectFactories)
	table.clear(state.unbindThreads)

	state.defaultCamera = nil
	Registry.remove(
		"CameraController"
	)
end

return CameraController :: CameraControllerType
