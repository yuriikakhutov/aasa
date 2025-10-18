---@class Blackboard
local Blackboard = {}
Blackboard.__index = Blackboard

---Creates a new blackboard instance.
---@return Blackboard
function Blackboard.new()
	local self = setmetatable({}, Blackboard)
	self.sensors = {}
	self.memory = {}
	self.danger = {}
	self.objective = nil
	self.path = nil
	self.tacticalPlan = nil
	self.lastOrders = {
		move = {time = 0, hash = nil},
		attack = {time = 0, hash = nil},
		cast = {time = 0, hash = nil}
	}
	return self
end

return Blackboard
