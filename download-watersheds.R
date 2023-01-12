
library(FedData)
library(mapview)
library(rmapshaper)
library(sf)
library(tidyverse)

owin <- st_bbox(
  c(
    xmin = -113.35,
    ymin = 30.05, 
    xmax = -105.35, 
    ymax = 38.25
  )
) |> 
  st_as_sfc() |> 
  st_sf(geometry = _, crs = 4326)

watersheds <- get_wbd(owin, "hndsr")

huc4_ids <- c(1302, 1303, 1408, 1502, 1504, 1505, 1506)

huc10 <- watersheds |> 
  select(huc12, name) |> 
  filter(substr(huc12, 1, 4) %in% huc4_ids) |> 
  ms_simplify(keep = 0.07) |> 
  mutate(huc10 = substr(huc12, 1, 10)) |> 
  group_by(huc10) |> 
  summarize() |>
  mutate(huc4 = substr(huc10, 1, 4))

write_sf(huc10, "watersheds.geojson")
