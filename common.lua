require("stream")
require("strutil")
require("terminal")
require("time")
require("process")

config={}
config.version="1.8"
config.show_beacons=false

function make_sorted(input, cmp_func)
local output={}
local key, value

for key,value in pairs(input)
do
  table.insert(output, value)
end

table.sort(output, cmp_func)

return output
end
