--!strict

local Lang = require("./Lang")
local nativeLang = require("./nativeLang")
local formatParser = require("./formatParser")
local Library = require("./Library")
local GoodSignal = require("../submodules/GoodSignal/src")
local i18nom = {
	--[=[
		유효한 언어 코드 모음
	]=]
	Lang = Lang
}

local currentLocale: string?
local langRevMap = {}
local onLocaleChanged = GoodSignal.new() :: GoodSignal.Signal<()>

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

--[=[
	로케일이 변경되었을때에 함수를 연결합니다. 연결을 해제하는 함수를 반환합니다.
]=]
function i18nom.subscribe(fn: (...any) -> ()): () -> ()
	local connection = onLocaleChanged:Connect(fn)
	return function()
		connection:Disconnect()
	end
end

--[=[
	현재 설정된 로케일에 따라 번역된 값을 가져옵니다.
]=]
function i18nom.get(translation: Translation): string
	return translation[currentLocale or "_" :: any] or translation._
end

--[=[
	주어진 언어/국제 코드 문자열을 i18nom이 지원하는 언어 코드 부분으로 변환을 시도합니다. 실패할 경우 오류를 반환합니다.

	유효한 언어 코드일 경우 그대로 반환됩니다.
]=]
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

--[=[
	타입 검사와 유효성 검사를 포함하여 현지화를 위한 번역 테이블을 생성합니다. 기본값 `_` 필드는 필수입니다.
]=]
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

--[=[
	현재 설정된 로케일을 가져오거나 설정합니다. 인수를 설정할 경우 해당 인수 `x`를 `i18nom.parse(x)`를 실행한 뒤 현재 로케일로 설정합니다.

	새로운 값을 설정하게될 때 `i18nom.subscribe`로 연결된 함수들을 호출합니다.
]=]
function i18nom.locale(language: string?): any
	if language then
		local newLocale = i18nom.parse(language)
		if currentLocale ~= newLocale then
			currentLocale = newLocale
			onLocaleChanged:Fire()
		end
	end
	return currentLocale
end

--[=[
	주어진 언어 코드를 해당 언어의 모국어로 반환합니다.
]=]
function i18nom.native(language: string): string?
	return nativeLang[i18nom.parse(language)]
end

--[=[
	현재 설정된 로케일에 따라 번역 테이블에서 번역된 문자열을 가져와 포멧합니다.
]=]
function i18nom.t(translation: Translation, arguments: { [string]: any }?): string
	local translated = i18nom.get(translation)
	if not arguments then
		return translated
	end
	local parsed = formatParser(translated).fragments
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

--[=[
	`i18nom.Lang`을 확장시킵니다.

	`i18nom.Lang`을 변형시키지만 확장된 `Lang`타입을 사용하려면 반환된 `Lang`을 사용하세요.
]=]
function i18nom.extendLang<T>(extendedLang: T): typeof(Lang) & T
	for k, v in extendedLang do
		Lang[k] = v
	end
	return Lang
end

--[=[
	리액트 루아 (`jsdotlua/react-lua`) 라이브러리 기준 현지화 유틸

	```lua
	local React = require(path.to.reactlua)

	i18nom.reactlua:import(React)
	local useTranslation = i18nom.reactlua.useTranslation
	local e = React.createElement

	local Lang = i18nom.Lang
	local localizer = i18nom.createLocalizer({
		hello = {
			[Lang.Korean] = "안녕 {name}!",
			_ = "hello {name}!"
		}
	})

	local function MyComponent(props)
		useTranslation()

		return e("TextLabel", {
			Text = i18nom.t(localizer.hello, "Caveful Games")
		})
	end
	```
]=]
i18nom.reactlua = Library(function(React)
	return {
		useTranslation = function()
			local current, update = React.useState(false)

			React.useEffect(function()
				local disconnect = i18nom.subscribe(function()
					update(not current)
				end)

				return disconnect
			end, nil)
		end,
	}
end)

--[=[
	퓨전(`Fusion 0.2` & `Fusion 0.3`) 라이브러리 기준 현지화 유틸

	```lua
	local Fusion = require(path.to.fusion)

	i18nom.fusion:import(Fusion)
	local Localized = i18nom.fusion.Localized
	local LocalizedOf = i18nom.fusion.LocalizedOf
	local New = Fusion.New

	local Lang = i18nom.Lang
	local localizer = i18nom.createLocalizer({
		hello = {
			[Lang.Korean] = "안녕 {name}!",
			_ = "hello {name}!"
		}
	})

	-- Fusion 0.2
	New "TextLabel" {
		Text = Localized(localizer.hello, {
			name = "Caveful Games"
		})
	}

	-- Fusion 0.3
	local scope = Fusion.scoped()
	local t = LocalizedOf(scope)
	scope:New "TextLabel" {
		Text = t(localizer.hello, {
			name = "Caveful Games"
		})
	}
	```
]=]
i18nom.fusion = Library(function(Fusion)
	local update = Fusion.Value(false)
	i18nom.subscribe(function()
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

--[=[
	비드(`vide`) 라이브러리 기준 현지화 유틸

	```lua
	local vide = require(path.to.vide)

	i18nom.vide:import(vide)
	local t = i18nom.vide.t
	local create = vide.create
	local root = vide.root

	local Lang = i18nom.Lang
	local localizer = i18nom.createLocalizer({
		hello = {
			[Lang.Korean] = "안녕 {name}!",
			_ = "hello {name}!"
		}
	})

	local function MyComponent()
		return create "TextLabel" {
			Text = t(localizer.hello, {
				name = "Caveful Games"
			})
		}
	end

	root(MyComponent)
	```
]=]
i18nom.vide = Library(function(vide)
	local update = vide.source(false) :: (boolean?) -> (boolean)
	i18nom.subscribe(function()
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
