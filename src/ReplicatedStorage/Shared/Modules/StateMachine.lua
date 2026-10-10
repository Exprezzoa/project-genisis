--!strict
-- Shared/Modules/StateMachine.lua
--
-- Generic finite state machine (Frame actions, Titan AI, UI screens, input contexts).
--
--   local machine = StateMachine.new({
--       Idle = { enter = function(m, from) end, update = function(m, dt) end },
--       Attack = { canEnter = function(m, from) return from == "Idle" end, exit = function(m, to) end },
--   }, "Idle", context)
--   machine:transition("Attack", extraArgs...)   -- false when canEnter refuses
--   machine:update(dt)
--
-- `context` is stored as machine.context for the callbacks. Changed fires (to, from) after each transition.

local Signal = require(script.Parent.Signal)

export type StateDef = {
	enter: ((machine: any, from: string?, ...any) -> ())?,
	exit: ((machine: any, to: string) -> ())?,
	update: ((machine: any, dt: number) -> ())?,
	canEnter: ((machine: any, from: string?, ...any) -> boolean)?,
}

export type StateMachine = {
	context: any,
	Changed: Signal.Signal<string, string?>,
	getState: (self: StateMachine) -> string,
	is: (self: StateMachine, name: string) -> boolean,
	timeInState: (self: StateMachine) -> number,
	transition: (self: StateMachine, to: string, ...any) -> boolean,
	update: (self: StateMachine, dt: number) -> (),
	destroy: (self: StateMachine) -> (),
}

local StateMachine = {}
StateMachine.__index = StateMachine

-- clock is injectable for tests; it defaults to os.clock.
function StateMachine.new(states: { [string]: StateDef }, initial: string, context: any?, clock: (() -> number)?): StateMachine
	assert(states[initial], "StateMachine: unknown initial state " .. tostring(initial))
	local self = setmetatable({
		context = context,
		Changed = Signal.new(),
		_states = states,
		_state = initial,
		_clock = clock or os.clock,
		_enteredAt = 0,
	}, StateMachine)
	self._enteredAt = self._clock()
	local enter = states[initial].enter
	if enter then
		enter(self, nil)
	end
	return (self :: any) :: StateMachine
end

function StateMachine.getState(self: any): string
	return self._state
end

function StateMachine.is(self: any, name: string): boolean
	return self._state == name
end

function StateMachine.timeInState(self: any): number
	return self._clock() - self._enteredAt
end

-- Returns true when the machine entered `to`. An unknown state is an error; a refused canEnter returns false.
-- Extra arguments are passed to canEnter and enter. Re-entering the current state is allowed (exit, then enter).
function StateMachine.transition(self: any, to: string, ...: any): boolean
	local target = self._states[to]
	if not target then
		error("StateMachine: unknown state " .. tostring(to), 2)
	end
	local from = self._state
	if target.canEnter and not target.canEnter(self, from, ...) then
		return false
	end
	local current = self._states[from]
	if current.exit then
		current.exit(self, to)
	end
	self._state = to
	self._enteredAt = self._clock()
	if target.enter then
		target.enter(self, from, ...)
	end
	self.Changed:Fire(to, from)
	return true
end

function StateMachine.update(self: any, dt: number)
	local update = self._states[self._state].update
	if update then
		update(self, dt)
	end
end

function StateMachine.destroy(self: any)
	self.Changed:Destroy()
end

return StateMachine
