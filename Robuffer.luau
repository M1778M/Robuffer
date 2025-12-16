Robuffer = {}
Robuffer.__index = Robuffer

type RobufferUnwrapped = {}
RobufferUnwrapped = {}

function RobufferUnwrapped.new()
	return setmetatable({}, RobufferUnwrapped)
end

local SizeTypes = {
	U8 = 1,
	U16 = 2,
	U32 = 3,
}

local DataTypes = {
	U8 = 1,
	U16 = 2,
	U32 = 3,
	I8 = 4,
	I16 = 5,
	I32 = 6,
	Float32 = 7,
	Float64 = 8,
	String = 9,
	Boolean = 10,
	Table = 11,
	name = function(dtype:number):string
		if type(dtype) == "number" and dtype ~= nil then
			if dtype == 1 then
				return "U8"
			elseif dtype == 2 then
				return "U16"
			elseif dtype == 3 then
				return "U32"
			elseif dtype == 4 then
				return "I8"
			elseif dtype == 5 then
				return "I16"
			elseif dtype == 6 then
				return "I32"
			elseif dtype == 7 then
				return "Float32"
			elseif dtype == 8 then
				return "Float64"
			elseif dtype == 9 then
				return "String"
			elseif dtype == 10 then
				return "Boolean"
			elseif dtype == 11 then
				return "Table"
			else
				return "Unknown"
			end
		end
		return "Unknown"
	end,
}

Robuffer.SizeTypes = SizeTypes
Robuffer.DataTypes = DataTypes

-- Configuration constants
local MAX_TABLE_DEPTH = 10
local MAX_TABLE_SIZE = 10000

function Robuffer.wrap(target, sizetype)
	if typeof(target) ~= "table" then
		error("invalid target: " .. typeof(target) .. " expected table")
	end
	local rb = Robuffer.new(#target, sizetype)

	for i,v in pairs(target) do
		rb:AddItem(target[i])
	end
	return rb
end

function Robuffer.new(element_count: number, sizetype)
	local self = setmetatable({}, Robuffer)
	self._buffer = nil
	self._memory = {}
	self.size_type = SizeTypes.U8
	self.index_pointer = 0
	self.debug = false
	self._element_count_size = DataTypes.U16
	self._table_depth = 0

	if element_count == nil or typeof(element_count) ~= "number" then
		error("invalid element count")
	end
	self._element_count = element_count

	if sizetype ~= nil and (sizetype == SizeTypes.U8 or sizetype == SizeTypes.U16 or sizetype == SizeTypes.U32) then
		self.size_type = sizetype
	end

	return self
end

function Robuffer:AddItem(item)
	if type(item) == "string" or type(item) == "number" or type(item) == "boolean" or type(item) == "table" then
		table.insert(self._memory, self:Compile(item))
	else
		error("Cannot add item of type: " .. typeof(item))
	end
end

function Robuffer:Clear()
	self._memory = {}
	self.index_pointer = 0
	self._buffer = nil
end

function Robuffer:SetItem(index:number, item)
	if type(item) == "string" or type(item) == "number" or type(item) == "boolean" or type(item) == "table" then
		self._memory[index] = self:Compile(item)
	else
		error("Cannot set item of type: " .. typeof(item))
	end
end

function Robuffer.SizeOf(dtype: number, value)
	if dtype == DataTypes.String then
		return #value
	elseif dtype == DataTypes.Boolean then
		return 1
	elseif dtype == DataTypes.U8 or dtype == DataTypes.I8 then
		return 1
	elseif dtype == DataTypes.U16 or dtype == DataTypes.I16 then
		return 2
	elseif dtype == DataTypes.U32 or dtype == DataTypes.I32 or dtype == DataTypes.Float32 then
		return 4
	elseif dtype == DataTypes.Float64 then
		return 8
	else
		error("invalid data type: " .. DataTypes.name(dtype))
	end
end

function Robuffer:GetMemory()
	return self._memory
end

function Robuffer:SetDebug(setto:boolean)
	if typeof(setto) == "boolean" then
		self.debug = setto
	end
end

function Robuffer:GetMemorySize():number 
	local sum = 0
	for i, v in pairs(self._memory) do
		sum += v[2]
	end
	return sum
end

function Robuffer:GetElement(index:number):number
	return self._memory[index]
end

function Robuffer:GetElementCountSize():number
	return Robuffer.SizeOf(self._element_count_size)
end

function Robuffer:GetSizeType():number
	return self.size_type
end

function Robuffer:GetElementsSize():number
	local sum = 0
	for i, v in pairs(self._memory) do
		sum += v[2]
	end
	return sum
end

local function validateTable(tbl, depth)
	if depth > MAX_TABLE_DEPTH then
		error("Table nesting depth exceeds maximum of " .. MAX_TABLE_DEPTH)
	end

	local count = 0
	for k, v in pairs(tbl) do
		count += 1
		if count > MAX_TABLE_SIZE then
			error("Table size exceeds maximum of " .. MAX_TABLE_SIZE .. " elements")
		end

		-- Validate key types
		local keyType = type(k)
		if keyType ~= "string" and keyType ~= "number" then
			error("Table keys must be strings or numbers, got: " .. keyType)
		end

		-- Validate value types
		local valueType = type(v)
		if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" and valueType ~= "table" then
			error("Table values must be string, number, boolean, or table, got: " .. valueType)
		end

		if valueType == "table" then
			validateTable(v, depth + 1)
		end
	end

	return count
end

local function isArrayTable(tbl)
	local maxIndex = 0
	local count = 0

	for k, v in pairs(tbl) do
		count += 1
		if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
			return false, 0
		end
		maxIndex = math.max(maxIndex, k)
	end

	return count == maxIndex, maxIndex
end

function Robuffer:Compile(value):unknown
	if self.debug then
		print("Compiling: " .. tostring(value))
	end	

	if value == nil then
		error("invalid value: values cannot be nil")
	end

	if typeof(value) == "string" then
		local size = Robuffer.SizeOf(DataTypes.String, value)
		return { DataTypes.String, size, value}

	elseif typeof(value) == "number" then
		if typeof(value) == "number" and math.floor(value) ~= value then
			-- Float
			if value <= 16777216 and value >= -16777216 then
				local size = Robuffer.SizeOf(DataTypes.Float32)
				return { DataTypes.Float32, size, value}
			else
				local size = Robuffer.SizeOf(DataTypes.Float64)
				return { DataTypes.Float64, size, value}
			end
		elseif typeof(value) == "number" then
			if value >= 0 and value <= 255 then
				local size = Robuffer.SizeOf(DataTypes.U8)
				return { DataTypes.U8, size, value}
			elseif value >= 0 and value <= 65535 then
				local size = Robuffer.SizeOf(DataTypes.U16)
				return { DataTypes.U16, size, value}
			elseif value >= 0 and value <= 4294967295 then
				local size = Robuffer.SizeOf(DataTypes.U32)
				return { DataTypes.U32, size, value}
			elseif value >= -128 and value <= 127 then
				local size = Robuffer.SizeOf(DataTypes.I8)
				return { DataTypes.I8, size, value}
			elseif value >= -32768 and value <= 32767 then
				local size = Robuffer.SizeOf(DataTypes.I16)
				return { DataTypes.I16, size, value}
			elseif value >= -2147483648 and value <= 2147483647 then
				local size = Robuffer.SizeOf(DataTypes.I32)
				return { DataTypes.I32, size, value}
			else
				error("Cannot compile number too big or small, please respect the appropriate range (-2147483648 to 2147483647): " .. value)
			end
		end

	elseif typeof(value) == "boolean" then
		local size = Robuffer.SizeOf(DataTypes.Boolean)
		return { DataTypes.Boolean, size, value and 1 or 0}

	elseif typeof(value) == "table" then
		self._table_depth += 1

		local elementCount = validateTable(value, self._table_depth)

		-- Create a new Robuffer for the table
		local estimatedSize = math.max(elementCount * 2 + 10, 50)
		local tableBuffer = Robuffer.new(estimatedSize, self.size_type)
		tableBuffer.debug = false
		tableBuffer._table_depth = self._table_depth

		-- Check if it's an array or dict
		local isArray, maxIndex = isArrayTable(value)

		if isArray then
			-- Array format: [type:U8=1][count:U16][element1][element2]...
			tableBuffer:AddItem(1) -- Type marker: 1 = array
			tableBuffer:AddItem(maxIndex) -- Number of elements

			for i = 1, maxIndex do
				local item = value[i]
				if item == nil then
					tableBuffer:AddItem(false)
				else
					tableBuffer:AddItem(item)
				end
			end

			if self.debug then
				print("  Compiled array table with " .. maxIndex .. " elements")
			end
		else
			-- Dictionary format: [type:U8=2][count:U16][key1][value1][key2][value2]...
			tableBuffer:AddItem(2) -- Type marker: 2 = dictionary
			tableBuffer:AddItem(elementCount) -- Number of key-value pairs

			for k, v in pairs(value) do
				if type(k) == "number" then
					tableBuffer:AddItem(tostring(k))
				else
					tableBuffer:AddItem(k)
				end
				tableBuffer:AddItem(v)
			end

			if self.debug then
				print("  Compiled dict table with " .. elementCount .. " entries")
			end
		end

		-- Serialize the table buffer
		local serializedTable = tableBuffer:Serialize()
		local tableSize = buffer.len(serializedTable)

		self._table_depth -= 1

		if self.debug then
			print("  Table serialized to " .. tableSize .. " bytes")
		end

		return { DataTypes.Table, tableSize, serializedTable}

	else
		error("Cannot compile invalid value type: " .. tostring(typeof(value)))
	end
end

function Robuffer.dtypef(dtype, act)
	if act == "read" then
		if dtype == DataTypes.Table then
			return function(buf, offset, size)
				local tempBuf = buffer.create(size)
				buffer.copy(tempBuf, 0, buf, offset, size)
				return Robuffer.Deserialize(tempBuf)
			end
		elseif dtype == DataTypes.String then
			return buffer.readstring
		elseif dtype == DataTypes.Boolean then
			return buffer.readi8
		elseif dtype == DataTypes.I8 then
			return buffer.readi8
		elseif dtype == DataTypes.I16 then
			return buffer.readi16
		elseif dtype == DataTypes.I32 then
			return buffer.readi32
		elseif dtype == DataTypes.U8 then
			return buffer.readu8
		elseif dtype == DataTypes.U16 then
			return buffer.readu16
		elseif dtype == DataTypes.U32 then
			return buffer.readu32
		elseif dtype == DataTypes.Float32 then
			return buffer.readf32
		elseif dtype == DataTypes.Float64 then
			return buffer.readf64
		else
			error("invalid DTYPE: " .. tostring(dtype))
		end
	else 
		if dtype == DataTypes.Table then
			-- Return a function that writes a buffer to another buffer
			return function(buf, offset, tableBuf)
				local size = buffer.len(tableBuf)
				buffer.copy(buf, offset, tableBuf, 0, size)
			end
		elseif dtype == DataTypes.String then
			return buffer.writestring
		elseif dtype == DataTypes.Boolean then
			return buffer.writei8
		elseif dtype == DataTypes.I8 then
			return buffer.writei8
		elseif dtype == DataTypes.I16 then
			return buffer.writei16
		elseif dtype == DataTypes.I32 then
			return buffer.writei32
		elseif dtype == DataTypes.U8 then
			return buffer.writeu8
		elseif dtype == DataTypes.U16 then
			return buffer.writeu16
		elseif dtype == DataTypes.U32 then
			return buffer.writeu32
		elseif dtype == DataTypes.Float32 then
			return buffer.writef32
		elseif dtype == DataTypes.Float64 then
			return buffer.writef64
		else
			error("invalid DTYPE: " .. tostring(dtype))
		end
	end
end

function Robuffer:Serialize():buffer
	local metadata_per_element = Robuffer.SizeOf(self.size_type) + 1 + Robuffer.SizeOf(self.size_type)
	local actual_element_count = #self._memory
	local metadata_size = metadata_per_element * actual_element_count
	local data_size = self:GetElementsSize()

	local buffer_size = 1 + 1 + Robuffer.SizeOf(self._element_count_size) + metadata_size + data_size
	local offset = 0
	self._buffer = buffer.create(buffer_size)

	-- Write size type
	self.dtypef(DataTypes.U8)(self._buffer, offset, self:GetSizeType())
	if self.debug then
		print("[" .. offset .. ":" .. offset + 1 .. "] -> " .. " Wrote " .. 1 .. " bytes :  " .. tostring(DataTypes.name(self:GetSizeType())))
	end
	offset += Robuffer.SizeOf(DataTypes.U8)

	-- Write element count size type
	self.dtypef(DataTypes.U8)(self._buffer, offset, self._element_count_size)
	if self.debug then
		print("[" .. offset .. ":" .. offset + 1 .. "] -> " .. " Wrote " .. 1 .. " bytes :  " .. tostring(DataTypes.name(self._element_count_size)))
	end
	offset += Robuffer.SizeOf(DataTypes.U8)

	-- Write actualelement count
	self.dtypef(self._element_count_size)(self._buffer, offset, #self._memory)
	if self.debug then
		print("[" .. offset .. ":" .. offset + Robuffer.SizeOf(self._element_count_size) .. "] -> " .. " Wrote " .. Robuffer.SizeOf(self._element_count_size) .. " bytes :  " .. tostring(#self._memory))
	end
	offset += Robuffer.SizeOf(self._element_count_size)

	local header_size = 1 + 1 + Robuffer.SizeOf(self._element_count_size)
	local occupied_offset = header_size + metadata_size

	local sizeType = self:GetSizeType()
	if self.debug then
		print("- Debug Info:")
		print("buffer size: " .. buffer_size)
		print("data starts at offset: " .. occupied_offset)
		print("element count: " .. #self._memory)
		print("elements size: ", self:GetElementsSize())
	end

	for i = 1, #self._memory do
		local element = self:GetElement(i)
		if element ~= nil then
			if self.debug then
				print("Adding element: " .. tostring(element[3]) .. " of type: " .. DataTypes.name(element[1]) .. " at offset: " .. occupied_offset .. " with size: " .. element[2])
			end

			-- Write offset 
			self.dtypef(sizeType)(self._buffer, offset, occupied_offset)
			offset += Robuffer.SizeOf(sizeType)

			-- Write dtype
			self.dtypef(DataTypes.U8)(self._buffer, offset, element[1])
			offset += Robuffer.SizeOf(DataTypes.U8)

			-- Write size
			self.dtypef(sizeType)(self._buffer, offset, element[2])
			offset += Robuffer.SizeOf(sizeType)

			if element[1] == DataTypes.Table then
				-- For tables, element[3] is already a buffer
				self.dtypef(element[1])(self._buffer, occupied_offset, element[3])
			else
				self.dtypef(element[1])(self._buffer, occupied_offset, element[3])
			end

			occupied_offset += element[2]
		end
	end
	return self._buffer
end

function Robuffer.Deserialize(serializedObj: buffer): RobufferUnwrapped
	return Robuffer.unwrap(serializedObj)
end

function Robuffer.unwrap(serializedObj: buffer): RobufferUnwrapped
	return RobufferUnwrapped.Unwrap(serializedObj)
end

function RobufferUnwrapped.Unwrap(serialized: buffer):table
	local pointer = 0
	local sizeType = buffer.readu8(serialized, pointer)
	pointer += 1
	local element_count_size = buffer.readu8(serialized, pointer)
	pointer += 1
	local element_count = Robuffer.dtypef(element_count_size, "read")(serialized, pointer)
	pointer += Robuffer.SizeOf(element_count_size)
	local elements = {}

	for i = 1, element_count do
		local offset = Robuffer.dtypef(sizeType, "read")(serialized, pointer)
		pointer += Robuffer.SizeOf(sizeType)
		local dtype = Robuffer.dtypef(DataTypes.U8, "read")(serialized, pointer)
		pointer += Robuffer.SizeOf(DataTypes.U8)
		local size = Robuffer.dtypef(sizeType, "read")(serialized, pointer)
		pointer += Robuffer.SizeOf(sizeType)

		local value
		if dtype == DataTypes.String then
			value = Robuffer.dtypef(dtype, "read")(serialized, offset, size)
		elseif dtype == DataTypes.Table then
			local deserializedTable = Robuffer.dtypef(dtype, "read")(serialized, offset, size)

			local tableType = deserializedTable[1]
			local tableCount = deserializedTable[2]

			if tableType == 1 then
				local arr = {}
				for j = 1, tableCount do
					arr[j] = deserializedTable[j + 2]
				end
				value = arr
			elseif tableType == 2 then
				local dict = {}
				for j = 1, tableCount do
					local keyIndex = 2 + (j - 1) * 2 + 1
					local valueIndex = keyIndex + 1
					local key = deserializedTable[keyIndex]
					local val = deserializedTable[valueIndex]

					if type(key) == "string" and tonumber(key) ~= nil then
						key = tonumber(key)
					end

					dict[key] = val
				end
				value = dict
			else
				error("Invalid table type marker: " .. tostring(tableType))
			end
		elseif dtype == DataTypes.Boolean then
			local rawValue = Robuffer.dtypef(dtype, "read")(serialized, offset)
			value = rawValue ~= 0
		else
			value = Robuffer.dtypef(dtype, "read")(serialized, offset)
		end

		table.insert(elements, value)
	end

	return elements
end

return Robuffer
