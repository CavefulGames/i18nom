--!strict

local Lang = require("./Lang")
local nativeLang = require("./nativeLang")
local formatParser = require("./formatParser")
local Library = require("./Library")
local i18nom = {
	Lang = Lang
}

local currentLocale: string?
local langRevMap = {}

for k, v in Lang do
	langRevMap[v] = k
end

type Translation = {
	[string]: string?,
	_: string
}

type Localizer = {
	[string]: Translation
}

local subscribedCallbacks = {}
local subscribeId = 0

local function subscribe(fn: (...any) -> ()): number
	table.insert(subscribedCallbacks, fn)
	subscribeId += 1
	return subscribeId
end

local function unsubscribe(id: number)
	subscribedCallbacks[id] = nil
end

local function callSubscribed()
	for _, fn in subscribedCallbacks do
		if fn then
			fn()
		end
	end
end

function i18nom.get(translation: Translation): string
	return translation[currentLocale or "_" :: any] or translation._
end

function i18nom.parse(languageName: string): string
	if langRevMap[languageName] then
		return languageName :: any
	end
	if languageName:find("-") then
		local lang = languageName:split("-")[1]
		if lang and langRevMap[lang] then
			return lang :: any
		end
	elseif languageName:find("_") then
		local lang = languageName:split("_")[1]
		if lang and langRevMap[lang] then
			return lang :: any
		end
	end
	error(`Failed to parse the language name '{languageName}'`)
end

function i18nom.createLocalizer<T>(localizer: Localizer & T): Localizer & T
	for name, translation in localizer :: any do
		if not translation._ then
			error(`Default is required for '{name}'`)
		end
		for lang, _ in translation do
			if lang ~= "_" and not langRevMap[lang] then
				error(`Language '{lang}' is not valid`)
			end
		end
	end
	return localizer
end

function i18nom.locale(language: string?): any
	if language then
		local newLocale = i18nom.parse(language)
		if currentLocale ~= newLocale then
			currentLocale = newLocale
			callSubscribed()
		end
	end
	return currentLocale
end

function i18nom.native(language: string): string?
	return nativeLang[language]
end

function i18nom.t(translation: Translation, arguments: { [string]: any }): string
	local parsed = formatParser(i18nom.get(translation)).fragments
	local result = table.create(#parsed)

	for _,v in parsed do
		if v.type == "const" then
			table.insert(result, v[1])
		elseif v.type == "format" then
			local found = arguments[v[1]]
			if found then
				table.insert(result, tostring(found))
			end
		end
	end

	return table.concat(result)
end

i18nom.reactlua = Library(function(React)
	return {
		useTranslation = function()
			local current, update = React.useState(false)

			React.useEffect(function()
				local id = subscribe(function()
					update(not current)
				end)

				return function()
					unsubscribe(id)
				end
			end, nil)
		end,
	}
end)

i18nom.fusion = Library(function(Fusion)
	local update = Fusion.Value(false)
	subscribe(function()
		update:set(not update:get())
	end)

	local LocalizedWithScope
	if Fusion.scoped then
		LocalizedWithScope = {
			__call = function(self, translation: Translation, arguments: { [string]: any })
				return self._s:Computed(function(use)
					use(update)
					local clonedArguments = table.clone(arguments)
					for k, v in arguments do
						if type(v) == "table" and v.get then
							local new = use(v)
							clonedArguments[k] = new
						end
					end
					return i18nom.t(translation, clonedArguments)
				end)
			end
		}
	end

	return {
		Localized = function(translation: Translation, arguments: { [string]: any })
			return Fusion.Computed(function()
				update:get()
				local clonedArguments = table.clone(arguments)
				for k, v in arguments do
					if type(v) == "table" and v.get then
						local new = v:get()
						clonedArguments[k] = new
					end
				end
				return i18nom.t(translation, clonedArguments)
			end)
		end,
		LocalizedOf = function(scope): (translation: Translation, arguments: { [string]: any }) -> (typeof(LocalizedWithScope.__call({}::any,{}::any,{}::any)))
			return setmetatable({
				_s = scope
			}, LocalizedWithScope) :: any
		end
	}
end)

i18nom.vide = Library(function(vide)
	local update = vide.source(false)
	subscribe(function()
		update(not update())
	end)
	return {
		t = function(translation: Translation, arguments: { [string]: any })
			return function()
				update()
				local clonedArguments = table.clone(arguments)
				for k, v in arguments do
					if type(v) == "function" then
						local new = v()
						clonedArguments[k] = new
					end
				end
				return i18nom.t(translation, clonedArguments)
			end
		end
	}
end)

return i18nom
