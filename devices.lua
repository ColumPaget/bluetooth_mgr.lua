devices={}

function NewDevice(addr, name)
local dev={}

if devices[addr] ~= nil then return devices[addr] end

-- functions
dev.setname=function(self, name)
local str

if strutil.strlen(name) == 0 then return end
if name=="(random)" then return end
if name=="(public)" then return end

str=string.gsub(name, "-", ":")
if strutil.strlen(name) > 0 and str ~= dev.addr then dev.name=name end
end

dev.adduuid=function(self, uuid)
local toks, tok

toks=strutil.TOKENIZER(uuid, "(")
tok=strutil.trim(toks:next())
self.uuids=self.uuids .. tok .. ","
end



dev.parse_manufacturer_key=function(self, toks)
local id

	id=toks:next()
	if id == "0x0000" then self.vendor="ericson"
	elseif id == "0x0001" then self.vendor="nokia"
	elseif id == "0x0002" then self.vendor="intel"
	elseif id == "0x0003" then self.vendor="ibm"
	elseif id == "0x0004" then self.vendor="toshiba"
	elseif id == "0x0005" then self.vendor="3com"
	elseif id == "0x0006" then self.vendor="microsoft"
	elseif id == "0x0007" then self.vendor="lucent"
	elseif id == "0x0008" then self.vendor="motorola"
	elseif id == "0x004c" then self.vendor="apple"
	elseif id == "0x0087" then self.vendor="garmin"
	elseif id == "0x00E0" then self.vendor="google"
	elseif id == "0x011b" then self.vendor="hp ent."
	elseif id == "0x013a" then self.vendor="tencent"
	elseif id == "0x0c8c" then self.vendor="tmobile"
	elseif id == "0x0d04" then self.vendor="bartec"
	elseif id == "0x0d07" then self.vendor="datalogic"
	elseif id == "0x0d08" then self.vendor="datalogic"
	elseif id == "0x0d5b" then self.vendor="axis"
	elseif id == "0x0d28" then self.vendor="fujitsu"
	elseif id == "0x0bee" then self.vendor="linksys"
	end
end


dev.parse_manufacturer=function(self, toks)
if toks:next() == "Key:"
then
 self:parse_manufacturer_key(toks)
end
end


dev.parse_rssi=function(self, toks)
local str

		str=toks:next()
		if string.sub(str, 1, 2) == "0x" then str=toks:next() end
		if string.sub(str, 1, 1) == "(" then str=string.sub(str, 2, 4) end
		self.rssi=str
end

dev.parse_info=function(self, tok, toks)

	if tok == "Name:" then self:setname(toks:remaining())
	elseif tok == "Paired:" and toks:next() =="yes" then self.paired=true
	elseif tok == "Trusted:" and toks:next() =="yes" then self.trusted=true
	elseif tok == "Connected:" and toks:next() =="yes" then self.connected=true
	elseif tok == "Icon:" then self.icon=toks:next()
	elseif tok == "Name:" then self:setname(toks:remaining())
	elseif tok == "UUID:" then self:adduuid(toks:remaining())
	--old format is "MaunfacturerData Key:"
	elseif tok == "ManufacturerData" then self:parse_manufacturer(toks)
	--new format is "MaunfacturerData.Key:"
	elseif tok == "ManufacturerData.Key:" then self:parse_manufacturer_key(toks)
	elseif tok == "RSSI:" then self:parse_rssi(toks)
  elseif tok == "Connected:" and toks:next() == "yes"
	then
	  bt:onconnected(self)
	end
end

dev.parse_change=function(self, toks)
local tok

	tok=toks:next()
	self:parse_info(tok, toks)
	ui:loaddevs()
end



dev.finalize=function(self)
local toks, tok

--if strutil.strlen(self.name) == 0 then self.name=self.addr end
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

