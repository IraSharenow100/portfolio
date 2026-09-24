# ============================================================
# El Cerrito Police Incident Analysis -- Data Pipeline
# Ira Sharenow
# ============================================================
#
# STRUCTURE
#   PART A -- January 2019 through June 2025 (Phases 0-17)
#             Source: 13 half-year PDF reports, re-extracted to Excel.
#             The pipeline behind the published 2019-2025 report.
#             One addition since publication: Phase 7B, a geocoding
#             correction found during the FY 2025-26 update. Where 7B
#             changed a result, both the corrected and the published
#             (pre-7B) values are recorded.
#
#   PART B -- FY 2025-26: July 1, 2025 through June 30, 2026 (Phases B0-B13)
#             Source: direct Excel export from the department (CPRA request).
#             Different input format, same analysis. Reuses Part A's
#             allow-list, landmarks, QA rules, and helper functions so both
#             periods are measured the same way.
#             B14 (planned): fpp3 seasonality -- hour, day of week, month.
#
# CONVENTIONS
#   "--- CHECK: ... ---" marks a verification step. Checks print results
#   for review; they do not change the data. The result is recorded in
#   the comment below each check.
#
# RUN ORDER
#   Part B uses objects created in Part A (police_clean, incident_types,
#   landmarks_geocoded, compute_landmark_counts, etc.), so run Part A
#   first. Phase 7B reads the FY 2025-26 geocode file created in Phase B4.
# ============================================================

library(tidyverse)
library(readxl)
library(readr)
library(stringr)
library(writexl)
library(tidygeocoder)
library(geosphere)
library(lubridate)
library(ggplot2)
library(ggspatial)
library(sf)
library(ggrepel)

source_dir <- "D:/Documents/Employment/2026 job search/GitHub/portfolio/Police Department 2026 Git/Police Data/Year Files"
output_dir <- "D:/Documents/Employment/2026 job search/GitHub/portfolio/Police Department 2026 Git/Police Data"


# ############################################################
# ############################################################
#
#   PART A -- JANUARY 2019 THROUGH JUNE 2025
#
# ############################################################
# ############################################################

# ============================================================
# PHASE 0 -- COMBINE RAW YEAR FILES & DATA INTEGRITY
# ============================================================

files <- c(
  "El_Cerrito_Police_Incidents_2019_corrected.xlsx",  # note: this one has "_corrected" in the name
  "El_Cerrito_Police_Incidents_2020.xlsx",
  "El_Cerrito_Police_Incidents_2021.xlsx",
  "El_Cerrito_Police_Incidents_2022.xlsx",
  "El_Cerrito_Police_Incidents_2023.xlsx",
  "El_Cerrito_Police_Incidents_2024.xlsx",
  "El_Cerrito_Police_Incidents_2025.xlsx"
)

all_sheets <- list()
for (f in files) {
  path <- file.path(source_dir, f)
  sheet_names <- excel_sheets(path)
  for (s in sheet_names) {
    all_sheets[[paste(f, s)]] <- read_excel(path, sheet = s)
  }
}
police_raw <- bind_rows(all_sheets)
nrow(police_raw)  # expect 137570

write_xlsx(police_raw, file.path(output_dir, "EC_police_incidents.xlsx"))

police <- read_excel(file.path(output_dir, "EC_police_incidents.xlsx")) %>%
  rename_with(~ str_trim(.) %>% str_replace_all(" ", "_") %>% tolower())

nrow(police)   # expect 137570
names(police)

police_clean <- police %>%
  filter(!is.na(event_number)) %>%
  distinct()

nrow(police_clean)  # expect 137194
n_distinct(police_clean$event_number) == nrow(police_clean)  # expect TRUE

# ============================================================
# PHASE 1 -- ADDRESS & TEXT CLEANING
# ============================================================

police_clean <- police_clean %>%
  mutate(
    address = str_squish(str_replace_all(address, "[\r\n]+", " ")),
    call_for_service = str_squish(call_for_service)
  )

sum(str_detect(police_clean$address, "[\r\n]"), na.rm = TRUE)  # expect 0
police_clean %>% filter(event_number == "190101060") %>% pull(address)

sum(is.na(police_clean$address))  # expect 2920

police_clean %>%
  filter(is.na(address)) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 20)

# Full date range covered by this dataset -- also the source of the `dt`
# column used everywhere below
police_clean_dated <- police_clean %>%
  mutate(dt = parse_date_time(received_date, orders = "mdy HM"))

max(police_clean_dated$dt, na.rm = TRUE)  # 2025-06-30 23:21:00 UTC
min(police_clean_dated$dt, na.rm = TRUE)

# ============================================================
# PHASE 2 -- INCIDENT-TYPE SCOPE (crime allow-list)
# ============================================================

incident_types_path <- "D:/Documents/Employment/2025 job search/Project 2025/el-cerrito-police-report/data/combined/types of incidents filtered.csv"

incident_types <- read_csv(incident_types_path, show_col_types = FALSE)[[1]] %>%
  str_trim() %>%
  str_to_lower()

length(incident_types)  # expect 47

incident_types <- c(incident_types,
                    "451 - arson", "20001 - hit and run with injury",
                    "20002 - hit and run no injury", "23152 - drunk driving", "602l - trespassing"
)
length(incident_types)  # expect 52

police_clean %>%
  filter(is.na(address)) %>%
  distinct(call_for_service) %>%
  mutate(call_for_service = str_to_lower(call_for_service)) %>%
  mutate(in_included_list = call_for_service %in% incident_types) %>%
  print(n = 20)
# Result: all 17 no-address call types are outside the crime allow-list

incident_types_check <- tibble(incident_type = incident_types) %>%
  rowwise() %>%
  mutate(n_matches = sum(str_to_lower(police_clean$call_for_service) == incident_type)) %>%
  ungroup() %>%
  arrange(n_matches)
incident_types_check %>% print(n = 52)

police_clean %>%
  filter(!(str_to_lower(call_for_service) %in% incident_types)) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 95)

df_filtered <- police_clean %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

nrow(df_filtered)  # expect 38075

# ============================================================
# PHASE 3 -- RESPONSE-TIME DATA COMPLETENESS (quick check)
# Full response-time analysis is Phase 16 below
# ============================================================

police_clean %>%
  summarize(
    total = n(),
    has_received = sum(!is.na(received_date)),
    has_arrived = sum(!is.na(first_unit_arrived_time)),
    has_both = sum(!is.na(received_date) & !is.na(first_unit_arrived_time))
  )

police_clean %>%
  filter(is.na(first_unit_arrived_time)) %>%
  mutate(in_crime_scope = str_to_lower(call_for_service) %in% incident_types) %>%
  count(in_crime_scope)

df_filtered %>%
  summarize(
    total = n(),
    missing_arrival = sum(is.na(first_unit_arrived_time)),
    pct_missing = round(100 * missing_arrival / total, 1)
  )
# Result: 88.3% complete within crime scope

# ============================================================
# PHASE 4 -- GEOCODING: INCIDENTS (long-running, ~3 hours)
# Commented out. Uncomment to re-run from scratch or resume.
# ============================================================

unique_addresses <- police_clean %>%
  distinct(address) %>%
  filter(!is.na(address))

nrow(unique_addresses)  # expect 25194

BAY_AREA_LAT_MIN <- 37.0
BAY_AREA_LAT_MAX <- 38.5
BAY_AREA_LONG_MIN <- -123.0
BAY_AREA_LONG_MAX <- -121.5

bay_area_extent <- paste(
  BAY_AREA_LONG_MIN, BAY_AREA_LAT_MIN,
  BAY_AREA_LONG_MAX, BAY_AREA_LAT_MAX,
  sep = ","
)

# checkpoint_path <- file.path(output_dir, "geocode_checkpoint.csv")
#
# if (file.exists(checkpoint_path)) {
#   already_done <- read_csv(checkpoint_path, show_col_types = FALSE)
#   to_geocode <- unique_addresses %>% anti_join(already_done, by = "address")
# } else {
#   already_done <- tibble(address = character(), lat = double(), long = double())
#   to_geocode <- unique_addresses
# }
#
# chunk_size <- 500
# n_chunks <- ceiling(nrow(to_geocode) / chunk_size)
#
# for (i in seq_len(n_chunks)) {
#   start_row <- (i - 1) * chunk_size + 1
#   end_row <- min(i * chunk_size, nrow(to_geocode))
#   chunk <- to_geocode[start_row:end_row, ]
#   result <- tryCatch(
#     chunk %>% geocode(address, method = "arcgis", lat = lat, long = long),
#     error = function(e) { Sys.sleep(30); tryCatch(chunk %>% geocode(address, method = "arcgis", lat = lat, long = long), error = function(e2) NULL) }
#   )
#   if (!is.null(result)) write_csv(result, checkpoint_path, append = file.exists(checkpoint_path))
#   Sys.sleep(2)
# }

# ============================================================
# PHASE 5 -- GEOCODING QA & FIX: WHY THE FIRST RUN FAILED
# Diagnostic API calls commented out. Findings summarized in comments.
# ============================================================

checkpoint_path <- file.path(output_dir, "geocode_checkpoint.csv")
geocoded <- read_csv(checkpoint_path, show_col_types = FALSE)

nrow(geocoded)             # expect 25194
sum(is.na(geocoded$lat))   # 457 failed to geocode at all

geocoded %>%
  filter(!is.na(lat)) %>%
  summarize(min_lat = min(lat), max_lat = max(lat), min_long = min(long), max_long = max(long))
# Result: essentially global (lat -62.5 to 65.8) -- some addresses matched
# somewhere else in the world entirely, with full confidence scores.
# "SAN PABLO/PANAMA" scored 100 and matched the country Panama.
# "CREEKSIDE PARK" scored 100 and matched a park in Australia.
# LESSON: ArcGIS's confidence score means "I found a match for this text,"
# not "I found the right place."

EC_CENTER_LAT <- 37.9161
EC_CENTER_LONG <- -122.3108

police_geocoded <- police_clean %>%
  left_join(geocoded, by = "address") %>%
  mutate(
    BAD_LATLON_FLAG = is.na(lat) |
      lat < BAY_AREA_LAT_MIN | lat > BAY_AREA_LAT_MAX |
      long < BAY_AREA_LONG_MIN | long > BAY_AREA_LONG_MAX
  )

police_geocoded %>%
  summarize(total = n(), missing_coords = sum(is.na(lat)), out_of_region = sum(!is.na(lat) & BAD_LATLON_FLAG), total_flagged = sum(BAD_LATLON_FLAG))
# Result: 3651 missing + 7401 wildly out of region = 11052 flagged

# Pattern: department shorthand (SPA = San Pablo Ave, POT = Potrero Ave)
# the geocoder can't recognize, so it guesses globally instead of failing
problem_addresses <- police_geocoded %>%
  filter(BAD_LATLON_FLAG) %>%
  distinct(address) %>%
  filter(!is.na(address)) %>%
  mutate(address_expanded = address %>% str_replace_all("\\bSPA\\b", "San Pablo Ave") %>% str_replace_all("\\bPOT\\b", "Potrero Ave"))

nrow(problem_addresses)  # expect 3046

# --- FIX: constrain the geocoder with searchExtent (Bay Area bounding box) ---
# Test confirmed: wrong-continent matches disappeared, resolving correctly
# nearby or returning NA (a safe failure, not a silent wrong one).

# geocode_v2_path <- file.path(output_dir, "geocode_checkpoint_v2.csv")
# [re-geocode logic for the 3046 problem_addresses with searchExtent -- see
#  Phase 4 pattern above, applied to problem_addresses instead of
#  unique_addresses, custom_query = list(searchExtent = bay_area_extent)]

# ============================================================
# PHASE 6 -- COMBINE GEOCODING RESULTS & FINALIZE FLAGS
# ============================================================

original_geocodes <- read_csv(file.path(output_dir, "geocode_checkpoint.csv"), show_col_types = FALSE)
fixed_geocodes <- read_csv(file.path(output_dir, "geocode_checkpoint_v2.csv"), show_col_types = FALSE)

final_geocodes <- original_geocodes %>%
  anti_join(fixed_geocodes, by = "address") %>%
  bind_rows(fixed_geocodes)

nrow(final_geocodes)  # expect 25194

final_geocodes <- final_geocodes %>%
  mutate(BAD_LATLON_FLAG = is.na(lat) | lat < BAY_AREA_LAT_MIN | lat > BAY_AREA_LAT_MAX | long < BAY_AREA_LONG_MIN | long > BAY_AREA_LONG_MAX)

final_geocodes %>% summarize(total = n(), still_bad = sum(BAD_LATLON_FLAG), pct_bad = round(100 * sum(BAD_LATLON_FLAG) / n(), 1))
# Result: 429 still bad out of 25194 (1.7%) -- 86% recovery from the fix

police_geocoded <- police_clean %>%
  left_join(final_geocodes %>% select(address, lat, long, BAD_LATLON_FLAG), by = "address") %>%
  mutate(BAD_LATLON_FLAG = if_else(is.na(address), TRUE, BAD_LATLON_FLAG))

nrow(police_geocoded)  # expect 137194

police_geocoded %>% summarize(total = n(), usable_for_map = sum(!BAD_LATLON_FLAG), excluded = sum(BAD_LATLON_FLAG))
# Result: 132996 usable (96.9%), 4198 excluded

# ============================================================
# PHASE 7 -- GEOCODING: LANDMARKS
# ============================================================

landmarks <- tribble(
  ~landmark, ~address,
  "El Cerrito Plaza BART", "6699 Fairmount Avenue, El Cerrito, CA 94530",
  "El Cerrito Del Norte BART", "6400 Cutting Blvd, El Cerrito, CA 94530",
  "Castro Park Pickleball", "1420 Norvell St, El Cerrito, CA 94530",
  "El Cerrito Community Center", "7007 Moeser Ln, El Cerrito, CA 94530",
  "El Cerrito High School", "540 Ashbury Ave, El Cerrito, CA 94530",
  "Korematsu Middle School", "7125 Donal Ave, El Cerrito, CA 94530",
  "Harding Elementary School", "7230 Fairmount Ave, El Cerrito, CA 94530",
  "Madera Elementary School", "8500 Madera Dr, El Cerrito, CA 94530",
  "Current Library", "6510 Stockton Ave, El Cerrito, CA 94530"
)

landmarks_geocoded <- landmarks %>%
  geocode(address, method = "arcgis", lat = lat, long = long, full_results = TRUE, custom_query = list(searchExtent = bay_area_extent))

landmarks_geocoded %>% select(landmark, address, lat, long, score = attributes.Score, addr_type = attributes.Addr_type)

# Korematsu: "perfect" 100-score match on the correct address, but the
# coordinate pointed to the school's OLD location (it moved ~10 years ago,
# ArcGIS's reference data wasn't updated). Caught via local knowledge,
# confirmed via an independent source (school newsletter), corrected below.
landmarks_geocoded <- landmarks_geocoded %>%
  mutate(
    lat = if_else(landmark == "Korematsu Middle School", 37.9208100248211, lat),
    long = if_else(landmark == "Korematsu Middle School", -122.30584773399178, long),
    source = if_else(landmark == "Korematsu Middle School", "manual correction - ArcGIS had stale address point", "arcgis")
  )

# Madera: separately verified against a hand-pulled Google Maps coordinate.
# Off by ~246 ft -- normal geocoder variance, NOT an error like Korematsu.
# No correction needed. Also confirmed: the school has been at this same
# address since 1980, so there's no relocation-driven staleness risk here.
madera_check_dist_ft <- distHaversine(c(-122.298090, 37.927869), c(-122.29869050515569, 37.92835061410911)) / 0.3048
madera_check_dist_ft  # ~246 ft, fine

# Short labels for map display
landmarks_geocoded <- landmarks_geocoded %>%
  mutate(landmark = case_when(
    landmark == "El Cerrito Del Norte BART"   ~ "Del Norte BART",
    landmark == "Madera Elementary School"    ~ "Madera",
    landmark == "Korematsu Middle School"     ~ "Korematsu",
    landmark == "El Cerrito Community Center" ~ "EC Community Center",
    landmark == "El Cerrito High School"      ~ "ECHS",
    landmark == "Harding Elementary School"   ~ "Harding",
    landmark == "El Cerrito Plaza BART"       ~ "EC Plaza BART",
    landmark == "Castro Park Pickleball"      ~ "Castro Park",
    landmark == "Current Library"             ~ "Library",
    TRUE ~ landmark
  ))

landmarks_geocoded %>% select(landmark, lat, long, source)

# ============================================================
# PHASE 7B -- CORRECTION: HOUSE ADDRESSES PLACED AT CROSS-STREETS
# Found during the FY 2025-26 update, after the 2019-2025 report was
# published. About 19% of Part A addresses have the form
#   "6400 CUTTING BLVD, SAN PABLO AVE & KEARNEY ST, EL CERRITO, CA, 94530"
# Phase 4 geocoded that whole string. For most, ArcGIS placed the house
# correctly -- but for 287 addresses (1,493 records) it placed the
# cross-street intersection instead. Worst case: the Del Norte BART
# station, placed 3,437 ft from the station.
#
# FIX: the FY 2025-26 pass (Phase B4) geocoded house addresses with the
# cross-street removed. Where the same house appears in both periods and
# the two coordinates differ by more than 500 ft, the FY 2025-26
# coordinate replaces Part A's. Validated below against verified landmark
# coordinates and one hand check. No new geocoding needed.
#
# Two limits on which addresses are compared:
#   - El Cerrito addresses only. The lookup string assumes El Cerrito, so
#     a Pinole or Richmond house would match the wrong street. (The first
#     version lacked this filter and moved 1800 ELM ST, PINOLE ~5.6 miles.)
#   - Addresses Phase 10 corrects separately are skipped, so the two
#     fixes cannot collide.
#
# Placed after Phase 7 because the validation uses landmark coordinates.
# Everything from Phase 8 on reflects the corrected coordinates.
# ============================================================

geocoded_fy26_ref <- read_csv(file.path(output_dir, "geocode_checkpoint_fy26.csv"),
                              show_col_types = FALSE)

outliers_v3_addresses <- read_csv(file.path(output_dir, "geocode_outliers_v3.csv"),
                                  show_col_types = FALSE)$address

HOUSE_PLUS_CROSS <- "^\\d+ [^,]+, [^,&]+ & [^,]+"

# --- CHECK: how common is the house + cross-street format? ---
police_clean %>%
  summarize(total = n(),
            house_plus_cross = sum(str_detect(address, HOUSE_PLUS_CROSS), na.rm = TRUE),
            pct = round(100 * house_plus_cross / total, 1))
# Result: 26460 of 137194 records (19.3%)

# Part A coordinate vs. FY 2025-26 coordinate for the same house address
house_cross_compare <- police_geocoded %>%
  filter(str_detect(address, HOUSE_PLUS_CROSS),
         str_detect(address, ", EL CERRITO, CA"),
         !address %in% outliers_v3_addresses,
         !BAD_LATLON_FLAG) %>%
  mutate(geocode_address = paste0(str_trim(str_extract(address, "^[^,]+")),
                                  ", El Cerrito, CA 94530")) %>%
  inner_join(geocoded_fy26_ref %>% select(geocode_address, lat_b = lat, long_b = long),
             by = "geocode_address") %>%
  filter(!is.na(lat_b)) %>%
  mutate(shift_ft = distHaversine(cbind(long, lat), cbind(long_b, lat_b)) / 0.3048)

# --- CHECK: how far apart are the two placements? ---
house_cross_compare %>%
  summarize(records_matched = n(),
            addresses_matched = n_distinct(address),
            median_shift_ft = round(median(shift_ft)),
            pct_over_500ft = round(100 * mean(shift_ft > 500), 1),
            pct_over_1000ft = round(100 * mean(shift_ft > 1000), 1))
# Result: 16170 records (3117 addresses) matched. Median shift 0 ft --
# most placements agree. 9.2% differ by >500 ft, 5.9% by >1,000 ft.

misplaced <- house_cross_compare %>%
  filter(shift_ft > 500) %>%
  group_by(address) %>%
  summarize(n = n(), shift_ft = round(first(shift_ft)),
            lat = first(lat), long = first(long),
            lat_b = first(lat_b), long_b = first(long_b),
            .groups = "drop") %>%
  arrange(desc(n))

# --- CHECK: concentrated in a few addresses, or spread out? ---
nrow(misplaced)                                                  # 287 addresses
sum(misplaced$n)                                                 # 1493 records
round(100 * sum(head(misplaced$n, 10)) / sum(misplaced$n), 1)    # 42.7% in top 10
misplaced %>% head(15) %>% select(address, n, shift_ft) %>% as.data.frame()
# Result: concentrated. Del Norte BART (6400 CUTTING BLVD) alone is 381
# records, 3,437 ft off. 7007 MOESER LN -- the Community Center's own
# address -- is 573 ft off.

# --- CHECK: which placement is right? ---
# Compare both placements to verified landmark coordinates.
del_norte_lm <- landmarks_geocoded %>% filter(landmark == "Del Norte BART")
comm_ctr_lm  <- landmarks_geocoded %>% filter(landmark == "EC Community Center")
library_lm   <- landmarks_geocoded %>% filter(landmark == "Library")

dist_ft <- function(lon, lat, lm) round(distHaversine(cbind(lon, lat), c(lm$long, lm$lat)) / 0.3048)

misplaced %>%
  head(15) %>%
  mutate(
    street        = str_extract(address, "^[^,]+"),
    a_to_del_norte = dist_ft(long, lat, del_norte_lm),
    b_to_del_norte = dist_ft(long_b, lat_b, del_norte_lm),
    a_to_comm_ctr  = dist_ft(long, lat, comm_ctr_lm),
    b_to_comm_ctr  = dist_ft(long_b, lat_b, comm_ctr_lm),
    a_to_library   = dist_ft(long, lat, library_lm),
    b_to_library   = dist_ft(long_b, lat_b, library_lm)
  ) %>%
  distinct(street, .keep_all = TRUE) %>%
  select(street, starts_with("a_to"), starts_with("b_to")) %>%
  as.data.frame()
# Result -- FY 2025-26 placement correct in every testable case:
#   6400 CUTTING BLVD       to Del Norte BART:   Part A 3,437 ft, FY26 0 ft
#   7007 MOESER LN          to Community Center: Part A 573 ft,   FY26 0 ft
#   6830/6922/6925 STOCKTON to Library (6510 Stockton, a few blocks away):
#                           Part A 5,213-5,819 ft, FY26 957-1,209 ft
# The rest are too far from any landmark for this test.

# --- CHECK: hand verification (same approach as Madera, Phase 7) ---
# Largest untestable address: 5611 POINSETT AVE (113 records).
# Google Maps coordinate: 37.934957, -122.317842
poinsett_google <- c(-122.31784237631963, 37.934957224913596)

misplaced %>%
  filter(str_detect(address, "^5611 POINSETT")) %>%
  distinct(lat, long, lat_b, long_b) %>%
  mutate(part_a_ft = round(distHaversine(cbind(long, lat), poinsett_google) / 0.3048),
         fy26_ft   = round(distHaversine(cbind(long_b, lat_b), poinsett_google) / 0.3048))
# Result: Part A 1,015 ft off; FY 2025-26 54 ft off. FY 2025-26 correct.

# --- CHECK: no overlap with the Phase 10 outlier correction ---
sum(misplaced$address %in% outliers_v3_addresses)  # 0 -- excluded above

# --- Apply the correction ---
final_geocodes <- final_geocodes %>%
  rows_update(misplaced %>% select(address, lat = lat_b, long = long_b), by = "address")

police_geocoded <- police_clean %>%
  left_join(final_geocodes %>% select(address, lat, long, BAD_LATLON_FLAG), by = "address") %>%
  mutate(BAD_LATLON_FLAG = if_else(is.na(address), TRUE, BAD_LATLON_FLAG))

nrow(police_geocoded)                  # 137194
sum(!police_geocoded$BAD_LATLON_FLAG)  # 132996 -- correction moves points, doesn't add or drop any

# Known limitation: about 10,000 house + cross-street records have no
# FY 2025-26 match and can't be checked this way. In the matched sample,
# about 91% were within 500 ft, so most of them are likely placed
# correctly.

# ============================================================
# PHASE 8 -- LANDMARK PROXIMITY COUNTS (500 ft, ALL activity)
# ============================================================

RADIUS_FT <- 500
RADIUS_M <- RADIUS_FT * 0.3048

incidents_for_proximity <- police_geocoded %>% filter(!BAD_LATLON_FLAG)
nrow(incidents_for_proximity)  # expect 132996

landmark_counts <- landmarks_geocoded %>%
  select(landmark, land_lat = lat, land_long = long) %>%
  rowwise() %>%
  mutate(n_within_500ft = sum(distHaversine(cbind(incidents_for_proximity$long, incidents_for_proximity$lat), c(land_long, land_lat)) <= RADIUS_M)) %>%
  ungroup() %>%
  arrange(desc(n_within_500ft))

landmark_counts %>% select(landmark, n_within_500ft)
# Result after 7B: EC Plaza BART 2298, Community Center 1841, ECHS 1248,
# Library 989, Del Norte BART 953, Harding 786, Madera 525, Castro Park
# 364, Korematsu 294.
# Changed from published: Del Norte BART 557 -> 953 (+71%, rank 6 -> 5),
# Community Center 1802 -> 1841, ECHS 1235 -> 1248, Library 1029 -> 989.
#
# CORRECTION: the published report attributed Del Norte BART's low count
# to the Richmond border and BART Police jurisdiction. Phase 7B found the
# main cause was geocoding -- 95% of station records were placed 3,437 ft
# away. The jurisdiction point may still apply, but is not the main cause.

# ============================================================
# PHASE 9 -- WORKLOAD SUMMARY (all call types, full population)
# ============================================================

workload_summary <- police_clean %>%
  count(call_for_service, sort = TRUE) %>%
  mutate(in_crime_scope = str_to_lower(call_for_service) %in% incident_types, pct_of_total = round(100 * n / sum(n), 1))

workload_summary %>% print(n = 30)

workload_summary %>%
  summarize(total = sum(n), crime_scope = sum(n[in_crime_scope]), pct_crime_scope = round(100 * crime_scope / total, 1))
# Result: 27.8% of everything logged is crime-scope. Headline number.

# ============================================================
# PHASE 10 -- CRIME-SCOPE POPULATION FOR MAPPING & GEOGRAPHIC QA
# This is where the real geocoding QA saga happened -- kept in full since
# it's a genuinely important part of the methodology story.
# ============================================================

police_total <- incidents_for_proximity %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

nrow(police_total)  # 37984 (fewer than df_filtered's 38075 -- the gap is
# crime-scope rows that failed geocoding entirely)

# --- Sanity check: does the point cloud actually trace El Cerrito's shape? ---
ggplot(police_total, aes(x = long, y = lat)) +
  geom_point(alpha = 0.15, size = 0.5, color = "steelblue") +
  geom_point(data = landmarks_geocoded, aes(x = long, y = lat), color = "red", size = 3, shape = 17) +
  coord_fixed(1.3, xlim = c(-122.35, -122.28), ylim = c(37.88, 37.94)) +
  theme_minimal()
# Traced the right shape. BUT a scatter/zoom only hides distant outliers
# from VIEW -- it doesn't remove them from the data, and stat_density_2d
# uses every row regardless of the plot window. Found this the hard way:

EC_CENTER_DIST_CHECK <- police_total %>%
  mutate(dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34)

outliers_full <- EC_CENTER_DIST_CHECK %>%
  filter(dist_from_ec_mi > 2) %>%
  distinct(address, lat, long, dist_from_ec_mi) %>%
  arrange(desc(dist_from_ec_mi))

nrow(outliers_full)  # 302 (unchanged by 7B)

# ATTEMPT 1 (failed): re-geocoded these 302 with a "tighter" 14-mile-wide
# searchExtent box. Still too big -- it fully contained San Francisco,
# Piedmont, and Oakland. "426 COLUMBUS AVE" matched the real, correct,
# famous Columbus Ave in San Francisco's North Beach -- 8.7 miles away.
# Same root problem as Panama, one size class smaller.

# outliers_result <- outliers_full %>% select(address) %>%
#   geocode(address, method = "arcgis", lat = lat, long = long, custom_query = list(searchExtent = ec_tight_extent))

outliers_result <- read_csv(file.path(output_dir, "geocode_outliers_v3.csv"), show_col_types = FALSE)

# FINAL APPROACH (adopted): stop tuning bounding boxes -- classify by
# distance AND check whether the address text itself explicitly names a
# real, different city (San Francisco, Piedmont, Oakland, Pinole, etc.).
# Legitimate neighboring jurisdictions (Richmond, San Pablo, Berkeley,
# Kensington, El Sobrante) are kept; genuinely distant or unresolved
# shorthand is excluded.

KNOWN_DISTANT_CITIES <- "SAN FRANCISCO|PIEDMONT|OAKLAND|PINOLE|STOCKTON|PETALUMA|SAN LEANDRO|CONCORD|ANTIOCH"

outliers_final <- outliers_result %>%
  mutate(
    dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34,
    exclusion_reason = case_when(
      is.na(lat) ~ "unresolved - no match",
      dist_from_ec_mi <= 5 ~ "usable",
      str_detect(address, KNOWN_DISTANT_CITIES) ~ "confirmed different city",
      TRUE ~ "unresolved - shorthand matched wrong location"
    )
  )

outliers_final %>% count(exclusion_reason)
# Result: 198 usable, 53 unresolved (no match), 51 excluded (7 confirmed
# different city, 44 unresolved shorthand)

usable_outliers <- outliers_final %>% filter(exclusion_reason == "usable") %>% select(address, lat, long)

# One address is a genuine out-of-state entry in the source PD data itself
# (a Michigan address) -- not a geocoding error, just not a location near
# El Cerrito. The 5-mile radius filter below naturally excludes it.

police_total_corrected <- police_total %>%
  rows_update(usable_outliers, by = "address") %>%
  mutate(dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34) %>%
  filter(dist_from_ec_mi <= 5)

nrow(police_total)            # 37984
nrow(police_total_corrected)  # 37867 (unchanged by 7B)

# ============================================================
# PHASE 11 -- GENERAL HEATMAP (final, correct version)
# Two bugs fixed to get here:
#  1. annotation_map_tile() draws in Web Mercator; coord_sf needs
#     crs = 4326 explicitly or it silently misinterprets the lat/long
#     xlim/ylim as some other unit (axis showed nonsense like "0.0003N").
#  2. Label collisions at the bottom cluster -- fixed with ggrepel.
# ============================================================

EC_MAP_LAT_MIN <- 37.885
EC_MAP_LAT_MAX <- 37.94
EC_MAP_LONG_MIN <- -122.325
EC_MAP_LONG_MAX <- -122.275

ggplot() +
  annotation_map_tile(type = "osm", zoomin = 0) +
  stat_density_2d(data = police_total_corrected, aes(x = long, y = lat, fill = after_stat(level)), geom = "polygon", contour = TRUE, alpha = 0.5, bins = 25) +
  scale_fill_gradient(low = "yellow", high = "red", breaks = range, labels = c("Fewer incidents", "More incidents")) +
  geom_point(data = landmarks_geocoded, aes(x = long, y = lat), color = "black", size = 2.5, shape = 17) +
  geom_label_repel(data = landmarks_geocoded, aes(x = long, y = lat, label = landmark), size = 2.8, fontface = "bold", label.padding = 0.15, label.size = 0, fill = alpha("white", 0.75), min.segment.length = 0, max.overlaps = Inf) +
  coord_sf(xlim = c(EC_MAP_LONG_MIN, EC_MAP_LONG_MAX), ylim = c(EC_MAP_LAT_MIN, EC_MAP_LAT_MAX), crs = 4326) +
  labs(title = "El Cerrito Crime-Scope Incident Density", fill = NULL) +
  theme_minimal() + theme(axis.title = element_blank())

# ============================================================
# PHASE 12 -- INCIDENT SUBSETS & LANDMARK COMPARISON TABLE
# Rebuilt from police_total_corrected (post outlier-fix), not the
# earlier uncorrected police_total.
# ============================================================

vehicle_crime_types <- c("459a - auto burglary", "10851 - motor vehicle theft", "10851r - recovered stolen vehicle", "215 - car jacking", "23110 - throwing objects at a vehicle", "10852 - vehcile parts theft")
dangerous_driving_types <- c("20001 - hit and run with injury", "20002 - hit and run no injury", "23152 - drunk driving")

police_vehicle_crime <- police_total_corrected %>% filter(str_to_lower(call_for_service) %in% vehicle_crime_types)
police_dangerous_driving <- police_total_corrected %>% filter(str_to_lower(call_for_service) %in% dangerous_driving_types)
police_other_crime <- police_total_corrected %>% filter(!(str_to_lower(call_for_service) %in% c(vehicle_crime_types, dangerous_driving_types)))

tibble(group = c("Total (crime scope, corrected)", "Vehicle crime", "Dangerous driving", "Everything else"),
       n = c(nrow(police_total_corrected), nrow(police_vehicle_crime), nrow(police_dangerous_driving), nrow(police_other_crime)))
# 37867 / 2887 / 1164 / 33816 (unchanged by 7B)

compute_landmark_counts <- function(incident_df, label) {
  landmarks_geocoded %>%
    select(landmark, land_lat = lat, land_long = long) %>%
    rowwise() %>%
    mutate(n_within_500ft = sum(distHaversine(cbind(incident_df$long, incident_df$lat), c(land_long, land_lat)) <= RADIUS_M)) %>%
    ungroup() %>%
    select(landmark, {{label}} := n_within_500ft)
}

vehicle_counts <- compute_landmark_counts(police_vehicle_crime, "vehicle_crime")
dangerous_counts <- compute_landmark_counts(police_dangerous_driving, "dangerous_driving")
other_counts <- compute_landmark_counts(police_other_crime, "other_crime")

landmark_comparison <- vehicle_counts %>%
  left_join(dangerous_counts, by = "landmark") %>%
  left_join(other_counts, by = "landmark") %>%
  mutate(total = vehicle_crime + dangerous_driving + other_crime) %>%
  arrange(desc(total))

landmark_comparison
# Result after 7B (vehicle / dangerous driving / other / total):
#   EC Plaza BART 29/14/368/411, Community Center 30/15/341/386,
#   ECHS 8/11/310/329, Library 21/2/267/290, Del Norte BART 16/12/231/259,
#   Harding 11/6/203/220, Castro Park 4/3/82/89, Korematsu 3/2/63/68,
#   Madera 4/3/56/63.
# Changed from published: Del Norte BART 194 -> 259 (+34%; vehicle crime
# 7 -> 16), Community Center 381 -> 386, ECHS 324 -> 329, Library
# 296 -> 290. Ranking unchanged: EC Plaza BART and the Community Center
# still lead in vehicle crime and dangerous driving; Korematsu/Madera
# still lowest.

# ============================================================
# PHASE 13 -- VEHICLE-CRIME HEATMAP
# ============================================================

nrow(police_vehicle_crime)  # 2887 (unchanged by 7B)

ggplot() +
  annotation_map_tile(type = "osm", zoomin = 0) +
  stat_density_2d(data = police_vehicle_crime, aes(x = long, y = lat, fill = after_stat(level)), geom = "polygon", contour = TRUE, alpha = 0.5, bins = 15) +
  scale_fill_gradient(low = "yellow", high = "red", breaks = range, labels = c("Fewer incidents", "More incidents")) +
  geom_point(data = landmarks_geocoded, aes(x = long, y = lat), color = "black", size = 2.5, shape = 17) +
  geom_label_repel(data = landmarks_geocoded, aes(x = long, y = lat, label = landmark), size = 2.8, fontface = "bold", label.padding = 0.15, label.size = 0, fill = alpha("white", 0.75), min.segment.length = 0, max.overlaps = Inf) +
  coord_sf(xlim = c(EC_MAP_LONG_MIN, EC_MAP_LONG_MAX), ylim = c(EC_MAP_LAT_MIN, EC_MAP_LAT_MAX), crs = 4326) +
  labs(title = "El Cerrito Vehicle Crime Density", fill = NULL) +
  theme_minimal() + theme(axis.title = element_blank())
# Published (pre-7B): same two hotspots as the general map (Del Norte BART,
# EC Plaza BART). After 7B: map not yet reviewed; Del Norte gained 9
# vehicle-crime records within 500 ft.

# ============================================================
# PHASE 14 -- TIME TRENDS
# (No location data used -- not affected by 7B)
# ============================================================

yearly_totals <- police_clean_dated %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  mutate(year = year(dt)) %>%
  count(year, name = "incidents")
yearly_totals
# COVID-era dip confirmed on corrected data: 6627 (2019) -> 5338 -> 5301
# -> 5058 (2022, low point) -> 6137 -> 6335 (2024, highest of period)

monthly_totals <- police_clean_dated %>%
  filter(str_to_lower(call_for_service) %in% incident_types, year(dt) %in% 2019:2024) %>%
  mutate(month = month(dt, label = TRUE)) %>%
  count(month, name = "incidents")
monthly_totals

# 2025's full-year-style total (3279) looks low next to other years'
# FULL-YEAR totals -- but 2025 is only Jan-Jun. Fair comparison:
police_clean_dated %>%
  filter(str_to_lower(call_for_service) %in% incident_types, month(dt) <= 6) %>%
  mutate(year = year(dt)) %>%
  count(year, name = "incidents_jan_jun")
# 2025 H1 (3279) is actually the HIGHEST first-half total of the whole
# 7-year period -- not a decline. The "low" 2025 number was an
# apples-to-oranges artifact of comparing a half-year to full years.

# October initially looked like a seasonal spike in the combined monthly
# total. Checked whether it holds in EVERY year:
police_clean_dated %>%
  filter(str_to_lower(call_for_service) %in% incident_types, year(dt) %in% 2019:2024, month(dt) == 10) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 15)
# PARKER - PARKING VIOLATION alone is 825 of October's total -- one
# category driving the bump, not a broad seasonal pattern. Correct framing:
# "parking enforcement spikes in October," not "incidents rise in October."

# ============================================================
# PHASE 15 -- PARKING VIOLATIONS (separate trend, genuinely newsworthy)
# (No location data used -- not affected by 7B)
# ============================================================

parking_yearly <- police_clean_dated %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION") %>%
  mutate(year = year(dt)) %>%
  count(year, name = "parking_violations")
parking_yearly
# 568 (2019) -> 1772 (2024) -- more than tripled

parking_by_year_month <- police_clean_dated %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION", year(dt) %in% 2019:2024) %>%
  mutate(year = year(dt), month = month(dt, label = TRUE)) %>%
  count(year, month, name = "parking_violations")

parking_by_year_month %>% filter(month == "Oct") %>% arrange(year)
# October itself is erratic year to year (69, 39, 182, 53, 274, 208) --
# NOT a consistent recurring spike. Elevated specifically in 2021 and
# 2023, unremarkable other years. Not a real seasonal pattern on its own.

# Fair like-for-like check on 2025 (H1 vs. H1, not H1 vs. full year):
police_clean_dated %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION", month(dt) <= 6) %>%
  mutate(year = year(dt)) %>%
  count(year, name = "parking_jan_jun")
# 260 -> 394 -> 369 -> 401 -> 723 -> 730 -> 1275
# Two distinct step-changes (2022->2023: +80%, 2024->2025: +75%), not
# smooth growth -- consistent with specific operational changes rather
# than gradual drift. Cause of these step-changes: known but intentionally
# not detailed in this report per project owner's direction.

# ============================================================
# PHASE 16 -- RESPONSE TIME ANALYSIS
# (No location data used -- not affected by 7B)
# ============================================================

response_data <- police_clean_dated %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  mutate(arrived_dt = parse_date_time(first_unit_arrived_time, orders = "mdy HM"),
         response_min = as.numeric(difftime(arrived_dt, dt, units = "mins")))

response_data %>% summarize(total = n(), has_response_time = sum(!is.na(response_min)))
# 33602 of 38075 -- matches the 88.3% completeness figure from Phase 3

response_data %>%
  filter(!is.na(response_min)) %>%
  summarize(negative = sum(response_min < 0), over_4_hours = sum(response_min > 240),
            min_val = min(response_min), max_val = max(response_min),
            median_val = median(response_min), mean_val = round(mean(response_min), 1))
# One value (3333 min, ~2.3 days, a DISTURBANCE call) is a clear data
# entry error, not a real response time. One negative value (-54 min) is
# a minor logging quirk.

response_data %>%
  filter(!is.na(response_min), response_min > 240, response_min < 1440) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 20)
# 20 cases between 4 and 24 hours. 13 are property crimes (vehicle theft,
# burglary, petty theft, recovered vehicle, vandalism) -- typically
# discovered and reported after the fact, not active emergencies. 4 more
# are non-violent (unwanted person, suspicious vehicle, hit and run no
# injury). 3 are violent (assault/battery, sexual battery, criminal
# threats) -- isolated, not a pattern.
# (Earlier comment said "17 of 20 are property" -- corrected: 17 of 20
# are non-violent, 13 of them property.)

response_data_clean <- response_data %>% filter(!is.na(response_min), response_min < 1440)
nrow(response_data)         # 38075
nrow(response_data_clean)   # 33601 (excludes the one multi-day data error)

response_data_clean %>%
  summarize(n = n(), median_min = median(response_min), mean_min = round(mean(response_min), 1), p90_min = round(quantile(response_min, 0.9), 1))
# Median 5 min, mean 10.3 (pulled up by the report-type tail), 90% within
# 25 min. Median is the fairer headline number given the right skew.

response_data_clean %>%
  mutate(year = year(dt)) %>%
  group_by(year) %>%
  summarize(median_min = median(response_min), n = n())
# Raw year trend looked like a dramatic speedup (7 -> 2 min) -- but this
# turned out to be a COMPOSITION EFFECT, not a real operational change.
# See below.

urgent_types <- c("245 - assault with a deadly weapon", "211 - robbery", "1071 - shooting (actual victim)",
                  "sfrmc - shots fired", "215 - car jacking", "243a - assault / battery",
                  "243.4 - sexual battery / assault", "422 - criminal threats")

response_data_clean %>%
  filter(str_to_lower(call_for_service) %in% urgent_types) %>%
  group_by(call_for_service) %>%
  summarize(median_min = median(response_min), mean_min = round(mean(response_min), 1), n = n()) %>%
  arrange(desc(median_min))
# "Urgent" bucket initially looked SLOWER than everything else on average
# -- traced to two categories with heavy after-the-fact reporting
# (SEXUAL BATTERY 23min median/17 cases, CRIMINAL THREATS 10min/224
# cases) dragging up the group average. The genuinely ACTIVE-danger
# categories (shots fired, shooting w/ victim, robbery, carjacking,
# assault w/ deadly weapon) all land in a tight 3.5-6 min band --
# consistently fast. Report these two groups separately, not blended.

# Self-initiated categories (parking, wanted-person checks, suspicious
# vehicle stops, recovered-vehicle follow-ups) have near-zero response
# time by nature -- no dispatch/travel involved. Their share of all
# crime-scope incidents grew hugely (parking alone nearly quadrupled),
# which mechanically drags the CITYWIDE median down over time even if
# real emergency response didn't get any faster.
self_initiated_types <- c("parker - parking violation", "1027 - wanted person / warrant",
                          "10851r - recovered stolen vehicle", "1154 - suspicious vehicle")

response_data_clean %>%
  filter(!str_to_lower(call_for_service) %in% self_initiated_types) %>%
  mutate(year = year(dt)) %>%
  group_by(year) %>%
  summarize(median_min = median(response_min), n = n())
# TRUE finding: response time for genuine call-and-respond incidents is
# FLAT, not dramatically improving -- 8,8,8,9,8,7,7 across 2019-2025.
# Stable performance is the honest, defensible claim, not "responses
# got twice as fast," which was an artifact of parking enforcement's
# growing share of all crime-scope incidents.

# ============================================================
# PHASE 17 -- PARKING ENFORCEMENT NEAR EL CERRITO PLAZA
# Checks whether the parking-district conversation near the Plaza is
# reflected in a rising SHARE of citywide enforcement, not just a rising
# raw count (which would just be riding the citywide tripling above).
# ============================================================

ec_plaza_bart <- landmarks_geocoded %>% filter(landmark == "EC Plaza BART")

parking_geocoded <- police_clean %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION") %>%
  mutate(dt = parse_date_time(received_date, orders = "mdy HM")) %>%
  left_join(final_geocodes %>% select(address, lat, long, BAD_LATLON_FLAG), by = "address") %>%
  filter(!BAD_LATLON_FLAG, !is.na(lat)) %>%
  mutate(dist_to_plaza_ft = distHaversine(cbind(long, lat), c(ec_plaza_bart$long, ec_plaza_bart$lat)) / 0.3048)

nrow(parking_geocoded)  # how much of the citywide parking-ticket total actually got geocoded

parking_geocoded %>%
  mutate(
    year = year(dt),
    within_500ft = dist_to_plaza_ft <= 500,
    within_1000ft = dist_to_plaza_ft <= 1000
  ) %>%
  group_by(year) %>%
  summarize(
    total_geocoded = n(),
    near_plaza_500ft = sum(within_500ft),
    pct_near_plaza_500ft = round(100 * near_plaza_500ft / total_geocoded, 1),
    near_plaza_1000ft = sum(within_1000ft),
    pct_near_plaza_1000ft = round(100 * near_plaza_1000ft / total_geocoded, 1)
  )
# Result (unchanged by 7B): the SHARE near the Plaza (1,000 ft) has not
# risen -- 10.4% (2019) to 6.7% (2025), if anything lower now. The raw
# count near the Plaza grew, but that's just riding the citywide tripling,
# not extra concentration there. Enforcement growth is broad-based.


# ############################################################
# ############################################################
#
#   PART B -- FY 2025-26 (JULY 1, 2025 THROUGH JUNE 30, 2026)
#
# ############################################################
# ############################################################
#
# WHAT CHANGED IN THE SOURCE DATA
# Part A came from 13 half-year PDFs that had to be re-extracted and
# verified. FY 2025-26 arrived through a CPRA request as a direct Excel
# export. Same six columns, but three practical differences:
#
#   1. No PDF extraction step -- and none of its defects (truncated
#      addresses, dropped page-top rows) to find and fix.
#   2. Dates arrive as true date-times with seconds, not "m/d/y H:M" text.
#      Part A's parse_date_time() call does not apply here.
#   3. Addresses use a new, verbose format, e.g.
#        "SAN PABLO AVE & POTRERO AVE, SAN PABLO AVE & POTRERO AVE
#         (SPA & POTRERO), EL CERRITO, CA, 94530"
#      These will not match Part A's geocode cache, so a fresh (smaller)
#      geocoding pass is needed.
#
# Per the department, addresses for sensitive calls (juvenile, sexual
# assault, 5150/medical, suicide) were redacted. In this export that means
# block-level addresses ("10900 SAN PABLO AVE"), not blanks. See B9.
#
# WHAT STAYS THE SAME
# Crime allow-list, self-initiated list, landmarks (incl. the Korematsu
# correction), 500 ft radius, 5-mile distance rule, and every analysis.
# Holding the method fixed is what makes FY 2025-26 comparable to the
# earlier years.
# ============================================================

fy26_file <- "Police Incidents 2025- JULY 1 - JUNE 30- 2026.xlsx"

# ============================================================
# PHASE B0 -- LOAD & DATA INTEGRITY
# ============================================================

excel_sheets(file.path(output_dir, fy26_file))  # 1 sheet

police_fy26 <- read_excel(file.path(output_dir, fy26_file)) %>%
  rename_with(~ str_trim(.) %>% str_replace_all(" ", "_") %>% tolower()) %>%
  mutate(event_number = as.character(event_number))

# --- CHECK: row count and columns ---
nrow(police_fy26)                             # 23118
setequal(names(police_fy26), names(police))   # TRUE -- same columns as Part A

# --- CHECK: missing values ---
police_fy26 %>% summarize(across(everything(), ~ sum(is.na(.))))
# Result: 0 missing in every column except first_unit_arrived_time (4591)

# --- CHECK: duplicates ---
n_distinct(police_fy26$event_number) == nrow(police_fy26)  # TRUE

# --- CHECK: no overlap with Part A ---
# The two periods are adjacent (Part A ends June 30, 2025). Part A had 376
# duplicates at a file boundary, so check this one too.
sum(police_fy26$event_number %in% as.character(police_clean$event_number))  # 0

# ============================================================
# PHASE B1 -- TEXT CLEANING & DATE HANDLING
# ============================================================

# --- CHECK: date format ---
class(police_fy26$received_date)  # "POSIXct" "POSIXt" -- already a date-time

# Part A timestamps were recorded to the minute. This export has seconds.
# Rounding down to the minute keeps FY 2025-26 response times measured on
# the same basis as 2019-2025, rather than looking slightly different just
# because the clock is finer.
police_fy26 <- police_fy26 %>%
  mutate(
    call_for_service = str_squish(call_for_service),
    address = str_squish(address),
    dt = floor_date(received_date, "minute"),
    arrived_dt = floor_date(first_unit_arrived_time, "minute")
  )

# --- CHECK: date range ---
range(police_fy26$dt)  # 2025-07-01 00:18 to 2026-06-30 23:23

# ============================================================
# PHASE B2 -- CALL-TYPE CONSISTENCY WITH PART A
# The crime allow-list is matched by exact text. If the department renamed
# a category, those incidents would silently fall out of the crime scope.
# ============================================================

new_call_types <- setdiff(unique(police_fy26$call_for_service),
                          unique(police_clean$call_for_service))

# --- CHECK: call types not seen in Part A ---
police_fy26 %>%
  filter(call_for_service %in% new_call_types) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 50)
# Result: 3 new types.
#   ONLINE - REFERRED TO ONLINE REPORT (28)   -- not a crime category
#   10852 - VEHICLE PARTS THEFT (11)          -- typo corrected, see below
#   HOSP - HOSPITAL TRANSPORTATION (1)        -- not a crime category

# --- CHECK: the allow-list uses the old misspelling ---
"10852 - vehcile parts theft" %in% incident_types  # TRUE

# The department corrected a typo in this export ("VEHCILE" -> "VEHICLE").
# Accept both spellings so the category is counted in both periods.
incident_types      <- union(incident_types,      "10852 - vehicle parts theft")
vehicle_crime_types <- union(vehicle_crime_types, "10852 - vehicle parts theft")

df_filtered_fy26 <- police_fy26 %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

nrow(df_filtered_fy26)                                       # 5491 (5480 before typo fix)
round(100 * nrow(df_filtered_fy26) / nrow(police_fy26), 1)   # 23.8 -- vs Part A's 27.8%

# ============================================================
# PHASE B3 -- ADDRESS NORMALIZATION
# Three address formats appear in this export:
#   el cerrito  "11645 SAN PABLO AVE, at KNOTT AVE (...), EL CERRITO, CA, 94530"
#   other city  "..., RICHMOND, CA, ..."  (Richmond, Albany, Berkeley, etc.)
#   shorthand   "SPA/BRIGHTON", "HARDING PARK" -- the old Part A style
# Build one clean geocoding string per record. The street is the text
# before the first comma; the rest is repetition or cross-street notes.
# ============================================================

police_fy26 <- police_fy26 %>%
  mutate(
    address_format = case_when(
      str_detect(address, ", EL CERRITO, CA") ~ "el cerrito",
      str_detect(address, ", CA")             ~ "other city",
      TRUE                                    ~ "shorthand"
    ),
    street = str_trim(str_extract(address, "^[^,]+")),
    city   = str_match(address, ", ([A-Z ]+), CA")[, 2],
    geocode_address = case_when(
      address_format == "el cerrito" ~ paste0(street, ", El Cerrito, CA 94530"),
      address_format == "other city" & city != "COUNTY" ~ paste0(street, ", ", str_to_title(city), ", CA"),
      address_format == "other city" ~ paste0(street, ", CA ", str_extract(address, "\\d{5}$")),  # unincorporated -- use ZIP instead of city
      TRUE ~ street %>%
        str_replace_all("\\bSPA\\b", "San Pablo Ave") %>%   # same expansions as Part A Phase 5
        str_replace_all("\\bPOT\\b", "Potrero Ave") %>%
        str_replace_all("/", " & ") %>%
        paste0(", El Cerrito, CA 94530")
    ),
    geocode_address = str_squish(geocode_address)   # "BART PATH / PORTOLA" had produced doubled spaces
  )

# --- CHECK: format counts ---
police_fy26 %>% count(address_format)
# Result: 21698 el cerrito / 523 other city / 897 shorthand

# --- CHECK: normalization reduces unique addresses ---
n_distinct(police_fy26$address)           # 7234 raw
n_distinct(police_fy26$geocode_address)   # 5185 to geocode

# --- CHECK: county (unincorporated) rows carry a ZIP ---
police_fy26 %>%
  filter(city == "COUNTY") %>%
  distinct(geocode_address) %>%
  head(5)
# Result: e.g. "38 AVON RD, CA 94707"

# --- CHECK: spot-check the transformation, 5 per format ---
police_fy26 %>%
  distinct(address_format, address, geocode_address) %>%
  group_by(address_format) %>%
  slice_sample(n = 5) %>%
  print(n = 15)

# --- CHECK: most common shorthand entries ---
police_fy26 %>%
  filter(address_format == "shorthand") %>%
  count(street, sort = TRUE) %>%
  print(n = 25)
# Result: mostly SPA/cross-street shorthand, plus named places (HARDING
# PARK, ECPD, EL CERRITO PLAZA, MDF, SAFEWAY). Named places can't be placed
# from street text; B5's imprecise-location rule excludes them from maps.

# ============================================================
# PHASE B4 -- GEOCODING: FY 2025-26 INCIDENTS (long-running, ~1 hour)
# Part A's hardest lesson applied from the start: every request carries
# the Bay Area searchExtent, so no Panama-style global matches.
# The loop is commented out. Uncomment to run or resume from checkpoint.
# ============================================================

geocode_fy26_path <- file.path(output_dir, "geocode_checkpoint_fy26.csv")

unique_addresses_fy26 <- police_fy26 %>% distinct(geocode_address)
nrow(unique_addresses_fy26)  # 5185

# if (file.exists(geocode_fy26_path)) {
#   already_done <- read_csv(geocode_fy26_path, show_col_types = FALSE)
#   to_geocode <- unique_addresses_fy26 %>% anti_join(already_done, by = "geocode_address")
# } else {
#   to_geocode <- unique_addresses_fy26
# }
#
# chunk_size <- 500
# n_chunks <- ceiling(nrow(to_geocode) / chunk_size)
#
# geocode_chunk <- function(chunk) {
#   chunk %>% geocode(geocode_address, method = "arcgis", lat = lat, long = long,
#                     custom_query = list(searchExtent = bay_area_extent))
# }
#
# for (i in seq_len(n_chunks)) {
#   start_row <- (i - 1) * chunk_size + 1
#   end_row <- min(i * chunk_size, nrow(to_geocode))
#   chunk <- to_geocode[start_row:end_row, ]
#   result <- tryCatch(
#     geocode_chunk(chunk),
#     error = function(e) { Sys.sleep(30); tryCatch(geocode_chunk(chunk), error = function(e2) NULL) }
#   )
#   if (!is.null(result)) write_csv(result, geocode_fy26_path, append = file.exists(geocode_fy26_path))
#   message("Chunk ", i, " of ", n_chunks, " done")
#   Sys.sleep(2)
# }

# ============================================================
# PHASE B5 -- GEOCODING QA
# Three exclusion rules, applied in order:
#   1. Distance  -- no coordinate, or more than 5 miles from El Cerrito
#                   (the threshold Part A settled on in Phase 10)
#   2. Fallback  -- a generic point ArcGIS used for many unmatched strings
#   3. Imprecise -- no house number and no cross street, so only a
#                   generic point on one street is possible
# ============================================================

geocoded_fy26 <- read_csv(geocode_fy26_path, show_col_types = FALSE)

# --- CHECK: every address was geocoded ---
nrow(geocoded_fy26) == nrow(unique_addresses_fy26)  # TRUE

# --- Rule 1: distance ---
police_fy26_geocoded <- police_fy26 %>%
  left_join(geocoded_fy26, by = "geocode_address") %>%
  mutate(
    dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34,
    BAD_LATLON_FLAG = is.na(lat) | dist_from_ec_mi > 5
  )

# --- CHECK: join did not add rows ---
nrow(police_fy26_geocoded)  # 23118

# --- CHECK: distance-rule failures by format ---
police_fy26_geocoded %>%
  count(address_format, BAD_LATLON_FLAG) %>%
  group_by(address_format) %>%
  mutate(pct = round(100 * n / sum(n), 1))
# Result: el cerrito 100% pass; other city 85 fail (16.3%); shorthand 100%
# pass. The 100% shorthand pass rate was suspicious -- see rule 2.

# --- CHECK: which cities fail the distance rule ---
police_fy26_geocoded %>%
  filter(BAD_LATLON_FLAG) %>%
  count(city, sort = TRUE)
# Result: Martinez 24, San Francisco 10, Oakland 7, Pinole 5, ... -- real
# locations outside El Cerrito, correctly excluded. Not geocoding errors.

# --- Rule 2: fallback points ---
# When ArcGIS cannot match the text, the Bay Area search extent stops it
# from guessing a distant place (Part A's Panama problem), but it can
# still drop the address on a generic local point that passes the 5-mile
# test. Detected as a single coordinate shared by 20+ different address
# strings -- a real location has one address, or a few spelling variants
# at an intersection.

# --- CHECK: coordinates shared by many different addresses ---
police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat, long) %>%
  summarize(n_addresses = n_distinct(geocode_address),
            n_rows = n(),
            example = first(geocode_address),
            .groups = "drop") %>%
  arrange(desc(n_addresses)) %>%
  head(10)
# Result: two points stand out -- 80 different addresses on one point
# (114 rows) and 21 on another (43 rows). Next largest is 12, a real
# intersection with spelling variants.

# --- CHECK: what's on the two fallback points ---
police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat, long) %>%
  filter(n_distinct(geocode_address) >= 20) %>%
  ungroup() %>%
  distinct(lat, long, geocode_address) %>%
  print(n = 40)
# Result: 101 unmatched strings -- "ECPD", "MDF", "24 HOUR", "SPIRIT
# STORE", "DEL NORTE BART", typos like "JACK N BOX & CUJTTING". Confirmed
# fallbacks.

fallback_coords <- police_fy26_geocoded %>%
  filter(!is.na(lat)) %>%
  group_by(lat, long) %>%
  summarize(n_addresses = n_distinct(geocode_address), .groups = "drop") %>%
  filter(n_addresses >= 20) %>%
  transmute(lat, long, FALLBACK_FLAG = TRUE)

nrow(fallback_coords)  # 2

police_fy26_geocoded <- police_fy26_geocoded %>%
  left_join(fallback_coords, by = c("lat", "long")) %>%
  mutate(
    FALLBACK_FLAG   = coalesce(FALLBACK_FLAG, FALSE),
    BAD_LATLON_FLAG = BAD_LATLON_FLAG | FALLBACK_FLAG
  )

sum(police_fy26_geocoded$FALLBACK_FLAG)  # 157

# --- Rule 3: imprecise locations ---

# --- CHECK: smaller shared points (5+ addresses) ---
# The 20-address rule catches big pileups only. Review smaller ones by eye.
suspect_coords <- police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat, long) %>%
  summarize(n_addresses = n_distinct(geocode_address),
            n_rows = n(),
            addresses = paste(unique(geocode_address), collapse = " | "),
            .groups = "drop") %>%
  filter(n_addresses >= 5) %>%
  arrange(desc(n_addresses))

nrow(suspect_coords)  # 35
# View(suspect_coords)   # interactive review
# Result: most are real intersections with spelling variants. The bad
# ones share a pattern -- when only one street name can be matched, the
# address is dropped at a single spot on that street. E.g. "KEARNEY ST",
# "WALL KEARNEY", "KEARNEY SO POTRERO" all stacked at Kearney & Fairmount.

# --- CHECK: example at full precision ---
police_fy26_geocoded %>%
  filter(str_detect(geocode_address, "WALL")) %>%
  distinct(geocode_address, lat, long) %>%
  as.data.frame()
# Result: "WALL KEARNEY" placed ~2 miles from the correct match for
# "WALL AVE & KEARNEY ST"; "WALL AVE OHLONE GREEN" ~2.3 miles from
# "OHLONE GREENWAY & WALL AVE". Both pass the 5-mile rule.

# Addresses with no house number and no cross street ("KEARNEY ST",
# "KEY HUM", "WALL KEARNEY") can only be placed at a generic point on one
# street. Excluded from maps and landmark counts. " AND " and "@" count as
# cross-street separators so "CARLSON AND EL DORADO" is not flagged.
police_fy26_geocoded <- police_fy26_geocoded %>%
  mutate(
    IMPRECISE_FLAG  = !str_detect(street, "^\\d") &
                      !str_detect(geocode_address, " & | AND |@"),
    BAD_LATLON_FLAG = BAD_LATLON_FLAG | IMPRECISE_FLAG
  )

# --- CHECK: imprecise flags by format ---
police_fy26_geocoded %>% count(address_format, IMPRECISE_FLAG)
# Result: 214 el cerrito, 5 other city, 215 shorthand -- 434 total

# --- CHECK: what the imprecise rule caught ---
police_fy26_geocoded %>%
  filter(IMPRECISE_FLAG) %>%
  count(street, sort = TRUE) %>%
  print(n = 30)
# Result: OHLONE GREENWAY 99 (a linear trail -- no single point; handled
# by address text in B13), HARDING PARK 57, ECPD 22, EL CERRITO PLZ/PLAZA
# 30, bare street names. All named places caught.
#
# Known limitation: badly abbreviated cross streets ("KEY & CUT",
# "SAN P & CENTRAL", "HIIL & KEARNY") look like intersections and pass.

# --- CHECK: final QA totals ---
police_fy26_geocoded %>%
  summarize(total = n(),
            fallback = sum(FALLBACK_FLAG),
            imprecise = sum(IMPRECISE_FLAG),
            usable = sum(!BAD_LATLON_FLAG),
            pct_usable = round(100 * usable / total, 1))
# Result: 23118 total, 157 fallback, 434 imprecise, 22532 usable (97.5%)

incidents_for_proximity_fy26 <- police_fy26_geocoded %>% filter(!BAD_LATLON_FLAG)
nrow(incidents_for_proximity_fy26)   # 22532 (97.5%) -- vs Part A's 96.9%

police_total_fy26 <- incidents_for_proximity_fy26 %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

# ============================================================
# PHASE B6 -- COMBINED DATASET, FISCAL-YEAR BASIS
# The new data covers a fiscal year (July-June), the city's budget year.
# Relabeling all 2019-2026 records by fiscal year gives six full,
# like-for-like years to compare against FY 2025-26. FY 2018-19 is only
# Jan-Jun 2019, so it is dropped from fiscal-year comparisons.
# ============================================================

fiscal_year <- function(x) if_else(month(x) >= 7, year(x) + 1, year(x))
fy_label <- function(fy) paste0("FY ", fy - 1, "-", str_sub(fy, 3, 4))

police_all <- bind_rows(
  police_clean_dated %>%
    transmute(event_number = as.character(event_number), call_for_service, address, dt,
              arrived_dt = parse_date_time(first_unit_arrived_time, orders = "mdy HM"),
              source = "PDF reports (2019 - Jun 2025)"),
  police_fy26 %>%
    transmute(event_number, call_for_service, address, dt, arrived_dt,
              source = "Excel export (FY 2025-26)")
) %>%
  mutate(fy = fiscal_year(dt), fy_label = fy_label(fy)) %>%
  filter(fy >= 2020)

# --- CHECK: combined totals by fiscal year ---
nrow(police_all)  # 146818 (137194 + 23118, less Jan-Jun 2019)
police_all %>% count(fy_label, source)
# Result: 23015 / 17964 / 16489 / 18011 / 23167 / 25054 / 23118
#         (FY 2019-20 through FY 2025-26)

# ============================================================
# PHASE B7 -- WORKLOAD: FY 2025-26 (compare to Phase 9)
# ============================================================

workload_summary_fy26 <- police_fy26 %>%
  count(call_for_service, sort = TRUE) %>%
  mutate(in_crime_scope = str_to_lower(call_for_service) %in% incident_types,
         pct_of_total = round(100 * n / sum(n), 1))

workload_summary_fy26 %>% print(n = 15)
# Result: large shift in what gets logged.
#   Traffic stops    13.4% (2019-25) -> 25.8% (FY 2025-26), now #1
#   Security checks  17.0%           ->  5.2%
#   Call transfers    2.9%           ->  8.7%
# Could be real changes in policing or changes in recording -- the data
# can't say which, and the export format also changed. Report as changes
# in what was logged, not in what officers did.

# ============================================================
# PHASE B8 -- CRIME-SCOPE TREND BY FISCAL YEAR (compare to Phase 14)
# ============================================================

fy_totals <- police_all %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  count(fy, fy_label, name = "incidents")
fy_totals
# Result: 6414 / 5038 / 5179 / 5481 / 6250 / 6587 / 5491
# FY 2025-26 down ~17% from FY 2024-25; third-lowest of seven years.
# Parking violations are on the allow-list and also fell -- consider
# showing crime with parking separated out (parking gets its own section).

# ============================================================
# PHASE B9 -- LANDMARK PROXIMITY: FY 2025-26 (compare to Phases 8 & 12)
# Reuses Part A's landmarks and compute_landmark_counts() unchanged.
# ============================================================

# --- CHECK: how the export redacts sensitive calls ---
police_fy26 %>%
  filter(str_detect(str_to_lower(call_for_service),
                    "juv|261|288|243.4|5150|1056|suicide|medical")) %>%
  count(call_for_service, street, sort = TRUE) %>%
  print(n = 30)
# Result: addresses rounded to the block ("10900 SAN PABLO AVE",
# "3400 CARLSON BLVD"), not removed. Not applied to every sensitive call
# -- some juvenile calls show exact school addresses (7125 DONAL AVE,
# 540 ASHBURY AVE). Stated as observed, not as department policy.

# --- CHECK: which types Part A was missing addresses for ---
# Part A had no address for sensitive call types, so they never appeared
# on its maps. To keep the periods comparable, exclude the same types here.
police_clean %>%
  group_by(call_for_service) %>%
  summarize(n = n(), pct_no_address = round(100 * mean(is.na(address)), 1)) %>%
  filter(pct_no_address > 0) %>%
  arrange(desc(pct_no_address)) %>%
  print(n = 30)
# Result: 17 types, all 92-100% missing (deaths, suicide, sexual assault,
# domestic battery, child and elder abuse, juvenile calls, 5150).
# None are on the crime allow-list, so crime-scope counts are unaffected.

part_a_redacted_types <- police_clean %>%
  group_by(call_for_service) %>%
  summarize(pct_no_address = mean(is.na(address))) %>%
  filter(pct_no_address >= 0.9) %>%
  pull(call_for_service)

length(part_a_redacted_types)  # 17

incidents_for_landmarks_fy26 <- incidents_for_proximity_fy26 %>%
  filter(!call_for_service %in% part_a_redacted_types)

nrow(incidents_for_landmarks_fy26)  # 22188

# --- All activity within 500 ft ---
# Part A covers 6.5 years (Jan 2019 - Jun 2025). Dividing its counts by
# 6.5 gives a per-year figure comparable to one fiscal year.
landmark_counts_fy26 <- compute_landmark_counts(incidents_for_landmarks_fy26, "fy_2025_26") %>%
  left_join(landmark_counts %>%
              transmute(landmark, per_year_2019_25 = round(n_within_500ft / 6.5)),
            by = "landmark") %>%
  arrange(desc(fy_2025_26))

landmark_counts_fy26
# Result after 7B (FY 2025-26 vs 2019-25 per year): Del Norte BART 359 vs
# 147 (2.4x), EC Plaza BART 343 vs 354, Library 248 vs 152 (+63%),
# Community Center 247 vs 283, ECHS 176 vs 192, Harding 161 vs 121,
# Castro Park 54 vs 56, Madera 48 vs 81 (-41%), Korematsu 44 vs 45.
# Pre-7B comparison (FY 2025-26 vs 2019-25 per year): Del Norte BART 359
# vs 86, EC Plaza BART 343 vs 354, Library 248 vs 158, Community Center
# 247 vs 277, ECHS 176 vs 190, Harding 161 vs 121, Castro Park 54 vs 56,
# Madera 48 vs 81, Korematsu 44 vs 45. After 7B the Part A per-year
# figures change for Del Norte (953/6.5 = 147), Community Center (283),
# ECHS (192), Library (152).

# --- Crime-scope incidents within 500 ft, by category ---
police_vehicle_crime_fy26     <- police_total_fy26 %>% filter(str_to_lower(call_for_service) %in% vehicle_crime_types)
police_dangerous_driving_fy26 <- police_total_fy26 %>% filter(str_to_lower(call_for_service) %in% dangerous_driving_types)
police_other_crime_fy26       <- police_total_fy26 %>% filter(!(str_to_lower(call_for_service) %in% c(vehicle_crime_types, dangerous_driving_types)))

landmark_comparison_fy26 <- compute_landmark_counts(police_vehicle_crime_fy26, "vehicle_crime") %>%
  left_join(compute_landmark_counts(police_dangerous_driving_fy26, "dangerous_driving"), by = "landmark") %>%
  left_join(compute_landmark_counts(police_other_crime_fy26, "other_crime"), by = "landmark") %>%
  mutate(total = vehicle_crime + dangerous_driving + other_crime) %>%
  left_join(landmark_comparison %>%
              transmute(landmark, total_per_year_2019_25 = round(total / 6.5)),
            by = "landmark") %>%
  arrange(desc(total))

landmark_comparison_fy26
# Result after 7B (FY 2025-26 total vs 2019-25 per year): Del Norte BART
# 101 vs 40, Library 85 vs 45, EC Plaza BART 66 vs 63, ECHS 63 vs 51,
# Community Center 56 vs 59, Harding 26 vs 34, Castro Park 11 vs 14,
# Korematsu 6 vs 10, Madera 6 vs 10.
# One year of data -- small counts per landmark, so frame as "consistent
# / not consistent with 2019-2025," not new rankings.

# --- CHECK: what's being counted near Del Norte BART ---
# Pre-7B, Del Norte BART looked ~4x its 2019-2025 rate. This check led to
# the Phase 7B finding.
del_norte <- landmarks_geocoded %>% filter(landmark == "Del Norte BART")

near_del_norte <- incidents_for_landmarks_fy26 %>%
  mutate(dist_ft = distHaversine(cbind(long, lat), c(del_norte$long, del_norte$lat)) / 0.3048) %>%
  filter(dist_ft <= RADIUS_FT)

near_del_norte %>% count(street, sort = TRUE) %>% print(n = 15)
near_del_norte %>% count(call_for_service, sort = TRUE) %>% print(n = 15)
# Result: 120 records at 6400 CUTTING BLVD (the station itself). Top call
# types: traffic stops 98, parking 80, call transfers 77.

near_del_norte %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 10)
# Result: parking is 80 of the 101 crime-scope incidents near Del Norte BART.

# --- CHECK: how Part A recorded the station ---
police_clean %>%
  filter(str_detect(address, "DEL NORTE|6400 CUTTING")) %>%
  count(address, sort = TRUE) %>%
  print(n = 20)
# Result: ~415 records at 6400 CUTTING, mostly with a cross-street
# ("6400 CUTTING BLVD, SAN PABLO AVE & KEARNEY ST, ..."). Where Part A
# placed those is the Phase 7B finding.

# --- CHECK: what changed near a landmark, by call type (per year) ---
# Compares Part A's per-year rate (corrected coordinates, 6.5 years) with
# FY 2025-26, call type by call type, within 500 ft of one landmark.
# Sorted by the size of the change.
compare_landmark_calls <- function(lm_name, top_n = 12) {
  lm <- landmarks_geocoded %>% filter(landmark == lm_name)
  near <- function(df) {
    df %>%
      mutate(d_ft = distHaversine(cbind(long, lat), c(lm$long, lm$lat)) / 0.3048) %>%
      filter(d_ft <= RADIUS_FT)
  }
  part_a <- near(incidents_for_proximity) %>%
    count(call_for_service, name = "part_a_total") %>%
    mutate(per_year_2019_25 = round(part_a_total / 6.5, 1))
  fy26 <- near(incidents_for_landmarks_fy26) %>%
    count(call_for_service, name = "fy_2025_26")
  full_join(part_a, fy26, by = "call_for_service") %>%
    mutate(across(c(part_a_total, per_year_2019_25, fy_2025_26), ~ coalesce(.x, 0)),
           change = fy_2025_26 - per_year_2019_25) %>%
    arrange(desc(abs(change))) %>%
    select(call_for_service, per_year_2019_25, fy_2025_26, change) %>%
    head(top_n)
}

compare_landmark_calls("Del Norte BART")
compare_landmark_calls("Library")
compare_landmark_calls("Madera")
# Result: changes are officer-initiated or administrative, not reported
# crime.
#   Del Norte BART: traffic stops 23 -> 98, parking 10 -> 80, call
#     transfers 19 -> 77, 911 disconnects 13 -> 26; assault/battery 2.5 -> 0.
#   Library: parking 15 -> 52, security checks 21.5 -> 43 (while falling
#     citywide), traffic stops 9 -> 28, call transfers 5 -> 19.
#   Madera: security checks 42 -> 18 (matches citywide drop).

# ============================================================
# PHASE B10 -- HEATMAP: FY 2025-26 (compare to Phase 11)
# Same map settings as Part A so the two maps can sit side by side.
# ============================================================

ggplot() +
  annotation_map_tile(type = "osm", zoomin = 0) +
  stat_density_2d(data = police_total_fy26, aes(x = long, y = lat, fill = after_stat(level)), geom = "polygon", contour = TRUE, alpha = 0.5, bins = 25) +
  scale_fill_gradient(low = "yellow", high = "red", breaks = range, labels = c("Fewer incidents", "More incidents")) +
  geom_point(data = landmarks_geocoded, aes(x = long, y = lat), color = "black", size = 2.5, shape = 17) +
  geom_label_repel(data = landmarks_geocoded, aes(x = long, y = lat, label = landmark), size = 2.8, fontface = "bold", label.padding = 0.15, label.size = 0, fill = alpha("white", 0.75), min.segment.length = 0, max.overlaps = Inf) +
  coord_sf(xlim = c(EC_MAP_LONG_MIN, EC_MAP_LONG_MAX), ylim = c(EC_MAP_LAT_MIN, EC_MAP_LAT_MAX), crs = 4326) +
  labs(title = "El Cerrito Crime-Scope Incident Density, FY 2025-26", fill = NULL) +
  theme_minimal() + theme(axis.title = element_blank())

# ============================================================
# PHASE B11 -- PARKING ENFORCEMENT (compare to Phases 15 & 17)
# Did the step-change pattern continue? Is enforcement concentrating
# near the Plaza?
# ============================================================

parking_fy <- police_all %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION") %>%
  count(fy, fy_label, name = "parking_violations")
parking_fy
# Result: 702 / 610 / 863 / 1054 / 1519 / 2317 / 1931 (FY 2019-20 to
# FY 2025-26). More than tripled to FY 2024-25, then down 17% -- first
# decline after four straight increases. Still 2.75x FY 2019-20.

parking_plaza_fy26 <- police_fy26_geocoded %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION", !BAD_LATLON_FLAG) %>%
  mutate(dist_to_plaza_ft = distHaversine(cbind(long, lat), c(ec_plaza_bart$long, ec_plaza_bart$lat)) / 0.3048) %>%
  summarize(
    total_geocoded = n(),
    near_plaza_1000ft = sum(dist_to_plaza_ft <= 1000),
    pct_near_plaza_1000ft = round(100 * near_plaza_1000ft / total_geocoded, 1)
  )
parking_plaza_fy26
# Result: 196 of 1894 geocoded (10.3%). Within Part A's calendar-year
# range (5.7%-11.7%), toward the top. Not strictly like-for-like
# (fiscal vs calendar year) -- state as "within the historical range".

# ============================================================
# PHASE B12 -- RESPONSE TIME BY FISCAL YEAR (compare to Phase 16)
# Same exclusions as Part A: no multi-day entries, no negative values,
# and self-initiated categories removed for the trend line.
# ============================================================

response_fy <- police_all %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  mutate(response_min = as.numeric(difftime(arrived_dt, dt, units = "mins"))) %>%
  filter(!is.na(response_min), response_min >= 0, response_min < 1440)

response_fy %>%
  filter(fy == 2026) %>%
  summarize(n = n(), median_min = median(response_min),
            p90_min = round(quantile(response_min, 0.9), 1))
# Result: n 5192, median 3, 90th percentile 22. Part A: median 5, p90 25.
# (All crime-scope incl. self-initiated -- affected by call mix.)

response_fy %>%
  filter(!str_to_lower(call_for_service) %in% self_initiated_types) %>%
  group_by(fy_label) %>%
  summarize(median_min = median(response_min), n = n())
# Result: 8 / 8 / 8 / 9 / 8 / 7 / 6 (FY 2019-20 to FY 2025-26). FY 2025-26
# lowest of seven years -- see mix check below.

response_fy %>%
  filter(fy == 2026, str_to_lower(call_for_service) %in% urgent_types) %>%
  group_by(call_for_service) %>%
  summarize(median_min = median(response_min), n = n()) %>%
  arrange(desc(median_min))
# Result: active-danger types 2-5 min (shots fired 5, robbery 4, ADW 3),
# but n = 1-15 per type. Report the group, not individual types.

# --- CHECK: is the FY 2025-26 speedup broad, or a change in call mix? ---
# Compares median response by call type, FY 2024-25 vs FY 2025-26, for
# call-and-respond types with enough cases in both years.
response_fy %>%
  filter(!str_to_lower(call_for_service) %in% self_initiated_types,
         fy %in% c(2025, 2026)) %>%
  group_by(call_for_service) %>%
  filter(sum(fy == 2025) >= 30, sum(fy == 2026) >= 30) %>%
  group_by(call_for_service, fy_label) %>%
  summarize(median_min = median(response_min), n = n(), .groups = "drop") %>%
  pivot_wider(names_from = fy_label, values_from = c(median_min, n)) %>%
  arrange(desc(`n_FY 2025-26`)) %>%
  print(n = 20)
# Result: of 14 types, 6 faster (grand theft 12 -> 8, criminal threats
# 13 -> 10, auto burglary 9.5 -> 7, vehicle theft 13 -> 11, disturbance
# 8 -> 7, petty theft 8 -> 7.5), 5 unchanged, 3 slower (residential
# burglary 10.5 -> 14, vandalism 8 -> 9, trespassing 6 -> 7). Fewer slow
# report-type calls also pull the median down. Partly real, partly mix;
# one year is not a trend.

# ============================================================
# PHASE B13 -- OHLONE GREENWAY
# Based on address text, not geocoding: the greenway is a long linear
# trail, and 99 incidents are logged only as "OHLONE GREENWAY" with no
# point location. Two buckets:
#   on greenway      -- the street field itself names the greenway:
#                       "OHLONE" ("OHLONE GREENWAY", "MANILA AVE & OHLONE
#                       TRL") or "BART PATH" -- the department's other name
#                       for the greenway, which runs under the BART tracks
#                       (confirmed by project owner). "BATH PATH" is a
#                       typo seen in the data.
#   next to greenway -- a house address with the greenway noted only as
#                       a cross-street ("6543 PORTOLA DR, at OHLONE TRL")
# Limitation: "next to" catches only records where the department noted
# the greenway as a cross-street. It is not a distance-based measure,
# which would need a map outline of the trail.
# Same rules applied to both periods, so 2019-25 and FY 2025-26 compare.
# ============================================================

GREENWAY_NAMES <- "OHLONE|BART PATH|BATH PATH"

greenway_bucket <- function(address) {
  street <- str_trim(str_extract(address, "^[^,]+"))
  case_when(
    str_detect(street, GREENWAY_NAMES)  ~ "on greenway",
    str_detect(address, GREENWAY_NAMES) ~ "next to greenway",
    TRUE                                ~ "elsewhere"
  )
}

# --- CHECK: every address form that names the greenway, FY 2025-26 ---
police_fy26 %>%
  filter(str_detect(address, GREENWAY_NAMES)) %>%
  count(street, sort = TRUE) %>%
  print(n = 100)
# Result with "OHLONE" only: 97 distinct forms -- "OHLONE GREENWAY" (99),
# intersections with OHLONE TRL / OHLONE GREENWAY, shorthand
# ("WALL/OHLONE", "POT/OHLONE"), and house addresses ("6543 PORTOLA DR")
# where the greenway appears only as a cross-street note.
# With BART PATH added: 105 forms -- adds 8 BART PATH / BATH PATH rows.

# --- CHECK: BART PATH forms in both periods ---
bind_rows(
  police_clean %>% filter(!is.na(address)) %>% transmute(period = "2019-25", address),
  police_fy26 %>% transmute(period = "FY 2025-26", address)
) %>%
  filter(str_detect(address, "BART PATH|BATH PATH")) %>%
  count(period, address, sort = TRUE) %>%
  print(n = 30)
# Result: 241 distinct forms. "BART PATH" was the department's usual
# name for the greenway in 2019-25 (e.g. "BART PATH" 174, "BART PATH AND
# HILL STREET" 45, "BEAT 10 BART PATH" 27) but is nearly gone in FY 2025-26
# (8 rows), where "OHLONE" is used instead. A naming change -- which is
# why the "OHLONE only" comparison below was wrong.

police_fy26 <- police_fy26 %>%
  mutate(greenway = greenway_bucket(address))

police_fy26 %>% count(greenway)
# Result with "OHLONE" only: 336 on greenway, 45 next to, 22737 elsewhere.
# With BART PATH added: 344 on greenway, 45 next to, 22729 elsewhere.

# --- CHECK: the "next to" bucket is house addresses with a greenway note ---
police_fy26 %>%
  filter(greenway == "next to greenway") %>%
  distinct(address) %>%
  slice_sample(n = 8) %>%
  as.data.frame()
# Result (OHLONE only): e.g. "6530 SCHMIDT LN, OHLONE TRL & LIBERTY ST ..."

# What gets reported in each bucket
police_fy26 %>%
  filter(greenway != "elsewhere") %>%
  count(greenway, call_for_service, sort = TRUE) %>%
  group_by(greenway) %>%
  slice_head(n = 12) %>%
  print(n = 24)
# Result (OHLONE only): on greenway mostly officer-initiated -- security
# checks 64, pedestrian stops 62, foot patrol 30, traffic stops 19,
# parking 14, bike stops 11. Public calls small: disturbance 9, welfare 9.
# With BART PATH added: nearly the same -- security checks 66, pedestrian
# stops 65, foot patrol 30, traffic stops 20.

# --- Greenway: FY 2025-26 vs 2019-25 per year ---
greenway_both <- bind_rows(
  police_clean %>% filter(!is.na(address)) %>%
    transmute(call_for_service, address, period = "per_year_2019_25", w = 1 / 6.5),
  police_fy26 %>%
    transmute(call_for_service, address, period = "fy_2025_26", w = 1)
) %>%
  mutate(greenway = greenway_bucket(address))

# --- CHECK: totals per bucket, per year ---
greenway_both %>%
  filter(greenway != "elsewhere") %>%
  group_by(greenway, period) %>%
  summarize(n = round(sum(w), 1), .groups = "drop") %>%
  pivot_wider(names_from = period, values_from = n)
# Result (OHLONE only): on greenway 158/yr -> 336; next to 45 -> 45
# (unchanged, a useful control against an address-format effect).
# With BART PATH added: on greenway 276/yr -> 344 (+25%), not 2.1x.
# CORRECTION: the earlier "more than doubled" was an artifact of the
# department switching from "BART PATH" to "OHLONE" in its addresses.

# --- CHECK: on-greenway call types, both periods ---
greenway_both %>%
  filter(greenway == "on greenway") %>%
  group_by(call_for_service, period) %>%
  summarize(n = round(sum(w), 1), .groups = "drop") %>%
  pivot_wider(names_from = period, values_from = n, values_fill = 0) %>%
  arrange(desc(fy_2025_26)) %>%
  print(n = 15)
# Result (OHLONE only, 2019-25 per year -> FY 2025-26): pedestrian stops
# 9 -> 62, foot patrol 2.5 -> 30, security checks 39 -> 64, bike stops
# 2 -> 11, traffic stops 8 -> 19, parking 3 -> 14. Public calls:
# disturbance 6 -> 9, welfare 5 -> 9, unwanted 3 -> 7, suspicious person
# 10.5 -> 6.
# With BART PATH added (2019-25 per year -> FY 2025-26): security checks
# 128 -> 66 (down), pedestrian stops 22 -> 65, foot patrol 3.4 -> 30,
# traffic stops 12 -> 20, parking 3.5 -> 14, bike stops 2.3 -> 11. Public
# calls: disturbance 6.5 -> 9, welfare 5 -> 9, unwanted 3.4 -> 7,
# suspicious person 11 -> 6. The mix shifted from security checks to
# stops and foot patrol.

# --- CHECK: on-greenway incidents by fiscal year ---
# "Officer-initiated" here = security checks, pedestrian/traffic/bike
# stops, foot patrol, parking. A working definition for this check, not a
# department category.
officer_initiated_types <- c("1059 - SECURITY CHECK", "1194 - PEDESTRIAN STOP",
                             "FOOTP - FOOT PATROL - MISCELLANEOUS", "1195 - TRAFFIC STOP",
                             "1195B - BIKE STOP", "PARKER - PARKING VIOLATION")

police_all %>%
  filter(!is.na(address)) %>%
  mutate(greenway = greenway_bucket(address)) %>%
  filter(greenway == "on greenway") %>%
  mutate(type = if_else(call_for_service %in% officer_initiated_types,
                        "officer_initiated", "other")) %>%
  count(fy_label, type) %>%
  pivot_wider(names_from = type, values_from = n, values_fill = 0) %>%
  mutate(total = officer_initiated + other)
# Result (OHLONE only; officer-initiated / other / total):
#   FY 2019-20 143/81/224, FY 2020-21 56/86/142, FY 2021-22 51/77/128,
#   FY 2022-23 37/95/132, FY 2023-24 70/93/163, FY 2024-25 42/137/179,
#   FY 2025-26 200/136/336.
# With BART PATH added (officer-initiated / other / total):
#   FY 2019-20 393/102/495, FY 2020-21 105/93/198, FY 2021-22 98/86/184,
#   FY 2022-23 56/98/154, FY 2023-24 80/94/174, FY 2024-25 48/137/185,
#   FY 2025-26 206/138/344.
# Officer-initiated activity was highest in FY 2019-20, fell sharply,
# stayed low for five years, then rose ~4x in FY 2025-26 (48 -> 206) --
# still about half the FY 2019-20 level. Other calls ran ~86-102 a year
# through FY 2023-24, then ~137 in both of the last two years.

# --- CHECK: did greenway patrol drop when COVID began (March 2020)? ---
# Monthly officer-initiated activity on the greenway, Jan 2019 - Dec 2021.
# Uses Part A only (starts Jan 2019); same greenway names and
# officer-initiated definition as above.
greenway_monthly <- police_clean_dated %>%
  filter(!is.na(address)) %>%
  mutate(greenway = greenway_bucket(address)) %>%
  filter(greenway == "on greenway",
         call_for_service %in% officer_initiated_types) %>%
  mutate(month = floor_date(dt, "month"),
         type = if_else(call_for_service == "1059 - SECURITY CHECK",
                        "security_check", "other_officer_initiated")) %>%
  count(month, type) %>%
  pivot_wider(names_from = type, values_from = n, values_fill = 0) %>%
  complete(month = seq(min(month), max(month), by = "month")) %>%
  mutate(across(-month, ~ coalesce(.x, 0L)))

greenway_monthly %>%
  filter(month < as.POSIXct("2022-01-01", tz = "UTC")) %>%
  print(n = 36)
# Result: TBD

# --- CHECK: was the early-2020 drop greenway-only, or citywide? ---
# Monthly security checks citywide vs. on the greenway, Jan 2019 - Dec 2021.
police_clean_dated %>%
  filter(call_for_service == "1059 - SECURITY CHECK",
         dt < as.POSIXct("2022-01-01", tz = "UTC")) %>%
  mutate(month = floor_date(dt, "month"),
         on_greenway = !is.na(address) & greenway_bucket(address) == "on greenway") %>%
  group_by(month) %>%
  summarize(citywide = n(), greenway = sum(on_greenway), .groups = "drop") %>%
  mutate(greenway_pct = round(100 * greenway / citywide, 1)) %>%
  print(n = 36)
# Result: TBD
# ============================================================
# PHASE B14 -- READER CATEGORIES
# The inherited "crime-scope" allow-list (Phase 2) mixes crimes with
# non-crimes: parking tickets, suspicious-vehicle checks, "person down."
# That list is kept unchanged for comparability with the published
# report. For the FY 2025-26 report, every call type is also assigned to
# a category a resident would recognize:
#
#   Crimes against persons  -- assault, robbery, sexual assault, shootings,
#                              threats, domestic violence, crimes against
#                              children and elders
#   Property crime          -- burglary, theft (petty and grand theft kept
#                              separate), vehicle theft, vandalism, fraud
#   Dangerous driving       -- hit and run, drunk driving, reckless
#                              driving, speeding, sideshows
#   Disorder                -- disturbance, unwanted person, trespassing,
#                              drugs and alcohol, noise
#   Parking                 -- parking violations only (own section)
#   Officer-initiated       -- traffic/pedestrian/bike stops, security
#                              checks, patrol, warrants
#   Everything else         -- alarms, collisions, welfare and medical
#                              calls, suspicious activity, administrative
#
# Each type also gets a subcategory for detail. The mapping is written to
# call_categories.csv for review. Assignments are the analyst's judgment,
# based on the call-type names; they are not department categories.
# ============================================================

call_categories <- tribble(
  ~cfs_key, ~category, ~subcategory,
  # --- Crimes against persons ---
  "245 - assault with a deadly weapon",          "Crimes against persons", "Assault",
  "243a - assault / battery",                    "Crimes against persons", "Assault",
  "22810 - assault with pepper spray / tear gas", "Crimes against persons", "Assault",
  "220 - assault with intent to rape or rob",    "Crimes against persons", "Assault",
  "fight - physical fight",                      "Crimes against persons", "Assault",
  "243.4 - sexual battery / assault",            "Crimes against persons", "Sexual assault",
  "261 - rape",                                  "Crimes against persons", "Sexual assault",
  "211 - robbery",                               "Crimes against persons", "Robbery & carjacking",
  "215 - car jacking",                           "Crimes against persons", "Robbery & carjacking",
  "1071 - shooting (actual victim)",             "Crimes against persons", "Shootings & guns",
  "sfrmc - shots fired",                         "Crimes against persons", "Shootings & guns",
  "1075 - shots fired (shotspotter)",            "Crimes against persons", "Shootings & guns",
  "246 - shooting into a dwelling",              "Crimes against persons", "Shootings & guns",
  "247b - shooting into an unoccupied vehicle",  "Crimes against persons", "Shootings & guns",
  "mgun - person with a gun",                    "Crimes against persons", "Shootings & guns",
  "417 - brandishing",                           "Crimes against persons", "Shootings & guns",
  "422 - criminal threats",                      "Crimes against persons", "Threats & stalking",
  "stalk - stalking",                            "Crimes against persons", "Threats & stalking",
  "148.1 - bomb threat",                         "Crimes against persons", "Threats & stalking",
  "207 - kidnapping",                            "Crimes against persons", "Kidnapping",
  "273.5 - domestic battery",                    "Crimes against persons", "Domestic violence",
  "166.4 - court order violation",               "Crimes against persons", "Court & custody orders",
  "278.5 - custody order violation",             "Crimes against persons", "Court & custody orders",
  "273d - child abuse with great bodily injury", "Crimes against persons", "Children & elders",
  "288 - child molestation",                     "Crimes against persons", "Children & elders",
  "300 - child neglect / endangerment",          "Crimes against persons", "Children & elders",
  "368 - elder abuse",                           "Crimes against persons", "Children & elders",
  # --- Property crime ---
  "459 - burglary (misc)",                       "Property crime", "Burglary (home, business)",
  "459c - commercial burglary",                  "Property crime", "Burglary (home, business)",
  "459r - residential burglary",                 "Property crime", "Burglary (home, business)",
  "459a - auto burglary",                        "Property crime", "Car break-in",
  "487 - grand theft",                           "Property crime", "Grand theft",
  "488 - petty theft",                           "Property crime", "Petty theft",
  "488ic - theft in custody",                    "Property crime", "Other theft",
  "titl18 - mail theft",                         "Property crime", "Other theft",
  "496 - stolen property",                       "Property crime", "Other theft",
  "10851 - motor vehicle theft",                 "Property crime", "Vehicle theft",
  "10852 - vehcile parts theft",                 "Property crime", "Vehicle theft",
  "10852 - vehicle parts theft",                 "Property crime", "Vehicle theft",
  "594 - vandalism",                             "Property crime", "Vandalism & arson",
  "451 - arson",                                 "Property crime", "Vandalism & arson",
  "23110 - throwing objects at a vehicle",       "Property crime", "Vandalism & arson",
  "530.5 - identity theft",                      "Property crime", "Fraud & identity theft",
  "fraud - fraud",                               "Property crime", "Fraud & identity theft",
  "bunco - fraud (report)",                      "Property crime", "Fraud & identity theft",
  "484 - illegal use of a card",                 "Property crime", "Fraud & identity theft",
  "470 - forgery",                               "Property crime", "Fraud & identity theft",
  "503 - embezzlement",                          "Property crime", "Fraud & identity theft",
  "537 - defrauding an innkeeper",               "Property crime", "Fraud & identity theft",
  # --- Dangerous driving ---
  "20001 - hit and run with injury",             "Dangerous driving", "Hit and run",
  "20002 - hit and run no injury",               "Dangerous driving", "Hit and run",
  "23152 - drunk driving",                       "Dangerous driving", "Drunk driving",
  "23103 - reckless driving",                    "Dangerous driving", "Reckless driving, speeding, sideshows",
  "22350 - speeding",                            "Dangerous driving", "Reckless driving, speeding, sideshows",
  "sidshw - sideshow",                           "Dangerous driving", "Reckless driving, speeding, sideshows",
  # --- Disorder ---
  "415 - disturbance",                           "Disorder", "Disturbance",
  "unwant - unwanted person",                    "Disorder", "Unwanted person",
  "602l - trespassing",                          "Disorder", "Trespassing, loitering, prowlers",
  "loiter - loitering",                          "Disorder", "Trespassing, loitering, prowlers",
  "1070 - prowler",                              "Disorder", "Trespassing, loitering, prowlers",
  "1051 - drunk / intoxicated",                  "Disorder", "Drugs & alcohol",
  "hs - narcotics use/possession",               "Disorder", "Drugs & alcohol",
  "dopers - narcotic sales",                     "Disorder", "Drugs & alcohol",
  "music - music",                               "Disorder", "Noise",
  "party - party",                               "Disorder", "Noise",
  "firewk - fireworks",                          "Disorder", "Noise",
  "647b - prostition",                           "Disorder", "Other disorder",
  "370 - public nuisance",                       "Disorder", "Other disorder",
  "314 - indecent exposure",                     "Disorder", "Other disorder",
  "330 - gambling",                              "Disorder", "Other disorder",
  "374b - illegal dumping",                      "Disorder", "Other disorder",
  "653m - annoying telephone calls",             "Disorder", "Other disorder",
  "odor - odor complaint",                       "Disorder", "Other disorder",
  "dogs - aggressive dogs",                      "Disorder", "Animals",
  "597 - cruelty to animals",                    "Disorder", "Animals",
  # --- Parking ---
  "parker - parking violation",                  "Parking", "Parking violation",
  # --- Officer-initiated ---
  "1195 - traffic stop",                         "Officer-initiated", "Traffic stop",
  "1194 - pedestrian stop",                      "Officer-initiated", "Pedestrian stop",
  "1195b - bike stop",                           "Officer-initiated", "Bike stop",
  "1059 - security check",                       "Officer-initiated", "Security check",
  "footp - foot patrol - miscellaneous",         "Officer-initiated", "Patrol",
  "xpat - extra patrol",                         "Officer-initiated", "Patrol",
  "1060 - pound the beat",                       "Officer-initiated", "Patrol",
  "1062 - beat projects",                        "Officer-initiated", "Patrol",
  "1027 - wanted person / warrant",              "Officer-initiated", "Warrants & investigations",
  "sw - search warrant",                         "Officer-initiated", "Warrants & investigations",
  "code5 - stakeout",                            "Officer-initiated", "Warrants & investigations",
  "sa - special assignment",                     "Officer-initiated", "Warrants & investigations",
  "1184 - traffic control",                      "Officer-initiated", "Other officer-initiated",
  "vc - vehicle code violation",                 "Officer-initiated", "Other officer-initiated",
  # --- Everything else ---
  "1066 - suspicious person",                    "Everything else", "Suspicious activity",
  "suscir - suspicious circumstances event",     "Everything else", "Suspicious activity",
  "1154 - suspicious vehicle",                   "Everything else", "Suspicious activity",
  "1179 - accident w/ medical routed",           "Everything else", "Collisions & traffic hazards",
  "1181 - accident minor injury",                "Everything else", "Collisions & traffic hazards",
  "1182 - accident no injury",                   "Everything else", "Collisions & traffic hazards",
  "1183 - accident no details",                  "Everything else", "Collisions & traffic hazards",
  "1125 - traffic hazard",                       "Everything else", "Collisions & traffic hazards",
  "1124 - abandoned vehicle",                    "Everything else", "Collisions & traffic hazards",
  "1033a - alarm audible",                       "Everything else", "Alarms",
  "1033s - alarm silent",                        "Everything else", "Alarms",
  "1033 - alarm video / other",                  "Everything else", "Alarms",
  "211a - business hold up/robbery alarm",       "Everything else", "Alarms",
  "5150 - mental health patient",                "Everything else", "Welfare & medical",
  "welfck - welfare check",                      "Everything else", "Welfare & medical",
  "1053 - person down",                          "Everything else", "Welfare & medical",
  "1054 - possibly deceased person",             "Everything else", "Welfare & medical",
  "1055 - deceased person",                      "Everything else", "Welfare & medical",
  "1056 - suicide",                              "Everything else", "Welfare & medical",
  "1056a - suicide attempt",                     "Everything else", "Welfare & medical",
  "hosp - hospital transportation",              "Everything else", "Welfare & medical",
  "misper - missing person",                     "Everything else", "Missing persons & juveniles",
  "misjuv - missing juvenile",                   "Everything else", "Missing persons & juveniles",
  "601 - juv out of control/runaway",            "Everything else", "Missing persons & juveniles",
  "601r - runaway juvenile returned",            "Everything else", "Missing persons & juveniles",
  "juvs - misc juvenile(s) activity complaint",  "Everything else", "Missing persons & juveniles",
  "10851r - recovered stolen vehicle",           "Everything else", "Recovered, found, lost property",
  "fp - found property",                         "Everything else", "Recovered, found, lost property",
  "lp - lost property",                          "Everything else", "Recovered, found, lost property",
  "911dis - 911 disconnect",                     "Everything else", "Administrative & service",
  "xfer - call transfer",                        "Everything else", "Administrative & service",
  "follow - follow up",                          "Everything else", "Administrative & service",
  "pmisc - police miscellaneous",                "Everything else", "Administrative & service",
  "info - info only",                            "Everything else", "Administrative & service",
  "oaided - outside assist",                     "Everything else", "Administrative & service",
  "foaided - outside assist",                    "Everything else", "Administrative & service",
  "flag - flag down",                            "Everything else", "Administrative & service",
  "trans - transportation",                      "Everything else", "Administrative & service",
  "csb - civil standby",                         "Everything else", "Administrative & service",
  "unk - unknown",                               "Everything else", "Administrative & service",
  "bolo - be on the lookout",                    "Everything else", "Administrative & service",
  "opdoor - open door",                          "Everything else", "Administrative & service",
  "testp - police test call",                    "Everything else", "Administrative & service",
  "notifi - notification",                       "Everything else", "Administrative & service",
  "1061 - community meeting",                    "Everything else", "Administrative & service",
  "rmc - richmond municipal code violation",     "Everything else", "Administrative & service",
  "pc - penal code / misc (report)",             "Everything else", "Administrative & service",
  "idmisc - evidence work misc.",                "Everything else", "Administrative & service",
  "id459a - evidence work auto burglary",        "Everything else", "Administrative & service",
  "idrec - evidence work recovered 10851",       "Everything else", "Administrative & service",
  "id459c - evidence work commercial burglary",  "Everything else", "Administrative & service",
  "new - new call (unknown)",                    "Everything else", "Administrative & service",
  "online - refered to online report",           "Everything else", "Administrative & service",
  "online - referred to online report",          "Everything else", "Administrative & service"
)

CATEGORY_ORDER <- c("Crimes against persons", "Property crime", "Dangerous driving",
                    "Disorder", "Parking", "Officer-initiated", "Everything else")

# --- CHECK: no call type listed twice ---
n_distinct(call_categories$cfs_key) == nrow(call_categories)  # expect TRUE

# --- CHECK: every call type in both periods has a category ---
all_call_types <- bind_rows(
  police_clean %>% transmute(call_for_service),
  police_fy26  %>% transmute(call_for_service)
) %>%
  mutate(cfs_key = str_to_lower(call_for_service)) %>%
  count(cfs_key, name = "n_records")

all_call_types %>%
  anti_join(call_categories, by = "cfs_key") %>%
  arrange(desc(n_records))
# expect 0 rows. Any type listed here needs a category above.

# --- CHECK: every category in the table is used ---
call_categories %>%
  anti_join(all_call_types, by = "cfs_key")
# expect 0 rows (a row here would mean a typo in the table above)

write_csv(call_categories, file.path(output_dir, "call_categories.csv"))

# Attach categories to the combined fiscal-year data
police_all <- police_all %>%
  mutate(cfs_key = str_to_lower(call_for_service)) %>%
  left_join(call_categories, by = "cfs_key") %>%
  mutate(category = factor(category, levels = CATEGORY_ORDER))

sum(is.na(police_all$category))  # expect 0

# --- Results: incidents by category and fiscal year ---
category_fy <- police_all %>%
  count(category, fy_label) %>%
  pivot_wider(names_from = fy_label, values_from = n, values_fill = 0)

category_fy
# Result: TBD

# --- Results: crimes against persons, by subcategory and fiscal year ---
police_all %>%
  filter(category == "Crimes against persons") %>%
  count(subcategory, fy_label) %>%
  pivot_wider(names_from = fy_label, values_from = n, values_fill = 0) %>%
  print(n = 20)
# Result: TBD

# --- Results: property crime, by subcategory and fiscal year ---
police_all %>%
  filter(category == "Property crime") %>%
  count(subcategory, fy_label) %>%
  pivot_wider(names_from = fy_label, values_from = n, values_fill = 0) %>%
  print(n = 20)
# Result: TBD

# --- CHECK: confirm the FY 2025-26 robbery drop ---
# Robbery & carjacking fell from 48 (FY 2024-25) to 15. Check by month
# and call type, and look for any robbery-related types elsewhere.
police_all %>%
  filter(subcategory == "Robbery & carjacking", fy >= 2025) %>%
  mutate(month = floor_date(dt, "month")) %>%
  count(fy_label, call_for_service, month) %>%
  print(n = 40)

police_fy26 %>%
  filter(str_detect(str_to_upper(call_for_service), "ROB|211|215|HOLD")) %>%
  count(call_for_service)
# Result: TBD

# ============================================================
# PHASE B15 -- SEASONALITY (fpp3): month, day of week, hour of day
# Three series, using the B14 reader categories:
#   Crimes against persons, Property crime, Parking
# Covers January 2019 through June 2026 (90 months) -- the fiscal-year
# filter from B6 is not applied here, so Jan-Jun 2019 is included.
#
# Methods:
#   Month       -- fpp3 time plot, seasonal plot (gg_season), subseries
#                  plot (gg_subseries), STL decomposition, ACF, and a
#                  seasonal-strength score (feat_stl)
#   Day of week -- fpp3 subseries plot on daily counts, plus each fiscal
#                  year's weekday share, so years can be compared
#   Hour of day -- each fiscal year's share of incidents by hour
# Shares (percent of a year's incidents) are used for the year
# comparisons so that a busy year and a quiet year can be compared on
# shape, not volume.
# "No seasonality" is a valid result and is reported as such.
# ============================================================

library(fpp3)

SERIES_ORDER <- c("Crimes against persons", "Property crime", "Parking")

police_series <- bind_rows(
  police_clean_dated %>% transmute(call_for_service, dt),
  police_fy26        %>% transmute(call_for_service, dt)
) %>%
  filter(!is.na(dt)) %>%
  mutate(cfs_key = str_to_lower(call_for_service)) %>%
  left_join(call_categories, by = "cfs_key") %>%
  filter(category %in% SERIES_ORDER) %>%
  mutate(series   = factor(category, levels = SERIES_ORDER),
         fy       = fiscal_year(dt),
         fy_label = fy_label(fy))

# --- CHECK: records per series, and date range ---
police_series %>% count(series)
range(police_series$dt)  # expect 2019-01-01 to 2026-06-30
# Result: TBD

# --- CHECK: placeholder timestamps ---
# If a system records a missing time as midnight, hour 0 would be
# inflated. Count records at exactly 00:00.
police_series %>%
  summarize(total = n(),
            at_midnight = sum(hour(dt) == 0 & minute(dt) == 0),
            pct = round(100 * at_midnight / total, 2))
# Result: TBD. Roughly 1/1440 (0.07%) would be normal.

# ------------------------------------------------------------
# MONTH
# ------------------------------------------------------------

monthly_ts <- police_series %>%
  mutate(month = yearmonth(dt)) %>%
  count(series, month) %>%
  as_tsibble(key = series, index = month) %>%
  fill_gaps(n = 0L, .full = TRUE)

# --- CHECK: 90 months per series, no gaps ---
monthly_ts %>% as_tibble() %>% count(series)  # expect 90 each

# Time plot -- trend and level shifts before looking for seasonality
monthly_ts %>%
  autoplot(n) +
  facet_grid(series ~ ., scales = "free_y") +
  labs(title = "Monthly incidents, January 2019 - June 2026",
       x = NULL, y = "Incidents per month") +
  theme_minimal() +
  theme(legend.position = "none")

# Seasonal plot -- one line per calendar year across the months
monthly_ts %>%
  gg_season(n, labels = "right") +
  labs(title = "Seasonal plot: each year's monthly pattern",
       x = NULL, y = "Incidents per month") +
  theme_minimal()

# Subseries plot -- each month's values across years; blue line = mean
monthly_ts %>%
  gg_subseries(n) +
  labs(title = "Subseries plot: each month across years (blue = average)",
       x = NULL, y = "Incidents per month") +
  theme_minimal()

# STL decomposition -- separates trend, seasonal pattern, and remainder
monthly_stl <- monthly_ts %>%
  model(stl = STL(n ~ trend(window = 13) + season(window = "periodic"))) %>%
  components()

monthly_stl %>%
  autoplot() +
  labs(title = "STL decomposition of monthly incidents") +
  theme_minimal()

# Autocorrelation -- a seasonal pattern shows as a spike at lag 12.
# A strong trend (parking) makes all lags high; read with the STL plot.
monthly_ts %>%
  ACF(n, lag_max = 24) %>%
  autoplot() +
  labs(title = "Autocorrelation of monthly incidents") +
  theme_minimal()

# Seasonal-strength score: 0 = no seasonal pattern, 1 = entirely seasonal
monthly_ts %>%
  features(n, feat_stl) %>%
  select(series, trend_strength, seasonal_strength_year,
         seasonal_peak_year, seasonal_trough_year) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))
# Result: TBD. Peak/trough are month numbers (1 = January).

# ------------------------------------------------------------
# DAY OF WEEK
# ------------------------------------------------------------

daily_ts <- police_series %>%
  mutate(date = as_date(dt)) %>%
  count(series, date) %>%
  as_tsibble(key = series, index = date) %>%
  fill_gaps(n = 0L, .full = TRUE)

# Subseries plot by weekday -- each weekday's daily counts over time
daily_ts %>%
  gg_subseries(n, period = "week") +
  labs(title = "Daily incidents by day of week (blue = average)",
       x = NULL, y = "Incidents per day") +
  theme_minimal()

# Weekday share by fiscal year -- compares the weekly shape across years
weekday_share <- police_series %>%
  filter(fy >= 2020) %>%
  mutate(weekday = wday(dt, label = TRUE, week_start = 1)) %>%
  count(series, fy_label, weekday) %>%
  group_by(series, fy_label) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

ggplot(weekday_share, aes(weekday, pct, color = fy_label, group = fy_label)) +
  geom_line() +
  geom_hline(yintercept = 100 / 7, linetype = "dashed", color = "grey50") +
  facet_wrap(~ series, ncol = 1) +
  labs(title = "Share of each fiscal year's incidents by day of week",
       subtitle = "Dashed line = even split (14.3% per day)",
       x = NULL, y = "% of the year's incidents", color = NULL) +
  theme_minimal()

weekday_share %>%
  select(series, fy_label, weekday, pct) %>%
  mutate(pct = round(pct, 1)) %>%
  pivot_wider(names_from = weekday, values_from = pct) %>%
  print(n = 21)
# Result: TBD

# ------------------------------------------------------------
# HOUR OF DAY
# ------------------------------------------------------------

hour_share <- police_series %>%
  filter(fy >= 2020) %>%
  mutate(hour = hour(dt)) %>%
  count(series, fy_label, hour) %>%
  group_by(series, fy_label) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

ggplot(hour_share, aes(hour, pct, color = fy_label, group = fy_label)) +
  geom_line() +
  facet_wrap(~ series, ncol = 1, scales = "free_y") +
  scale_x_continuous(breaks = seq(0, 23, 3)) +
  labs(title = "Share of each fiscal year's incidents by hour of day",
       x = "Hour (0 = midnight)", y = "% of the year's incidents", color = NULL) +
  theme_minimal()

# Busiest and quietest hour, each series and year
hour_share %>%
  group_by(series, fy_label) %>%
  summarize(busiest_hour  = hour[which.max(pct)],
            busiest_pct   = round(max(pct), 1),
            quietest_hour = hour[which.min(pct)],
            quietest_pct  = round(min(pct), 1),
            .groups = "drop") %>%
  print(n = 21)
# Result: TBD

# --- CHECK: seasonal peak and trough months, read from STL directly ---
# feat_stl's seasonal_peak_year / seasonal_trough_year are position
# offsets, not calendar months, so read the months from the seasonal
# component instead.
monthly_stl %>%
  as_tibble() %>%
  mutate(month_name = month(month, label = TRUE)) %>%
  group_by(series, month_name) %>%
  summarize(seasonal_effect = round(mean(season_year), 1), .groups = "drop") %>%
  group_by(series) %>%
  summarize(peak_month   = month_name[which.max(seasonal_effect)],
            peak_effect  = max(seasonal_effect),
            trough_month = month_name[which.min(seasonal_effect)],
            trough_effect = min(seasonal_effect),
            .groups = "drop")
# Result: TBD. Effects are incidents per month above/below the trend.