--!strict

-- Services
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Player
const player = Players.LocalPlayer

-- Dependencies
const Preload = require(
	ReplicatedStorage.Shared.preload
)

const Registry = require(
	ReplicatedStorage.Shared.registry
)

-- Types
export type AnimationDefinition = Preload.AnimationDefinition
export type AnimationGroup = Preload.AnimationGroup
export type AnimationLibrary = Preload.AnimationLibrary

export type AnimationControllerConfig = {
	fadeTime: number,
	blendSpeed: number,
}

export type AnimationControllerType = {
	Register: (
		name: string,
		definition: AnimationDefinition
	) -> (),

	RegisterGroup: (
		groupName: string,
		animations: AnimationGroup
	) -> (),

	Has: (
		name: string
	) -> boolean,

	Play: (
		name: string,
		fadeTime: number?
	) -> boolean,

	Stop: (
		name: string,
		fadeTime: number?
	) -> boolean,

	SetWeight: (
		name: string,
		weight: number,
		fadeTime: number?
	) -> boolean,

	SetSpeed: (
		name: string,
		speed: number
	) -> boolean,

	GetTrack: (
		name: string
	) -> AnimationTrack?,

	Start: () -> (),
	Destroy: () -> (),
}

type AnimationState = {
	definitions: {
		[string]: AnimationDefinition,
	},

	tracks: {
		[string]: AnimationTrack,
	},

	humanoid: Humanoid?,
	animator: Animator?,
	character: Model?,

	config: AnimationControllerConfig,
}

const state: AnimationState = {
	definitions = {},
	tracks = {},

	humanoid = nil,
	animator = nil,
	character = nil,

	config = {
		fadeTime = 0.15,
		blendSpeed = 10,
	},
}

-- Helpers

const function GetAnimator(): Animator?
	const animator = state.animator
	if animator ~= nil then
		return animator
	end

	const humanoid = state.humanoid
	if humanoid == nil then
		return nil
	end

	const existingAnimator = humanoid:FindFirstChildOfClass(
		"Animator"
	)

	if existingAnimator ~= nil then
		state.animator = existingAnimator
		return existingAnimator
	end

	const newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid

	state.animator = newAnimator
	return newAnimator
end

const function LoadAnimation(
	name: string,
	definition: AnimationDefinition
): AnimationTrack?
	print(`loaded animation: ${name}`)
	const animator = GetAnimator()
	if animator == nil then
		warn(
			`[AnimationController] Cannot load "{name}": no Animator.`
		)
		return nil
	end

	const animation = Instance.new("Animation")

	animation.Name = name
	animation.AnimationId = definition.id

	const track = animator:LoadAnimation(
		animation
	)
	animation:Destroy()

	track.Looped = definition.looped == true
	if definition.priority ~= nil then
		track.Priority = definition.priority
	end

	return track
end

const function DestroyTrack(
	name: string
)
	const track = state.tracks[name]
	if track == nil then
		return
	end
	track:Stop(0)
	track:Destroy()
	state.tracks[name] = nil
end

-- Controller
const AnimationController = {}

function AnimationController.Register(
	name: string,
	definition: AnimationDefinition
)
	DestroyTrack(name)
	state.definitions[name] = definition
	if state.animator ~= nil then
		const track = LoadAnimation(
			name,
			definition
		)
		if track ~= nil then
			state.tracks[name] = track
		end
	end
end

function AnimationController.RegisterGroup(
	groupName: string,
	animations: AnimationGroup
)
	for name, definition: AnimationDefinition in animations do
		AnimationController.Register(
			`{groupName}.{name}`,
			definition
		)
	end
end

function AnimationController.Has(
	name: string
): boolean
	return state.definitions[name] ~= nil
end

function AnimationController.GetTrack(
	name: string
): AnimationTrack?
	return state.tracks[name]
end

function AnimationController.Play(
	name: string,
	fadeTime: number?
): boolean
	const track = state.tracks[name]
	if track == nil then
		warn(
			`[AnimationController] Animation "{name}" is not loaded.`
		)
		return false
	end
	track:Play(
		fadeTime or state.config.fadeTime
	)
	return true
end

function AnimationController.Stop(
	name: string,
	fadeTime: number?
): boolean
	const track = state.tracks[name]
	if track == nil then
		return false
	end
	track:Stop(
		fadeTime or state.config.fadeTime
	)
	return true
end

function AnimationController.SetWeight(
	name: string,
	weight: number,
	fadeTime: number?
): boolean
	const track = state.tracks[name]
	if track == nil then
		return false
	end
	track:AdjustWeight(
		math.clamp(weight, 0, 1),
		fadeTime or 0
	)
	return true
end

function AnimationController.SetSpeed(
	name: string,
	speed: number
): boolean
	const track = state.tracks[name]
	if track == nil then
		return false
	end
	track:AdjustSpeed(speed)
	return true
end

function AnimationController.Start()
	if state.character ~= nil then
		return
	end

	const character = player.Character
	if character == nil then
		warn(
			"[AnimationController] Cannot start: character does not exist."
		)
		return
	end

	const humanoid = character:FindFirstChildOfClass(
		"Humanoid"
	)

	if humanoid == nil then
		warn(
			"[AnimationController] Character has no Humanoid."
		)
		return
	end

	state.character = character
	state.humanoid = humanoid
	state.animator = GetAnimator()

	if state.animator == nil then
		warn(
			"[AnimationController] Failed to get Animator."
		)
		state.character = nil
		state.humanoid = nil
		return
	end

	for name, definition: AnimationDefinition in state.definitions do
		const track = LoadAnimation(
			name,
			definition
		)
		if track ~= nil then
			state.tracks[name] = track
		end
	end
end

function AnimationController.Destroy()
	for name: string in state.tracks do
		DestroyTrack(name)
	end

	table.clear(state.tracks)

	state.character = nil
	state.humanoid = nil
	state.animator = nil
end

function AnimationController.onInit()
	const animationsToPreload: AnimationLibrary =
		Preload.AnimationsToLoad
	for groupName, animations: AnimationGroup in animationsToPreload do
		AnimationController.RegisterGroup(
			groupName,
			animations
		)
	end
	Registry.register(
		"AnimationController",
		AnimationController
	)
end

function AnimationController.onStart()
	AnimationController.Start()
end

function AnimationController.onDestroy()
	AnimationController.Destroy()
	Registry.remove(
		"AnimationController"
	)
end

return AnimationController :: AnimationControllerType
