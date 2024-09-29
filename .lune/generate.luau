local net = require("@lune/net")
local serde = require("@lune/serde")
local fs = require("@lune/fs")

local DATA_URL = "https://raw.githubusercontent.com/haliaeetus/iso-639/refs/heads/master/data/iso_639-1.min.json"
local KOREAN_NAMES_URL = "https://raw.githubusercontent.com/umpirsky/language-list/refs/heads/master/data/ko/language.json"
local LANG_PATH = "src/Lang.luau"
local NATIVE_PATH = "src/nativeLang.luau"

local res = net.request(KOREAN_NAMES_URL)
local koreanNamesData: {
	[string]: string
} = {}
if res.ok then
	koreanNamesData = serde.decode("json", res.body)
else
	warn("Failed to fetch korean language names data!")
end

res = net.request(DATA_URL)
if res.ok then
	local data: {
		[string]: {
			["639-1"]: string,
			["639-2"]: string,
			family: string,
			name: string,
			nativeName: string,
			wikiUrl: string
		}
	} = serde.decode("json", res.body)

	local enumContent = {}
	local langContent = { "return{" }
	local nativeContent = { "return{" }
	for k, v in data do
		table.insert(enumContent, `"{k}"`)
		local displayName = koreanNamesData[k] or v.name
		table.insert(langContent, `--- {displayName} - {v.nativeName}\n["{v.name}"]="{k}",\n`)
		table.insert(nativeContent, `["{k}"]="{v.nativeName}",`)
	end
	table.insert(langContent, "}")
	table.insert(nativeContent, "}")

	fs.writeFile(LANG_PATH, table.concat(
		{ "export type Lang=" .. table.concat(enumContent, "|"), table.concat(langContent) }
	, " "))
	fs.writeFile(NATIVE_PATH, table.concat(nativeContent))
end
