local parser = require("../submodules/parser")
local createParser = parser.createParser
local eof = parser.eof

local pushConst = function (self, str)
    local prev = self.fragments[#self.fragments]
    if prev and prev.type == "const" then
        prev[1] = prev[1] .. str
    else
        table.insert(self.fragments,{ str, type = "const" })
    end
end
local formatParser = createParser {
    -- "\\(.)", function (self,str,pos,startAt,endAt,char)
    --     pushConst(self,char)
    -- end;
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

local parsed = formatParser("Hello {{{name}}}").fragments
local formatData = {
	name = "qwreey"
}
local vec = table.create(#parsed)
for _,v in parsed do
	if v.type == "const" then
		table.insert(vec, v[1])
	elseif v.type == "format" then
		local found = formatData[v[1]]
		if found then
			table.insert(vec, found)
		end
	end
end

print(table.concat(vec))
