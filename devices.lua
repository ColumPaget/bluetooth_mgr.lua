devices={}

function NewDevice(addr, name)
local dev={}

if devices[addr] ~= nil then return devices[addr] end

-- functions
dev.setname=function(self, name)
if strutil.strlen(name) > 0 then dev.name=name end
end

dev.adduuid=function(self, uuid)
local toks, tok

toks=strutil.TOKENIZER(uuid, "(")
tok=strutil.trim(toks:next())
self.uuids=self.uuids .. tok .. ","
end



dev.parsechange=function(self, toks)
local tok

	tok=toks:next()
	if tok == "Name:" 
	then 
	self.name=toks:remaining() 
	ui:loaddevs()
  elseif tok == "RSSI:"
	then 
	self.rssi=toks:next()
	ui:loaddevs()
	elseif tok == "Connected:" and toks:next() == "yes"
	then
	  bt:onconnected(self)
	end

end



dev.finalize=function(self)
local has_audio_sink=false 
local has_audio_source=false
local toks, tok

if strutil.strlen(self.name) == 0 then self.name=self.addr end

toks=strutil.TOKENIZER(self.uuids, ",")
tok=toks:next()
while tok ~= nil
do
if tok=="Audio Sink" then has_audio_sink=true end
if tok=="Audio Source" then has_audio_source=true end
tok=toks:next()
end

if self.icon == "audio-card"
then
	if has_audio_sink ~= true then self.icon = "audio-source"
	elseif has_audio_source ~= true then self.icon = "audio-output"
	end
end

end

--end functions

dev.addr=addr
dev:setname(name)
dev.uuids=""
devices[addr]=dev

return dev
end


function GetDevice(addr)
local dev

dev=devices[addr]
if dev == nil then dev=NewDevice(addr) end

return dev
end

