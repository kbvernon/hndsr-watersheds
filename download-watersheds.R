
library(FedData)
library(mapview)
library(rmapshaper)
library(sf)
library(tidyverse)

owin <- st_bbox(
  c(
    xmin = -113.27329,
    ymin = 29.69843, 
    xmax = -105.22713, 
    ymax = 38.60808
  )
) |> 
  st_as_sfc() |> 
  st_sf(geometry = _, crs = 4326)

watersheds <- get_wbd(owin, "hndsr")

huc6_ids <- c(130301, 130302, 130202, 140801, 140802,
              150200, 150400, 150501:150503, 150601)

huc10 <- watersheds |> 
  ms_simplify(keep = 0.08) |> 
  select(vpuid, huc12, name) |> 
  filter(substr(huc12, 1, 6) %in% huc6_ids) |> 
  mutate(huc10 = substr(huc12, 1, 10)) |> 
  group_by(huc10) |> 
  summarize() |>
  mutate(huc6 = substr(huc10, 1, 6))

write_sf(huc10, "watersheds.geojson")
