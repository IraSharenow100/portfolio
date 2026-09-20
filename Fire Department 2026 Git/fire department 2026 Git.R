


# El Cerrito + fire department study for GitHub
# Start September 8, 2026

# ============================================================
# DATA ISSUES LOG — for eventual letter to Fire Department
# Do not publish findings until these are reviewed
# ============================================================
#
# 1. STATION RENUMBERING, UNDOCUMENTED IN EXPORT
#    Stations 71/72/65 became 51/52/55 on a single date (2023-04-01),
#    confirmed by non-overlapping date ranges in the data and
#    corroborated independently via city website + old business
#    listings. Export carries no field indicating this change —
#    reconstructed by us. Ask FD to confirm date/reason officially.
#
# 2. INCIDENT_NUMBER IS NOT A UNIQUE INCIDENT IDENTIFIER
#    15,307 incident_number values are reused across different years.
#    We built a composite key (incident_number + year) ourselves.
#    Ask whether DATABASEID (first column, unused so far) was intended
#    as the true unique identifier — if so, switch to it; not yet
#    checked whether it's actually unique.
#
# 3. EXCEL "ZERO-DATE" SENTINEL (1899-12-31) USED IN PLACE OF BLANK
#    apparatus_dispatch_time: 2,054 rows affected
#    apparatus_arrival_time: 32,395 rows affected (~20% of all rows)
#    Converted to NA ourselves. Confirm whether this is expected
#    export behavior or a defect in the NFIRS extraction process.
#
# 4. NEGATIVE RESPONSE TIMES
#    5 incidents where apparatus_arrival_time precedes
#    apparatus_dispatch_time — not physically possible. Small count,
#    but ask whether this reflects clock-sync or manual-entry issues
#    on specific apparatus/dates.
#
# 5. EXTREME RESPONSE-TIME OUTLIERS
#    74 incidents (0.17%) exceed 30 minutes, up to 208 minutes.
#    Some may be genuine (distant mutual aid, a held unit), but not
#    yet individually verified. Ask FD about specific cases before
#    reporting any high-end response time claims.
#
# 6. INCIDENT_CITY FREE-TEXT FIELD HAS 30+ SPELLING/CASING VARIANTS
#    e.g. "RICHMOND," "Richmond," "Richmod," "RICHOMOND" for the same
#    city. Suggests no validated dropdown at data entry. Normalized
#    ourselves (incident_city_clean); note as data-quality issue even
#    though it didn't block analysis.
#
# 7. EL CERRITO SERVICE-CALL CODING SKEWS GENERIC
#    ~60% of El Cerrito's Service Call incidents use the generic
#    "500 - Service call, other" code, vs. ~21% Richmond, ~24%
#    Kensington — despite El Cerrito and Kensington sharing the same
#    FDID (07040). Open question whether this is a coding-convention/
#    training difference or something else. Affects reliability of
#    any El Cerrito-vs-Richmond service-call or EMS-mix comparison.

# 8. APPARATUS_CLEARED_TIME HEAVILY MISSING
#    71,660 rows (43.9%) NA, plus 2,413 rows (1.5%) carrying the same
#    Excel zero-date sentinel found in apparatus_arrival_time. At most
#    54.7% of rows have a usable cleared time. Limits reliability of
#    any on-scene-duration or station-utilization/busy-ness metric.
#    Ask FD whether cleared time became more consistently recorded in
#    later years/after a system change, or whether it's a field that's
#    just inconsistently logged throughout.

# 8. APPARATUS_CLEARED_TIME HEAVILY MISSING — RICHMOND-SPECIFIC, BY YEAR
#    Overall: 71,660 rows (43.9%) NA + 2,413 (1.5%) Excel sentinel.
#    Breaking out by FDID + year reveals this is not a general data
#    quality issue — El Cerrito/Kensington (07040) has 1.2%-8.8%
#    missing every year, consistently usable. Richmond (07095) is
#    COMPLETELY missing (100%) in 2018, 2022, 2023, 2024, and 2025 —
#    only 2017 (43% missing), 2019 (23%), 2020 (2%), and 2021 (46%)
#    have any usable Richmond cleared-time data, and only 2020 is
#    fully clean. This asymmetry blocks any full-period EC-vs-Richmond
#    time-on-task or station-busyness comparison; Richmond-side
#    analysis is only defensible for 2020, or 2017-2021 as a partial
#    window with this caveat stated explicitly.
#    ASK FD: did Richmond's records system stop capturing/exporting
#    apparatus_cleared_time starting in 2018 (with a 2019-2021 partial
#    recovery), or is this an export/extraction issue specific to
#    this data pull rather than what Richmond actually has on file?

# 9. APPARATUS_CLEARED_TIME — SUSPICIOUS ~24-HOUR CLUSTER (LIKELY ARTIFACT)
#    10 rows in EC/Kensington data show time-on-task of 1400-1500 min
#    (~23.3-25 hrs), with dispatch and cleared timestamps landing at
#    nearly identical clock time on consecutive days. Call types
#    involved include "Dispatched & canceled enroute" and routine EMS/
#    medical assist calls that are logically inconsistent with a full
#    day out of service. Suspected system default/rollover when
#    cleared_time wasn't manually recorded, not a real 24-hr
#    commitment. Excluded from time-on-task analysis pending FD
#    confirmation. ASK FD: does the CAD system auto-populate a cleared
#    time ~24hrs after dispatch when a unit isn't manually cleared?
#
# 10. TWO GENUINE MULTI-WEEK OUTLIERS — CONFIRMED REAL, NOT ERRORS
#     Incident 8076297_2018 (dispatched 7/26/2018, cleared 8/25/2018,
#     ~30.5 days) and 8078873_2018 (dispatched 8/1/2018, cleared
#     8/19/2018, ~18 days), both type 141 (wildland fire), station 51.
#     Dates align with the 2018 Mendocino Complex Fire (started
#     7/27/2018) and Carr Fire (started 7/23/2018) — consistent with
#     an El Cerrito mutual-aid strike team deployed out of county.
#     Retained as real data; excluded from "typical incident duration"
#     distributions but relevant to station-51 availability/capacity
#     if that line of inquiry is pursued.
#
# 12. DOES EC FIRE TRANSPORT PATIENTS TO THE HOSPITAL?
#     Ira believes EC does not transport (separate provider likely
#     handles hospital transport). Not yet confirmed. Matters for
#     interpreting ALS/BLS unit (apparatus_type 75/76) time-on-task —
#     a transporting unit is committed far longer than one that clears
#     once a transport unit arrives. ASK FD directly.
# ============================================================
# METHODOLOGY NOTES — for eventual report
# ============================================================
#
# 1. STATION-SCOPED vs. LOCATION-SCOPED ANALYSIS ARE DIFFERENT QUESTIONS
#    Any table built by filtering on station_code (e.g. EC/Kens stations
#    51/52/55) includes calls those stations responded to ANYWHERE,
#    including mutual aid into Richmond. Any table built by filtering
#    on incident_city_clean/incident location includes calls from ALL
#    responding units regardless of home station. These answer
#    different questions ("how hard do EC/Kens stations work" vs.
#    "how fast/serious is service AT an EC/Kens location") and must
#    not be blended or labeled interchangeably in the report. Always
#    state explicitly which scope a given table uses. The call_type
#    field (home / mutual_aid, built in Phase 2) is the tool for
#    splitting station-scoped data back out by actual location.

# 13. WILDLAND STRIKE-TEAM DEPLOYMENTS ≠ LOCAL MUTUAL AID FOR COVERAGE PURPOSES
#     The two multi-week wildfire deployments (8076297_2018, 8078873_2018)
#     are excluded from station_busy_hours. Rationale, per Ira: extended
#     out-of-county strike-team deployments are very likely backfilled
#     (home station stays fully staffed), unlike routine local mutual
#     aid (Hercules, San Pablo, Richmond, etc.), where the on-duty crew
#     itself leaves with no real-time backfill. These are conceptually
#     different for any "how much home coverage is reduced" analysis.
#     ASSUMPTION, NOT CONFIRMED: ask FD whether wildland/OES strike-team
#     deployments are backfilled, and whether any other deployments
#     beyond these two exist in the data that should be treated the
#     same way.

# 14. 2020-2021 OUTSIDE-HOURS SHARE SPIKE — LIKELY COVID DENOMINATOR EFFECT, NOT VERIFIED
#     Outside-EC/Kensington hours share jumps to 31.0% (2020) and 30.7%
#     (2021), roughly double the 11-20% typical range in other years,
#     then reverts by 2022. Plausible explanation: COVID-era drop in
#     in-jurisdiction call volume (denominator effect) rather than a
#     real increase in mutual-aid activity. NOT YET CHECKED against
#     home-side incident volume for 2020-2021 specifically. Don't
#     present as a real behavioral shift without verifying this.

# 14. [UPDATED] 2020-2021 OUTSIDE-HOURS SHARE SPIKE — PARTIALLY EXPLAINED
#     In-jurisdiction incident counts: 2019=2,715, 2020=2,429 (-10.5%),
#     2021=2,601 (-4.2% vs 2019, nearly recovered). COVID-era volume
#     drop plausibly explains 2020's elevated outside-hours share
#     (31.0%) via denominator effect, but does NOT explain 2021
#     staying equally elevated (30.7%) despite near-normal volume.
#     2021 needs a separate explanation — not yet identified. Do not
#     attribute both years to COVID without flagging this gap.

# 15. ENGINE "BUSY %" METRIC — SCOPE LIMITATION
#     Time-on-task as % of 24/7/365 measures time responding to
#     incidents ONLY. Does not include training (11,725 hrs
#     dept-wide in 2023 per BB25 city budget KPI table), inspections,
#     maintenance, or admin work — none of which is in this incident
#     dataset. A low "busy %" is NOT equivalent to "idle %" and must
#     be presented with this caveat to stay factual rather than
#     implying idleness the data can't actually show.
# 16. 2025 DATA IS PARTIAL-YEAR
#     Station 51 data ends 2025-04-30; other EC/Kens stations end
#     2025-03-31 (confirmed earlier via date-range check). Any
#     per-year metric for 2025 (busy hours, %, incident counts) is
#     artificially low vs. a full year and should be excluded or
#     clearly footnoted, not compared directly to complete years.

# 17. APRIL 2020 MEDICAL-CALL VOLUME ANOMALY — EXPLAINED, NOT AN ERROR
#     Medical emergency (home, code 321) calls in April 2020: 38, vs.
#     typical April range of 60-100+ across other years. Explained by
#     Bay Area shelter-in-place order (Contra Costa County included),
#     effective 2020-03-17, extended through 2020-05-03. Consistent
#     with the broader 2020 in-jurisdiction volume dip already
#     identified. Exclude or footnote in any month-over-month or
#     year-over-year seasonal chart that includes 2020, since it will
#     otherwise distort April's average.
# ============================================================


library(tidyverse)
library(readxl)

# ============================================================
# PHASE 0 — DATA INTEGRITY & CLEANING
# ============================================================

setwd("D:/Documents/Employment/2026 job search/GitHub/portfolio/Fire Department 2026 Git/Fire Data")

fire <- read_excel("Fire Incident Data.xlsx", sheet = "DATA")
dim(fire)
names(fire)

names(fire) <- names(fire) |> str_replace_all("[\r\n]+", " ") |> str_squish()
names(fire)

names(fire) <- names(fire) |> str_replace_all(" ", "_") |> str_to_lower()
names(fire)

names(fire)[names(fire) == "incident_alarm/dispatch_time"] <- "incident_alarm_dispatch_time"
names(fire)

fire |> count(fdid, station_id, incident_city, sort = TRUE) |> print(n = Inf)

fire <- fire |> mutate(incident_city_clean = incident_city |> str_to_upper() |> str_squish())
fire |> count(fdid, station_id, incident_city_clean, sort = TRUE) |> print(n = Inf)

fire <- fire |>
  mutate(incident_city_clean = case_when(
    incident_city_clean %in% c("ELCERRIT", "ELCERRITO", "EL CERRI", "EL CERR",
                               "EL CERITTO", "EL CERRITP", "E CERRITO") ~ "EL CERRITO",
    incident_city_clean %in% c("RICHMOD", "RICHMOMD", "RICHMONS", "RICHOMOND",
                               "RICHOMD", "RICHMONC") ~ "RICHMOND",
    incident_city_clean %in% c("KENSNGTN", "KENNINGSTON") ~ "KENSINGTON",
    incident_city_clean == "SAB PABLO" ~ "SAN PABLO",
    incident_city_clean == "E SOBRANTE" ~ "EL SOBRANTE",
    TRUE ~ incident_city_clean
  ))

fire |> count(fdid, station_id, incident_city_clean, sort = TRUE) |> print(n = Inf)

fire |>
  filter(fdid %in% c("07040", "07095")) |>
  group_by(fdid, station_id) |>
  summarise(n = n(),
            min_date = min(incident_date, na.rm = TRUE),
            max_date = max(incident_date, na.rm = TRUE),
            .groups = "drop") |>
  arrange(fdid, station_id) |>
  print(n = Inf)


fire <- fire |>
  mutate(station_code = case_when(
    fdid == "07040" & station_id == "71" ~ "51",
    fdid == "07040" & station_id == "72" ~ "52",
    fdid == "07040" & station_id == "65" ~ "55",
    TRUE ~ station_id
  ))

fire |> filter(fdid == "07040") |> count(station_code, sort = TRUE)


fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55")) |>
  count(station_code, incident_city_clean, sort = TRUE) |>
  print(n = Inf)

fire |>
  filter(fdid == "07095", station_id %in% c("61","62","63","64","65","66","67","68")) |>
  count(station_id, incident_city_clean, sort = TRUE) |>
  print(n = Inf)

station_home <- tribble(
  ~fdid,   ~station_code, ~home_city,
  "07040", "51", "EL CERRITO",
  "07040", "52", "EL CERRITO",
  "07040", "55", "KENSINGTON",
  "07095", "61", "RICHMOND",
  "07095", "62", "RICHMOND",
  "07095", "63", "RICHMOND",
  "07095", "64", "RICHMOND",
  "07095", "66", "RICHMOND",
  "07095", "67", "RICHMOND",
  "07095", "68", "RICHMOND"
)

fire <- fire |> left_join(station_home, by = c("fdid", "station_code"))

fire <- fire |>
  mutate(call_type = case_when(
    is.na(home_city) ~ NA_character_,
    station_code == "55" & incident_city_clean %in% c("KENSINGTON", "EL CERRITO") ~ "home",
    incident_city_clean == home_city ~ "home",
    TRUE ~ "mutual_aid"
  ))

fire |> filter(!is.na(home_city)) |> count(fdid, station_code, call_type, sort = TRUE)

fire |>
  select(incident_date, incident_alarm_dispatch_time, incident_arrival_time,
         apparatus_dispatch_time, apparatus_arrival_time) |>
  slice(1:10)

fire |>
  summarise(across(c(incident_arrival_time, apparatus_dispatch_time, apparatus_arrival_time,
                     incident_controlled_time, incident_last_unit_cleared_tme),
                   ~ sum(.x == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"), na.rm = TRUE)))

fire <- fire |>
  mutate(
    apparatus_dispatch_time = if_else(apparatus_dispatch_time == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"), 
                                      as.POSIXct(NA), apparatus_dispatch_time),
    apparatus_arrival_time = if_else(apparatus_arrival_time == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"), 
                                     as.POSIXct(NA), apparatus_arrival_time)
  )

fire |>
  summarise(across(c(apparatus_dispatch_time, apparatus_arrival_time),
                   ~ sum(.x == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"), na.rm = TRUE)))


fire |>
  count(incident_number, name = "n_rows") |>
  count(n_rows, sort = TRUE) |> print(n = Inf)


fire |>
  count(incident_number, name = "n_rows") |>
  count(n_rows, sort = TRUE) |>
  print(n = Inf)

fire |>
  filter(incident_number == fire$incident_number[which(duplicated(fire$incident_number))[1]]) |>
  select(incident_number, station_id, apparatus_id, apparatus_type, apparatus_dispatch_time, apparatus_arrival_time)


fire |>
  mutate(incident_year = year(incident_date)) |>
  distinct(incident_number, incident_year) |>
  count(incident_number, sort = TRUE) |>
  filter(n > 1) |>
  nrow()

fire <- fire |>
  mutate(incident_year = year(incident_date),
         incident_key = paste(incident_number, incident_year, sep = "_"))

# sanity check: composite key should have far fewer collisions than incident_number alone
n_distinct(fire$incident_key)
n_distinct(fire$incident_number)

fire |>
  count(incident_key, name = "n_rows") |>
  count(n_rows, sort = TRUE) |>
  print(n = Inf)


# ============================================================
# PHASE 1 — INCIDENT TYPE CLASSIFICATION
# ============================================================


fire |>
  distinct(incident_type_code_and_description) |>
  arrange(incident_type_code_and_description) |>
  print(n = Inf)

fire <- fire |>
  mutate(incident_type_num = str_extract(incident_type_code_and_description, "^\\d+") |> as.integer())

fire |> filter(is.na(incident_type_num)) |> count(incident_type_code_and_description, sort = TRUE)


fire <- fire |>
  mutate(incident_category = case_when(
    is.na(incident_type_num) ~ NA_character_,
    incident_type_num == 111 ~ "Building fire",
    incident_type_num %in% c(112) ~ "Structure fire, other",
    incident_type_num %in% 113:118 ~ "Confined fire",
    incident_type_num %in% 120:199 ~ "Fire, other (vehicle/vegetation/outside)",
    incident_type_num %in% 200:299 ~ "Overpressure/explosion, no fire",
    incident_type_num %in% 300:399 ~ "Rescue & EMS",
    incident_type_num %in% 400:499 ~ "Hazardous condition, no fire",
    incident_type_num %in% 500:599 ~ "Service call",
    incident_type_num %in% 600:699 ~ "Good intent call",
    incident_type_num %in% 700:799 ~ "False alarm/false call",
    incident_type_num %in% 800:899 ~ "Severe weather/natural disaster",
    incident_type_num %in% 900:999 ~ "Special incident type",
    TRUE ~ "Unclassified"
  ))

fire |> count(incident_category, sort = TRUE)

fire |> filter(incident_category == "Unclassified") |> count(incident_type_num, sort = TRUE)

fire <- fire |>
  mutate(incident_category = case_when(
    is.na(incident_type_num) ~ NA_character_,
    incident_type_num == 111 ~ "Building fire",
    incident_type_num %in% c(112) ~ "Structure fire, other",
    incident_type_num %in% 113:118 ~ "Confined fire",
    incident_type_num %in% 100:199 ~ "Fire, other (vehicle/vegetation/outside)",
    incident_type_num %in% 200:299 ~ "Overpressure/explosion, no fire",
    incident_type_num %in% 300:399 ~ "Rescue & EMS",
    incident_type_num %in% 400:499 ~ "Hazardous condition, no fire",
    incident_type_num %in% 500:599 ~ "Service call",
    incident_type_num %in% 600:699 ~ "Good intent call",
    incident_type_num %in% 700:799 ~ "False alarm/false call",
    incident_type_num %in% 800:899 ~ "Severe weather/natural disaster",
    incident_type_num %in% 900:999 ~ "Special incident type",
    TRUE ~ "Unclassified"
  ))

fire |> count(incident_category, sort = TRUE)

# ============================================================
# PHASE 2 — STATION COUNTS & GEOGRAPHY
# ============================================================

fire |>
  filter(!is.na(home_city)) |>
  count(incident_key, station_code, name = "units_from_station") |>
  count(units_from_station, sort = TRUE)


station_calls <- fire |>
  filter(!is.na(home_city)) |>
  distinct(incident_key, station_code, fdid, home_city)

station_calls |>
  count(fdid, station_code, home_city, sort = TRUE)


station_calls <- fire |>
  filter(!is.na(home_city)) |>
  distinct(incident_key, station_code, fdid, home_city, call_type)

station_calls |>
  count(fdid, station_code, home_city, call_type) |>
  arrange(fdid, station_code, call_type)

# ============================================================
# PHASE 3 — RESPONSE TIME
# ============================================================


fire |>
  filter(!is.na(home_city), call_type == "home",
         !is.na(apparatus_dispatch_time), !is.na(apparatus_arrival_time)) |>
  group_by(incident_key, station_code) |>
  slice_min(apparatus_dispatch_time, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(response_min = as.numeric(difftime(apparatus_arrival_time, apparatus_dispatch_time, units = "mins"))) |>
  summarise(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            min_min = min(response_min),
            max_min = max(response_min))

response_data <- fire |>
  filter(!is.na(home_city), call_type == "home",
         !is.na(apparatus_dispatch_time), !is.na(apparatus_arrival_time)) |>
  group_by(incident_key, station_code) |>
  slice_min(apparatus_dispatch_time, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(response_min = as.numeric(difftime(apparatus_arrival_time, apparatus_dispatch_time, units = "mins")))

response_data |>
  summarise(
    n_total = n(),
    n_negative = sum(response_min < 0),
    n_over_30 = sum(response_min > 30),
    n_over_60 = sum(response_min > 60),
    pct_negative = round(100 * n_negative / n_total, 2),
    pct_over_30 = round(100 * n_over_30 / n_total, 2)
  )


response_data |>
  filter(response_min < 0) |>
  select(incident_key, station_code, incident_category, apparatus_dispatch_time, apparatus_arrival_time, response_min)

response_data |>
  filter(response_min > 30) |>
  select(incident_key, station_code, incident_category, apparatus_dispatch_time, apparatus_arrival_time, response_min) |>
  arrange(desc(response_min)) |>
  print(n = Inf)

"incident_zip" %in% names(fire)
ncol(fire)
names(fire)


location_incidents <- fire |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND")) |>
  distinct(incident_key, incident_city_clean, incident_category)

location_incidents |>
  count(incident_city_clean, incident_category, sort = TRUE) |>
  print(n = Inf)


location_incidents |>
  count(incident_city_clean, incident_category) |>
  group_by(incident_city_clean) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)


fire |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND"),
         incident_category == "Service call") |>
  distinct(incident_key, incident_city_clean, incident_type_code_and_description) |>
  count(incident_city_clean, incident_type_code_and_description, sort = TRUE) |>
  print(n = Inf)



response_location <- fire |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_arrival_time)) |>
  group_by(incident_key) |>
  slice_min(apparatus_dispatch_time, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(response_min = as.numeric(difftime(apparatus_arrival_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(response_min >= 0)

response_location |>
  group_by(incident_city_clean, incident_category) |>
  summarise(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)


response_location |>
  group_by(incident_city_clean, incident_type_num, incident_type_code_and_description) |>
  summarise(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)


response_location <- response_location |>
  mutate(response_group = case_when(
    incident_type_num %in% c(111, 112) ~ "Structure fire",
    incident_type_num %in% 113:118 ~ "Confined fire",
    incident_type_num == 321 ~ "Medical emergency (home)",
    incident_type_num %in% c(322, 323) ~ "Medical emergency (vehicle accident)",
    incident_type_num == 320 ~ "EMS, other/unspecified",
    incident_type_num == 311 ~ "EMS assist",
    TRUE ~ incident_category
  ))

response_location |>
  filter(!is.na(response_group)) |>
  group_by(incident_city_clean, response_group) |>
  summarise(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)

response_location |>
  filter(!is.na(response_group)) |>
  group_by(incident_city_clean, response_group) |>
  summarise(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(response_group, incident_city_clean) |>
  print(n = Inf)

# ============================================================
# PHASE 4 — STATION PERFORMANCE & WORKLOAD
# ============================================================

kensington_first_station <- fire |>
  filter(incident_city_clean == "KENSINGTON",
         !is.na(apparatus_arrival_time)) |>
  group_by(incident_key) |>
  slice_min(apparatus_arrival_time, n = 1, with_ties = FALSE) |>
  ungroup()

kensington_first_station |>
  count(station_code, sort = TRUE)

kensington_first_station |>
  filter(incident_type_num == 321) |>
  count(station_code, sort = TRUE)

fire |>
  summarise(n_cleared_na = sum(is.na(apparatus_cleared_time)),
            n_cleared_sentinel = sum(apparatus_cleared_time == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"), na.rm = TRUE))

fire <- fire |>
  mutate(apparatus_cleared_time = if_else(
    apparatus_cleared_time == as.POSIXct("1899-12-31 00:00:00", tz = "UTC"),
    as.POSIXct(NA), apparatus_cleared_time))

fire |>
  group_by(incident_year) |>
  summarise(n = n(), pct_missing = round(100 * mean(is.na(apparatus_cleared_time)), 1)) |>
  print(n = Inf)


fire |>
  group_by(fdid, incident_year) |>
  summarise(n = n(), pct_missing = round(100 * mean(is.na(apparatus_cleared_time)), 1), .groups = "drop") |>
  arrange(fdid, incident_year) |>
  print(n = Inf)


ec_time_on_task <- fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins")))

ec_time_on_task |>
  summarise(
    n_total = n(),
    n_negative = sum(time_on_task_min < 0),
    median_min = median(time_on_task_min[time_on_task_min >= 0]),
    p90_min = quantile(time_on_task_min[time_on_task_min >= 0], 0.9),
    max_min = max(time_on_task_min[time_on_task_min >= 0])
  )


ec_time_on_task |>
  filter(time_on_task_min >= 0) |>
  arrange(desc(time_on_task_min)) |>
  select(incident_key, station_code, incident_type_code_and_description,
         apparatus_dispatch_time, apparatus_cleared_time, time_on_task_min) |>
  head(15)

fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(time_on_task_min >= 1400, time_on_task_min <= 1500) |>
  nrow()


ec_time_on_task_clean <- ec_time_on_task |>
  filter(time_on_task_min >= 0,
         !(time_on_task_min >= 1400 & time_on_task_min <= 1500),
         incident_key != "8076297_2018",
         incident_key != "8078873_2018") |>
  left_join(response_location |> distinct(incident_key, response_group), by = "incident_key")

ec_time_on_task_clean |>
  filter(!is.na(response_group)) |>
  group_by(response_group) |>
  summarise(n = n(),
            median_min = median(time_on_task_min),
            p90_min = quantile(time_on_task_min, 0.9),
            .groups = "drop") |>
  arrange(desc(n)) |>
  print(n = Inf)


ec_time_on_task_clean |>
  filter(response_group == "Structure fire") |>
  mutate(severity_bucket = cut(time_on_task_min,
                               breaks = c(0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, Inf),
                               labels = c("0-5", "5-10", "10-15", "15-20", "20-30", "30-45",
                                          "45-60", "60-90", "90-120", "120-180", "180-240", "240+"),
                               right = TRUE, include.lowest = TRUE)) |>
  count(severity_bucket) |>
  mutate(pct = round(100 * n / sum(n), 1))


fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55")) |>
  distinct(station_code, apparatus_id, apparatus_type) |>
  count(station_code, apparatus_type, sort = TRUE) |>
  print(n = Inf)


station_busy_hours <- fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(time_on_task_min >= 0,
         !(time_on_task_min >= 1400 & time_on_task_min <= 1500),
         !incident_key %in% c("8076297_2018", "8078873_2018")) |>
  left_join(response_location |> distinct(incident_key, response_group), by = "incident_key") |>
  select(incident_key, station_code, apparatus_id, apparatus_type, incident_year,
         call_type, response_group, incident_category, time_on_task_min)

glimpse(station_busy_hours)


station_busy_hours <- fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(time_on_task_min >= 0,
         !(time_on_task_min >= 1400 & time_on_task_min <= 1500),
         !incident_key %in% c("8076297_2018", "8078873_2018")) |>
  mutate(response_group = case_when(
    incident_type_num %in% c(111, 112) ~ "Structure fire",
    incident_type_num %in% 113:118 ~ "Confined fire",
    incident_type_num == 321 ~ "Medical emergency (home)",
    incident_type_num %in% c(322, 323) ~ "Medical emergency (vehicle accident)",
    incident_type_num == 320 ~ "EMS, other/unspecified",
    incident_type_num == 311 ~ "EMS assist",
    TRUE ~ incident_category
  )) |>
  select(incident_key, station_code, apparatus_id, apparatus_type, incident_city_clean,
         incident_year, call_type, response_group, incident_category, time_on_task_min)

glimpse(station_busy_hours)



station_busy_hours |>
  filter(call_type == "mutual_aid") |>
  group_by(incident_city_clean) |>
  summarise(n = n(),
            total_hours = round(sum(time_on_task_min) / 60, 1),
            .groups = "drop") |>
  arrange(desc(total_hours)) |>
  print(n = Inf)

station_busy_hours |>
  filter(call_type == "mutual_aid", time_on_task_min > 240) |>
  arrange(desc(time_on_task_min)) |>
  select(incident_key, station_code, apparatus_type, incident_city_clean, incident_year, response_group, time_on_task_min) |>
  print(n = Inf)


station_busy_hours |>
  filter(call_type == "mutual_aid", incident_city_clean != "KENSINGTON") |>
  group_by(incident_year) |>
  summarise(n = n(),
            total_hours = round(sum(time_on_task_min) / 60, 1),
            .groups = "drop") |>
  print(n = Inf)

station_busy_hours |>
  group_by(call_type) |>
  summarise(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1))

station_busy_hours |>
  group_by(call_type, response_group) |>
  summarise(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  group_by(call_type) |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1)) |>
  arrange(call_type, desc(total_hours)) |>
  print(n = Inf)

station_busy_hours |>
  mutate(location_scope = if_else(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
                                  "In EC/Kensington", "Outside EC/Kensington")) |>
  group_by(location_scope) |>
  summarise(n = n(), total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1))



station_busy_hours |>
  mutate(location_scope = if_else(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
                                  "In EC/Kensington", "Outside EC/Kensington")) |>
  group_by(incident_year, location_scope) |>
  summarise(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  group_by(incident_year) |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1)) |>
  arrange(incident_year, location_scope) |>
  print(n = Inf)



fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  distinct(incident_key, incident_year) |>
  count(incident_year, name = "n_incidents_in_jurisdiction")

engine_hours <- station_busy_hours |>
  filter(apparatus_type == "11") |>
  group_by(station_code, incident_year) |>
  summarise(busy_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop")

engine_hours |>
  mutate(pct_busy = round(100 * busy_hours / (24 * 365), 1)) |>
  arrange(station_code, incident_year) |>
  print(n = Inf)

station_busy_hours |>
  filter(response_group == "Structure fire", incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  group_by(incident_key) |>
  summarise(incident_time_on_task = max(time_on_task_min), .groups = "drop") |>
  mutate(severity_bucket = cut(incident_time_on_task,
                               breaks = c(0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, Inf),
                               labels = c("0-5","5-10","10-15","15-20","20-30","30-45",
                                          "45-60","60-90","90-120","120-180","180-240","240+"),
                               right = TRUE, include.lowest = TRUE)) |>
  count(severity_bucket) |>
  mutate(pct = round(100 * n / sum(n), 1))

# ============================================================
# PHASE 5 — SEASONALITY
# ============================================================


fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_alarm_dispatch_time)) |>
  distinct(incident_key, incident_alarm_dispatch_time) |>
  mutate(hour_of_day = hour(incident_alarm_dispatch_time)) |>
  count(hour_of_day) |>
  arrange(hour_of_day)|>
  print(n = Inf)

fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(day_of_week = wday(incident_date, label = TRUE, week_start = 1)) |>
  count(day_of_week)

fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(day_of_month = mday(incident_date)) |>
  count(day_of_month) |>
  arrange(day_of_month) |>
  print(n = Inf)

fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(day_of_month = mday(incident_date)) |>
  count(day_of_month, name = "n_incidents") |>
  left_join(
    tibble(date = seq(min(fire$incident_date, na.rm = TRUE), max(fire$incident_date, na.rm = TRUE), by = "day")) |>
      mutate(day_of_month = mday(date)) |>
      count(day_of_month, name = "n_occurrences"),
    by = "day_of_month"
  ) |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 1)) |>
  arrange(day_of_month) |>
  print(n = Inf)



fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  distinct(incident_key, incident_year) |>
  count(incident_year, name = "n_incidents") |>
  print(n = Inf)


fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE)) |>
  count(month_num, name = "n_incidents") |>
  left_join(
    fire |>
      distinct(incident_year) |>
      tidyr::crossing(month_num = month.abb) |>
      mutate(month_num = factor(month_num, levels = month.abb, ordered = TRUE)) |>
      filter(!(incident_year == 2025 & !month_num %in% month.abb[1:4])) |>
      count(month_num, name = "n_occurrences"),
    by = "month_num"
  ) |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 1)) |>
  arrange(month_num) |>
  print(n = Inf)



month_occurrences <- fire |>
  distinct(incident_year) |>
  tidyr::crossing(month_num = month.abb) |>
  mutate(month_num = factor(month_num, levels = month.abb, ordered = TRUE)) |>
  filter(!(incident_year == 2025 & !month_num %in% month.abb[1:4])) |>
  count(month_num, name = "n_occurrences")

fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(incident_date)) |>
  mutate(response_group = case_when(
    incident_type_num %in% c(111, 112) ~ "Structure fire",
    incident_type_num %in% 113:118 ~ "Confined fire",
    incident_type_num == 321 ~ "Medical emergency (home)",
    incident_type_num %in% c(322, 323) ~ "Medical emergency (vehicle accident)",
    TRUE ~ NA_character_
  )) |>
  filter(!is.na(response_group)) |>
  distinct(incident_key, incident_date, response_group) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE)) |>
  count(response_group, month_num, name = "n_incidents") |>
  left_join(month_occurrences, by = "month_num") |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 2)) |>
  arrange(response_group, month_num) |>
  print(n = Inf)




fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         incident_type_num == 321,
         incident_year != 2025) |>
  distinct(incident_key, incident_date) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE),
         year = year(incident_date)) |>
  count(year, month_num) |>
  tidyr::pivot_wider(names_from = month_num, values_from = n, values_fill = 0) |>
  print(n = Inf)
