require "faraday"
require "json"

HUE = {
  -20 => 60_000,
  50 => 25_500,
  100 => 0,
}

# Get the hue for a temperature.  It should be between 0 and 65535.
def hue_for_temp(temp)
  # array of temperature keys
  #   example: [-20, 50, 100]
  temps = HUE.keys.sort

  # ensure temp stays above -20 and below 100
  temp = [temp, temps.first].max
  temp = [temp, temps.last].min

  if key = HUE[temp]
    return key
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

  hue.to_i
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

new_hue = hue_for_temp(temp)

# the new state of the hue light
state = {
  :on => true,
  :hue => new_hue,
  :sat => 255,
  :bri => 200,
  :transitiontime => 10,
}

if ENV["DEBUG"] == "1"
  puts "#{temp}F => #{new_hue}"
end

# change the hue light
hueapi = Faraday.new ENV["HUE_API"]
hueapi.put "/api/#{ENV["HUE_USER"]}/lights/#{ENV["HUE_LIGHT"]}/state", state.to_json
