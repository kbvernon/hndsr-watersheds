library(mapview)
library(rmapshaper)
library(sf)
library(tidyverse)
library(magrittr)

simple_hydro_read <- function(x){
  
  out <-
    x %>%
    sf::read_sf(layer = "WBDHU10") %>%
    dplyr::select(HUC10, Name) %>%
    dplyr::rename(`Hydrologic_Unit` = HUC10) %>%
    magrittr::set_names(c("Hydrologic_Unit","Watershed","geometry")) %>%
    sf::st_set_geometry("geometry")
  
  hydrologic_units <-
    c("Subregion" = 4,
      "Basin" = 6,
      "Subbasin" = 8)
  
  for(i in seq(4,8,2)){
    out %<>%
      dplyr::mutate(HUC = stringr::str_sub(`Hydrologic_Unit`, end = i)) %>%
      dplyr::left_join(
        sf::read_sf(x,
                                   layer = paste0("WBDHU",i)) %>%
                         sf::st_drop_geometry() %>%
                         dplyr::rename(HUC = paste0("HUC",i)) %>%
                         dplyr::select(HUC, Name) %>%
                         magrittr::set_names(c("HUC",
                                               names(hydrologic_units)[hydrologic_units == i])) %>%
                         dplyr::distinct()
        ) %>%
      dplyr::select(-HUC)
  }
  out %>%
    dplyr::select(`Hydrologic_Unit`, Subregion:Subbasin, Watershed, geometry) %>%
    sf::st_transform(4326)
}

extract_river <- function(x, river){
  x %>%
    sf::read_sf(layer = "NHDFlowline") %>%
    sf::st_zm() %>%
    dplyr::filter(GNIS_Name == river) %>%
    sf::st_union() %>%
    sf::st_cast("MULTILINESTRING") %>%
    sf::st_line_merge()
}

cut_hydro <- function(x, river, side){
  x %>%
    sf::st_intersection(x %>%
                          sf::st_union() %>%
                          lwgeom::st_split(river) %>%
                          sf::st_collection_extract("POLYGON") %>%
                          sf::st_make_valid() %>%
                          magrittr::extract(side))
}

download_huc <- function(x, 
                         out_dir = tempdir()){
  out <- paste0(out_dir,"/NHDPLUS_H_", x, "_HU4_GDB.gdb/")
  if(file.exists(out))
    return(out)
  
  httr::GET(
    url = paste0("https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/NHDPlusHR/Beta/GDB/NHDPLUS_H_",x,"_HU4_GDB.zip"),
    httr::write_disk(tempfile(fileext = ".zip")),
    httr::progress()
  ) %$%
    content %>%
    magrittr::extract2(1) %>%
    unzip(exdir = out_dir)
  
  return(out)
}

huc4 <- 
  c(1302, 
    1303,
    1403,
    1407,
    1408,
    1501,
    1502, 
    1504, 
    1505, 
    1506) %>%
  magrittr::set_names(.,.) %>%
  purrr::map(download_huc,
             out_dir = "data-raw") %>%
  purrr::map(simple_hydro_read)

colorado_river <-
  list("data-raw/NHDPLUS_H_1407_HU4_GDB.gdb/",
       "data-raw/NHDPLUS_H_1501_HU4_GDB.gdb/") %>%
  purrr::map(extract_river,
             "Colorado River") %>%
  purrr::map_dfr(sf::st_as_sf) %>%
  sf::st_union() %>%
  sf::st_cast("MULTILINESTRING") %>%
  sf::st_line_merge()

huc4$`1403` %<>%
  dplyr::filter(Hydrologic_Unit %in%
                  c("1403000201",
                    "1403000202",
                    "1403000203",
                    "1403000204",
                    "1403000206"))

# Cut at Colorado River
huc4$`1407` %<>%
  dplyr::filter(stringr::str_starts(Hydrologic_Unit, "14070006")) %>%
  cut_hydro(colorado_river, 2)

# Cut at Colorado River, north of Little Colorado
huc4$`1501` %<>%
  dplyr::filter(stringr::str_starts(Hydrologic_Unit, "15010001"),
                Hydrologic_Unit != "1501000106") %>%
  cut_hydro(colorado_river, 2)

huc4 %>%
  dplyr::bind_rows() %>%
  rmapshaper::ms_simplify(keep = 0.07) %>%
  sf::write_sf("watersheds.geojson", delete_dsn = TRUE)
