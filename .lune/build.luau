local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local NAME = "i18nom"

if fs.isDir("dist") then
	fs.removeDir("dist")
end

process.spawn("darklua", { "process", "src", "dist/src/src" }, {
	stdio = "forward"
})
process.spawn("darklua", { "process", "submodules", "dist/src/submodules" }, {
	stdio = "forward"
})

fs.writeFile("dist/src/init.luau", "return require(script.src)")

fs.writeFile("dist/default.project.json", serde.encode("json", {
	name = NAME,
	tree = {
		["$path"] = "src"
	}
}))

process.spawn("rojo", { "build", "dist/default.project.json", "--output", `dist/{NAME}.rbxm` })

local pesde = serde.decode("toml", fs.readFile("pesde.toml")) :: {
	target: {
		environment: string,
		lib: string,
		build_files: { string }?
	}
}
pesde.target.environment = "roblox"
pesde.target.build_files = { "src" }
fs.copy("README.md", "dist/src/README.md")
fs.writeFile("dist/src/pesde.toml", serde.encode("toml", pesde))
