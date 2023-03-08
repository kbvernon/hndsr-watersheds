
library(here)
library(plotly)
library(rjson) # plotly uses rjson formatted json
library(sf)
library(tidyverse)

selection <- here("data", "selected-watersheds.txt") |> 
  readLines() |> 
  strsplit(", ") |> 
  unlist() |> 
  as.numeric()

watersheds <- here("data", "watersheds.geojson") |> 
  read_sf() |> 
  rename("name" = watershed, "watershed" = hydrologic_unit) |> 
  relocate(watershed, name) |> 
  filter(watershed %in% selection)

xy <- watersheds |> 
  st_union() |> 
  st_centroid() |> 
  st_coordinates() |> 
  c()

# standard cyberSW date ranges
min_year <- 700
max_year <- 1600

years <- seq(min_year, max_year, by = 100)

room_counts <- here("data", "cyberSW-datacut-230224_room-allocations.csv") |> 
  read_csv() |> 
  rename(
    "watershed" = HU10,
    "year" = "25year",
    "rooms" = "allocatedRooms"
  ) |> 
  select(watershed, year, rooms) |> 
  filter(
    watershed %in% selection,
    year >= min_year,
    year <= max_year
  ) |> 
  group_by(watershed, year) |> 
  summarize(rooms = sum(rooms)) |> 
  ungroup()

missing_watersheds <- tibble(watershed = selection) |> 
  filter(!(watershed %in% unique(room_counts$watershed))) |> 
  mutate(year = min_year, rooms = 0)

room_counts <- room_counts |> 
  bind_rows(missing_watersheds) |> 
  group_by(watershed) |> 
  complete(
    year = years, 
    fill = list(rooms = 0)
  ) |> 
  ungroup() |> 
  distinct() |> 
  mutate(year = floor(year/100)*100) |> 
  group_by(watershed, year) |> 
  summarize(
    mu = mean(rooms),
    rooms = ifelse(mu > 0, log(mu), log(0.0001))
  ) |> 
  ungroup() |> 
  mutate(
    rooms = scales::rescale(rooms, to = c(0, 1)),
    rooms = round(rooms, 3),
    mu = round(mu, 3),
    watershed = as.character(watershed)
  ) |> 
  left_join(
    watersheds |> st_drop_geometry(), 
    by = "watershed"
  ) |> 
  mutate(
    hover = paste0(
      "<b style='font-size:1.4em;'>", name, "</b><br>",
      "<b>ID:</b> ", watershed, "<br>",
      "<b>Basin:</b> ", basin, "<br>",
      "<b>Year:</b> ", year, "<br>",
      "<b>Mean estimate:</b> ", mu, "<br>",
      "<b>Transform estimate:</b> ", rooms
    )
  ) |> 
  select(watershed, year, rooms, hover) |> 
  rename("hydrologic_unit" = watershed)

remove(min_year, max_year, years, watersheds, missing_watersheds)

geojson <- rjson::fromJSON(file = here("data", "watersheds.geojson"))

geojson$features <- geojson$features |> keep(\(x){ x$properties$hydrologic_unit %in% selection })

p <- plot_ly() |> 
  add_trace(
    type = "choroplethmapbox",
    geojson = geojson,
    locations = room_counts$hydrologic_unit,
    featureidkey = "properties.hydrologic_unit",
    stroke = I("#fafafa"),
    span = I(0.4),
    frame = room_counts$year,
    z = room_counts$rooms,
    zmin = 0,
    zmax = 1,
    colorscale = "Viridis",
    text = room_counts$hover,
    hoverinfo = "text",
    marker = list(opacity = 0.5)
  ) |>
  layout(
    mapbox = list(
      style = "stamen-terrain",
      zoom = 5,
      center = list(lon = xy[1], lat = xy[2])
    )
  )

htmlwidgets::saveWidget(
  p,
  here("plotly-map-only.html"),
  selfcontained = FALSE,
  libdir = "plotly-map-lib"
)
