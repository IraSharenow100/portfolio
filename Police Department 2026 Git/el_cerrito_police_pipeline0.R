# ============================================================
# El Cerrito Police Incident Analysis -- Data Pipeline
# ============================================================
#
# STRUCTURE
#   PART A -- January 2019 through June 2025 (Phases 0-17)
#             Source: 13 half-year PDF reports, re-extracted to Excel.
#             This is the pipeline behind the published 2019-2025 report.
#             Unchanged, except for this header.
#
#   PART B -- FY 2025-26: July 1, 2025 through June 30, 2026 (Phases B0-B12)
#             Source: direct Excel export from the department (CPRA request).
#             Different input format, same analysis. Reuses Part A's
#             allow-list, landmarks, QA rules, and helper functions so both
#             periods are measured the same way.
#
# Part B depends on objects created in Part A (police_clean,
# police_clean_dated, incident_types, landmarks_geocoded,
# compute_landmark_counts, etc.), so run Part A first.
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
# Del Norte BART shows lower than expected -- straddles the Richmond city
# line and has its own BART Police substation, so cross-jurisdiction and
# on-property incidents are outside this dataset entirely. Not a data error.

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

nrow(outliers_full)  # 302

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
# Result: 198 usable, 53 unresolved (no match), 51 excluded (mix of
# confirmed-different-city and unresolved shorthand)

usable_outliers <- outliers_final %>% filter(exclusion_reason == "usable") %>% select(address, lat, long)

# One address is a genuine out-of-state entry in the source PD data itself
# (a Michigan address) -- not a geocoding error, just not a location near
# El Cerrito. The 5-mile radius filter below naturally excludes it.

police_total_corrected <- police_total %>%
  rows_update(usable_outliers, by = "address") %>%
  mutate(dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34) %>%
  filter(dist_from_ec_mi <= 5)

nrow(police_total)            # 37984
nrow(police_total_corrected)  # 37867

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
# 37867 / 2887 / 1164 / 33816

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
# EC Plaza BART and EC Community Center lead in BOTH vehicle crime and
# dangerous driving, not just overall. Korematsu/Madera lowest across
# all three -- consistent with being residential/school areas off the
# main San Pablo Ave corridor.

# ============================================================
# PHASE 13 -- VEHICLE-CRIME HEATMAP
# ============================================================

nrow(police_vehicle_crime)  # 2887

ggplot() +
  annotation_map_tile(type = "osm", zoomin = 0) +
  stat_density_2d(data = police_vehicle_crime, aes(x = long, y = lat, fill = after_stat(level)), geom = "polygon", contour = TRUE, alpha = 0.5, bins = 15) +
  scale_fill_gradient(low = "yellow", high = "red", breaks = range, labels = c("Fewer incidents", "More incidents")) +
  geom_point(data = landmarks_geocoded, aes(x = long, y = lat), color = "black", size = 2.5, shape = 17) +
  geom_label_repel(data = landmarks_geocoded, aes(x = long, y = lat, label = landmark), size = 2.8, fontface = "bold", label.padding = 0.15, label.size = 0, fill = alpha("white", 0.75), min.segment.length = 0, max.overlaps = Inf) +
  coord_sf(xlim = c(EC_MAP_LONG_MIN, EC_MAP_LONG_MAX), ylim = c(EC_MAP_LAT_MIN, EC_MAP_LAT_MAX), crs = 4326) +
  labs(title = "El Cerrito Vehicle Crime Density", fill = NULL) +
  theme_minimal() + theme(axis.title = element_blank())
# Same two hotspots as the general map (Del Norte BART, EC Plaza BART) --
# consistent with the landmark comparison table.

# ============================================================
# PHASE 14 -- TIME TRENDS
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
# 17 of 20 long-delay cases are property-theft/burglary/recovered-vehicle
# calls -- discovered-after-the-fact reports, not active emergencies.
# Expected and benign. 3 exceptions (assault/battery, sexual battery,
# criminal threats) are isolated, not a pattern.

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
# RESULT: the SHARE near the Plaza (1,000ft) has not risen -- 10.4% (2019)
# to 6.7% (2025), if anything lower now. The raw count near the Plaza grew,
# but that's just riding the citywide tripling, not extra concentration
# there specifically. Enforcement growth is broad-based, not Plaza-specific.


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

excel_sheets(file.path(output_dir, fy26_file))  # expect a single sheet

police_fy26 <- read_excel(file.path(output_dir, fy26_file)) %>%
  rename_with(~ str_trim(.) %>% str_replace_all(" ", "_") %>% tolower()) %>%
  mutate(event_number = as.character(event_number))

nrow(police_fy26)                          # expect 23118
setequal(names(police_fy26), names(police))  # expect TRUE -- same columns as Part A

police_fy26 %>% summarize(across(everything(), ~ sum(is.na(.))))
# expect 0 missing in every column except first_unit_arrived_time (4591)

n_distinct(police_fy26$event_number) == nrow(police_fy26)  # expect TRUE

# The two periods are adjacent (Part A ends June 30, 2025). Confirm no
# record appears in both -- Part A had 376 duplicates at a file boundary.
sum(police_fy26$event_number %in% as.character(police_clean$event_number))  # expect 0

# ============================================================
# PHASE B1 -- TEXT CLEANING & DATE HANDLING
# ============================================================

class(police_fy26$received_date)  # expect "POSIXct" "POSIXt" -- already a date-time

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

range(police_fy26$dt)  # expect 2025-07-01 00:18 to 2026-06-30 23:23

# ============================================================
# PHASE B2 -- CALL-TYPE CONSISTENCY WITH PART A
# The crime allow-list is matched by exact text. If the department renamed
# a category, those incidents would silently fall out of the crime scope.
# ============================================================

new_call_types <- setdiff(unique(police_fy26$call_for_service),
                          unique(police_clean$call_for_service))

police_fy26 %>%
  filter(call_for_service %in% new_call_types) %>%
  count(call_for_service, sort = TRUE) %>%
  print(n = 50)

# The department corrected a typo in this export ("VEHCILE" -> "VEHICLE").
# Accept both spellings so the category is counted in both periods.
incident_types      <- union(incident_types,      "10852 - vehicle parts theft")
vehicle_crime_types <- union(vehicle_crime_types, "10852 - vehicle parts theft")

# Result: TBD. Review each -- genuinely new category, or a renamed one
# that belongs on the allow-list?

df_filtered_fy26 <- police_fy26 %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

nrow(df_filtered_fy26)                                       # 5491 (after typo fix; 5480 before)
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

police_fy26 %>% count(address_format)
# 21698 el cerrito / 523 other city / 897 shorthand

n_distinct(police_fy26$address)           # 7234 raw
n_distinct(police_fy26$geocode_address)   # 5185

# County (unincorporated) rows should now carry a ZIP code
police_fy26 %>%
  filter(city == "COUNTY") %>%
  distinct(geocode_address) %>%
  head(5)
# expect e.g. "19 LAM CT, CA 94707"

# Spot-check the transformation on a random sample of each format
police_fy26 %>%
  distinct(address_format, address, geocode_address) %>%
  group_by(address_format) %>%
  slice_sample(n = 5) %>%
  print(n = 15)

# Named places in the shorthand group ("HARDING PARK", "ECPD",
# "EL CERRITO PLAZA", "MDF", "SAFEWAY") will not geocode reliably as
# street text. They are geocoded along with everything else in B4, then
# overwritten in B5 with hand-verified coordinates -- the same approach
# used for Korematsu in Part A.
police_fy26 %>%
  filter(address_format == "shorthand") %>%
  count(street, sort = TRUE) %>%
  print(n = 25)
# ============================================================
# PHASE B4 -- GEOCODING: FY 2025-26 INCIDENTS (long-running, ~1 hour)
# Part A's hardest lesson applied from the start: every request carries
# the Bay Area searchExtent, so no Panama-style global matches.
# Commented out. Uncomment to run or resume from checkpoint.
# ============================================================

# geocode_fy26_path <- file.path(output_dir, "geocode_checkpoint_fy26.csv")
# 
# unique_addresses_fy26 <- police_fy26 %>% distinct(geocode_address)
# nrow(unique_addresses_fy26)  # roughly 5700
# 
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
# One rule instead of Part A's two-stage fix: a coordinate is usable if
# it exists and falls within 5 miles of El Cerrito's center -- the same
# distance threshold Part A arrived at after the bounding-box attempts.
# ============================================================

geocoded_fy26 <- read_csv(geocode_fy26_path, show_col_types = FALSE)

nrow(geocoded_fy26) == nrow(unique_addresses_fy26)  # expect TRUE

police_fy26_geocoded <- police_fy26 %>%
  left_join(geocoded_fy26, by = "geocode_address") %>%
  mutate(
    dist_from_ec_mi = distHaversine(cbind(long, lat), c(EC_CENTER_LONG, EC_CENTER_LAT)) / 1609.34,
    BAD_LATLON_FLAG = is.na(lat) | dist_from_ec_mi > 5
  )

nrow(police_fy26_geocoded)  # expect 23118 -- join must not add rows

police_fy26_geocoded %>%
  count(address_format, BAD_LATLON_FLAG) %>%
  group_by(address_format) %>%
  mutate(pct = round(100 * n / sum(n), 1))
# Result: TBD. Expect the shorthand group to fail most often.
# Some "other city" records are real locations outside El Cerrito
# (Martinez, San Francisco) -- correctly excluded by the 5-mile rule,
# not geocoding errors.

incidents_for_proximity_fy26 <- police_fy26_geocoded %>% filter(!BAD_LATLON_FLAG)
nrow(incidents_for_proximity_fy26)                                     # TBD
round(100 * nrow(incidents_for_proximity_fy26) / nrow(police_fy26), 1)  # compare to Part A's 96.9%

police_total_fy26 <- incidents_for_proximity_fy26 %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

# 1. Fallback-point check
police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat = round(lat, 5), long = round(long, 5)) %>%
  summarize(n_addresses = n_distinct(geocode_address),
            n_rows = n(),
            example = first(geocode_address),
            .groups = "drop") %>%
  arrange(desc(n_addresses)) %>%
  head(10)

# 2. Excluded rows by city
police_fy26_geocoded %>%
  filter(BAD_LATLON_FLAG) %>%
  count(city, sort = TRUE)

# 3. Redaction check
police_fy26 %>%
  filter(str_detect(str_to_lower(call_for_service),
                    "juv|261|288|243.4|5150|1056|suicide|medical")) %>%
  count(call_for_service, street, sort = TRUE) %>%
  print(n = 30)

fallback_points <- police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat, long) %>%
  filter(n_distinct(geocode_address) >= 20) %>%
  ungroup()

fallback_points %>% count(lat, long)
fallback_points %>% distinct(lat, long, geocode_address) %>% print(n = 40)

police_fy26_geocoded %>%
  filter(str_detect(geocode_address, "WALL")) %>%
  distinct(geocode_address, lat, long)


# Fallback points. When ArcGIS cannot match the text, the Bay Area search
# extent stops it from guessing a distant place (Part A's Panama problem),
# but it can still drop the address on a generic local point that passes
# the 5-mile test. Detected as a single coordinate shared by 20+ different
# address strings -- a real location has one address, or a few spelling
# variants at an intersection.
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

sum(police_fy26_geocoded$FALLBACK_FLAG)  # expect 157

police_fy26_geocoded %>%
  filter(str_detect(geocode_address, "WALL")) %>%
  distinct(geocode_address, lat, long) %>%
  as.data.frame()

suspect_coords <- police_fy26_geocoded %>%
  filter(!BAD_LATLON_FLAG) %>%
  group_by(lat, long) %>%
  summarize(n_addresses = n_distinct(geocode_address),
            n_rows = n(),
            addresses = paste(unique(geocode_address), collapse = " | "),
            .groups = "drop") %>%
  filter(n_addresses >= 5) %>%
  arrange(desc(n_addresses))

nrow(suspect_coords)
View(suspect_coords)


# Imprecise locations. Addresses with no house number and no cross street
# ("KEARNEY ST", "KEY HUM", "WALL KEARNEY") can only be placed at a generic
# point on one street. The shared-coordinate review found such points up to
# ~2 miles from the actual location. Excluded from maps and landmark counts.
police_fy26_geocoded <- police_fy26_geocoded %>%
  mutate(
    IMPRECISE_FLAG  = !str_detect(street, "^\\d") &
      !str_detect(geocode_address, " & | AND |@"),
    BAD_LATLON_FLAG = BAD_LATLON_FLAG | IMPRECISE_FLAG
  )

police_fy26_geocoded %>% count(address_format, IMPRECISE_FLAG)

police_fy26_geocoded %>%
  filter(IMPRECISE_FLAG) %>%
  count(street, sort = TRUE) %>%
  print(n = 30)



police_fy26_geocoded %>%
  summarize(total = n(),
            fallback = sum(FALLBACK_FLAG),
            imprecise = sum(IMPRECISE_FLAG),
            usable = sum(!BAD_LATLON_FLAG),
            pct_usable = round(100 * usable / total, 1))

nrow(incidents_for_proximity_fy26)                                     # 22532
round(100 * nrow(incidents_for_proximity_fy26) / nrow(police_fy26), 1)  # 97.5 -- vs Part A's 96.9

police_fy26 %>%
  filter(str_detect(address, "OHLONE")) %>%
  count(street, sort = TRUE) %>%
  print(n = 200)


incidents_for_proximity_fy26 <- police_fy26_geocoded %>% filter(!BAD_LATLON_FLAG)
nrow(incidents_for_proximity_fy26)   # expect 22532
police_total_fy26 <- incidents_for_proximity_fy26 %>%
  filter(str_to_lower(call_for_service) %in% incident_types)

nrow(incidents_for_proximity_fy26)   # 22532 (97.5%) -- after fallback + imprecise flags



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

nrow(police_all)  # TBD (137194 + 23118, less the Jan-Jun 2019 records)
police_all %>% count(fy_label, source)

# ============================================================
# PHASE B7 -- WORKLOAD: FY 2025-26 (compare to Phase 9)
# ============================================================

workload_summary_fy26 <- police_fy26 %>%
  count(call_for_service, sort = TRUE) %>%
  mutate(in_crime_scope = str_to_lower(call_for_service) %in% incident_types,
         pct_of_total = round(100 * n / sum(n), 1))

workload_summary_fy26 %>% print(n = 15)
# Result: TBD. Initial look: traffic stops (not security checks) lead in
# FY 2025-26 -- a change from 2019-2025. Confirm.

# ============================================================
# PHASE B8 -- CRIME-SCOPE TREND BY FISCAL YEAR (compare to Phase 14)
# ============================================================

fy_totals <- police_all %>%
  filter(str_to_lower(call_for_service) %in% incident_types) %>%
  count(fy, fy_label, name = "incidents")
fy_totals
# Result: TBD

# ============================================================
# PHASE B9 -- LANDMARK PROXIMITY: FY 2025-26 (compare to Phases 8 & 12)
# Reuses Part A's landmarks and compute_landmark_counts() unchanged.
# ============================================================

# --- Comparability check: redacted call types ---
# Part A had no address for sensitive call types, so they never appeared
# on its maps. The FY 2025-26 export has block-level addresses for them
# instead (e.g. "10900 SAN PABLO AVE"). Identify the types Part A was
# missing addresses for, so the same ones can be excluded here.
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

nrow(incidents_for_landmarks_fy26)  # TBD

# --- All activity within 500 ft ---
# Part A covers 6.5 years (Jan 2019 - Jun 2025). Dividing its counts by
# 6.5 gives a per-year figure comparable to one fiscal year.
landmark_counts_fy26 <- compute_landmark_counts(incidents_for_landmarks_fy26, "fy_2025_26") %>%
  left_join(landmark_counts %>%
              transmute(landmark, per_year_2019_25 = round(n_within_500ft / 6.5)),
            by = "landmark") %>%
  arrange(desc(fy_2025_26))

landmark_counts_fy26
# Result: TBD

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
# First run (before comparison columns): Del Norte BART 101, Library 85,
# EC Plaza BART 66. One year of data -- small counts per landmark, so
# frame as "consistent / not consistent with 2019-2025," not new rankings.

# --- Diagnostic: Del Norte BART ---
# First run showed Del Norte BART at roughly 4x its 2019-2025 yearly rate
# (all activity ~86/yr -> 362; crime ~27/yr -> 101). A jump that size in
# one year is more likely a data effect than a real change. Check what is
# being counted there.
del_norte <- landmarks_geocoded %>% filter(landmark == "Del Norte BART")

near_del_norte <- incidents_for_landmarks_fy26 %>%
  mutate(dist_ft = distHaversine(cbind(long, lat), c(del_norte$long, del_norte$lat)) / 0.3048) %>%
  filter(dist_ft <= RADIUS_FT)

near_del_norte %>% count(street, sort = TRUE) %>% print(n = 15)
near_del_norte %>% count(call_for_service, sort = TRUE) %>% print(n = 15)
# Result: TBD

police_clean %>%
  filter(str_detect(address, "DEL NORTE|6400 CUTTING")) %>%
  count(address, sort = TRUE) %>%
  print(n = 20)

police_geocoded %>%
  filter(str_detect(address, "^6400 CUTTING")) %>%
  mutate(dist_to_del_norte_ft = round(distHaversine(cbind(long, lat),
                                                    c(del_norte$long, del_norte$lat)) / 0.3048)) %>%
  group_by(address) %>%
  summarize(n = n(), dist_ft = first(dist_to_del_norte_ft), bad_flag = first(BAD_LATLON_FLAG)) %>%
  arrange(desc(n))

police_clean %>%
  mutate(house_plus_cross = str_detect(address, "^\\d+ [^,]+, [^,&]+ & [^,]+")) %>%
  summarize(total = n(),
            house_plus_cross = sum(house_plus_cross, na.rm = TRUE),
            pct = round(100 * house_plus_cross / total, 1))


part_a_house_cross <- police_geocoded %>%
  filter(str_detect(address, "^\\d+ [^,]+, [^,&]+ & [^,]+"), !BAD_LATLON_FLAG) %>%
  mutate(geocode_address = paste0(str_trim(str_extract(address, "^[^,]+")),
                                  ", El Cerrito, CA 94530")) %>%
  inner_join(geocoded_fy26 %>% select(geocode_address, lat_b = lat, long_b = long),
             by = "geocode_address") %>%
  filter(!is.na(lat_b)) %>%
  mutate(shift_ft = distHaversine(cbind(long, lat), cbind(long_b, lat_b)) / 0.3048)

part_a_house_cross %>%
  summarize(records_matched = n(),
            addresses_matched = n_distinct(address),
            median_shift_ft = round(median(shift_ft)),
            pct_over_500ft = round(100 * mean(shift_ft > 500), 1),
            pct_over_1000ft = round(100 * mean(shift_ft > 1000), 1))

misplaced <- part_a_house_cross %>%
  filter(shift_ft > 500) %>%
  group_by(address) %>%
  summarize(n = n(), shift_ft = round(first(shift_ft)), .groups = "drop") %>%
  arrange(desc(n))

nrow(misplaced)                                    # how many distinct addresses
sum(misplaced$n)                                   # how many records
round(100 * sum(head(misplaced$n, 10)) / sum(misplaced$n), 1)  # % in the top 10
misplaced %>% head(15) %>% as.data.frame()



lib <- landmarks_geocoded %>% filter(landmark == "Library")
cc  <- landmarks_geocoded %>% filter(landmark == "EC Community Center")

part_a_house_cross %>%
  filter(address %in% head(misplaced$address, 15)) %>%
  distinct(address, lat, long, lat_b, long_b) %>%
  mutate(
    street        = str_extract(address, "^[^,]+"),
    a_to_library  = round(distHaversine(cbind(long, lat),     c(lib$long, lib$lat)) / 0.3048),
    b_to_library  = round(distHaversine(cbind(long_b, lat_b), c(lib$long, lib$lat)) / 0.3048),
    a_to_comm_ctr = round(distHaversine(cbind(long, lat),     c(cc$long, cc$lat)) / 0.3048),
    b_to_comm_ctr = round(distHaversine(cbind(long_b, lat_b), c(cc$long, cc$lat)) / 0.3048)
  ) %>%
  distinct(street, .keep_all = TRUE) %>%
  select(street, a_to_library, b_to_library, a_to_comm_ctr, b_to_comm_ctr) %>%
  as.data.frame()



part_a_house_cross %>%
  filter(str_detect(address, "^5611 POINSETT")) %>%
  distinct(lat, long, lat_b, long_b) %>%
  as.data.frame()

# ============================================================
# PHASE B10 -- HEATMAP: FY 2025-26 (compare to Phase 11)
# Same map settings as Part A so the two maps can sit side by side.
# ============================================================

ggplot() +
  annotation_ma
p_tile(type = "osm", zoomin = 0) +
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
# Result: TBD

parking_plaza_fy26 <- police_fy26_geocoded %>%
  filter(call_for_service == "PARKER - PARKING VIOLATION", !BAD_LATLON_FLAG) %>%
  mutate(dist_to_plaza_ft = distHaversine(cbind(long, lat), c(ec_plaza_bart$long, ec_plaza_bart$lat)) / 0.3048) %>%
  summarize(
    total_geocoded = n(),
    near_plaza_1000ft = sum(dist_to_plaza_ft <= 1000),
    pct_near_plaza_1000ft = round(100 * near_plaza_1000ft / total_geocoded, 1)
  )
parking_plaza_fy26
# Result: TBD. Compare to Part A's 5.7%-11.7% range.

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
# Result: TBD. Part A: median 5, 90th percentile 25.

response_fy %>%
  filter(!str_to_lower(call_for_service) %in% self_initiated_types) %>%
  group_by(fy_label) %>%
  summarize(median_min = median(response_min), n = n())
# Result: TBD. Part A: flat at 7-9 minutes.

response_fy %>%
  filter(fy == 2026, str_to_lower(call_for_service) %in% urgent_types) %>%
  group_by(call_for_service) %>%
  summarize(median_min = median(response_min), n = n()) %>%
  arrange(desc(median_min))
# Result: TBD. Small n per category in one year -- report cautiously.

# ============================================================
# PHASE B13 -- OHLONE GREENWAY
# Based on address text, not geocoding: the greenway is a long linear
# trail, and 99 incidents are logged only as "OHLONE GREENWAY" with no
# point location. Two buckets:
#   on greenway      -- the street field itself names the greenway
#                       ("OHLONE GREENWAY", "MANILA AVE & OHLONE TRL")
#   next to greenway -- a house address with the greenway noted only as
#                       a cross-street ("6543 PORTOLA DR, at OHLONE TRL")
# ============================================================

police_fy26 <- police_fy26 %>%
  mutate(greenway = case_when(
    str_detect(street, "OHLONE")  ~ "on greenway",
    str_detect(address, "OHLONE") ~ "next to greenway",
    TRUE                          ~ "elsewhere"
  ))

police_fy26 %>% count(greenway)

# Confirm the "next to" bucket is what we think: house addresses whose
# cross-street note names the greenway
police_fy26 %>%
  filter(greenway == "next to greenway") %>%
  distinct(address) %>%
  slice_sample(n = 8) %>%
  as.data.frame()

# What gets reported in each bucket
police_fy26 %>%
  filter(greenway != "elsewhere") %>%
  count(greenway, call_for_service, sort = TRUE) %>%
  group_by(greenway) %>%
  slice_head(n = 12) %>%
  print(n = 24)
