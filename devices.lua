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



dev.parse_change=function(self, toks)
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
local toks, tok

if strutil.strlen(self.name) == 0 then self.name=self.addr end
self.audio_output=false
self.audio_input=false

toks=strutil.TOKENIZER(self.uuids, ",")
tok=toks:next()
while tok ~= nil
do
if tok=="Audio Sink" then self.audio_output=true end
if tok=="Audio Source" then self.audio_input=true end
tok=toks:next()
end

if self.icon == "audio-card"
then
	if self.audio_output ~= true then self.icon = "audio-source"
	elseif self.audio_input ~= true then self.icon = "audio-output"
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

