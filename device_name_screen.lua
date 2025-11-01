
device_name_screen={


run=function(self, device)
local Term, str

Term=ui.Term;

Term:clear()
Term:move(0,0)
Term:puts("~M~nRename Device "..device.addr.."~>~0\n")
Term:puts("\n")
Term:puts("Device 'real name': " .. device.name .. "\n")
Term:puts("Device 'display name': " .. device_names:get(device.addr) .. "\n\n")
Term:puts("Enter new name for this device\nOr just enter blank cance\n")
Term:puts("\n")
str=Term:prompt("New Name: ")

if strutil.strlen(str) > 0 then device_names:add(device.addr, str) end

end

}
