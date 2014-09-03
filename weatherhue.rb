require "faraday"
require "json"
require "color"

# Get an HSL tuple for a temperature.  This tuple should be suited for
# the Philips Hue API.  It's an array of 3 floats:
#
# - hue (0 - 65535)
# - saturation (0-255)
# - brightness (0-255)
#
def color_for_temp(temp)
  # ensure temp stays above -20 and below 100
  temp = [temp, -20].max
  temp = [temp, 100].min

  remainder = temp % 5
  if remainder == 0
    return HSL[temp]
  end

  lower = temp - remainder
  upper = lower + 5

  lower_color = hsl_to_color(HSL[lower])
  upper_color = hsl_to_color(HSL[upper])

  color = lower_color.mix_with(upper_color, remainder / 5.0)

  color_to_hsl color
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

HSL = {
  -20=>[53884, 255, 200],
  -15=>[53988, 255, 200],
  -10=>[53726, 255, 200],
  -5=>[52902, 255, 200],
  0=>[50399, 255, 200],
  5=>[48821, 255, 200],
  10=>[44592, 255, 200],
  15=>[39094, 255, 200],
  20=>[36305, 255, 200],
  25=>[35041, 255, 200],
  30=>[31547, 255, 200],
  35=>[22141, 255, 200],
  40=>[19216, 255, 200],
  45=>[16245, 255, 200],
  50=>[13075, 255, 200],
  55=>[11802, 255, 200],
  60=>[10831, 255, 200],
  65=>[9901, 255, 200],
  70=>[8470, 255, 200],
  75=>[5908, 255, 200],
  80=>[3346, 255, 200],
  85=>[2983, 255, 200],
  90=>[2409, 255, 200],
  95=>[1820, 255, 200],
  100=>[1492, 255, 200]
}

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
