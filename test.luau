-- src/tests/test.luau
-- Robuffer comprehensive usage and validation test
-- Author: M1778M

local Robuffer = require(script.Parent.Parent.Robuffer)

print("=== Robuffer Test Suite Started ===")

----------------------------------------------------------------
-- Test 1: Basic primitive serialization
----------------------------------------------------------------

local rb_basic = Robuffer.new(6)
rb_basic:SetDebug(true)

rb_basic:AddItem(42)                 -- U8
rb_basic:AddItem(1024)               -- U16
rb_basic:AddItem(-120)               -- I8
rb_basic:AddItem(3.14159)             -- Float32
rb_basic:AddItem("Hello Robuffer")   -- String
rb_basic:AddItem(true)               -- Boolean

local buffer_basic = rb_basic:Serialize()
local result_basic = Robuffer.Deserialize(buffer_basic)

print("\n[Test 1 Results]")
for i, v in ipairs(result_basic) do
	print(i, v, typeof(v))
end

----------------------------------------------------------------
-- Test 2: Array table serialization
----------------------------------------------------------------

local array_data = {
	10,
	20,
	30,
	40,
	50
}

local rb_array = Robuffer.new(1)
rb_array:AddItem(array_data)

local buffer_array = rb_array:Serialize()
local result_array = Robuffer.Deserialize(buffer_array)

print("\n[Test 2 Results - Array Table]")
for i, v in ipairs(result_array[1]) do
	print(i, v)
end

----------------------------------------------------------------
-- Test 3: Dictionary table serialization
----------------------------------------------------------------

local dict_data = {
	name = "PlayerOne",
	level = 25,
	health = 97.5,
	isAlive = true
}

local rb_dict = Robuffer.new(1)
rb_dict:AddItem(dict_data)

local buffer_dict = rb_dict:Serialize()
local result_dict = Robuffer.Deserialize(buffer_dict)

print("\n[Test 3 Results - Dictionary Table]")
for k, v in pairs(result_dict[1]) do
	print(k, v)
end

----------------------------------------------------------------
-- Test 4: Mixed nested tables
----------------------------------------------------------------

local complex_data = {
	player = {
		id = 123456,
		username = "M1778M",
		stats = {
			kills = 18,
			deaths = 2,
			accuracy = 0.873
		}
	},
	inventory = {
		"Sword",
		"Shield",
		"Potion"
	},
	flags = {
		admin = false,
		banned = false
	}
}

local rb_complex = Robuffer.new(1)
rb_complex:AddItem(complex_data)

local buffer_complex = rb_complex:Serialize()
local result_complex = Robuffer.Deserialize(buffer_complex)

print("\n[Test 4 Results - Nested Tables]")
print("Player Username:", result_complex[1].player.username)
print("Kills:", result_complex[1].player.stats.kills)
print("Inventory Item 2:", result_complex[1].inventory[2])
print("Admin Flag:", result_complex[1].flags.admin)

----------------------------------------------------------------
-- Test 5: Multiple elements in one buffer
----------------------------------------------------------------

local rb_multi = Robuffer.new(4)

rb_multi:AddItem("SessionStart")
rb_multi:AddItem(os.time())
rb_multi:AddItem({
	position = { x = 12.5, y = 9.75, z = -4.2 },
	velocity = { 0, 0, 0 }
})
rb_multi:AddItem(false)

local buffer_multi = rb_multi:Serialize()
local result_multi = Robuffer.Deserialize(buffer_multi)

print("\n[Test 5 Results - Multi Element Buffer]")
print("Event:", result_multi[1])
print("Timestamp:", result_multi[2])
print("Position Z:", result_multi[3].position.z)
print("Velocity Count:", #result_multi[3].velocity)
print("Final Flag:", result_multi[4])

----------------------------------------------------------------
-- Test 6: Table wrapping shortcut
----------------------------------------------------------------

local wrapped_data = {
	100,
	200,
	{
		score = 9999,
		rank = "S"
	},
	true
}

local rb_wrap = Robuffer.wrap(wrapped_data)
local buffer_wrap = rb_wrap:Serialize()
local result_wrap = Robuffer.Deserialize(buffer_wrap)

print("\n[Test 6 Results - Wrapped Table]")
for i, v in ipairs(result_wrap) do
	print(i, v)
end

----------------------------------------------------------------
-- Test 7: Clear and reuse buffer
----------------------------------------------------------------

local rb_reuse = Robuffer.new(2)
rb_reuse:AddItem("First")
rb_reuse:AddItem("Run")

rb_reuse:Serialize()
rb_reuse:Clear()

rb_reuse:AddItem("Second")
rb_reuse:AddItem("Run")

local buffer_reuse = rb_reuse:Serialize()
local result_reuse = Robuffer.Deserialize(buffer_reuse)

print("\n[Test 7 Results - Reuse After Clear]")
for i, v in ipairs(result_reuse) do
	print(i, v)
end

----------------------------------------------------------------
-- Final status
----------------------------------------------------------------

print("\n=== Robuffer Test Suite Completed Successfully ===")
