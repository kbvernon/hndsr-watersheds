
library(here)
library(httr2)
library(lwgeom)
library(rmapshaper)
library(sf)
library(tidyverse)

# download watersheds -----------------------------------------------------

download_hydro <- function(x, out_dir){
  
  out <- file.path(out_dir, paste0("NHDPLUS_H_", x, "_HU4_GDB.gdb"))
  
  if(file.exists(out)) return(out)
  
  base_url <- "https://prd-tnm.s3.amazonaws.com/StagedProducts/"
  product <- "Hydrography/NHDPlusHR/Beta/GDB/"
  gdb <- paste0("NHDPLUS_H_", x, "_HU4_GDB.zip")
  
  tmp <- tempfile(fileext = ".zip")
  
  download.file(paste0(base_url, product, gdb), tmp, mode = "wb")
  
  unzip(tmp, exdir = out_dir)
  
  return(out)
  
}

read_hydro <- function(x){
  
  out <- read_sf(x, layer = "WBDHU10") |> 
    rename(
      "watershed" = Name,
      "hydrologic_unit" = HUC10,
      "geometry" = Shape 
    ) |> 
    st_set_geometry("geometry") |> 
    select(hydrologic_unit, watershed)
  
  hydrologic_units <- c("subregion" = 4, "basin" = 6, "subbasin" = 8)
  
  for(i in c(4,6,8)){
    
    hydro_names_tbl <- read_sf(x, layer = paste0("WBDHU", i)) |>
      st_drop_geometry() |>
      rename(huc = paste0("HUC", i)) |>
      select(huc, Name) |> 
      distinct()
    
    names(hydro_names_tbl)[2] <- names(hydrologic_units)[hydrologic_units == i]
    
    out <- out |> 
      mutate(huc = substr(hydrologic_unit, 1, i)) |>
      left_join(hydro_names_tbl, by = "huc")
    
  }
  
  out |>
    select(hydrologic_unit, subregion:subbasin, watershed, geometry) |>
    sf::st_transform(4326)
  
}

huc4 <- c(1108, 1301, 1302, 1303, 1305, 1306, 1403,
          1407, 1408, 1501, 1502, 1504, 1505, 1506)

watersheds <- huc4 |> 
  map(download_hydro, out_dir = "data-raw") |> 
  map(read_hydro)

names(watersheds) <- huc4

# colorado river ----------------------------------------------------------

extract_river <- function(x, river){
  
  read_sf(x, layer = "NHDFlowline") |>
    st_zm() |>
    filter(GNIS_Name == river) |>
    st_union() |>
    st_cast("MULTILINESTRING") |>
    st_line_merge()
  
}

cut_hydro <- function(x, river, side){
  
  shp <- st_union(x) |>
    lwgeom::st_split(river) |>
    st_collection_extract("POLYGON") |>
    st_make_valid()
  
  st_intersection(x, shp[side])
  
}

cr_lyrs <- list(
  "data-raw/NHDPLUS_H_1407_HU4_GDB.gdb/",
  "data-raw/NHDPLUS_H_1501_HU4_GDB.gdb/"
)

colorado_river <- cr_lyrs |> 
  map(extract_river, river = "Colorado River") |> 
  map(st_as_sf) |> 
  bind_rows() |>
  st_union() |>
  st_cast("MULTILINESTRING") |>
  st_line_merge()

watersheds$`1403` <- watersheds$`1403` |> 
  filter(
    hydrologic_unit %in% c("1403000201", "1403000202", "1403000203", "1403000204", "1403000206")
  )

# Cut at Colorado River
watersheds$`1407` <- watersheds$`1407` |> 
  filter(
    str_starts(hydrologic_unit, "14070006")
  ) |>
  cut_hydro(colorado_river, 2)

# Cut at Colorado River, north of Little Colorado
watersheds$`1501` <- watersheds$`1501` |> 
  filter(
    str_starts(hydrologic_unit, "15010001"), 
    hydrologic_unit != "1501000106"
  ) |>
  cut_hydro(colorado_river, 2)

watersheds <- watersheds |>
  bind_rows() |>
  rmapshaper::ms_simplify(keep = 0.06) |> 
  distinct()

write_sf(
  watersheds, 
  dsn = "watersheds.geojson", 
  delete_dsn = TRUE
)
