json.locations @locations do |location|
  json.id         location.id
  json.name       location.name
  json.elevation  location.elevation
  json.latitude   location.latitude
  json.longitude  location.longitude
end