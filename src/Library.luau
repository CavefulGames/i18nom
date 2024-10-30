export type Library<T, E> = {
	__index: (self: Library<T, E>, key: any) -> (),
	_onImport: () -> (),
	_imported: { string: any }?,
	isEmpty: boolean,
	import: (self: Library<T, E>, library: any) -> (),
	new: (onImport: (E) -> (T)) -> (Library<T, E>)
} & T

local Library = {} :: Library<any, any>

function Library.__index(self, key)
	local extended = rawget(self, "_imported")
	if extended then
		local extendedValue = extended[key]
		if extendedValue then
			return extendedValue
		end
	end
	local value = (Library :: any)[key]
	if value then
		return value
	end
end

function Library.import(self, library)
	if not self.isEmpty then
		error("Already imported and initialized")
	end
	self._imported = self._onImport(library)
	self.isEmpty = false
end

return function<T, E>(onImport: (E) -> (T)): Library<T, E>
	return setmetatable({
		_onImport = onImport,
		isEmpty = true
	}, Library) :: any
end
