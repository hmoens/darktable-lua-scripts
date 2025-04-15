--[[
  lighttable_exposure_controls.lua – Quick exposure adjustments from Darktable's lighttable view.

  Description:
    This script adds a set of buttons under "Actions on selection" in the lighttable UI,
    allowing quick bulk exposure adjustments of ±1/3 EV or ±1 EV to selected images, and
    equalizing exposure across a series of images.

    Tjhe equalize exposure button equalizes the exposure of a set of images relative to 
    the first selected one, based on their aperture, shutter speed, and ISO. This is 
    useful when dealing with bracketed or unevenly exposed series.

    Because Darktable does not allow reading or modifying module parameters from the
    lighttable via Lua, the script works around this limitation by:
      1. Reading the latest exposure value from the image's XMP sidecar file.
      2. Generating a temporary style with the adjusted exposure value.
      3. Applying the style to the image, creating a new history stack entry.

    Requirements:
      - Darktable must be configured to write XMP sidecar files.
      - The Lua script must be allowed to read and write temporary files.


  Author: moenshendrik@protonmail.com
]]

local dt = require "darktable"

local debug = require "darktable.debug"

local function hex_to_bin(hex)
  return (hex:gsub('..', function(cc) return string.char(tonumber(cc, 16)) end))
end


local function unpack_exposure_params(hex)
  local bin = hex_to_bin(hex)
  local mode, black, exposure, percentile, target, compensate =
    string.unpack("<iffff i4", bin)

  return {
    mode = mode,
    black = black,
    exposure = exposure,
    deflicker_percentile = percentile,
    deflicker_target_level = target,
    compensate_exposure_bias = compensate
  }
end


local function pack_exposure_params(params)
  local bin = string.pack("<iffff i4",
      params.mode,
      params.black,
      params.exposure,
      params.deflicker_percentile,
      params.deflicker_target_level,
      params.compensate_exposure_bias
  )
  local hex = bin:gsub('.', function(c) return string.format('%02x', c:byte()) end)
  return hex
end


local function get_current_exposure(image)
  local xmp_path = image.sidecar
  local xmp = io.open(xmp_path, "r")
  if not xmp then return nil end
  local content = xmp:read("*all")
  xmp:close()

  local highest_num = -1
  local latest_params = nil

  -- Match each block containing the exposure operation
  for block in content:gmatch("<rdf:li.-/>") do
    if block:find('darktable:operation="exposure"') then
      local num = tonumber(block:match('darktable:num="(%d+)"') or "")
      local params = block:match('darktable:params="([0-9a-fA-F]+)"')
      if num and params and num > highest_num then
        highest_num = num
        latest_params = params
      end
    end
  end

  if latest_params then
    return unpack_exposure_params(latest_params)
  end
  return nil
end



function style_xml(style_name, op_params_hex)
  return [[<?xml version="1.0" encoding="UTF-8"?>
<darktable_style version="1.0">
  <info>
    <name>]] .. style_name .. [[</name>
    <description></description>
  </info>
  <style>
    <plugin>
      <num>15</num>
      <module>6</module>
      <operation>exposure</operation>
      <op_params>]] .. op_params_hex .. [[</op_params>
      <enabled>1</enabled>
      <blendop_params>gz08eJxjYGBgYAFiCQYYOOHEgAZY0QWAgBGLGANDgz0Ej1Q+dlAx68oBEMbFxwX+AwGIBgCbGCeh</blendop_params>
      <blendop_version>13</blendop_version>
      <multi_priority>0</multi_priority>
      <multi_name></multi_name>
      <multi_name_hand_edited>0</multi_name_hand_edited>
    </plugin>
  </style>
</darktable_style>
]]
end


function set_exposure_via_style(image, params)
  -- local tmp_style_path = "/tmp/ev_adjust.dtstyle"

  local tmp_path = os.tmpname() .. ".dtstyle"
  local style_name = "temp_style_" .. tostring(os.time())

  print("path: " .. tmp_path)
  print("style name: " .. style_name)

  local op_params = pack_exposure_params(params)
  local xml = style_xml(style_name, op_params)
  print(xml)

  -- Write dtstyle file
  local f = io.open(tmp_path, "w")
  f:write(xml)
  f:close()

  dt.styles.import(tmp_path)
  os.remove(tmp_path)

  -- Find the style we just imported by name
  local style_obj = nil
  for _, s in ipairs(dt.styles) do
    if s.name == style_name then
      style_obj = s
      break
    end
  end

  dt.styles.apply(style_obj, image)
  dt.styles.delete(style_obj)
end

local function adjust_exposure(ev)
  for _, image in ipairs(dt.gui.action_images) do

    print(image.sidecar)
    print("adjust exposure " .. ev)

    exposure_params = get_current_exposure(image)
    print(debug.dump(exposure_params))

    exposure_params.exposure = exposure_params.exposure + ev
    print(debug.dump(exposure_params))

    set_exposure_via_style(image, exposure_params)
  end
end

local function log2(x)
  return math.log(x) / math.log(2)
end

local function compute_ev(aperture, exposure_time, iso)
  return log2((aperture^2) / exposure_time) - log2(iso / 100)
end


local function equalize_exposure()
  local ref_ev

  for i, image in ipairs(dt.gui.action_images) do

    exposure_params = get_current_exposure(image)

    local ev = compute_ev(
      image.exif_aperture,
      image.exif_exposure,
      image.exif_iso
    ) + exposure_params.exposure

    if i == 1 then
      ref_ev = ev
    else
      local delta_ev = ref_ev - ev
      print(string.format(
        "%s EV delta: %.2f",
        image.path, delta_ev
      ))
      exposure_params.exposure = exposure_params.exposure - delta_ev
      set_exposure_via_style(image, exposure_params)
    end
  end
end



dt.gui.libs.image.register_action("Exposure adjust -1", "-1 EV", function() adjust_exposure(-1.0) end)
dt.gui.libs.image.register_action("Exposure adjust -1/3", "-1/3 EV", function() adjust_exposure(-1.0/3.0) end)
dt.gui.libs.image.register_action("Exposure adjust +1/3", "+1/3 EV", function() adjust_exposure(1.0/3.0) end)
dt.gui.libs.image.register_action("Exposure adjust +1", "+1 EV", function() adjust_exposure(1.0) end)

dt.gui.libs.image.register_action("Equalize exposure", "Equalize exposure",  equalize_exposure)