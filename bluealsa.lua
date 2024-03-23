bluealsa={


use=function(self, bt_dev)
local S, str, name

name=string.gsub(bt_dev.name, " ", "_")
str=process.getenv("HOME") .. "/.asoundrc"
if config.debug == true then io.stderr:write("BLUEALSA SETUP -----------------------["..str.."]\n") end
S=stream.STREAM(str, "w")
if S ~= nil
then
str="pcm."..name.." {\n"
str=str.."type plug\n"
str=str.."slave.pcm { type bluealsa; service org.bluealsa; device \""..bt_dev.addr.."\"; profile a2dp}\n"
str=str.."}\n\n"
str=str.."ctl."..name.." {\ntype bluealsa\n}\n\n";
str=str.."pcm.!default {type plug; slave.pcm \""..name.."\"}\n"
S:writeln(str)
if config.debug == true then io.stderr:write(str) end
S:close()
if config.debug == true then io.stderr:write("BLUEALSA SETUP -----------------------\n") end
end

end

}
