function SettingsInit(cmd_line_args)
config.debug=false

for i,val in ipairs(cmd_line_args)
do
if val == "-debug" then config.debug=true end
end

end
