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
	local name = splitFile[1]
	local ext = splitFile[2]

	if (ext=="txt") then
		_:AddFileTxt(name,ext)
	elseif (ext=="tga") then
		_:AddFileTga(name,ext)
	elseif ext=="obj" then
		table.insert(_._Files, {name = fileName} )
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

		local str = string.char(unpack(ByteStream))
		local fileBin = io.open(fileName,"wb")
		fileBin:write(str)
		fileBin:close()
	end
end

function Packer.AddFileTxt(_,name,ext)
	local valid =
	{
		["l"] = true,
		["e"] = true,
		["c"] = true,
		["f"] = true,
		["s"] = true,
	}

	local ByteStream = {}
	local f=io.open(name.."."..ext, "r")
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

	_:AddByteStream(name..".draw", ByteStream)
end

function Read(f,i)
	return string.byte(f:read(i))
end

function Packer.AddFileTga(_,name,ext)
	local f = io.open(name.."."..ext,"rb")
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
	img.pixpal={}

	local nPixCount = img.width*img.height
	print(string.format("pixel read %dx%d : %d", img.width, img.height, nPixCount))

	local pal = {{0,0,0}}
	for y = img.height-1,0,-1 do
		for x = 0,img.width-1 do
			local ipix = y*img.width+x
			local b,g,r=Read(f,1),Read(f,1),Read(f,1)
			img.pixrgb[ipix] = {r,g,b}

			-- find color idx
			local ic=0
			for k,v in pairs(pal) do
				if v[1]==r and v[2]==g and v[3]==b then
					ic=k
					break
				end
			end
			if ic==0 then
				table.insert(pal,{r,g,b})
				ic =#pal
			end

			-- store paletted image
			img.pixpal[ipix+1] = ic-1
		end
	end

	print(string.format("Color count %d", #pal))

	local ByteStream = {}
	-- write palette
	PushToStream(ByteStream,#pal)			-- num colors
	for k,v in pairs(pal) do
		PushToStream(ByteStream,v[1])		-- r g b
		PushToStream(ByteStream,v[2])
		PushToStream(ByteStream,v[3])
	end

	-- write img
	PushToStream(ByteStream,img.width)		-- width
	PushToStream(ByteStream,img.height)		-- height
	for i=1,nPixCount do
		local a = img.pixpal[i]
		PushToStream(ByteStream,a)

		-- for k=0,7 do
		-- 	a=(a<<5)|img.pixpal[i+k]
		-- end

		-- local a5 = a&0xFF	a = a>>8
		-- local a4 = a&0xFF	a = a>>8
		-- local a3 = a&0xFF	a = a>>8
		-- local a2 = a&0xFF	a = a>>8
		-- local a1 = a&0xFF	a = a>>8
		-- PushToStream(ByteStream, a1)
		-- PushToStream(ByteStream, a2)
		-- PushToStream(ByteStream, a3)
		-- PushToStream(ByteStream, a4)
		-- PushToStream(ByteStream, a5)
	end

	_:AddByteStream(name..".c31",ByteStream)
end

function Packer.OutputZip(_, fileName)

	local Zipfile = "out.zip"
	local handle = io.popen("del "..Zipfile)
	handle:close()

	local cmd7z="7za.exe a -y "..Zipfile
	for k,f in pairs(_._Files) do
		cmd7z=cmd7z.." "..f.name
	end

	-- compress to zip
	-- 7za.exe a -mx9 test.zip Levex.draw Spectrals.draw test.c31
	handle = io.popen(cmd7z)
	handle:close()

	-- Read Zip infos & print
	handle = io.popen("7za.exe l "..Zipfile)
	local result = handle:read("*a")
	handle:close()
	print(result)

	-- Zip written, read to ByteStream
	local add = function(s,c)
		table.insert(s,string.format("%02x",c))
	end

	local fZip = io.open(Zipfile, "rb")
	local fOut = io.open(fileName,"w")
	if fOut==nil or fZip==nil then return end

	local ZipData = fZip:read("*a")
	fZip:close()

	local ZipSize=#ZipData
	local ByteStream = { }
	add(ByteStream,ZipSize>>8)
	add(ByteStream,ZipSize&0xFF)
	for i=1,#ZipData do
		local c = string.byte(ZipData:sub(i,i))
		add(ByteStream,c)
	end

	-- now build map lua file
	local sHeader = "-- <MAP>";
	local sFooter = "\n-- </MAP>\n";

	fOut:write(sHeader)

	local iCurrentRow = -1
	local i = 0;
	while i < #ByteStream do
		if i%240 == 0 then
			iCurrentRow = iCurrentRow+1
			-- "-- 001:"
			local sRow = string.format("\n-- %03d:",iCurrentRow);
			fOut:write(sRow);
		end
		local str = ByteStream[i+1]
		local hi = str:sub(1,1)
		local lo = str:sub(2,2)
		fOut:write(lo);
		fOut:write(hi);
		i = i+1
	end

	-- trailing zeros
	while i%240 ~= 0 do
		fOut:write("00");
		i = i+1;
	end

	fOut:write(sFooter)

	io.close(fOut)

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


local InputFiles = {"Spectrals.txt","Levex.txt","Tibet.txt","Dear.txt","Rando.txt","Tunnel.txt",
					"MountainVista.tga",
					"cube.obj", "tetrahedron.obj","octahedron.obj", "pyramid.obj", "cyl.obj" }
Packer:AddFiles(InputFiles)

print("Writing ...")
--Packer:Output("out.lua")
Packer:OutputZip("out.lua")

print("Done")

