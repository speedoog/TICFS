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

local Packer={ _Files = { } }

function Packer.AddFiles(_, files)
	for k,v in pairs(files) do
		_:AddFile(v)
	end
end

function Packer.AddFile(_, fileName)

	local splitFile=Split(fileName, ".")
	if (splitFile[2]=="txt") then
		_:AddFileTxt(fileName)
	elseif (splitFile[2]=="tga") then
		_:AddFileTga(fileName)
	else
		print(string.format("%s : Unsupported file extension %s", fileName, splitFile[2]))
	end

end

function PushToStream(ByteStream, b)
	table.insert(ByteStream,b)
end

function Packer.AddByteStream(_,fileName,ByteStream)
	if #ByteStream > 0 then
		table.insert(ByteStream,0)
		local file = {name = fileName,data = ByteStream}
		table.insert(_._Files,file)
	end
end

function Packer.AddFileTxt(_, fileName)
	local valid =
	{
		["l"] = true,
		["e"] = true,
		["c"] = true,
		["f"] = true,
		["s"] = true,
	}

	local ByteStream = {}
	local f=io.open(fileName, "r")
	if f~=nil then
		while(true) do
			local line=f:read()
			if line==nil then break end

			local s=Split(line)

			local cmd=s[1]
			if (valid[cmd]~=nil) then
				PushToStream(ByteStream, string.byte(cmd))

				for i=2,#s do
					PushToStream(ByteStream, s[i])
				end
			end

		end
		io.close(f)
	end

	_:AddByteStream(fileName, ByteStream)
end

function Read(f,i)
	return string.byte(f:read(i))
end

function Packer.AddFileTga(_, fileName)
	local f = io.open(fileName,"rb")
	if f==nil then return end

	local img = {}
--	f:seek("set",0xC)
	img.image_id_len = Read(f,1)
	img.color_map_type = Read(f,1)
	img.image_type = Read(f,1)
	img.color_map_ofs = Read(f,2)
	img.num_color_map = Read(f,2)
	img.color_map_depth = Read(f,1)
	img.x_offset = Read(f,2)
	img.y_offset = Read(f,2)
	img.width = Read(f,2)
	img.height = Read(f,2)
	img.img_depth = Read(f,1)
	img.img_descriptor = Read(f,1)

	img.image_id = Read(f, img.image_id_len)

	img.pixrgb = {}

	local nPix = img.width*img.height
    for i = 1, nPix do
		local b,g,r=Read(f,1),Read(f,1),Read(f,1)
		table.insert(img.pixrgb,{r,g,b})
	end

	print(string.format("pixel read %dx%d : %d", img.width, img.height, nPix))

	-- count colors
	local pal = {colors = {}}
	pal.getindex= function(_,r,g,b)
		for k,v in pairs(_.colors) do
			if v[1]==r and v[2]==g and v[3]==b then
				return k
			end
		end
		table.insert(_.colors,{r,g,b})
		return #_.colors
	end

	img.pixpal={}

	for k,v in pairs(img.pixrgb) do
		local ic=pal:getindex(v[1],v[2],v[3])
		table.insert(img.pixpal,ic)
	end

	print(string.format("Color count %d", #pal.colors))

	local ByteStream = {}
	for i=1,nPix,8 do
		local a=0
		for k=0,7 do
			a=(a<<5)|img.pixpal[i+k]
		end

		local a5 = a&0xFF	a = a>>8
		local a4 = a&0xFF	a = a>>8
		local a3 = a&0xFF	a = a>>8
		local a2 = a&0xFF	a = a>>8
		local a1 = a&0xFF	a = a>>8
		PushToStream(ByteStream, a1)
		PushToStream(ByteStream, a2)
		PushToStream(ByteStream, a3)
		PushToStream(ByteStream, a4)
		PushToStream(ByteStream, a5)
	end

	_:AddByteStream(fileName,ByteStream)
end


function Packer.Output(_, fileName)

	local add =function(s,c)
		table.insert(s, string.format("%02x", c))
	end
	-- prepare raw stream
	local ByteStream ={}
	add(ByteStream, #_._Files)
	for k,f in pairs(_._Files) do
		local str=f.name
		for i = 1, #str do
			local c = str:sub(i,i)
			add(ByteStream, string.byte(c))
		end
		add(ByteStream, 0)
		
		local filesize16 = #f.data
		print(string.format("+ %s %d bytes", str, filesize16))
		add(ByteStream, filesize16&0xFF);
		add(ByteStream, filesize16>>8);
	end

	for k1,f in pairs(_._Files) do
		for k2,b in pairs(f.data) do
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


local InputFiles = {"Spectrals.txt","Levex.txt", "test.tga" }
Packer:AddFiles(InputFiles)

print("Writing ...")
Packer:Output("out.lua")

print("Done")