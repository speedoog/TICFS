-- https://github.com/LazerLars/how_to_setup_lua_in_windows11_and_vscode
-- TIC-80 Lua version 5.3.6

--print(arg[2])

require("lldebugger").start()

if arg[2] == "debug" then
	require("lldebugger").start()
	print "----------"
end


function Split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		local num=tonumber(str)
		if num==nil then 
			table.insert(t, str)
		else
			table.insert(t, num)
		end
	end
	return t
end

local Packer={
	_Files = { }
	, AddFiles = function(self, files)
		for k,v in pairs(files) do
			self:AddFile(v)
		end
	end
	,AddFile = function (self, fileName)
		local Convert =
		{
			["line"] 	= "l",
			["ellipse"] = "e",
			["circle"] 	= "c",
			["fill"] 	= "f",
		}

		local ByteStream={}
		local f=io.open(fileName, "r")
		if f~=nil then
			while(true) do
				local line=f:read()
				if line==nil then break end
				
				local s=Split(line)

				local c=Convert[s[1]]
				if (c~=nil) then
					table.insert(ByteStream, string.byte(c))
					for i=2,#s do
						table.insert(ByteStream, s[i])
					end
				end
				
			end
			io.close(f)
		end
		
		if #ByteStream>0 then
			table.insert(ByteStream, 0)
			local file = {name=fileName, data=ByteStream}
			table.insert(self._Files, file)
		end
		
	end
	,Output=function(self, fileName)

		local add =function(s,c)
			table.insert(s, string.format("%02x", c))
		end
		-- prepare raw stream
		local ByteStream ={}
		add(ByteStream, #self._Files)
		for k,f in pairs(self._Files) do
			local str=f.name
			for i = 1, #str do
				local c = str:sub(i,i)
				add(ByteStream, string.byte(c))
			end
			add(ByteStream, 0)
			
			filesize16 = #f.data
			print(string.format("+ %s %d bytes", str, filesize16))
			add(ByteStream, filesize16&0xFF);
			add(ByteStream, filesize16>>8);
		end

		for k,f in pairs(self._Files) do
			for k,b in pairs(f.data) do
				add(ByteStream, b);
			end
		end

		--		local RawStream = table.concat(ByteStream)
		print(string.format("--------------------\nTotal %d bytes", #ByteStream))
		
		local f=io.open(fileName, "w")
		if f~=nil then
			local sHeader = "-- <MAP>";
			local sFooter = "\n-- </MAP>\n";

			f:write(sHeader)

			local iCurrentRow=-1
			local i=0;
			while i<#ByteStream do
				if i%240==0 then
					iCurrentRow=iCurrentRow+1
					-- "-- 001:"
					local sRow=string.format("\n-- %03d:", iCurrentRow);
					f:write(sRow);
				end
				local str=ByteStream[i+1]
				local hi=str:sub(1,1)
				local lo=str:sub(2,2)
				f:write(lo);
				f:write(hi);
				i=i+1
			end

			-- trailing zeros
			while i%240~=0 do
				f:write("00");
				i=i+1;
			end

			f:write(sFooter)
			
			io.close(f)
		end

	end
}


local InputFiles = { "Spectrals.txt" }
Packer:AddFiles(InputFiles)

print("Writing ...")
Packer:Output("out.lua")

print("Done")