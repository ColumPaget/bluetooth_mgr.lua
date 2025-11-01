device_names={
items={},

filepath=function(self)
return process.homeDir() .. "/.config/bluetooth_mgr.lua/device_names.conf"
end,


add=function(self, addr, title)
self.items[addr]=title
self:save()
end,

del=function(self, addr)
self.items[addr]=nil
end,

get=function(self, addr)
local str

str=self.items[addr]
if strutil.strlen(str) > 0 then return str end
return("")
end,


save=function(self)
local S, addr, name, str

str=self:filepath()
filesys.mkdirPath(str)
S=stream.STREAM(str, "w")
if S ~= nil
then
  for addr, name in pairs(self.items)
  do
	S:writeln(addr .. " ".. name.."\n")
  end
  S:close()
end

end,


load_item=function(self, str)
local toks, addr, name

toks=strutil.TOKENIZER(str, "\\S")
addr=toks:next()
name=toks:remaining()

if strutil.strlen(addr) > 0 and strutil.strlen(name) then self.items[addr]=name end
end,


load=function(self)
local S, str

str=self:filepath()
S=stream.STREAM(str, "r")
if S ~= nil
then
  str=S:readln()
  while str ~= nil
  do
  self:load_item(strutil.trim(str))
  str=S:readln()
  end
  S:close()
end

end

}
