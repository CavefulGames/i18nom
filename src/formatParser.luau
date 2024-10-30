--!nonstrict

local parser = require("../submodules/parser")
local createParser = parser.createParser
local eof = parser.eof

-- selene: allow(mixed_table)
local pushConst = function (self, str)
	local prev = self.fragments[#self.fragments]
	if prev and prev.type == "const" then
		prev[1] = prev[1] .. str
	else
		table.insert(self.fragments,{ str, type = "const" })
	end
end

-- selene: allow(mixed_table,unused_variable)
local formatParser = createParser {
	"{{", function(self, str, pos, startAt, endAt)
		pushConst(self,"{")
		return endAt+1
	end,
	"}}", function(self, str, pos, startAt, endAt)
		pushConst(self,"}")
		return endAt+1
	end,
	inner = createParser{
		"}", eof;
		orphans = function (self,str) table.insert(self.ret,str) end;
		init = function (self,str,pos) self.ret = {} end;
		stop = function (self) return { table.concat(self.ret), type= "format" } end;
	};
	"{", function (self,str,pos,startAt,endAt)
		local innerParsed,parseEndAt = self:inner(str,endAt+1)
		table.insert(self.fragments, innerParsed)
		return parseEndAt+1
	end;
	orphans = function (self,str)
		pushConst(self,str)
	end;
	init = function (self,str,pos) self.fragments = {} end;
	noEOF = true;
}

return formatParser
