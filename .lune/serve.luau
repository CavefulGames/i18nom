local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

fs.writeFile("dist/test.project.json", serde.encode("json", {
	name = "i18nom",
	tree = {
		["$className"] = "DataModel",
		ReplicatedStorage = {
			["$ignoreUnknownInstances"] = true,
			i18nom = {
				["$path"] = "src"
			}
		}
	}
}))

print(process.spawn("rojo", { "serve", "dist/test.project.json" }).stdout)
