
# date: 30/03/21
# author: VB
# description: script to develop Future Forest Mangement Pathways (FFMPs) using data provided by Skogforsk.

#wd <- "~/R/FFMPs" # laptop
wd <- "~/FFMPs" # sandbox
dirData <- paste0(wd,"/data-raw/")
dataDrive <- "D:"
dirOut <- paste0(dataDrive,"/FFMP-data-processed/")
dirFigs <- paste0(wd,"/figures/")

### libraries ------------------------------------------------------------------

library(tidyverse)
library(sf)
library(raster)
library(ggplot2)
library(RColorBrewer)
library(vroom)
library(rnaturalearth)
library(viridis)


### plan -----------------------------------------------------------------------

# per file
# apply thresholds (NA if beyond)
# then new vars, above120, above110, above100, below100
# if pred for each location meets any of these, then assign 1 in the new var
# group by RCP, the new vars across GCMs (should then get agreement)
# can then use this to assign pathway classification - rasterise and plot this
# ONLY FOR 2050


### sweden outline -------------------------------------------------------------

# load country outline
worldmap <- ne_countries(scale = 'medium', type = 'map_units',
                         returnclass = 'sf')
sweden <- worldmap[worldmap$name == 'Sweden',]

# seed zones file for utm crs
sfSeedZones <- st_read(paste0(dirData,"Seed_zones_SP_Sweden/Shaper/Frözoner_tall_Sverige.shp"))
utm <- crs(sfSeedZones)

sweden <- st_transform(sweden, utm)


### read in each file, remove data > thresholds, & new threshold vars ----------

# list production prediction files per scenario
files <-  list.files(paste0(dirData, "Productionpredictions/"),pattern = "*.csv",full.names = T)
files
# remove ensemble mean and reference
files <- files[-c(9:12,25)]
# just 2050
#files <- grep("50",files,value=TRUE)

scenario_list <- c()

for (f in files){
  
  #f <- files[2]
  
  scenario <- strsplit(f, "[_]")[[1]][1]
  scenario <- strsplit(scenario, "[/]")[[1]][8]
  GCM <- substr(scenario,1,6)
  period <- ifelse(grepl("50",scenario),"2050","2070")
  
  print(paste0("Processing for GCM: ", GCM, " | For period: ", period))
  
  scenario_list[[length(scenario_list) + 1]] <- scenario
  
  print("Read in data and apply thresholds")
  dfP <- vroom(f)
  
  # apply predictability limits (latitudinal transfer, and GDD5)
  # lat transfer
  dfP$PrProdidxSOh60[which(dfP$CenterLat > 65 | dfP$CenterLat < 55)] <- NA
  dfP$PrProdidxSOh62[which(dfP$CenterLat > 67 | dfP$CenterLat < 57)] <- NA
  dfP$PrProdidxSOh64[which(dfP$CenterLat > 69 | dfP$CenterLat < 59)] <- NA
  dfP$PrProdidxSOh66[which(dfP$CenterLat > 71 | dfP$CenterLat < 61)] <- NA
  dfP$PrProdidxSOhs60[which(dfP$CenterLat > 65 | dfP$CenterLat < 55)] <- NA
  dfP$PrProdidxSOhs62[which(dfP$CenterLat > 67 | dfP$CenterLat < 57)] <- NA
  dfP$PrProdidxSOhs64[which(dfP$CenterLat > 69 | dfP$CenterLat < 59)] <- NA
  dfP$PrProdidxSOhs66[which(dfP$CenterLat > 71 | dfP$CenterLat < 61)] <- NA
  
  # and GDD5
  dfP$PrProdidxSOh60[which(dfP$GDD5Future < 527| dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOh62[which(dfP$GDD5Future < 527| dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOh64[which(dfP$GDD5Future < 527| dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOh66[which(dfP$GDD5Future < 527| dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOhs60[which(dfP$GDD5Future < 527 | dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOhs62[which(dfP$GDD5Future < 527 | dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOhs64[which(dfP$GDD5Future < 527 | dfP$GDD5Future > 1349)] <- NA
  dfP$PrProdidxSOhs66[which(dfP$GDD5Future < 527 | dfP$GDD5Future > 1349)] <- NA
  
  # for survival, threshold for 2050 should use baseline period survival
  # if (period == 2050){
  #   dfRef <- vroom(paste0(dirData, "Productionpredictions/Refclimate_SO1.5g_predictions.csv"))
  #   print("Read in reference survival")
  #   dfP$survivalSOh60 <- dfRef$PrSurvSOh60
  #   dfP$survivalSOh62 <- dfRef$PrSurvSOh62
  #   dfP$survivalSOh64 <- dfRef$PrSurvSOh64
  #   dfP$survivalSOh66 <- dfRef$PrSurvSOh66
  #   dfP$survivalSOhs60 <- dfRef$PrSurvSOhs60
  #   dfP$survivalSOhs62 <- dfRef$PrSurvSOhs62
  #   dfP$survivalSOhs64 <- dfRef$PrSurvSOhs64
  #   dfP$survivalSOhs66 <- dfRef$PrSurvSOhs66
  # } else if (period == 2070){
  #   print("Read 2050 survival")
  #   df2050 <- vroom(paste0(dirData, "Productionpredictions/",GCM,"50_SO1.5g_predictions.csv"))
  #   dfP$survivalSOh60 <- df2050$PrSurvSOh60
  #   dfP$survivalSOh62 <- df2050$PrSurvSOh62
  #   dfP$survivalSOh64 <- df2050$PrSurvSOh64
  #   dfP$survivalSOh66 <- df2050$PrSurvSOh66
  #   dfP$survivalSOhs60 <- df2050$PrSurvSOhs60
  #   dfP$survivalSOhs62 <- df2050$PrSurvSOhs62
  #   dfP$survivalSOhs64 <- df2050$PrSurvSOhs64
  #   dfP$survivalSOhs66 <- df2050$PrSurvSOhs66
  # }
  
  print("Calculate agreement between GCMs")
  # new var - pathway
  dfP <- dfP[,c("GridID","CenterLat","CenterLong",
                "PrProdidxSOh60","PrProdidxSOh62","PrProdidxSOh64","PrProdidxSOh66",
                "PrProdidxSOhs60","PrProdidxSOhs62","PrProdidxSOhs64","PrProdidxSOhs66",
                "PrSurvSOh60","PrSurvSOh62","PrSurvSOh64","PrSurvSOh66",
                "PrSurvSOhs60","PrSurvSOhs62","PrSurvSOhs64", "PrSurvSOhs66")] %>% 
    mutate(SOh60_120 = ifelse(PrProdidxSOh60 >= 1.2 & PrSurvSOh60 >= 0.5, 1, NA),
           SOh60_110 = ifelse(PrProdidxSOh60 >= 1.1 & PrSurvSOh60 >= 0.5, 1, NA),
           SOh60_100 = ifelse(PrProdidxSOh60 >= 1.0 & PrSurvSOh60 >= 0.5, 1, NA),
           SOh60_expIP = ifelse(PrProdidxSOh60 < 1, 1, NA),
           SOh60_expLS = ifelse(PrSurvSOh60 <0.5, 1, NA),
           SOh60_lim = ifelse(is.na(PrProdidxSOh60),1,NA),
           #
           SOh62_120 = ifelse(PrProdidxSOh62 >= 1.2 & PrSurvSOh62 >= 0.5, 1, NA),
           SOh62_110 = ifelse(PrProdidxSOh62 >= 1.1 & PrSurvSOh62 >= 0.5, 1, NA),
           SOh62_100 = ifelse(PrProdidxSOh62 >= 1.0 & PrSurvSOh62 >= 0.5, 1, NA),
           SOh62_expIP = ifelse(PrProdidxSOh62 < 1, 1, NA),
           SOh62_expLS = ifelse(PrSurvSOh62 <0.5, 1, NA),
           SOh62_lim = ifelse(is.na(PrProdidxSOh62),1,NA),
           #
           SOh64_120 = ifelse(PrProdidxSOh64 >= 1.2 & PrSurvSOh64 >= 0.5, 1, NA),
           SOh64_110 = ifelse(PrProdidxSOh64 >= 1.1 & PrSurvSOh64 >= 0.5, 1, NA),
           SOh64_100 = ifelse(PrProdidxSOh64 >= 1.0 & PrSurvSOh64 >= 0.5, 1, NA),
           SOh64_expIP = ifelse(PrProdidxSOh64 < 1, 1, NA),
           SOh64_expLS = ifelse(PrSurvSOh64 <0.5, 1, NA),
           SOh64_lim = ifelse(is.na(PrProdidxSOh64),1,NA),
           #
           SOh66_120 = ifelse(PrProdidxSOh66 >= 1.2 & PrSurvSOh66 >= 0.5, 1, NA),
           SOh66_110 = ifelse(PrProdidxSOh66 >= 1.1 & PrSurvSOh66, 1, NA),
           SOh66_100 = ifelse(PrProdidxSOh66 >= 1.0 & PrSurvSOh66, 1, NA),
           SOh66_expIP = ifelse(PrProdidxSOh66 < 1, 1, NA),
           SOh66_expLS = ifelse(PrSurvSOh66 <0.5, 1, NA),
           SOh66_lim = ifelse(is.na(PrProdidxSOh66),1,NA),
           #
           SOhs60_120 = ifelse(PrProdidxSOhs60 >= 1.2 & PrSurvSOhs60 >= 0.5, 1, NA),
           SOhs60_110 = ifelse(PrProdidxSOhs60 >= 1.1 & PrSurvSOhs60 >= 0.5, 1, NA),
           SOhs60_100 = ifelse(PrProdidxSOhs60 >= 1.0 & PrSurvSOhs60 >= 0.5, 1, NA),
           SOhs60_expIP = ifelse(PrProdidxSOhs60 < 1, 1, NA),
           SOhs60_expLS = ifelse(PrSurvSOhs60 <0.5, 1, NA),
           SOhs60_lim = ifelse(is.na(PrProdidxSOhs60),1,NA),
           #
           SOhs62_120 = ifelse(PrProdidxSOhs62 >= 1.2 & PrSurvSOhs62 >= 0.5, 1, NA),
           SOhs62_110 = ifelse(PrProdidxSOhs62 >= 1.1 & PrSurvSOhs62 >= 0.5, 1, NA),
           SOhs62_100 = ifelse(PrProdidxSOhs62 >= 1.0 & PrSurvSOhs62 >= 0.5, 1, NA),
           SOhs62_expIP = ifelse(PrProdidxSOhs62 < 1, 1, NA),
           SOhs62_expLS = ifelse(PrSurvSOhs62 <0.5, 1, NA),
           SOhs62_lim = ifelse(is.na(PrProdidxSOhs62),1,NA),
           #
           SOhs64_120 = ifelse(PrProdidxSOhs64 >= 1.2 & PrSurvSOhs64 >= 0.5, 1, NA),
           SOhs64_110 = ifelse(PrProdidxSOhs64 >= 1.1 & PrSurvSOhs64 >= 0.5, 1, NA),
           SOhs64_100 = ifelse(PrProdidxSOhs64 >= 1.0 & PrSurvSOhs64 >= 0.5, 1, NA),
           SOhs64_expIP = ifelse(PrProdidxSOhs64 < 1, 1, NA),
           SOhs64_expLS = ifelse(PrSurvSOhs64 <0.5, 1, NA),
           SOhs64_lim = ifelse(is.na(PrProdidxSOhs64),1,NA),
           #
           SOhs66_120 = ifelse(PrProdidxSOhs66 >= 1.2 & PrSurvSOhs66 >= 0.5, 1, NA),
           SOhs66_110 = ifelse(PrProdidxSOhs66 >= 1.1 & PrSurvSOhs66, 1, NA),
           SOhs66_100 = ifelse(PrProdidxSOhs66 >= 1.0 & PrSurvSOhs66, 1, NA),
           SOhs66_expIP = ifelse(PrProdidxSOhs66 < 1, 1, NA),
           SOhs66_expLS = ifelse(PrSurvSOhs66 <0.5, 1, NA),
           SOhs66_lim = ifelse(is.na(PrProdidxSOhs66),1,NA))
  
  dfP <- dfP[,c(1:3,20:67)]
  
  dfP$scenario <- scenario
  
  dfP <- dfP %>% pivot_longer(cols = 4:51,
                       names_to = "threshold",
                       values_to = paste0(scenario,"_ag"))
  
  vroom_write(dfP, path = paste0(dirOut,"SO_choice_per_pixel_",scenario,".csv"), append=FALSE)
  
  }

# check survival implemented differently for 2050 and 2070

check50 <- vroom(paste0(dirOut,"SO_choice_per_pixel_no85in50.csv"))
check70 <- vroom(paste0(dirOut,"SO_choice_per_pixel_no85in70.csv"))

summary(check50);summary(check70)

### list new files & merge -----------------------------------------------------  

files2 <-  list.files(dirOut,pattern = "*.csv",full.names = T)
files2 <- grep("SO_choice",files2, value=TRUE)

lstRCP <- c("45in50","85in50","45in70","85in70")
#lstRCP <- c("85in50","45in70","85in70")

for (rcp in lstRCP){
  
  #rcp <- lstRCP[2]
  files3 <- grep(rcp,files2, value=TRUE)
  
  rcp.name <- ifelse(grepl("45",rcp),"RCP4.5","RCP8.5")
  period <- ifelse(grepl("50",rcp), "2050", "2070")
  
  for(f in files3){
    
    #f <- files2[1]
    scenario <- strsplit(f, "[_]")[[1]][5]
    scenario <- strsplit(scenario, "[.]")[[1]][1]
    assign(scenario, vroom(f))
    
  }
  
  #head(bc45in50)
  if (rcp.name == "RCP4.5" & period == "2050"){
    df <- cbind(bc45in50[,c(1,2,3,4,5,6)],he45in50$he45in50_ag, mg45in50$mg45in50_ag, mi45in50$mi45in50_ag, no45in50$no45in50_ag)
    colnames(df)[7:10] <- c("he45in50_ag","mg45in50_ag","mi45in50_ag","no45in50_ag")
  }else if (rcp.name == "RCP8.5" & period == "2050"){
    df <- cbind(bc85in50[,c(1,2,3,4,5,6)],he85in50$he85in50_ag, mg85in50$mg85in50_ag, mi85in50$mi85in50_ag, no85in50$no85in50_ag)
    colnames(df)[7:10] <- c("he85in50_ag","mg85in50_ag","mi85in50_ag","no85in50_ag")
  }else if (rcp.name == "RCP4.5" & period == "2070"){
    df <- cbind(bc45in70[,c(1,2,3,4,5,6)],he45in70$he45in70_ag, mg45in70$mg45in70_ag, mi45in70$mi45in70_ag, no45in70$no45in70_ag)
    colnames(df)[7:10] <- c("he45in70_ag","mg45in70_ag","mi45in70_ag","no45in70_ag")
  }else if (rcp.name == "RCP8.5" & period == "2070"){
    df <- cbind(bc85in70[,c(1,2,3,4,5,6)],he85in70$he85in70_ag, mg85in70$mg85in70_ag, mi85in70$mi85in70_ag, no85in70$no85in70_ag)
    colnames(df)[7:10] <- c("he85in70_ag","mg85in70_ag","mi85in70_ag","no85in70_ag")
  }
  
  head(df)
  rm(list=c("bc45in50","he45in50","mg45in50","mi45in50","no45in50"))
  rm(list=c("bc85in50","he85in50","mg85in50","mi85in50","no85in50"))
  rm(list=c("bc45in70","he45in70","mg45in70","mi45in70","no45in70"))
  rm(list=c("bc85in70","he85in70","mg85in70","mi85in70","no85in70"))
  
  df <- df %>% mutate(tot = rowSums(.[6:10], na.rm = TRUE))
  
  df <- df %>% pivot_wider(id_cols = c("GridID","CenterLat","CenterLong"),
                           names_from = threshold,
                           values_from = tot)
  head(df)
  
  dfPathway <- df %>% mutate(SOh60_pathway = ifelse(SOh60_lim >=3, 1,
                                                    ifelse(SOh60_expLS >=3, 3,
                                                           ifelse(SOh60_expIP >=3, 2,
                                                                  ifelse(SOh60_120 >=3, 6,
                                                                         ifelse(SOh60_110 >=3, 5,
                                                                                ifelse(SOh60_100 >= 3, 4,NA)))))),
                             SOh62_pathway = ifelse(SOh62_lim >=3, 1,
                                                    ifelse(SOh62_expLS >=3, 3,
                                                           ifelse(SOh62_expIP >=3, 2,
                                                                  ifelse(SOh62_120 >=3, 6,
                                                                         ifelse(SOh62_110 >=3, 5,
                                                                                ifelse(SOh62_100 >= 3, 4,NA)))))),
                             SOh64_pathway = ifelse(SOh64_lim >=3, 1,
                                                    ifelse(SOh64_expLS >=3, 3,
                                                           ifelse(SOh64_expIP >=3, 2,
                                                                  ifelse(SOh64_120 >=3, 6,
                                                                         ifelse(SOh64_110 >=3, 5,
                                                                                ifelse(SOh64_100 >= 3, 4,NA)))))),
                             SOh66_pathway = ifelse(SOh66_lim >=3, 1,
                                                    ifelse(SOh66_expLS >=3, 3,
                                                           ifelse(SOh66_expIP >=3, 2,
                                                                  ifelse(SOh66_120 >=3, 6,
                                                                         ifelse(SOh66_110 >=3, 5,
                                                                                ifelse(SOh66_100 >= 3, 4,NA)))))),
                             SOhs60_pathway = ifelse(SOhs60_lim >=3, 1,
                                                     ifelse(SOhs60_expLS >=3, 3,
                                                            ifelse(SOhs60_expIP >=3, 2,
                                                                   ifelse(SOhs60_120 >=3, 6,
                                                                          ifelse(SOhs60_110 >=3, 5,
                                                                                 ifelse(SOhs60_100 >= 3, 4,NA)))))),
                             SOhs62_pathway = ifelse(SOhs62_lim >=3, 1,
                                                     ifelse(SOhs62_expLS >=3, 3,
                                                            ifelse(SOhs62_expIP >=3, 2,
                                                                   ifelse(SOhs62_120 >=3, 6,
                                                                          ifelse(SOhs62_110 >=3, 5,
                                                                                 ifelse(SOhs62_100 >= 3, 4,NA)))))),
                             SOhs64_pathway = ifelse(SOhs64_lim >=3, 1,
                                                     ifelse(SOhs64_expLS >=3, 3,
                                                            ifelse(SOhs64_expIP >=3, 2,
                                                                   ifelse(SOhs64_120 >=3, 6,
                                                                          ifelse(SOhs64_110 >=3, 5,
                                                                                 ifelse(SOhs64_100 >= 3, 4,NA)))))),
                             SOhs66_pathway = ifelse(SOhs66_lim >=3, 1,
                                                     ifelse(SOhs66_expLS >=3, 3,
                                                            ifelse(SOhs66_expIP >=3, 2,
                                                                   ifelse(SOhs66_120 >=3, 6,
                                                                          ifelse(SOhs66_110 >=3, 5,
                                                                                 ifelse(SOhs66_100 >= 3, 4,NA)))))))#,
                             # NA_check = ifelse(SOhs66_lim < 3 & 
                             #                     SOhs66_expIP < 3 & 
                             #                     SOhs66_expLS < 3 &
                             #                     SOhs66_120 < 3 &
                             #                     SOhs66_110 < 3 &
                             #                     SOhs66_100 < 3, 9999, NA))
  
  colnames(dfPathway)
  rm(df)
  
  dfPathway <- dfPathway[,c("GridID","CenterLat","CenterLong",
                            "SOh60_pathway","SOh62_pathway","SOh64_pathway","SOh66_pathway",
                            "SOhs60_pathway","SOhs62_pathway","SOhs64_pathway","SOhs66_pathway")]#,"NA_check")]
  
  # head(dfPathway)
  # check <- dfPathway %>% 
  #   dplyr::select(SOhs66_lim,SOhs66_expIP,SOhs66_expLS,SOhs66_120,SOhs66_110,SOhs66_100,SOhs66_pathway,NA_check) %>%  
  #   dplyr::filter(NA_check == 9999)
  
  coordinates(dfPathway) <- ~ CenterLong + CenterLat
  
  # define lat long crs
  proj4string(dfPathway) <- CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs") 
  
  # transform points to utm
  spPathway <- spTransform(dfPathway, CRSobj = utm)
  
  rstUTM <- raster(crs = crs(spPathway), resolution = c(1100,1100), ext = extent(spPathway))
  
  for (var in names(spPathway)[c(2:9)]){ 
    
    #var <- names(spPathway)[2]
    
    rst <- rasterize(spPathway, rstUTM, spPathway[[var]], fun=max, na.rm=TRUE) 
    
    writeRaster(rst, paste0(dirOut,"pathway_rst/",var,"_",rcp.name,"_",period,"_GCMagreement.tif"), overwrite=TRUE)
    
    print(paste0("Written raster for: ", var))
    
  }
  
  
}


### convert to df and assign pathway based on code -----------------------------

lstRsts <- list.files(paste0(dirOut,"pathway_rst"),full.names = T)

#lstRCP2 <- c("RCP4.5_2050","RCP8.5_2050","RCP4.5_2070","RCP8.5_2070")
lstYrs <- c("2050","2070")
lstSOs <- c("SOh60","SOh62","SOh64","SOh66",
            "SOhs60","SOhs62","SOhs64","SOhs66")

for (yr in lstYrs){
#for (rcp in lstRCP2){
  
  #rcp <- lstRCP2[3]
  #RCP_rsts <- grep(rcp,lstRsts,value=TRUE)
  #yr <- lstYrs[1]
  yrRSTs <- grep(yr, lstRsts, value = TRUE)
  
  #for (i in RCP_rsts){
  for (SO in lstSOs){  
    
    #i <- RCP_rsts[4]
    #SO <- lstSOs[1]
    
    soRST <- grep(SO, yrRSTs, value = TRUE)
    
    #dfSO <- tibble()
    
    for (i in soRST){
      
      #i <- soRST[2]
      
      seed.orchard <- stringr::str_split(i,"/") %>% map_chr(.,4)
      period <- stringr::str_split(seed.orchard,"_") %>% map_chr(.,4)
      rcp.name <- stringr::str_split(seed.orchard,"_") %>% map_chr(.,3)
      seed.orchard <- stringr::str_split(seed.orchard,"_") %>% map_chr(.,1)
      
      SO.name <- ifelse(grepl("SOh60", seed.orchard), 'SO 1.5g 60°N', 
                        ifelse(grepl("SOhs60", seed.orchard), 'SO 1.5gS 60°N',
                               ifelse(grepl("SOh62", seed.orchard), 'SO 1.5g 62°N',
                                      ifelse(grepl("SOhs62", seed.orchard), 'SO 1.5gS 62°N',
                                             ifelse(grepl("SOh64", seed.orchard), 'SO 1.5g 64°N',
                                                    ifelse(grepl("SOhs64", seed.orchard), 'SO 1.5gS 64°N',
                                                           ifelse(grepl("SOh66", seed.orchard), 'SO 1.5g 66°N',
                                                                  ifelse(grepl("SOhs66", seed.orchard), 'SO 1.5gS 66°N', NA))))))))
      

      rst <- raster(i)
      
      # Convert raster to dataframe
      dfPathway <- as.data.frame(rst, xy=T)
      colnames(dfPathway) <- c("x","y","code")
      # dfPathway$pathway <- NA
      # dfPathway$pathway[which(dfPathway$code == 1)] <- "Beyond model limits"
      # dfPathway$pathway[which(dfPathway$code == 2)] <- "Expiry (below local)"
      # dfPathway$pathway[which(dfPathway$code == 3)] <- "Expiry (low survival)"
      # dfPathway$pathway[which(dfPathway$code == 4)] <- "Good performance (above local)"
      # dfPathway$pathway[which(dfPathway$code == 5)] <- "Very good performance (above 110)"
      # dfPathway$pathway[which(dfPathway$code == 6)] <- "Excellent performance (above 120)"
      
      assign(rcp.name, dfPathway$code)
      
    }
    
    dfMaster <- dfPathway[,1:2] %>% 
      mutate(RCP4.5 = RCP4.5,
             RCP8.5 = RCP8.5)
    head(dfMaster)
    summary(dfMaster)
    
    dfMaster <- dfMaster %>% mutate(recommendation = ifelse(RCP4.5 == RCP8.5, RCP8.5,
                                                            ifelse(RCP4.5 < RCP8.5, RCP4.5, RCP8.5)))
    
    #filter(dfMaster, RCP4.5 == 5 & RCP8.5 == 6)
    
    dfMaster <- dfMaster %>% pivot_longer(cols = RCP4.5:recommendation, names_to = "scenario", values_to = "code")
    
    dfMaster$pathway <- NA
    dfMaster$pathway[which(dfMaster$code == 1)] <- "Beyond model limits"
    dfMaster$pathway[which(dfMaster$code == 2)] <- "Expiry (below local)"
    dfMaster$pathway[which(dfMaster$code == 3)] <- "Expiry (low survival)"
    dfMaster$pathway[which(dfMaster$code == 4)] <- "Good performance (above local)"
    dfMaster$pathway[which(dfMaster$code == 5)] <- "Very good performance (above 110)"
    dfMaster$pathway[which(dfMaster$code == 6)] <- "Excellent performance (above 120)"
    
    dfMaster$seed.orchard <- SO.name
    
    dfMaster$pathway <- factor(dfMaster$pathway, ordered=T, levels=c("Excellent performance (above 120)",
                                                                     "Very good performance (above 110)",
                                                                     "Good performance (above local)",
                                                                     "Expiry (below local)",
                                                                     "Expiry (low survival)",
                                                                     "Beyond model limits"))
    
    # if (seed.orchard == "SOh60" | seed.orchard == "SOhs60"){
    #   lat.lim <- c(6600000,7300000)
    # } else if (seed.orchard == "SOh62" | seed.orchard == "SOhs62"){
    #   lat.lim <- c(6600000,7500000)
    # } else if (seed.orchard == "SOh64" | seed.orchard == "SOhs64"){
    #   lat.lim <- c(6650000,7650000)
    # } else if (seed.orchard == "SOh66" | seed.orchard == "SOhs66"){
    #   lat.lim <- c(6750000,7650000)
    # }
    
    dfMaster$scenario[which(dfMaster$scenario=="recommendation")] <- "Compound performance"
    
    
    (p1 <- dfMaster %>% filter(scenario != "Compound performance") %>% 
        ggplot()+#data = dfMaster) +
        geom_sf(data = sweden, fill=NA, col=NA)+
        geom_tile(data = dfMaster %>% filter(scenario != "Compound performance"), mapping = aes(x = x, y = y, fill = pathway), size = 1) +
        facet_grid(seed.orchard~scenario)+
        scale_fill_viridis(discrete=T, direction = -1, drop=FALSE, #na.value = "grey60",
                            labels = c("Excellent performance (above 120)",
                                       "Very good performance (above 110)",
                                       "Good performance (above local)",
                                       "Expiry (below local)",
                                       "Expiry (low survival)",
                                       "Beyond model limits",
                                       "No GCM majority")
                           )+
        #labs(fill="Performance")+
        theme_bw()+
        #ggtitle(paste0(SO.name, " | ", rcp.name))+
        #xlab("Longitude")+ylab("Latitude")+
        #coord_sf(ylim=lat.lim, xlim=c(269731,918731))+
        theme(plot.title = element_text(face="bold",size=24),
              axis.title = element_blank(),#element_text(size=18,face="bold"),
              axis.text = element_text(size = 16),
              strip.text = element_text(size = 14, face = "bold"),
              #axis.ticks = element_blank(),
              #legend.title = element_text(size = 16, face = "bold", vjust = 3),
              #legend.text = element_text(size = 14))+
              legend.position = "none"))
    #guides(fill = guide_legend(override.aes = list(color = "grey40"))))
    
    ggsave(p1, file=paste0(dirFigs,"Pathway_per_pixel_",seed.orchard,"_",period,".png"), width=8, height=6, dpi=300)
    
    dfMaster$scenario <- factor(dfMaster$scenario, ordered=TRUE, levels = c("RCP4.5","RCP8.5","Compound performance"))
    
    (p2 <- dfMaster %>% 
        ggplot()+
        geom_sf(data = sweden, fill=NA, col=NA)+
        geom_tile(data = dfMaster , mapping = aes(x = x, y = y, fill = pathway), size = 1) +
        facet_grid(seed.orchard~scenario)+
        scale_fill_viridis(discrete=T, direction = -1, drop=FALSE, #na.value = "grey60",
                           labels = c("Excellent performance (above 120)",
                                      "Very good performance (above 110)",
                                      "Good performance (above local)",
                                      "Expiry (below local)",
                                      "Expiry (low survival)",
                                      "Beyond model limits",
                                      "No GCM majority")
        )+
        #labs(fill="Performance")+
        theme_bw()+
        #ggtitle(paste0(SO.name, " | ", rcp.name))+
        #xlab("Longitude")+ylab("Latitude")+
        #coord_sf(ylim=lat.lim, xlim=c(269731,918731))+
        theme(plot.title = element_text(face="bold",size=24),
              axis.title = element_blank(),#element_text(size=18,face="bold"),
              axis.text = element_text(size = 16),
              strip.text = element_text(size = 12, face = "bold"),
              #axis.ticks = element_blank(),
              #legend.title = element_text(size = 16, face = "bold", vjust = 3),
              #legend.text = element_text(size = 14))+
              legend.position = "none"))
    #guides(fill = guide_legend(override.aes = list(color = "grey40"))))
    
    ggsave(p2, file=paste0(dirFigs,"Pathway_per_pixel_",seed.orchard,"_",period,"_compound.png"), width=14, height=6, dpi=300)
    
  }
  
}

# get legend
# in loop, i've commented out the bits that plot the legend, but i ran once with the legend included & then extracted & saved
#library(ggpubr)

# Extract the legend. Returns a gtable
#legend <- get_legend(p1)

# Convert to a ggplot and save
#legend <- as_ggplot(legend)
#plot(legend)
#ggsave(legend, file=paste0(dirFigs,"Pixel_Pathway_legend.png"),width=4, height=6, dpi=300)


### arrange in single figure per RCP? ------------------------------------------

library(grid)
library(png)
library(gridExtra)

lstPlots <- list.files(paste0(dirFigs), full.names = T)
lstPlots <- grep("ixel", lstPlots, value=TRUE)

lst1 <- grep("Oh6", lstPlots, value=TRUE)
lst1 <- grep("2050.png", lst1, value=TRUE)
lst1 <- lst1[c(10,7,4,1)]
lst1 <- append(lst1, "C:/Users/vanessa.burton.sb/Documents/FFMPs/figures/Pixel_Pathway_legend.png" )

r1 <- lapply(lst1, png::readPNG)
g1 <- lapply(r1, grid::rasterGrob)

ggsave(gridExtra::grid.arrange(grobs=g1, 
                               ncol=2,
                               layout_matrix = cbind(c(1,2,3,4),
                                                     #c(2,4,6,8),
                                                     c(5,5,5,5))), 
       file=paste0(dirFigs,"Seed_orchard_height_gain_pathways_2050_2.png"),
       width=24, 
       height=40, 
       dpi=300)

lst2 <- grep("Ohs6", lstPlots, value=TRUE)
lst2 <- grep("2050.png", lst2, value=TRUE)
lst2 <- lst2[c(10,7,4,1)]
lst2 <- append(lst2, "C:/Users/vanessa.burton.sb/Documents/FFMPs/figures/Pixel_Pathway_legend.png" )

r2 <- lapply(lst2, png::readPNG)
g2 <- lapply(r2, grid::rasterGrob)

ggsave(gridExtra::grid.arrange(grobs=g2, 
                               ncol=2,
                               layout_matrix = cbind(c(1,2,3,4),
                                                     #c(2,4,6,8),
                                                     c(5,5,5,5))), 
       file=paste0(dirFigs,"Seed_orchard_height_&_survival_gain_pathways_2050_2.png"),
       width=24, 
       height=40, 
       dpi=300)


lst3 <- grep("Oh6", lstPlots, value=TRUE)
lst3 <- grep("2070.png", lst3, value=TRUE)
lst3 <- lst3[c(10,7,4,1)]
lst3 <- append(lst3, "C:/Users/vanessa.burton.sb/Documents/FFMPs/figures/Pixel_Pathway_legend.png" )

r3 <- lapply(lst3, png::readPNG)
g3 <- lapply(r3, grid::rasterGrob)

ggsave(gridExtra::grid.arrange(grobs=g3, 
                               ncol=2,
                               layout_matrix = cbind(c(1,2,3,4),
                                                     #c(2,4,6,8),
                                                     c(5,5,5,5))), 
       file=paste0(dirFigs,"Seed_orchard_height_gain_pathways_2070_2.png"),
       width=24, 
       height=40, 
       dpi=300)


lst4 <- grep("Ohs6", lstPlots, value=TRUE)
lst4 <- grep("2070.png", lst4, value=TRUE)
lst4 <- lst4[c(10,7,4,1)]
lst4 <- append(lst4, "C:/Users/vanessa.burton.sb/Documents/FFMPs/figures/Pixel_Pathway_legend.png" )

r4 <- lapply(lst4, png::readPNG)
g4 <- lapply(r4, grid::rasterGrob)

ggsave(gridExtra::grid.arrange(grobs=g4, 
                               ncol=2,
                               layout_matrix = cbind(c(1,2,3,4),
                                                     #c(2,4,6,8),
                                                     c(5,5,5,5))), 
       file=paste0(dirFigs,"Seed_orchard_height_&_survival_gain_pathways_2070_2.png"),
       width=24, 
       height=40, 
       dpi=300)
