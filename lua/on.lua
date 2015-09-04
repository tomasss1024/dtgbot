local on_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function SwitchID(DeviceName, idx, DeviceType, state, level, SendTo)
  if string.lower(state) == "on" then
    state = "On";
  elseif string.lower(state) == "off" then
    state = "Off";
  elseif string.sub(string.lower(state),1,3) == "set" then
    level = math.ceil(level * Deviceproperties[idx].MaxDimLevel / 100)
    print_to_log(0,'level',level)
    state = "Set%20Level&level="..level
  else
    return "state must be on, off or set level!";
  end
  t = server_url.."/json.htm?type=command&param=switch"..DeviceType.."&idx="..idx.."&switchcmd="..state
  print_to_log (1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  print_to_log(1,"raw jason", jresponse)
  response = 'Switched '..DeviceName..' '..command
  return response
end

function sSwitchName(DeviceName, DeviceType, SwitchType,idx,state)
  local status
  if idx == nil then
    response = 'Device '..DeviceName..'  not found.'
  else
    local subgroup = "light"
    if DeviceType == "scenes" then
      subgroup = "scene"
    end
    if string.lower(state) == "on" then
      state = "On";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
    elseif string.lower(state) == "off" then
      state = "Off";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
    elseif string.lower(string.sub(state,1,9)) == "set level" then
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd=Set%20Level&level="..string.sub(state,11)
    else
      return "state must be on, off or Set Level!";
    end
    print_to_log(1,"JSON request <"..t..">");
    jresponse, status = http.request(t)
    print_to_log(1,"JSON feedback: ", jresponse)
    response = dtgmenu_lang[language].text["Switched"] .. ' ' ..DeviceName..' => '..state
  end
  print_to_log(0,"   -< SwitchName:",DeviceName,idx, status,response)
  return response, status
end

function switch(parsed_cli)
  command = parsed_cli[2]
  -- Set level value is more than a single word command so
  if string.lower(command) == 'set' then
    DeviceName = form_device_name({select(3, unpack(parsed_cli))})
    print_to_log(0,DeviceName,parsed_cli[1],parsed_cli[2],parsed_cli[3],parsed_cli[4],parsed_cli[5],parsed_cli[6],parsed_cli[7])
    dimlevel = string.match(parsed_cli[4],"%d+")
    if dimlevel ~= nil then
      command = parsed_cli[2]..' '..parsed_cli[3]..' '..parsed_cli[4]
      --'Set%20Level&level='..dimlevel
    else
      return 'Set level but no level provided'
    end
  else  
    DeviceName = form_device_name(parsed_cli)
  end
  if DeviceName ~= nil then
    print_to_log('Device Name: '..DeviceName)
    -- DeviceName can either be a device / group / scene name or a number refering to list previously generated
    if tonumber(DeviceName) ~= nil then
      NewDeviceName = StoredList[tonumber(DeviceName)]
      if NewDeviceName == nil then
        response = 'No '..StoredType..' with number '..DeviceName..' was found - please execute devices or scenes command with qualifier to generate list'
        return status, response
      else
        DeviceName = NewDeviceName
      end
    end
    -- Update the list of device names and ids to be checked later
    -- Check if DeviceName is a device
    DeviceID = idx_from_name(DeviceName,'devices')
    switchtype = 'light'
    -- Its not a device so check if a scene
    if DeviceID == nil then
      DeviceID = idx_from_name(DeviceName,'scenes')
      switchtype = 'scene'
    end
    if DeviceID ~= nil then
      -- Now switch the device
      response = SwitchID(DeviceName, DeviceID, switchtype, command, dimlevel, SendTo)
    else   
      response = 'Device '..DeviceName..' was not found on Domoticz - please check spelling and capitalisation'
    end
  else
    response = 'No device specified'
  end
  return response
end 

function on_module.handler(parsed_cli)
  local response = ""
  response = switch(parsed_cli)
  return status, response;
end

local on_commands = {
  ["on"] = {handler=on_module.handler, description="on - on devicename - switches devicename on"},
  ["off"] = {handler=on_module.handler, description="off - off devicename - switches devicename off"},
  ["set"] = {handler=on_module.handler, description="set level - set level value devicename - set devicename to defined % of full"},
}

function on_module.get_commands()
  return on_commands;
end

return on_module;
