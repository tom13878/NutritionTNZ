#######################################
########## TANZANIA 2012-13 ###########
#######################################

# Tom
# dataPath <- "C:/Users/Tomas/Documents/LEI/data/TZA/2012/Data"

# LEI Path
# dataPath <- "W:/LEI/Internationaal Beleid  (IB)/Projecten/2285000066 Africa Maize Yield Gap/SurveyData/TZA/2012/Data"


# Vincent at home
dataPath <- "D:/Models/CIMMYT/SurveyData/TNZ/2012/Data"

library(haven)
library(dplyr)
library(reshape2)

options(scipen=999)

#######################################
############## LOCATION ###############
#######################################

# file containing the zone, region and district

location <- read_dta(file.path(dataPath, "HH_SEC_A.dta")) %>%
  select(y3_hhid, REGCODE = hh_a01_1 , DISCODE = hh_a02_1, rural = y3_rural)
location$rural <- as.integer(location$rural)
location$REGCODE <- as.integer(location$REGCODE)

# match up with the names from the survey (prepared in a seperate file)

ZONEREGDIS <- read.csv(file.path(paste0(dataPath,"/../../.."), "Other/Spatial/TZA/ZONEREGDIS.csv"))

# join with household identifications

location <- left_join(location, ZONEREGDIS)

rm(ZONEREGDIS)

#######################################
########### SOCIO/ECONOMIC ############
#######################################

HH12 <- read_dta(file.path(dataPath, "HH_SEC_B.dta")) %>%
  select(y3_hhid, indidy3, status=hh_b05, sex=hh_b02,
         yob=hh_b03_1, age=hh_b04, years=hh_b25)

HH12$years <- as.numeric(HH12$years)
HH12$years <- ifelse(HH12$years %in% 99, HH12$age, HH12$years)
HH12$status <- as_factor(HH12$status)
HH12$sex <- toupper(as_factor(HH12$sex))
HH12$yob <- as.integer(HH12$yob)

# make a new variable cage (cut age) which splits
# individuals according to their age group with
# breaks at 15, 55 and the max age

HH12$cage <- cut(HH12$age, breaks = c(0, 15, 55, max(HH12$age, na.rm=TRUE)),
                 labels=c("0-15", "16-55", "56+"), include.lowest = TRUE, right = TRUE)

# -------------------------------------
# education of household members and sum
# of education of all household members
# between the ages of 15 and 55

ed <- read_dta(file.path(dataPath, "HH_SEC_C.dta")) %>%
  select(y3_hhid, indidy3, ed_any=hh_c03, start=hh_c04, end=hh_c08)

ed$ed_any <- as_factor(ed$ed_any) # ever went to school
ed$end <- as.integer(as.character(ed$end))
ed$end <- ifelse(ed$end %in% 9999, NA, ed$end)

# join with HH10 dataframe
HH12 <- left_join(HH12, ed)
HH12$education <- HH12$end - (HH12$yob + HH12$start)
HH12$education <- ifelse(HH12$ed_any %in% "NO", 0, HH12$education)
HH12 <- select(HH12, -start, -end, -yob)

# remove negative years of education (56 obs)
HH12$education <- ifelse(HH12$education < 0, NA, HH12$education)

# summarise the data: get sum of education
# of household members 15-55 and number of
# household members 15:55
HH12_x <- group_by(HH12, y3_hhid) %>%
  summarise(education1555=sum(education[cage %in% "16-55"], na.rm=T),
            N1555=sum(cage %in% "16-55"))
HH12 <- left_join(HH12, HH12_x); rm(HH12_x)

# -------------------------------------
# death in the family
# -------------------------------------

death <- read_dta(file.path(dataPath, "HH_SEC_S.dta")) 
death$personid <- zap_empty(death$personid)
death <- unique(transmute(death, y3_hhid, death=ifelse(!is.na(personid), 1, 0)))

# -------------------------------------
# membership to a credit group
# -------------------------------------

credit <- read_dta(file.path(dataPath, "HH_SEC_O2.dta")) 
credit$personid <- zap_empty(credit$personid)
credit <- unique(transmute(credit, y3_hhid, SACCO=ifelse(!is.na(personid), 1, 0)))

HH12 <- left_join(HH12, death) 
HH12 <- left_join(HH12, credit) 

rm(ed, credit, death)

#######################################
############### OUTPUT ################
#######################################

oput <- read_dta(file.path(dataPath, "AG_SEC_4A.dta")) %>%
  select(y3_hhid, plotnum, zaocode, one_crop=ag4a_01,
         crop_share=ag4a_02, inter_crop=ag4a_04,
         harv_area=ag4a_21, harv_area2=ag4a_22, 
         harv_area3=ag4a_23, qty=ag4a_28, valu=ag4a_29,
         hybrd=ag4a_08)

oput$crop_share <- as_factor(oput$crop_share)
oput$zaocode <- as.integer(oput$zaocode)
oput$harv_area2 <- as_factor(oput$harv_area2)
oput$harv_area3 <- toupper(as_factor(oput$harv_area3))

# harv area is in acres -> change to hectares
oput$harv_area <- oput$harv_area*0.404686

# -------------------------------------
# create dummy variables for crop groups
# (fruit, cash crops (permanent),
# Cereals/Tubers/Roots, cash crops (not permanent),
# vegetables, legumes)
# -------------------------------------

fruit <- c(70:74, 76:85, 97:99, 67, 38, 39)
cashCropsPerm <- c(53:61, 63:66, 18, 34, 21, 75, 44:46) # permanent cash crops
CTR <- c(11:17, 22:27) # Cereals, Tubers, Roots
cashCropNPerm <- c(50, 51, 53, 62, 19) # non permanent cash crops
vegetables <- c(86:96, 100, 101)
legumes <- c(31, 32, 33, 35, 36, 37, 41, 42, 43, 47, 48)

oput_x <- group_by(oput, y3_hhid, plotnum) %>%
  summarise(crop_count=length(unique(zaocode[!is.na(zaocode)])),
            fruit=ifelse(any(zaocode %in% fruit), 1, 0),
            cashCropsPerm=ifelse(any(zaocode %in% cashCropsPerm), 1, 0),
            CTR=ifelse(any(zaocode %in% CTR), 1, 0),
            cashCropNPerm=ifelse(any(zaocode %in% cashCropNPerm), 1, 0),
            vegetables=ifelse(any(zaocode %in% vegetables), 1, 0),
            legume=ifelse(any(zaocode %in% legumes), 1, 0),
            maize=ifelse(any(zaocode %in% 11), 1, 0), # maize has crop code 11
            wheat=ifelse(any(zaocode %in% 16), 1, 0)) # wheat has crop code 16

oput <- left_join(oput, oput_x); rm(oput_x)

# remove farmers who responded they produced
# zero quantity ofcrop, or did not respond (NA)

oput <- oput[!is.na(oput$qty) & !oput$qty %in% 0, ]
oput$crop_price <- oput$valu/oput$qty
oput <- select(oput, -valu)

rm(list=c("legumes", "cashCropNPerm", "cashCropsPerm",
          "CTR", "fruit", "vegetables"))

#######################################
############# CHEMICAL ################
#######################################

plot <- read_dta(file.path(dataPath, "AG_SEC_3A.dta")) %>%
  select(y3_hhid, plotnum, main_crop=ag3a_07_2,  soil=ag3a_10, slope_farmer=ag3a_17, irrig=ag3a_18, title=ag3a_28, 
                manure=ag3a_41, pest=ag3a_60, pest_q=ag3a_62_1, pest_q_unit=ag3a_62_2, fallow_year=ag3a_22, fallow=ag3a_23)

plot$main_crop <- as.integer(plot$main_crop)
plot$soil <- factor(plot$soil, levels=c(1,2,3,4), labels=c("Sandy", "Loam", "Clay", "Other"))
plot$slope_farmer <- factor(plot$slope_farmer, levels=c(1,2,3,4), labels=c("Flat bottom", "Flat top", "Slightly sloped", "Very steep"))
plot$title <- as.numeric(as_factor(plot$title))
plot$pest_q_unit <- as_factor(plot$pest_q_unit)

plot$pest_q <- ifelse(plot$pest_q_unit %in% c("LITRE", "KG"), plot$pest_q,
                      ifelse(plot$pest_q_unit %in% "MILLILITRE", plot$pest_q*0.001, NA))

# two questions on fallow - make sure they match up correctly
# fallow value of 98 means subject did not know how long plot
# was left fallow
plot$fallow_year <- ifelse(plot$fallow_year %in% 98, NA, plot$fallow_year)
plot$fallow <- ifelse(plot$fallow_year %in% 0, 0, plot$fallow )
plot$fallow <- ifelse(is.na(plot$fallow_year), NA, plot$fallow)
plot <- dplyr::select(plot, -fallow_year, -pest_q_unit)

fert1 <- read_dta(file.path(dataPath, "AG_SEC_3A.dta")) %>%
  dplyr::select(y3_hhid, plotnum, typ=ag3a_48, qty=ag3a_49, vouch=ag3a_50, valu=ag3a_51)

fert2 <- read_dta(file.path(dataPath, "AG_SEC_3A.dta")) %>%
  dplyr::select(y3_hhid, plotnum, typ=ag3a_55, qty=ag3a_56, vouch=ag3a_57, valu=ag3a_58)

fert1$typ <- as_factor(fert1$typ)
fert1$vouch <- ifelse(fert1$vouch %in% 2, 0, fert1$vouch)

fert2$typ <- as_factor(fert2$typ)
fert2$vouch <- ifelse(fert2$vouch %in% 2, 0, fert2$vouch)

levels(fert1$typ) <- levels(fert2$typ) <-
  c("DAP", "UREA", "TSP", "CAN", "SA", "generic NPK (TZA)", "MRP")

# -------------------------------------
# reorganize data so that observations
# on fertilizer type occupy a single row
# fertilizer is unit of observation
# Data on NPK composition from Sheahan et al (2014), Food Policy
# -------------------------------------

conv <- read.csv(file.path(paste0(dataPath,"/../../.."), "Other/Fertilizer/Fert_comp.csv")) %>%
  transmute(typ=Fert_type2, n=N_share/100, p=P_share/100) %>%
  filter(typ %in% levels(fert1$typ))

fert1 <- left_join(fert1, conv)
fert2 <- left_join(fert2, conv)
rm(conv)

# -------------------------------------
# organize fertilizer data for analysis

fert <- rbind(fert1, fert2)

fert <- mutate(fert,
               Vfert=valu/qty,
               Qn=qty*n,
               Qp=qty*p)

fert$Pn <- fert$Vfert/fert$n

# Compute subsidised, non-subsidised and mix fertilizer prices per plot
# As valu or N is sometimes 0, all prices that are 0 are set to NA
fertnosub   <- filter(fert, vouch==0) %>%
  group_by(y3_hhid, plotnum) %>%
  summarise(N=sum(Qn, na.rm=TRUE),
            WPnnosub=sum((Qn/N)*Pn, na.rm=TRUE)) %>%
  dplyr::select(-N) %>%
  mutate(WPnnosub = replace(WPnnosub, WPnnosub==0, NA))


fertsub   <- filter(fert, vouch==1) %>%
  group_by(y3_hhid, plotnum) %>%
  summarise(N=sum(Qn, na.rm=TRUE),
            WPnsub=sum((Qn/N)*Pn, na.rm=TRUE)) %>%
  dplyr::select(-N) %>% 
  mutate(WPnsub = replace(WPnsub, WPnsub==0, NA))

fertmix <- filter(fert, vouch %in% c(0,1)) %>%
  group_by(y3_hhid, plotnum) %>%
  summarise(N=sum(Qn, na.rm=TRUE),
            P=sum(Qp, na.rm=TRUE),
            WPn=sum((Qn/N)*Pn, na.rm=TRUE)) %>%
  mutate(WPn = replace(WPn, WPn==0, NA))

# join back with the rest of the data and set N and P to 0 for NA values
plot <- left_join(plot, fertmix) %>%
  left_join(., fertnosub) %>%
  left_join(., fertsub) %>%
  mutate(N = ifelse(is.na(N), 0, N),
         P = ifelse(is.na(P), 0, P))
rm(list=c("fert1", "fert2", "fert", "fertsub", "fertnosub", "fertmix"))

#######################################
############### LABOUR ################
#######################################

lab <- read_dta(file.path(dataPath, "AG_SEC_3A.dta")) %>%
  dplyr::select(y3_hhid, plotnum, ag3a_72_id1:ag3a_74_16 )

# calculate the total labour days for hired and family labour.
bad <- grep( "ag3a_72_id", names( lab ) )
lab <- lab[, -bad]

bad <- names( lab )[( length( lab )-15 ):length( lab )][seq( from=4, to=16, by=4 )]
lab <- lab[, -which( names( lab ) %in% bad )]; rm(bad)

lab <- transmute( lab, y3_hhid, plotnum,
                  fam_lab_days=rowSums( lab[, 3:30], na.rm=TRUE ),
                  hir_lab_days=rowSums( lab[, 32:ncol( lab )], na.rm=TRUE ) )

lab <- transmute(lab, y3_hhid, plotnum, lab=fam_lab_days + hir_lab_days)

# doesn't make sense to have 0 labour on a plot so set values to zero
lab$lab <- ifelse(lab$lab %in% 0, NA, lab$lab)

#######################################
############### ASSETS ################
#######################################

implmt <- read_dta(file.path(dataPath, "AG_SEC_11.dta")) %>%
  dplyr::select(y3_hhid, itemname, qty=ag11_01, valu=ag11_02) %>%
  filter(!qty %in% 0, !is.na(qty), !valu %in% 0, !is.na(valu)) %>%
  transmute(y3_hhid, valu=qty*valu) %>%
  group_by(y3_hhid) %>%
      summarise(value=sum(valu))

# -------------------------------------
# Livestock assets
# -------------------------------------

# classifications from wave 3 classification table
LR <- c("BULLS", "COWS", "STEERS", "HEIFERS", "MALE-CALVES", "FEMALE-CALVES")
SR <- c("GOATS", "SHEEP")
PIGS <- c("PIGS")
POULTRY <- c("CHICKENS", "DUCKS", "OTHER-POULTRY")
OTHER <- c("RABBITS", "DONKEYS", "DOGS", "OTHER")

# read in the data
lvstock <- read_dta(file.path(dataPath, "LF_SEC_02.dta")) %>%
  select(y3_hhid, animal = lvstckid, owned = lf02_01,
         indigQty = lf02_04_1, improvQty = lf02_04_2)
lvstock$owned <- ifelse(lvstock$owned %in% 1, 1, 0)
lvstock$animal <- as_factor(lvstock$animal)

# remove white space
lvstock$animal <- gsub(" ", "-", lvstock$animal)
lvstock <- filter(lvstock, !is.na(animal) )

# count the number of animals of each class a household owns
lvstock_x <- select(lvstock, y3_hhid, animal, indigQty, improvQty) %>%
  melt(id = c("y3_hhid", "animal")) %>%
  group_by(y3_hhid, animal) %>%
  mutate(class = ifelse(animal %in% LR, "LR",
                        ifelse(animal %in% SR, "SR", 
                               ifelse(animal %in% PIGS, "PIGS_",
                                      ifelse(animal %in% POULTRY, "POULTRY",
                                             ifelse(animal %in% OTHER, "OTHER_")))))) %>%
  group_by(y3_hhid, class) %>%
  summarise(n=sum(value, na.rm=TRUE)) %>%
  dcast(y3_hhid ~ class)

# count the number of each animal a household owns
lvstock_y <- select(lvstock, y3_hhid, animal, indigQty, improvQty) %>%
  melt(id = c("y3_hhid", "animal")) %>%
  group_by(y3_hhid, animal) %>%
  summarise(n=sum(value, na.rm=TRUE)) %>%
  dcast(y3_hhid ~ animal)

# join together
lvstock <- left_join(lvstock_x, lvstock_y)

rm("LR", "SR", "lvstock_x", "lvstock_y", "OTHER", "PIGS", "POULTRY")

#######################################
############### GEO ###################
#######################################

geo12 <- readRDS(file.path(dataPath, "../../../Other/Spatial/TZA/TZA_geo_2012.rds"))

#######################################
############### AREAs #################
#######################################

areas <- read.csv(file.path(dataPath, "/areas_w3.csv")) %>%
  select(y3_hhid, plotnum,
                area_farmer=area.est,
                area_gps=gps_imputed)
areas$y3_hhid <- as.character(areas$y3_hhid)
areas$plotnum <- as.character(areas$plotnum)
areas$area_gps <- ifelse(areas$area_gps %in% 0, NA, areas$area_gps)

# 2012 areas are in acres, change to hectares in line
# with the 2010 data
areas$area_gps <- areas$area_gps*0.404686 # from wikipedia
areas$area_farmer <- areas$area_farmer*0.404686

# plot ownership
own <- read_dta(file.path(dataPath, "AG_SEC_3A.dta")) %>%
  dplyr::select(y3_hhid, plotnum, own=ag3a_25)
own$own <- ifelse(own$own %in% 1 | own$own %in% 5, 1, 0)

areas <- left_join(areas, own); rm(own)

# total farm holdings
areaTotal <- group_by(areas, y3_hhid) %>%
  summarise(area_tot = sum(area_gps))

#######################################
########## TRANSPORT COSTS ############
#######################################

tc <- read_dta(file.path(dataPath, "AG_SEC_5A.dta")) %>%
  select(y3_hhid, zaocode, trans=ag5a_18, trans_dist=ag5a_19, trans_cost=ag5a_22)
tc$zaocode <- as.integer(tc$zaocode)

#######################################
############ PANEL KEY ################
#######################################

# key for joing individuals and households across years
key <- read_dta(file.path(dataPath, "NPSY3.PANEL.KEY.dta")) %>%
  select(-UPI3) %>% rename(hhid2008 = y1_hhid, hhid2010=y2_hhid)

bad <- is.na(as.numeric(key$hhid2008))
key$hhid2008[bad] <- NA

bad <- is.na(as.numeric(key$hhid2010))
key$hhid2010[bad] <- NA

key$y3_hhid <- zap_empty(key$y3_hhid)

#######################################
########### CROSS SECTION #############
#######################################

# joins at the household level (y3_hhid)

TZA2012 <- left_join(location, HH12); rm(location); rm(HH12)
TZA2012 <- left_join(TZA2012, key); rm(key)
TZA2012 <- left_join(TZA2012, implmt); rm(implmt)
TZA2012 <- left_join(TZA2012, areaTotal); rm(areaTotal)
TZA2012 <- left_join(TZA2012, lvstock); rm(lvstock)

# joins at the plot level (y3_hhid, plotnum)

TZA2012 <- left_join(TZA2012, geo12); rm(geo12)
TZA2012 <- left_join(TZA2012, plot); rm(plot)
TZA2012 <- left_join(TZA2012, oput); rm(oput)
TZA2012 <- left_join(TZA2012, tc); rm(tc)
TZA2012 <- left_join(TZA2012, lab); rm(lab)
TZA2012 <- left_join(TZA2012, areas); rm(areas)



# -------------------------------------
# For some questions respondents answered
# NA, it is not certain how these responses
# should be treated. Often we assume that
# an NA is equivalent to NO/0
# -------------------------------------

TZA2012$SACCO <- ifelse(TZA2012$SACCO %in% 1, 1, 0) # assume NA -> no SACCO
TZA2012$death <- ifelse(TZA2012$death %in% 1, 1, 0) # assume NA -> no death
TZA2012$one_crop <- ifelse(TZA2012$one_crop %in% 1, 1, 0) # assume NA -> no crops 
TZA2012$inter_crop <- ifelse(TZA2012$inter_crop %in% 1, 1, 0) # assume NA -> no intercropping
TZA2012$hybrd <- ifelse(TZA2012$hybrd %in% 2, 1, 0) # assume NA -> no hybrid seeds
TZA2012$title <- ifelse(TZA2012$title %in% c(1:10), 1, 0) # assume NA -> no title
TZA2012$irrig <- ifelse(TZA2012$irrig %in% 1, 1, 0) # assume NA -> no irrigation
TZA2012$manure <- ifelse(TZA2012$manure %in% 1, 1, 0) # assume NA -> no manure
TZA2012$N <- ifelse(is.na(TZA2012$N), 0, TZA2012$N) # assume NA -> no nitrogen
TZA2012$P <- ifelse(is.na(TZA2012$P), 0, TZA2012$P) # assume NA -> no Phosphorous
TZA2012$pest <- ifelse(TZA2012$pest %in% 1, 1, 0) # assume NA -> no pesticide
TZA2012$trans <- ifelse(TZA2012$trans %in% 1, 1, 0) # assume NA -> no transportation for crop

# -------------------------------------
# Make some new variables
# -------------------------------------

# per hectacre
TZA2012 <- mutate(TZA2012,
                  yld=qty/area_gps,
                  N=N/area_gps,
                  P=P/area_gps,
                  lab=lab/area_gps,
                  pest_q=pest_q/area_gps,
                  assetph=value/area_tot,
                  asset=value
)

# there are three possible yield variables. 
# that can be created for the last two waves of data. 
# 1. yld: above uses the full gps areas as denominator
# 2. yld2: uses harvested area as denominator
# 3. yld3: Uses relatve harvest area to correct gps area
TZA2012$area_farmer[TZA2012$area_farmer %in% 0] <- NA
TZA2012$harv_area[TZA2012$harv_area %in% 0] <- NA

# make a new yield called yld2 based on harvested area
TZA2012$yld2 <- TZA2012$qty/TZA2012$harv_area

# make a new yield called yld3 based on relative share
TZA2012$relative_share <- (TZA2012$harv_area/TZA2012$area_farmer) 
TZA2012$relative_area <- TZA2012$relative_share * TZA2012$area_gps 
TZA2012$yld3 <- TZA2012$qty/TZA2012$relative_area

TZA2012 <- select(TZA2012, -value) %>% rename(crop_qty_harv = qty)

# add and rename final variables
TZA2012 <- mutate(TZA2012, surveyyear=2012) %>% rename(hhid2012=y3_hhid)
              
saveRDS(TZA2012, file.path(dataPath, "/../../TZA2012.rds"))
