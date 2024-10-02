local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local NAME = "i18nom"

if fs.isDir("dist") then
	fs.removeDir("dist")
end

process.spawn("darklua", { "process", "src", "dist/src/src" })
process.spawn("darklua", { "process", "submodules", "dist/src/submodules" })

fs.writeFile("dist/src/init.luau", "return require(script.src)")

fs.writeFile("dist/default.project.json", serde.encode("json", {
	name = NAME,
	tree = {
		["$path"] = "src"
	}
}))

process.spawn("rojo", { "build", "dist/default.project.json", "--output", `dist/{NAME}.rbxm` })
