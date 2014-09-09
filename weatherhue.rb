require "faraday"
require "json"
require "color"

HUE = {
  -20 => 60_000,
  50 => 25_500,
  100 => 0,
}

# Get an HSL tuple for a temperature.  This tuple should be suited for
# the Philips Hue API.  It's an array of 3 floats:
#
# - hue (0 - 65535)
# - saturation (0-255)
# - brightness (0-255)
#
def color_for_temp(temp)
  # array of temperature keys
  #   example: [-20, 50, 100]
  temps = HUE.keys.sort

  # ensure temp stays above -20 and below 100
  temp = [temp, temps.first].max
  temp = [temp, temps.last].min

  if key = HUE[temp]
    return [key, 255, 200]
  end

  min = max = nil
  HUE.keys.sort.each do |key|
    if key < temp
      min = key
    end

    if key > temp && max == nil
      max = key
    end
  end

  full_range = max - min
  temp_range = temp - min
  temp_perc = temp_range / full_range.to_f

  min_hue = HUE[min]
  max_hue = HUE[max]
  full_hue_range = min_hue - max_hue
  hue_range = full_hue_range * temp_perc
  hue = min_hue - hue_range

  [hue.to_i, 255, 200]
end

# Convert an HSL tuple to a Color::HSL object.
def hsl_to_color(hsl)
  Color::HSL.from_fraction(
    hsl[0] / 65535.0,
    hsl[1] / 255.0,
    hsl[2] / 255.0)
end

# Convert a Color::HSL object to an HSL tuple.
def color_to_hsl(color)
  [(color.h * 65535).to_i, (color.s * 255).to_i, (color.l * 255).to_i]
end

if temp = ARGV[0]
  # Get the temperature from the first argument.
  #
  #   ruby weatherhue.rb 75
  #
  temp = temp.to_i
else
  # Get the temperature from the weather2 api
  #
  # http://www.myweather2.com/developer/
  url = "http://www.myweather2.com/developer/forecast.ashx?uac=#{ENV["WEATHER2_TOKEN"]}&temp_unit=f&output=json&query=#{ENV["WEATHER2_QUERY"]}"
  res = Faraday.get(url)
  if res.status != 200
    puts res.status
    puts res.body
    exit
  end

  data = JSON.parse(res.body)
  temp = data["weather"]["curren_weather"][0]["temp"].to_i
end

temp_color = color_for_temp(temp)

# the new state of the hue light
state = {
  :on => true,
  :hue => temp_color[0],
  :sat => temp_color[1],
  :bri => temp_color[2],
  :transitiontime => 10,
}

# change the hue light
hueapi = Faraday.new ENV["HUE_API"]
hueapi.put "/api/#{ENV["HUE_USER"]}/lights/#{ENV["HUE_LIGHT"]}/state", state.to_json
