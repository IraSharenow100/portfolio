# ============================================================
# El Cerrito + fire department study for GitHub
# Started September 8, 2026
# Updated September 24, 2026 (rev. 8: adds D33–D35, Tables 3C.4, 4.1, 5B.4)
#   Adds Fire Department answers (Castrejon emails 9/23 and 9/24/2026),
#   new NFIRS 2023–2025 and NERIS 2026 files, the old-vs-new match,
#   ambulance exclusion, and "first truck, any department" response
#   times. Tracker items renumbered in order.
# ============================================================

# ============================================================
# REPORT-WRITING RULES (for the final report)
# ============================================================
# R1. State only what the data or a written source shows. Nothing
#     invented.
# R2. If an analysis is not possible because the data is not there,
#     say so plainly ("The data does not allow ...").
# R3. Neutral tone. Do not criticize the Fire Department. Describe
#     patterns and let the data speak. Where the department gave an
#     explanation, quote or paraphrase it and cite the email.
# R4. Label inferences as inferences, never as facts.
# R5. Always state which scope a table uses (station-scoped vs.
#     location-scoped). See M1.
# R6. Always flag shortcomings in the data next to the numbers they
#     affect (Ira, 9/24).
# R7. American English throughout, in prose and in code.

# ============================================================
# SOURCES
# ============================================================
# S1. "Fire Incident Data.xlsx" (sheet DATA): NFIRS apparatus-level
#     export, Jan 2017 – Mar/Apr 2025, 163,384 rows. FDID 07040
#     (El Cerrito/Kensington), 07095 (Richmond), 01010 (Albany).
# S2. "[NFIRS] Fire Board Report 3.csv": El Cerrito only (FDID 07040),
#     incident-level, calendar 2023–2025, 11,904 rows.
#     "[NFIRS] Fire Board Report 2.csv" is the 2025 part of S2 and is
#     not used.
# S3. "[NERIS] Fire Board Report 5.csv": El Cerrito only,
#     Feb 1 – about Sep 23, 2026, 4,781 rows.
# S4. City dashboard PDFs: "[NFIRS] Fire Board Report – El Cerrito
#     Responses" (2025) and "[NERIS] ... Apparatus Responses" (2026),
#     generated 9/23/2026.
# S5. Emails from Battalion Chief Jose Castrejon, 9/23/2026 and
#     9/24/2026 (answers to Ira's letters of 9/14 and 9/23/2026).

# ============================================================
# DATA ISSUES LOG
# Status: RESOLVED / PARTIAL / OPEN / NOT POSSIBLE
# "FD" = Castrejon email 9/24/2026 unless noted.
# ============================================================
#
# --- Issues in the original export (S1) ---
#
# D1. STATION RENUMBERING — RESOLVED
#     Stations 71/72/65 became 51/52/55. FD: April 1, 2023 was the
#     date the change was made in CAD. Matches the data.
#
# D2. INCIDENT IDENTIFIER — RESOLVED (key switched to DATABASEID)
#     15,307 incident_number values reused across years.
#     FD: numbers reset annually with the year as prefix.
#     S1: El Cerrito (07040) numbers carry a 1-digit year prefix
#     2018–2025; 2017 has two formats (1,976 start with 7; 1,828 with 1).
#     Richmond (07095) numbers have NO year prefix, so they repeat.
#     Repeats: 13,654 Richmond-only; 1,202 Albany+Richmond; 422
#     EC+Richmond; 29 all three.
#     Old key (number + year) merged unrelated incidents: 2,730 keys
#     held rows from more than one FDID; 2,716 of them span different
#     dates (collisions, not shared incidents). 71 more merges within
#     one agency.
#     DATABASEID: 139,599 values; never maps to more than one
#     number+year+FDID. => One ID per agency report.
#     DECISION (Ira, 9/24): incident_key = DATABASEID.
#     incident_num_year kept for display and the wildland exclusions.
#     S2: 7-digit numbers through Apr 2025; 8-digit (25xxxxxx) after.
#
# D3. EXCEL ZERO-DATE (1899-12-31) IN PLACE OF BLANK — OPEN
#     apparatus_dispatch_time 2,054 rows; apparatus_arrival_time
#     32,395 rows; apparatus_cleared_time 2,413 rows.
#     FD: does not know why the old system defaulted to 12/31/1899.
#     Treated as missing.
#
# D4. NEGATIVE RESPONSE TIMES (5 incidents) — RESOLVED
#     FD: some incidents do not come through the 911 system, e.g.
#     a crew is flagged down. Excluded from response-time statistics
#     for that reason.
#
# D5. RESPONSE TIMES OVER 30 MINUTES — OPEN
#     Station-scoped home calls: 74 before the ambulance exclusion
#     (D11), 43 after (0.10%); maximum 208 minutes. Not asked about
#     individually. Do not report high-end response-time claims
#     without checking specific cases.
#
# D6. INCIDENT_CITY SPELLING VARIANTS (30+) — handled
#     Normalized in incident_city_clean. Data-quality note only.
#
# D7. EL CERRITO "500 – SERVICE CALL, OTHER" SHARE — PARTIAL
#     FD: the company officer codes the incident as what best
#     describes what they found on arrival.
#     S1 share of Service Calls coded 500, by incident location:
#       El Cerrito 2017 3.2%, 2018 42.3%, 2019 71.1%, 2020 71.9%,
#         2021 65.9%, 2022 66.0%, 2023 66.3%, 2024 48.7%, 2025* 36.6%
#       Kensington 5.6% to 43.8% (2020); Richmond 13.0–28.0%
#       (*2025 partial). High El Cerrito share runs 2019–2023.
#     Check (q): matched S1 code-500 incidents are labeled "Assist EMS
#     Crew-NO EMS PROVIDED" in S2 from 2024 on (D27). This suggests
#     many El Cerrito code-500 records may be "assist EMS crew, no EMS
#     provided." INFERENCE — ask FD in the final letter.
#     Describe the pattern; the cause is not documented.
#
# D8. APPARATUS_CLEARED_TIME MISSING, RICHMOND — NOT POSSIBLE (most years)
#     El Cerrito/Kensington 1.5–10% missing each year. Richmond 100%
#     missing in 2018 and 2022–2025; partial in 2017 (43% missing),
#     2019 (23%), 2021 (46%); 2020 2%.
#     FD: does not know why. Only Richmond Fire could answer.
#     => Richmond time on task is NOT POSSIBLE for 2018, 2022–2025.
#        Defensible only for 2020, or 2017 and 2019–2021 with caveat.
#
# D9. ~24-HOUR CLEARED TIMES (10 rows, 1,400–1,500 min) — PARTIAL
#     FD: CAD does not auto-clear; "one possible reason" is that
#     dispatchers clear their board at shift change.
#     Excluded from time on task. Cite FD explanation as possible,
#     not confirmed.
#
# D10. TWO MULTI-WEEK WILDLAND INCIDENTS — kept, but excluded from
#      typical-duration figures
#      8076297_2018 (7/26–8/25/2018, ~30.5 days) and 8078873_2018
#      (8/1–8/19/2018, ~18 days), type 141, station 51.
#      Dates coincide with the 2018 Mendocino Complex and Carr fires.
#      That link is our inference; not confirmed by FD (not asked).
#
# D11. AMBULANCES IN THE DATA — RESOLVED
#      FD: ambulances are provided through AMR; "M" units are
#      ambulances. El Cerrito Fire does not transport patients.
#      S1: apparatus type 76 at EC stations = M-numbered units;
#      type 75 = BLS units (BLS60, BLS61, ...).
#      Rows removed (check n): El Cerrito 5,078; Richmond 2;
#      Albany 1,454. Incidents with only an ambulance/BLS unit:
#      El Cerrito 620; Albany 1,229; Richmond 0.
#      DECISION (Ira, 9/24): leave ambulance/BLS units (types 75, 76)
#      out of workload, counts, and response times. Applied to all
#      departments (fire_units) so they are measured the same way.
#
# D12. THIRD AGENCY IN S1: FDID 01010 = ALBANY FIRE DEPARTMENT
#      (FDID per city NFIRS 2025 report, p. 28). Not in station_home,
#      so outside station analysis. Most of its rows are ambulance/BLS
#      units (D11). It can appear in location-scoped tables.
#
# D13. ONE EMERGENCY CAN HAVE TWO OR MORE REPORTS — HANDLED (M8)
#      Each department files its own report, under its own number,
#      for the same emergency. Nothing in S1 links them.
#      Reports located in El Cerrito, 2017–Apr 2025 (all units):
#        El Cerrito FD 20,836 | Richmond FD 1,684 | Albany FD 103
#      Located in Kensington: El Cerrito FD 3,370 | Richmond 203 |
#        Albany 25
#      El Cerrito marked 1,500 of its El Cerrito reports and 39 of its
#      Kensington reports "aid received" (another department also came).
#
# D14. LINKING REPORTS ACROSS DEPARTMENTS — PARTIAL
#      Method: same city, alarm times within 10 minutes.
#      Check (i): El Cerrito "aid received" -> other department "aid given":
#        El Cerrito 1,500: 444 one match, 10 two or more, 1,046 none (70%).
#        Kensington 39: 1 match, 38 none.
#        Matched gaps: median 2.9 min; most 1–5 min; small tail
#        10–60 min (check k), so a 10-minute window is reasonable.
#      Check (m): Richmond/Albany "aid given" -> ANY El Cerrito report:
#        El Cerrito: 830 have one (likely shared call), 510 none
#        (likely Richmond/Albany alone). Kensington: 19 / 142.
#        Caveat: El Cerrito averages ~7 calls a day, so an unrelated
#        report falls inside the window by chance maybe 1 time in 10.
#      Unmatched El Cerrito "aid received" reports may involve agencies
#      not in S1 (e.g., Contra Costa County Fire) — NOT VERIFIED.
#      Phase 3B (fire units only): host said "aid received" but no
#      partner report found: El Cerrito 713 of 20,972 emergencies
#      (3.4%); Kensington 20 (0.6%); Richmond 1,536 (1.6%).
#
# D15. EL CERRITO "AID GIVEN" REPORTS LOCATED IN EL CERRITO — OPEN
#      661 reports. 588 carry El Cerrito ZIP 94530, so they are NOT
#      Kensington calls with El Cerrito addresses (an earlier guess
#      was wrong). By year: 2017 229, 2018 139, then 19–63 a year.
#      Kensington "aid given" reports carry Kensington ZIPs (94707:
#      2,252; 94708: 524), consistent with D25.
#
# D16. RICHMOND REPORTS LABELED "KENSINGTON" WITH NON-KENSINGTON ZIPs — OPEN
#      Of 142 Richmond/Albany solo reports labeled Kensington, 95 carry
#      ZIP 94805 and 45 carry 94706; only 1 carries 94707. Kensington's
#      usual ZIPs are 94707/94708. The city label may be wrong.
#      NOT VERIFIED.
#
# D17. SOLO RICHMOND/ALBANY REPORTS IN EC/KENSINGTON (check m)
#      652 reports (El Cerrito 510, Kensington 142). First truck:
#      Richmond Station 66 (405), Station 64 (216). Types: code 321
#      medical 339; dispatched & canceled en route 139; hazards 32;
#      false alarms 31; outside fires 28; service calls 26; confined
#      fires 5; building fire 1. Building fires shared vs. solo: 12 vs. 1.
#      Canceled-en-route reports are not arrivals (M8).
#
# D18. RICHMOND ARRIVAL TIMES MISSING — NOT POSSIBLE for 2018, 2022–2025
#      Share of fire-unit rows with an arrival time (check o):
#      Richmond 2017 38% | 2018 0% | 2019 48% | 2020 65% | 2021 37% |
#      2022–2025 0%.
#      => Richmond response times only for 2017 and 2019–2021, partial.
#      "Richmond truck first" in EC/Kensington is measurable only in
#      those years: 34 cases with both arrival times; the El Cerrito
#      truck arrived a median 2.9 min later (mean 3.9, middle half
#      1.0–5.2, maximum 13.7) (check p).
#
# D19. EL CERRITO ARRIVAL TIMES PARTIAL EVERY YEAR — FLAG
#      Only 61–66% of El Cerrito fire-unit rows have an arrival time
#      (check o). Unknown whether the missing rows differ from the rest.
#
# --- Issues in the new files (S2, S3, S4) ---
#
# D20. NO UNIT-LEVEL DATA AFTER THE OLD EXPORT — NOT POSSIBLE
#      S2/S3 have incident-level times only (alarm, incident time,
#      last unit cleared, PSAP-to-arrival). FD: "This is all of the
#      new data available in the new system."
#      => Unit-level response time, time on task, station busy hours,
#         and the Richmond comparison cannot be extended past
#         Mar/Apr 2025.
#
# D21. 2023–2025 RECORDS MIGRATED TO NEW RMS
#      FD (9/23): records for the past three years were transferred
#      to the new system. Phase 6 checks whether S2 matches S1 for
#      the overlap (Jan 2023 – Mar 2025). Result: D29.
#
# D22. PSAP-TO-ARRIVAL DEFINITION AND COVERAGE — PARTIAL
#      FD: clock starts when the 911 call lands at the PSAP (CHP,
#      Richmond PD, or Albany PD dispatch), which relays to Contra
#      Costa Fire or Richmond Fire dispatch; ends when a unit arrives.
#      => Not comparable with our apparatus dispatch-to-arrival times.
#      Coverage in S2: blank for every 2023 and 2024 row; 2025 filled
#      for 790 of 3,331 incidents, almost all Oct–Dec.
#      90th percentile of those 790 = 9.35 min (9:21); dashboard
#      shows 9:18 for "2025." By station: 8:20 / 10:01 / 9:55 vs.
#      dashboard 8:12 / 10:01 / 9:58.
#      INFERENCE (not confirmed by FD): the 2025 dashboard figure
#      rests on roughly Oct–Dec 2025 only.
#
# D23. STATION RELIABILITY — definition only
#      FD: percentage of the time the engine responded out of
#      quarters vs. being out of station. No field for it in S2/S3.
#      => Cannot compute or verify. Can quote dashboard values with
#         FD's definition: 2025 St51 83.59%, St52 92.25%, St55 84.18%,
#         overall 85.31%; 2026 St51 95.77%, St52 91.08%, St55 93.81%,
#         overall 93.77% (different system; not compared).
#
# D24. DISPATCH MODEL CHANGE — PARTIAL
#      FD: dispatch changed from sending a unit based on geographic
#      area to the closest unit based on AVL. FD gave no date.
#      Data: zone codes change from "ECR" (Jan–Apr 2025) to 51/52/55
#      (May–Dec 2025); incident number format changes in May 2025.
#      INFERENCE: change around May 2025. Mostly after S1 ends.
#
# D25. KENSINGTON CALLS CODED AS AUTOMATIC AID GIVEN — PARTIAL
#      FD: this was the old system of tracking how many incidents
#      happened in Kensington.
#      S2, 2025: Jan–Apr, 133 incidents "aid given to El Cerrito Fire
#      Department" (101 in Kensington, 29 in El Cerrito, 3 other);
#      May–Dec, 137 "aid given to Kensington Fire 07040" (122
#      Kensington, 14 El Cerrito, 1 undefined).
#      => City "automatic aid given" totals include Kensington calls.
#         Our call_type rule (Kensington = home for Station 55) stands.
#
# D26. DIFFERENT 2025 TOTALS ON DASHBOARD PAGES — OPEN
#      3,331 (p. 33), 3,330 (p. 12), 3,628 (p. 15 Station Summary),
#      2,463 (p. 8 zone table). FD: does not know; possibly ambulance-
#      only responses or a Richmond unit running a call in El Cerrito.
#      => Use 3,331 distinct incident numbers (S2); footnote the others.
#
# D27. 2023 -> 2024 DROP — OPEN (corrected twice, 9/24)
#      Real in both files: S1 (07040 distinct incident numbers)
#      4,676 -> 4,016 (-14%); S2 3,899 -> 3,231 (-17%). Cause unknown.
#      FD: emergency services has spikes from time to time for
#      unknown reasons.
#      Check (q): S1 code-500 incidents matched in S2 are labeled
#      "Service call, other" in 2023 (497) but "Assist EMS Crew-NO EMS
#      PROVIDED" in 2024 (403) and 2025 Q1 (49). So the fall in
#      "Service call, other" in S2 is a relabel, not a drop.
#
# D28. S1 vs. S2 INCIDENT COUNTS DIFFER — EXPLAINED BY D29
#      EC (07040) distinct incidents, S1 vs. S2: 2023 4,676 vs. 3,899;
#      2024 4,016 vs. 3,231; Jan–Apr 2025 1,022 vs. about 1,031.
#
# D29. PHASE 6 MATCH, S1 vs. S2 (Jan 2023 – Mar 2025) — RESULT
#      In both: 2023 3,880 | 2024 3,212 | 2025 Q1 498
#      Only in S1: 796 | 804 | 210    Only in S2: 19 | 19 | 267
#      Matched incidents agree 100% on type series and alarm time.
#      S1-only incidents are mostly series 9 "special incident"
#      (about 1,080) and series 5 service calls (about 360).
#      => S2 totals run about 800 a year lower than S1 for 2023–2024.
#         2025 Q1 match is weaker; cause unknown.
#
# D30. JANUARY 2026 MISSING — NOT POSSIBLE
#      S2 ends 12/31/2025; S3 starts 2/1/2026. FD: "This was the
#      NFIRS NERIS change." No January 2026 records in either file.
#
# D31. NO NFIRS–NERIS CROSSWALK — NOT POSSIBLE
#      FD did not answer. => 2026 cannot be compared with earlier
#      years by incident type.
#
# D32. NERIS 2026 90TH PERCENTILE — approximate match only
#      Distinct-incident p90 PSAP-to-arrival: St51 8.36 min (8:22),
#      St52 10.48 (10:29), St55 10.78 (10:47), overall 9.50 (9:30).
#      Dashboard: 8:24 / 10:30 / 11:12 / 9:39. Dashboard method
#      unknown (its station totals, 2,294, exceed 2,084 incidents).
#
# --- Findings from the trend and seasonality work (Phase 5B) ---
#
# D33. CODE 900 "SPECIAL INCIDENT TYPE, OTHER" SPIKE, 2022–2024 — OPEN
#      EC/Kensington incidents coded 900 (Table 5B.4): 0–4 a year
#      2017–2021; 217 (2022); 575 (2023); 235 (2024); 3 (2025 Q1).
#      Drives most of the 2022–2024 "All other" spike and the 2023
#      peak in total incidents. Without code 900: 2022 2,860 |
#      2023 2,923 | 2024 2,640 (vs. 2,429–2,713 in 2017–2021).
#      Same code dominates S1-only records missing from S2 (D29).
#      What these calls are is not documented — ask FD (letter).
#      Table 3C.4: excluding code 900 changes El Cerrito medians by
#      0.1 min or less and Kensington not at all. The response-time
#      rise is not a code-900 effect.
#
# D34. ONE CALL TYPE, THREE CODES? — INFERENCE, ask FD (letter)
#      311 "Medical assist, assist EMS crew": 443 (2017), 344 (2018),
#      then 82 (2019) and 13–37 after. 500 "Service call, other" in
#      El Cerrito: 6 (2017) -> 447 (2019) (D7). From 2024, matched
#      code-500 records appear in S2 as "Assist EMS Crew-NO EMS
#      PROVIDED" (D27). Likely the same kind of call coded three
#      ways. => The Service Call trend (strength 0.87) is probably
#      mostly a coding change. Report as a pattern with this caveat.
#
# D35. KENSINGTON: WHOSE TRUCK ARRIVED FIRST (Table 4.1) — FINDING
#      Station 55 first: 88–94% (2017–2022), 81% (2023), 86% (2024),
#      91% (2025 Jan–Apr). Station 51 first: 1–4% before 2023, then
#      10% (2023), 7% (2024). Same years Kensington response times
#      rose (Table 3C.1). Cause not in the data (N11). Richmond 0% in
#      2018 and 2022–2025 reflects missing arrival times (D18).

# ============================================================
# METHODOLOGY NOTES
# ============================================================
#
# M1. STATION-SCOPED vs. LOCATION-SCOPED ARE DIFFERENT QUESTIONS
#     Filtering on station_code = calls those stations went to
#     anywhere (including mutual aid). Filtering on incident_city_clean
#     = calls at that location from any responding unit. Never blend.
#     call_type (home / mutual_aid) splits station-scoped data by
#     location.
#
# M2. WILDLAND STRIKE TEAMS ≠ LOCAL MUTUAL AID
#     D10 incidents excluded from station_busy_hours. Assumption
#     (Ira, NOT CONFIRMED, not asked): long out-of-county strike-team
#     deployments are backfilled; routine local mutual aid is not.
#
# M3. OUTSIDE-EC/KENSINGTON SHARE OF EC STATION HOURS (fire units only)
#     2017 25.7% | 2018 19.7 | 2019 26.1 | 2020 31.0 | 2021 30.7 |
#     2022 22.2 | 2023 19.4 | 2024 22.4 | 2025* 17.2. Overall 24.6%.
#     In-jurisdiction incidents: 2019 2,715 | 2020 2,429 | 2021 2,601.
#     COVID volume drop plausibly explains 2020 (denominator effect).
#     2021 is NOT explained. Do not attribute both years to COVID.
#
# M4. ENGINE "BUSY %" = INCIDENT TIME ONLY
#     Excludes training (11,725 hrs department-wide in 2023 per budget
#     KPI table), inspections, maintenance, and admin. Low busy % ≠
#     idle. Denominator is leap-year aware (8,784 hrs in 2020, 2024).
#
# M5. 2025 IS PARTIAL IN THE OLD EXPORT
#     Station 51 ends 2025-04-30; other EC/Kensington stations
#     2025-03-31. Flag or exclude 2025 in per-year metrics.
#
# M6. APRIL 2020 MEDICAL-CALL DIP — explained
#     Code 321 home calls April 2020 = 38 vs. typical 60–100+.
#     Bay Area shelter-in-place from 2020-03-17 (Contra Costa
#     included), extended through 2020-05-03. Footnote in seasonal
#     charts.
#
# M7. RESPONSE-TIME DEFINITIONS
#     Ours: apparatus dispatch -> apparatus arrival (S1).
#     City: PSAP call receipt -> arrival (D22). Different start
#     points; never compare directly.
#
# M8. "FIRST TRUCK, ANY DEPARTMENT" (Phase 3B) — approved by Ira 9/24
#     Every department's reports at a location. A report from another
#     department within 10 minutes of the host department's report
#     (same city) is merged into one emergency. Response = earliest
#     unit dispatch to earliest unit arrival across the merged reports.
#     "Dispatched & canceled en route" (611) is not an arrival.
#     Host report marked "aid received" with no partner found is
#     reported as uncertainty (D14). Hosts: El Cerrito FD for
#     El Cerrito and Kensington; Richmond FD for Richmond.
#
# M9. WHICH YEARS TO REPORT — approved by Ira 9/24
#     El Cerrito and Kensington: a table for every year.
#     El Cerrito vs. Richmond: only 2017, 2019, 2020, 2021 (D18).

# ============================================================
# ANALYSES NOT POSSIBLE WITH AVAILABLE DATA
# ============================================================
# N1. Richmond time on task / busy hours for 2018, 2022–2025 (D8).
# N2. Richmond response times for 2018, 2022–2025 (D18).
# N3. Any unit-level metric after Mar/Apr 2025 (D20).
# N4. El Cerrito vs. Richmond after Mar/Apr 2025 (S2/S3 are EC only).
# N5. 2026 vs. earlier years by incident type (D31).
# N6. January 2026 (D30).
# N7. Station reliability — no source field (D23).
# N8. City PSAP-based response times for 2023–2024 (field blank, D22).
# N9. "First truck, any department" for ALL El Cerrito/Kensington
#     emergencies — reports cannot all be linked (D13, D14, D18).
#     Partial answer only.
# N10. Street-level location — S1 has city and ZIP only.
# N11. Causes of any trend (e.g., rising response times) — the data
#      shows patterns, not reasons.

# ============================================================
# TO DO / DONE
# ============================================================
# T1. DONE — key switched to DATABASEID (D2).
# T2. DONE — ambulance/BLS units excluded (D11).
# T3. DONE — "first truck, any department" method (M8) and report
#     years (M9).
# T4. DONE — Phase 6 match (D29) and relabel check (D27).
# T5. DONE — solo Richmond/Albany reports summarized (D17).
# T6. Write the report (Quarto page, Public Safety section) following
#     the report-writing rules above. Include a section on mutual aid
#     (Ira, 9/24): Phase 1B (reports by department, solo reports and
#     their types), Phase 3B (who arrived first), Phase 4 (EC hours
#     outside EC/Kensington). Facts only; no recommendations.
# T7. After the report: letter to Battalion Chief Castrejon listing
#     the data-quality issues found (D-items), including the code-500
#     question (D7, D34) and what code 900 calls are (D33).

library(tidyverse)
library(readxl)

setwd("D:/Documents/Employment/2026 job search/GitHub/portfolio/Fire Department 2026 Git/Fire Data")

# Local file names of the new CSVs (S2, S3), as shown by dir on 9/24.
new_nfirs_file <- "[NFIRS] Fire Board Report 3.csv"
new_neris_file <- "[NERIS] Fire Board Report 5.csv"

# ------------------------------------------------------------
# Helper objects and functions
# ------------------------------------------------------------
excel_zero_date <- as.POSIXct("1899-12-31 00:00:00", tz = "UTC")

add_response_group <- function(df) {
  df |>
    mutate(response_group = case_when(
      incident_type_num %in% c(111, 112) ~ "Structure fire",
      incident_type_num %in% 113:118 ~ "Confined fire",
      incident_type_num == 321 ~ "Medical emergency (home)",
      incident_type_num %in% c(322, 323) ~ "Medical emergency (vehicle accident)",
      incident_type_num == 320 ~ "EMS, other/unspecified",
      incident_type_num == 311 ~ "EMS assist",
      TRUE ~ incident_category
    ))
}

# Incident numbers as clean text (avoids "1e+07" from numeric columns)
id_chr <- function(x) {
  if (is.numeric(x)) format(x, scientific = FALSE, trim = TRUE) else str_squish(as.character(x))
}

# For the city dashboard CSV exports (S2, S3)
clean_export_names <- function(x) {
  x |>
    str_remove("\\s*\\(.*\\)\\s*$") |>
    str_replace_all("[^A-Za-z0-9]+", "_") |>
    str_remove("^_|_$") |>
    str_to_lower() |>
    make.unique(sep = "_")
}

clean_export_values <- function(x) {
  x |>
    str_remove("^=") |>
    str_remove_all('^"|"$') |>
    str_squish() |>
    na_if("(blank)") |>
    na_if("")
}

read_city_export <- function(path) {
  df <- read_csv(path, col_types = cols(.default = col_character()),
                 name_repair = "minimal")
  names(df) <- clean_export_names(names(df))
  df |> mutate(across(everything(), clean_export_values))
}

# ============================================================
# PHASE 0 — DATA INTEGRITY & CLEANING (original export, S1)
# ============================================================

fire <- read_excel("Fire Incident Data.xlsx", sheet = "DATA")
dim(fire)

names(fire) <- names(fire) |> str_replace_all("[\r\n]+", " ") |> str_squish()
names(fire) <- names(fire) |> str_replace_all(" ", "_") |> str_to_lower()
names(fire)[names(fire) == "incident_alarm/dispatch_time"] <- "incident_alarm_dispatch_time"
names(fire)

# --- City name cleaning (D6) ---
fire |> count(fdid, station_id, incident_city, sort = TRUE) |> print(n = Inf)

fire <- fire |>
  mutate(incident_city_clean = incident_city |> str_to_upper() |> str_squish(),
         incident_city_clean = case_when(
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

# --- Station date ranges (D1) ---
fire |>
  filter(fdid %in% c("07040", "07095")) |>
  group_by(fdid, station_id) |>
  summarize(n = n(),
            min_date = min(incident_date, na.rm = TRUE),
            max_date = max(incident_date, na.rm = TRUE),
            .groups = "drop") |>
  arrange(fdid, station_id) |>
  print(n = Inf)

# --- Station renumbering (D1, confirmed by FD: April 1, 2023) ---
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

# --- Home city and call type (M1, D25) ---
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

# --- Excel zero-date sentinel (D3) ---
fire |>
  summarize(across(c(incident_arrival_time, apparatus_dispatch_time, apparatus_arrival_time,
                     apparatus_cleared_time, incident_controlled_time,
                     incident_last_unit_cleared_tme),
                   ~ sum(.x == excel_zero_date, na.rm = TRUE)))

fire <- fire |>
  mutate(across(c(apparatus_dispatch_time, apparatus_arrival_time, apparatus_cleared_time),
                ~ if_else(.x == excel_zero_date, as.POSIXct(NA), .x)))

# confirm none remain (expect all zeros)
fire |>
  summarize(across(c(apparatus_dispatch_time, apparatus_arrival_time, apparatus_cleared_time),
                   ~ sum(.x == excel_zero_date, na.rm = TRUE)))

# --- Incident key (D2) ---
fire |>
  count(incident_number, name = "n_rows") |>
  count(n_rows, sort = TRUE) |>
  print(n = Inf)

fire <- fire |>
  mutate(incident_year = year(incident_date),
         incident_key = paste(incident_number, incident_year, sep = "_"))

# numbers reused across years (expect 15,307)
fire |>
  distinct(incident_number, incident_year) |>
  count(incident_number) |>
  filter(n > 1) |>
  nrow()

n_distinct(fire$incident_key)
n_distinct(fire$incident_number)

fire |>
  count(incident_key, name = "n_rows") |>
  count(n_rows, sort = TRUE) |>
  print(n = Inf)

# --- NEW D2 diagnostics ---
# (a) First digit of incident number vs. year, by FDID.
#     FD says the prefix is the year. Check whether that holds.
fire |>
  distinct(fdid, incident_number, incident_year) |>
  mutate(first_digit = str_sub(id_chr(incident_number), 1, 1),
         n_digits = nchar(id_chr(incident_number))) |>
  count(fdid, incident_year, first_digit, n_digits) |>
  arrange(fdid, incident_year, desc(n)) |>
  print(n = Inf)

# (b) Are the cross-year repeats within one FDID or across FDIDs?
repeat_numbers <- fire |>
  distinct(incident_number, incident_year, fdid) |>
  group_by(incident_number) |>
  filter(n_distinct(incident_year) > 1) |>
  ungroup()

repeat_numbers |>
  group_by(incident_number) |>
  summarize(n_fdid = n_distinct(fdid), fdids = paste(sort(unique(fdid)), collapse = "+"),
            .groups = "drop") |>
  count(n_fdid, fdids, sort = TRUE)

# (c) Does any incident_key contain rows from both FDIDs?
#     If > 0, adding fdid to the key may be needed (needs Ira's approval).
fire |>
  distinct(incident_key, fdid) |>
  count(incident_key) |>
  filter(n > 1) |>
  nrow()

# (d) Is DATABASEID unique? (FD did not answer this question.)
#     9/24 run: 163,384 rows, 139,599 distinct -> not a row ID.
c(rows = nrow(fire), distinct_databaseid = n_distinct(fire$databaseid))

# (e) Keys with rows from more than one FDID (2,730 in 9/24 run):
#     one shared incident, or two unrelated incidents with the same number?
#     Same date and city = likely one shared incident.
multi_fdid_keys <- fire |>
  distinct(incident_key, fdid) |>
  count(incident_key) |>
  filter(n > 1) |>
  pull(incident_key)

fire |>
  filter(incident_key %in% multi_fdid_keys) |>
  group_by(incident_key) |>
  summarize(same_date = n_distinct(as.Date(incident_date)) == 1,
            same_city = n_distinct(incident_city_clean) == 1,
            .groups = "drop") |>
  count(same_date, same_city)

fire |>
  filter(incident_key %in% multi_fdid_keys) |>
  count(fdid, incident_aid_type, sort = TRUE) |>
  print(n = Inf)

# (f) Is DATABASEID one ID per agency incident (incident_key + fdid)?
#     Expect both counts = 0 if so.
db_map <- fire |> distinct(databaseid, incident_key, fdid)
c(n_distinct_key_fdid = n_distinct(paste(fire$incident_key, fire$fdid)),
  databaseid_to_many = db_map |> count(databaseid) |> filter(n > 1) |> nrow(),
  key_fdid_to_many   = db_map |> count(incident_key, fdid) |> filter(n > 1) |> nrow())
# 9/24 run: 139,514 / 0 / 71

# --- Switch incident key to DATABASEID (D2, approved 9/24) ---
# Everything below this line uses incident_key = DATABASEID.
fire <- fire |>
  mutate(incident_num_year = incident_key,
         incident_key = id_chr(databaseid))

n_distinct(fire$incident_key)   # expect 139,599

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
fire |> filter(incident_category == "Unclassified") |> count(incident_type_num, sort = TRUE)

# --- NEW D7 check: share of Service Calls coded 500, by location and year ---
# S2 shows code 500 use stopping in Jan 2024. Check whether the
# ~60% El Cerrito share is concentrated in particular years.
fire |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND"),
         incident_category == "Service call") |>
  distinct(incident_key, incident_city_clean, incident_year, incident_type_num) |>
  group_by(incident_city_clean, incident_year) |>
  summarize(n_service = n(),
            n_500 = sum(incident_type_num == 500),
            pct_500 = round(100 * n_500 / n_service, 1),
            .groups = "drop") |>
  arrange(incident_city_clean, incident_year) |>
  print(n = Inf)

# ============================================================
# PHASE 1B — REPORTS FROM MORE THAN ONE DEPARTMENT (D13–D17)
# Diagnostics only. Nothing here changes the data.
# Runs after Phase 1 because it uses incident_category.
# ============================================================

# (g) Reports by city, department, and aid type
fire |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND")) |>
  distinct(incident_key, fdid, incident_city_clean, incident_aid_type) |>
  count(incident_city_clean, fdid, incident_aid_type) |>
  arrange(incident_city_clean, fdid, desc(n)) |>
  print(n = Inf)

# (h) Alarm time is a full date-time (9/24: 2017-01-01 to 2025-04-30)
range(fire$incident_alarm_dispatch_time, na.rm = TRUE)

# (i) El Cerrito "aid received" reports matched to other departments'
#     "aid given" reports: same city, alarm times within 10 minutes
host_recv <- fire |>
  filter(fdid == "07040", incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         str_detect(incident_aid_type, "Aid Received")) |>
  distinct(host_key = incident_key, incident_city_clean,
           host_alarm = incident_alarm_dispatch_time)

aid_given <- fire |>
  filter(fdid != "07040", incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         str_detect(incident_aid_type, "Aid Given")) |>
  distinct(aid_key = incident_key, aid_fdid = fdid, incident_city_clean,
           aid_alarm = incident_alarm_dispatch_time)

aid_links <- host_recv |>
  inner_join(aid_given, by = "incident_city_clean", relationship = "many-to-many") |>
  mutate(gap_min = abs(as.numeric(difftime(aid_alarm, host_alarm, units = "mins")))) |>
  filter(gap_min <= 10)

host_recv |>
  left_join(aid_links |> count(host_key, name = "n_matches"), by = "host_key") |>
  mutate(n_matches = replace_na(n_matches, 0)) |>
  count(incident_city_clean, n_matches = pmin(n_matches, 2))

aid_links |>
  summarize(n = n(), median_gap = median(gap_min),
            pct_within_1 = round(100 * mean(gap_min <= 1), 1))

# (j) El Cerrito "aid given" reports in EC/Kensington, by ZIP (D15)
fire |>
  filter(fdid == "07040", str_detect(incident_aid_type, "Aid Given"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  distinct(incident_key, incident_city_clean, incident_zip) |>
  count(incident_city_clean, incident_zip, sort = TRUE) |>
  print(n = 20)

# (k) Gap bands up to 60 minutes (supports the 10-minute window)
host_recv |>
  inner_join(aid_given, by = "incident_city_clean", relationship = "many-to-many") |>
  mutate(gap_min = abs(as.numeric(difftime(aid_alarm, host_alarm, units = "mins")))) |>
  filter(gap_min <= 60) |>
  count(gap_band = cut(gap_min, c(-Inf, 1, 3, 5, 10, 20, 30, 60)))

# (l) El Cerrito "aid given" reports located in El Cerrito, by year (D15)
fire |>
  filter(fdid == "07040", str_detect(incident_aid_type, "Aid Given"),
         incident_city_clean == "EL CERRITO") |>
  distinct(incident_key, incident_year) |>
  count(incident_year)

# (m) Richmond/Albany "aid given" reports: is there ANY El Cerrito
#     report in the same city within 10 minutes?
#     TRUE = likely shared call; FALSE = likely Richmond/Albany alone.
ec_any <- fire |>
  filter(fdid == "07040", incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  distinct(ec_key = incident_key, incident_city_clean,
           ec_alarm = incident_alarm_dispatch_time)

aid_check <- aid_given |>
  left_join(ec_any, by = "incident_city_clean", relationship = "many-to-many") |>
  mutate(gap_min = abs(as.numeric(difftime(ec_alarm, aid_alarm, units = "mins")))) |>
  group_by(aid_key, aid_fdid, incident_city_clean) |>
  summarize(has_ec_report = any(gap_min <= 10, na.rm = TRUE), .groups = "drop")

aid_check |> count(incident_city_clean, has_ec_report)
# 9/24 run: El Cerrito 830 TRUE / 510 FALSE; Kensington 19 / 142

# One row per report, keeping the first unit to arrive
aid_reports <- fire |>
  inner_join(aid_check |> select(incident_key = aid_key, has_ec_report),
             by = "incident_key") |>
  arrange(incident_key, apparatus_arrival_time) |>
  distinct(incident_key, .keep_all = TRUE)

aid_solo <- aid_reports |> filter(!has_ec_report)

# Where: department and city
aid_solo |> count(fdid, incident_city_clean)

# Where: ZIP code (no street address in S1)
aid_solo |> count(incident_city_clean, incident_zip, sort = TRUE) |> print(n = 20)

# Which station sent the first truck
aid_solo |> count(fdid, station_id, sort = TRUE)

# When: by year
aid_solo |>
  count(incident_year, incident_city_clean) |>
  pivot_wider(names_from = incident_city_clean, values_from = n, values_fill = 0)

# What: broad category, solo vs. shared
aid_reports |>
  mutate(call = if_else(has_ec_report, "shared", "solo")) |>
  count(incident_category, call) |>
  pivot_wider(names_from = call, values_from = n, values_fill = 0) |>
  arrange(desc(solo))

# What: top 20 specific incident types, solo reports
aid_solo |> count(incident_type_code_and_description, sort = TRUE) |> print(n = 20)

# ============================================================
# PHASE 2 — STATION COUNTS & GEOGRAPHY
# ============================================================

# --- Leave out ambulance/BLS units (D11, decision 9/24) ---
# Phases 2–5 use fire_units. Phases 0, 1, 1B and 6 use full fire.
ems_types <- c("75", "76")

fire_units <- fire |>
  filter(is.na(apparatus_type) | !apparatus_type %in% ems_types)

# (n) Effect of the exclusion: rows and incidents removed, by department
fire |>
  mutate(unit = if_else(apparatus_type %in% ems_types, "ambulance/BLS", "fire unit")) |>
  count(fdid, unit) |>
  pivot_wider(names_from = unit, values_from = n, values_fill = 0)

fire |>
  group_by(fdid, incident_key) |>
  summarize(ambulance_only = all(apparatus_type %in% ems_types), .groups = "drop") |>
  count(fdid, ambulance_only)


fire_units |>
  filter(!is.na(home_city)) |>
  count(incident_key, station_code, name = "units_from_station") |>
  count(units_from_station, sort = TRUE)

station_calls <- fire_units |>
  filter(!is.na(home_city)) |>
  distinct(incident_key, station_code, fdid, home_city, call_type)

station_calls |>
  count(fdid, station_code, home_city, sort = TRUE)

station_calls |>
  count(fdid, station_code, home_city, call_type) |>
  arrange(fdid, station_code, call_type)

# Table 2.1 Calls per station per year (fire units only;
# 2025 = Jan–Mar for Richmond, Jan–Apr for El Cerrito)
station_calls |>
  left_join(fire_units |> distinct(incident_key, incident_year), by = "incident_key") |>
  count(fdid, station_code, incident_year) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0) |>
  print(n = Inf)

# ============================================================
# PHASE 3 — RESPONSE TIME (apparatus dispatch -> arrival; see M7)
# ============================================================

# Station-scoped, home calls, first unit per station per incident
response_data <- fire_units |>
  filter(!is.na(home_city), call_type == "home",
         !is.na(apparatus_dispatch_time), !is.na(apparatus_arrival_time)) |>
  group_by(incident_key, station_code) |>
  slice_min(apparatus_dispatch_time, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(response_min = as.numeric(difftime(apparatus_arrival_time, apparatus_dispatch_time, units = "mins")))

# Data-quality counts (D4, D5)
response_data |>
  summarize(
    n_total = n(),
    n_negative = sum(response_min < 0),
    n_over_30 = sum(response_min > 30),
    n_over_60 = sum(response_min > 60),
    pct_negative = round(100 * n_negative / n_total, 2),
    pct_over_30 = round(100 * n_over_30 / n_total, 2)
  )

response_data |>
  filter(response_min < 0) |>
  select(incident_key, station_code, incident_category, apparatus_dispatch_time,
         apparatus_arrival_time, response_min)

response_data |>
  filter(response_min > 30) |>
  select(incident_key, station_code, incident_category, apparatus_dispatch_time,
         apparatus_arrival_time, response_min) |>
  arrange(desc(response_min)) |>
  print(n = Inf)

# Summary excluding negatives (D4: FD explanation — non-911 incidents)
response_data |>
  filter(response_min >= 0) |>
  summarize(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            max_min = max(response_min))

# --- Location-scoped incident mix ---
# NOTE (D13): location tables below count reports, not emergencies.
# One emergency can have reports from two departments. For the
# report, use Phase 3B, which counts emergencies (M8).
location_incidents <- fire_units |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND")) |>
  distinct(incident_key, incident_city_clean, incident_category)

location_incidents |>
  count(incident_city_clean, incident_category) |>
  group_by(incident_city_clean) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)

fire_units |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND"),
         incident_category == "Service call") |>
  distinct(incident_key, incident_city_clean, incident_type_code_and_description) |>
  count(incident_city_clean, incident_type_code_and_description, sort = TRUE) |>
  print(n = Inf)

# --- Location-scoped response time, EACH DEPARTMENT'S OWN REPORTS ---
# Kept for reference. The resident view ("first truck, any department")
# is Phase 3B.
response_location <- fire_units |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON", "RICHMOND"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_arrival_time)) |>
  group_by(incident_key) |>
  slice_min(apparatus_dispatch_time, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(response_min = as.numeric(difftime(apparatus_arrival_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(response_min >= 0) |>
  add_response_group()

response_location |>
  group_by(incident_city_clean, incident_type_num, incident_type_code_and_description) |>
  summarize(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(incident_city_clean, desc(n)) |>
  print(n = Inf)

response_location |>
  filter(!is.na(response_group)) |>
  group_by(incident_city_clean, response_group) |>
  summarize(n = n(),
            median_min = median(response_min),
            p90_min = quantile(response_min, 0.9),
            .groups = "drop") |>
  arrange(response_group, incident_city_clean) |>
  print(n = Inf)

# ============================================================
# PHASE 3B — FIRST TRUCK TO ARRIVE, ANY DEPARTMENT (M8, approved 9/24)
# One emergency can have reports from two departments (D13). Reports
# from another department within 10 minutes of the host department's
# report (same city) are merged into one emergency. Response time =
# earliest unit dispatch to earliest unit arrival across the merged
# reports. Ambulances excluded (fire_units). Code 611 "dispatched &
# canceled en route" is not an arrival.
# ============================================================

safe_min <- function(x) if (all(is.na(x))) as.POSIXct(NA, tz = "UTC") else min(x, na.rm = TRUE)

host_dept <- tribble(
  ~incident_city_clean, ~host_fdid,
  "EL CERRITO",         "07040",
  "KENSINGTON",         "07040",
  "RICHMOND",           "07095"
)

# One row per report at these locations
loc_reports <- fire_units |>
  inner_join(host_dept, by = "incident_city_clean") |>
  group_by(incident_key, fdid, host_fdid, incident_city_clean, incident_year,
           incident_type_num, incident_category, incident_aid_type) |>
  summarize(alarm          = safe_min(incident_alarm_dispatch_time),
            first_dispatch = safe_min(apparatus_dispatch_time),
            first_arrival  = safe_min(apparatus_arrival_time),
            .groups = "drop") |>
  mutate(is_host = fdid == host_fdid,
         arrived = !is.na(first_arrival) & coalesce(incident_type_num, 0L) != 611L)

# Link each non-host report to the nearest host report within 10 minutes
host_reps  <- loc_reports |> filter(is_host) |>
  select(host_key = incident_key, incident_city_clean, host_alarm = alarm)

other_reps <- loc_reports |> filter(!is_host, !is.na(alarm)) |>
  transmute(other_key = incident_key, incident_city_clean,
            lo = alarm - 600, hi = alarm + 600, other_alarm = alarm)

links <- other_reps |>
  inner_join(host_reps,
             by = join_by(incident_city_clean, lo <= host_alarm, hi >= host_alarm)) |>
  mutate(gap_min = abs(as.numeric(difftime(other_alarm, host_alarm, units = "mins")))) |>
  group_by(other_key) |>
  slice_min(gap_min, n = 1, with_ties = FALSE) |>
  ungroup()

loc_reports <- loc_reports |>
  left_join(links |> select(incident_key = other_key, host_key), by = "incident_key") |>
  mutate(emergency_id = coalesce(host_key, incident_key))

# One row per emergency
emergencies <- loc_reports |>
  group_by(emergency_id) |>
  summarize(
    incident_city_clean = first(incident_city_clean),
    incident_year       = first(incident_year),
    n_reports           = n(),
    has_host            = any(is_host),
    has_other           = any(!is_host),
    # incident type from the host department's report when present
    incident_type_num   = if (any(is_host)) incident_type_num[is_host][1] else incident_type_num[1],
    incident_category   = if (any(is_host)) incident_category[is_host][1] else incident_category[1],
    # host report says another department helped, but no partner report found
    partner_missing     = n() == 1 & any(is_host & str_detect(coalesce(incident_aid_type, ""), "Received")),
    start               = safe_min(first_dispatch),
    first_arrival_any   = safe_min(first_arrival[arrived]),
    host_arrival        = safe_min(first_arrival[arrived & is_host]),
    first_dept          = if (any(arrived)) fdid[arrived][which.min(first_arrival[arrived])] else NA_character_,
    .groups = "drop") |>
  mutate(response_min = as.numeric(difftime(first_arrival_any, start, units = "mins")),
         first_by = case_when(is.na(first_dept) ~ "no arrival recorded",
                              first_dept %in% c("07040") & incident_city_clean != "RICHMOND" ~ "own department",
                              first_dept == "07095" & incident_city_clean == "RICHMOND" ~ "own department",
                              TRUE ~ "other department")) |>
  add_response_group()

# 1. Reports vs. emergencies, by city
loc_reports |> count(incident_city_clean, name = "reports") |>
  left_join(emergencies |> count(incident_city_clean, name = "emergencies"),
            by = "incident_city_clean")

# 2. How many emergencies involved more than one department
emergencies |>
  count(incident_city_clean, has_host, has_other) |>
  print(n = Inf)

# 3. Uncertainty: host said "aid received" but no partner report found
emergencies |>
  group_by(incident_city_clean) |>
  summarize(emergencies = n(),
            partner_missing = sum(partner_missing),
            pct = round(100 * partner_missing / emergencies, 1),
            .groups = "drop")

# 4. Which department's truck arrived first
emergencies |>
  count(incident_city_clean, first_by) |>
  group_by(incident_city_clean) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  print(n = Inf)

# 5. Same, by year (mutual-aid section, T6)
emergencies |>
  filter(first_by != "no arrival recorded") |>
  count(incident_city_clean, incident_year, first_by) |>
  pivot_wider(names_from = first_by, values_from = n, values_fill = 0) |>
  print(n = Inf)

# 6. First-truck response time (resident view), by city and type
emergencies |>
  filter(!is.na(response_min), response_min >= 0) |>
  group_by(incident_city_clean, response_group) |>
  summarize(n = n(),
            median_min = round(median(response_min), 2),
            p90_min = round(quantile(response_min, 0.9), 2),
            .groups = "drop") |>
  arrange(response_group, incident_city_clean) |>
  print(n = Inf)

# 7. When another department's truck arrived first: by how much?
emergencies |>
  filter(first_by == "other department", !is.na(host_arrival)) |>
  mutate(minutes_earlier = as.numeric(difftime(host_arrival, first_arrival_any, units = "mins"))) |>
  group_by(incident_city_clean) |>
  summarize(n = n(),
            median_minutes_earlier = round(median(minutes_earlier), 2),
            .groups = "drop")

# (o) Share of fire-unit rows with an arrival time, by department and
#     year (D18, D19). Richmond: 0% in 2018 and 2022–2025.
fire_units |>
  filter(fdid %in% c("07040", "07095")) |>
  group_by(fdid, incident_year) |>
  summarize(rows = n(),
            pct_with_arrival = round(100 * mean(!is.na(apparatus_arrival_time)), 1),
            .groups = "drop") |>
  pivot_wider(names_from = fdid, values_from = c(rows, pct_with_arrival))

# (p) Richmond truck first, El Cerrito truck second, both arrival
#     times recorded (D18). 9/24 run: n 34, median 2.89, mean 3.93,
#     p25 0.98, p75 5.22, max 13.7.
emergencies |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         first_dept == "07095", !is.na(host_arrival)) |>
  mutate(minutes_later = as.numeric(difftime(host_arrival, first_arrival_any, units = "mins"))) |>
  summarize(n = n(),
            median = round(median(minutes_later), 2),
            mean = round(mean(minutes_later), 2),
            p25 = round(quantile(minutes_later, 0.25), 2),
            p75 = round(quantile(minutes_later, 0.75), 2),
            max = round(max(minutes_later), 2))

# ============================================================
# PHASE 3C — FIRST-TRUCK RESPONSE TIMES FOR THE REPORT (M9)
# Table 3C.1 El Cerrito and Kensington, all calls, every year
# Table 3C.2 Same, home medical calls only
# Table 3C.3 El Cerrito vs. Richmond, only years both have arrival times
# Table 3C.4 Table 3C.1 without code 900 calls (D33)
# Flags: Richmond arrival times missing in 2018 and 2022–2025; partial
# (37–65% of rows) in 2017, 2019–2021 (D18). El Cerrito arrival times
# on 61–66% of rows (D19). 2025 = January–April only (M5).
# ============================================================

# Table 3C.1 El Cerrito and Kensington, all calls, by year
emergencies |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(response_min), response_min >= 0) |>
  group_by(incident_city_clean, incident_year) |>
  summarize(n = n(),
            median_min = round(median(response_min), 2),
            p90_min = round(quantile(response_min, 0.9), 2),
            .groups = "drop") |>
  print(n = Inf)

# Table 3C.2 Same, home medical calls only
emergencies |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         response_group == "Medical emergency (home)",
         !is.na(response_min), response_min >= 0) |>
  group_by(incident_city_clean, incident_year) |>
  summarize(n = n(),
            median_min = round(median(response_min), 2),
            p90_min = round(quantile(response_min, 0.9), 2),
            .groups = "drop") |>
  print(n = Inf)

# Table 3C.3 Comparison: 2017, 2019, 2020, 2021 only
compare_years <- c(2017, 2019, 2020, 2021)

emergencies |>
  filter(incident_year %in% compare_years,
         !is.na(response_min), response_min >= 0) |>
  group_by(incident_city_clean, response_group) |>
  summarize(n = n(),
            median_min = round(median(response_min), 2),
            p90_min = round(quantile(response_min, 0.9), 2),
            .groups = "drop") |>
  arrange(response_group, incident_city_clean) |>
  print(n = Inf)


# Table 3C.4 First-truck response time by year, excluding code 900 (D33)
emergencies |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(response_min), response_min >= 0,
         coalesce(incident_type_num, 0L) != 900L) |>
  group_by(incident_city_clean, incident_year) |>
  summarize(n = n(),
            median_min = round(median(response_min), 2),
            p90_min = round(quantile(response_min, 0.9), 2),
            .groups = "drop") |>
  print(n = Inf)

# ============================================================
# PHASE 4 — STATION PERFORMANCE & WORKLOAD
# ============================================================

# --- Which station arrives first in Kensington ---
kensington_first_station <- fire_units |>
  filter(incident_city_clean == "KENSINGTON", !is.na(apparatus_arrival_time)) |>
  group_by(incident_key) |>
  slice_min(apparatus_arrival_time, n = 1, with_ties = FALSE) |>
  ungroup()

kensington_first_station |> count(station_code, sort = TRUE)
kensington_first_station |> filter(incident_type_num == 321) |> count(station_code, sort = TRUE)

# --- Cleared-time coverage (D8) ---
fire_units |>
  group_by(fdid, incident_year) |>
  summarize(n = n(), pct_missing = round(100 * mean(is.na(apparatus_cleared_time)), 1),
            .groups = "drop") |>
  arrange(fdid, incident_year) |>
  print(n = Inf)

# --- EC/Kens time on task ---
ec_time_on_task <- fire_units |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins")))

ec_time_on_task |>
  summarize(
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

# ~24-hour cluster (D9) — expect 10
ec_time_on_task |>
  filter(time_on_task_min >= 1400, time_on_task_min <= 1500) |>
  nrow()

# Exclusions: negatives, ~24-hr cluster (D9), wildland deployments (D10)
ec_time_on_task_clean <- ec_time_on_task |>
  filter(time_on_task_min >= 0,
         !(time_on_task_min >= 1400 & time_on_task_min <= 1500),
         !incident_num_year %in% c("8076297_2018", "8078873_2018")) |>
  left_join(response_location |> distinct(incident_key, response_group), by = "incident_key")

ec_time_on_task_clean |>
  filter(!is.na(response_group)) |>
  group_by(response_group) |>
  summarize(n = n(),
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

# --- Apparatus by station (full data, before exclusion) ---
fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55")) |>
  distinct(station_code, apparatus_id, apparatus_type) |>
  count(station_code, apparatus_type, sort = TRUE) |>
  print(n = Inf)

# D11: list apparatus types 75/76 at EC stations (full data, before exclusion).
fire |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         apparatus_type %in% c("75", "76")) |>
  count(station_code, apparatus_id, apparatus_type, sort = TRUE) |>
  print(n = Inf)

# --- Station busy hours (station-scoped; exclusions as above) ---
station_busy_hours <- fire_units |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         !is.na(apparatus_dispatch_time), !is.na(apparatus_cleared_time)) |>
  mutate(time_on_task_min = as.numeric(difftime(apparatus_cleared_time, apparatus_dispatch_time, units = "mins"))) |>
  filter(time_on_task_min >= 0,
         !(time_on_task_min >= 1400 & time_on_task_min <= 1500),
         !incident_num_year %in% c("8076297_2018", "8078873_2018")) |>
  add_response_group() |>
  select(incident_key, station_code, apparatus_id, apparatus_type, incident_city_clean,
         incident_year, call_type, response_group, incident_category, time_on_task_min)

glimpse(station_busy_hours)

station_busy_hours |>
  filter(call_type == "mutual_aid") |>
  group_by(incident_city_clean) |>
  summarize(n = n(), total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  arrange(desc(total_hours)) |>
  print(n = Inf)

station_busy_hours |>
  filter(call_type == "mutual_aid", time_on_task_min > 240) |>
  arrange(desc(time_on_task_min)) |>
  select(incident_key, station_code, apparatus_type, incident_city_clean, incident_year,
         response_group, time_on_task_min) |>
  print(n = Inf)

station_busy_hours |>
  filter(call_type == "mutual_aid", incident_city_clean != "KENSINGTON") |>
  group_by(incident_year) |>
  summarize(n = n(), total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  print(n = Inf)

station_busy_hours |>
  group_by(call_type) |>
  summarize(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1))

station_busy_hours |>
  group_by(call_type, response_group) |>
  summarize(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  group_by(call_type) |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1)) |>
  arrange(call_type, desc(total_hours)) |>
  print(n = Inf)

station_busy_hours <- station_busy_hours |>
  mutate(location_scope = if_else(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
                                  "In EC/Kensington", "Outside EC/Kensington"))

station_busy_hours |>
  group_by(location_scope) |>
  summarize(n = n(), total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1))

# Outside-hours share by year (M3)
station_busy_hours |>
  group_by(incident_year, location_scope) |>
  summarize(total_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  group_by(incident_year) |>
  mutate(pct = round(100 * total_hours / sum(total_hours), 1)) |>
  arrange(incident_year, location_scope) |>
  print(n = Inf)

# In-jurisdiction incident counts by year (M3)
fire_units |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON")) |>
  distinct(incident_key, incident_year) |>
  count(incident_year, name = "n_incidents_in_jurisdiction")

# Engine busy % (M4, M5). Denominator now leap-year aware.
engine_hours <- station_busy_hours |>
  filter(apparatus_type == "11") |>
  group_by(station_code, incident_year) |>
  summarize(busy_hours = round(sum(time_on_task_min) / 60, 1), .groups = "drop") |>
  mutate(hours_in_year = if_else(leap_year(incident_year), 24 * 366, 24 * 365),
         pct_busy = round(100 * busy_hours / hours_in_year, 1),
         partial_year = incident_year == 2025)   # M5: do not compare 2025

engine_hours |> arrange(station_code, incident_year) |> print(n = Inf)

# Structure fire severity, location-scoped, longest unit per incident
station_busy_hours |>
  filter(response_group == "Structure fire", location_scope == "In EC/Kensington") |>
  group_by(incident_key) |>
  summarize(incident_time_on_task = max(time_on_task_min), .groups = "drop") |>
  mutate(severity_bucket = cut(incident_time_on_task,
                               breaks = c(0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, Inf),
                               labels = c("0-5","5-10","10-15","15-20","20-30","30-45",
                                          "45-60","60-90","90-120","120-180","180-240","240+"),
                               right = TRUE, include.lowest = TRUE)) |>
  count(severity_bucket) |>
  mutate(pct = round(100 * n / sum(n), 1))

# Table 4.1 Kensington: whose truck arrived first, by year (% of reports) (D35)
kensington_first_station |>
  mutate(first_unit = case_when(
    fdid == "07040" & station_code %in% c("51", "52", "55") ~ paste("EC", station_code),
    fdid == "07095" ~ "Richmond",
    TRUE ~ "Other")) |>
  count(incident_year, first_unit) |>
  group_by(incident_year) |>
  mutate(pct = round(100 * n / sum(n), 1)) |>
  select(-n) |>
  pivot_wider(names_from = first_unit, values_from = pct, values_fill = 0) |>
  print(n = Inf)

# ============================================================
# PHASE 5 — SEASONALITY (EC/Kens stations, in-jurisdiction)
# ============================================================

ec_home_incidents <- fire_units |>
  filter(fdid == "07040", station_code %in% c("51", "52", "55"),
         incident_city_clean %in% c("EL CERRITO", "KENSINGTON"))

# Hour of day
ec_home_incidents |>
  filter(!is.na(incident_alarm_dispatch_time)) |>
  distinct(incident_key, incident_alarm_dispatch_time) |>
  mutate(hour_of_day = hour(incident_alarm_dispatch_time)) |>
  count(hour_of_day) |>
  arrange(hour_of_day) |>
  print(n = Inf)

# Day of week
ec_home_incidents |>
  filter(!is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(day_of_week = wday(incident_date, label = TRUE, week_start = 1)) |>
  count(day_of_week)

# Day of month, per occurrence of that day
ec_home_incidents |>
  filter(!is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(day_of_month = mday(incident_date)) |>
  count(day_of_month, name = "n_incidents") |>
  left_join(
    tibble(date = seq(as.Date(min(fire$incident_date, na.rm = TRUE)),
                      as.Date(max(fire$incident_date, na.rm = TRUE)), by = "day")) |>
      mutate(day_of_month = mday(date)) |>
      count(day_of_month, name = "n_occurrences"),
    by = "day_of_month"
  ) |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 1)) |>
  arrange(day_of_month) |>
  print(n = Inf)

# Incidents per year (2025 partial, M5)
ec_home_incidents |>
  distinct(incident_key, incident_year) |>
  count(incident_year, name = "n_incidents") |>
  print(n = Inf)

# Month occurrences (2025 counts Jan–Apr only; see M5)
month_occurrences <- fire_units |>
  distinct(incident_year) |>
  tidyr::crossing(month_num = month.abb) |>
  mutate(month_num = factor(month_num, levels = month.abb, ordered = TRUE)) |>
  filter(!(incident_year == 2025 & !month_num %in% month.abb[1:4])) |>
  count(month_num, name = "n_occurrences")

# Month, all incidents
ec_home_incidents |>
  filter(!is.na(incident_date)) |>
  distinct(incident_key, incident_date) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE)) |>
  count(month_num, name = "n_incidents") |>
  left_join(month_occurrences, by = "month_num") |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 1)) |>
  arrange(month_num) |>
  print(n = Inf)

# Month, by response group (four groups)
ec_home_incidents |>
  filter(!is.na(incident_date)) |>
  add_response_group() |>
  filter(response_group %in% c("Structure fire", "Confined fire",
                               "Medical emergency (home)",
                               "Medical emergency (vehicle accident)")) |>
  distinct(incident_key, incident_date, response_group) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE)) |>
  count(response_group, month_num, name = "n_incidents") |>
  left_join(month_occurrences, by = "month_num") |>
  mutate(avg_per_occurrence = round(n_incidents / n_occurrences, 2)) |>
  arrange(response_group, month_num) |>
  print(n = Inf)

# Code 321 by year and month (M6: April 2020 dip)
ec_home_incidents |>
  filter(incident_type_num == 321, incident_year != 2025) |>
  distinct(incident_key, incident_date) |>
  mutate(month_num = month(incident_date, label = TRUE, abbr = TRUE),
         year = year(incident_date)) |>
  count(year, month_num) |>
  tidyr::pivot_wider(names_from = month_num, values_from = n, values_fill = 0) |>
  print(n = Inf)

# ============================================================
# PHASE 5B — TREND AND SEASONALITY GRAPHS (fpp3)
# Monthly series, full months only: Jan 2017 – Dec 2024 (96 months).
# 2025 is partial and left out (M5). The April 2020 shelter-in-place
# dip is shown, not removed (M6). Fire units only (D11).
# Needs the fpp3 package: install.packages("fpp3") once.
# Strength scores (Tables 5B.1–5B.3): 0 = none, 1 = very strong.
# ============================================================

library(fpp3)

ts_start <- yearmonth("2017 Jan")
ts_end   <- yearmonth("2024 Dec")

# --- Series 1: incidents in El Cerrito/Kensington answered by
#     Stations 51, 52, 55 (same scope as Phase 5), by call group
ec_monthly <- ec_home_incidents |>
  add_response_group() |>
  distinct(incident_key, incident_date, response_group) |>
  mutate(month = yearmonth(as.Date(incident_date)),
         call_group = case_when(
           response_group == "Medical emergency (home)" ~ "Medical (home)",
           response_group == "Service call"             ~ "Service call",
           response_group == "Good intent call"         ~ "Good intent",
           response_group == "False alarm/false call"   ~ "False alarm",
           TRUE                                         ~ "All other")) |>
  filter(month >= ts_start, month <= ts_end)

ec_total <- ec_monthly |>
  count(month, name = "incidents") |>
  as_tsibble(index = month) |>
  fill_gaps(incidents = 0L)

ec_by_group <- ec_monthly |>
  count(call_group, month, name = "incidents") |>
  as_tsibble(index = month, key = call_group) |>
  fill_gaps(incidents = 0L)

# Figure 5B.1 Monthly incidents
ec_total |>
  autoplot(incidents) +
  labs(title = "El Cerrito and Kensington: incidents per month, 2017–2024",
       subtitle = "Answered by Stations 51, 52, 55; fire units only. April 2020 = shelter-in-place.",
       x = NULL, y = "Incidents")

# Figure 5B.2 Seasonal plot: one line per year
ec_total |>
  gg_season(incidents, labels = "both") +
  labs(title = "Incidents per month, one line per year",
       x = NULL, y = "Incidents")

# Figure 5B.3 Subseries plot: each month across the years (blue line = average)
ec_total |>
  gg_subseries(incidents) +
  labs(title = "Incidents by month across years",
       x = NULL, y = "Incidents")

# Figure 5B.4 STL decomposition: trend, seasonal pattern, remainder
ec_total |>
  model(STL(incidents ~ trend(window = 13) + season(window = "periodic"), robust = TRUE)) |>
  components() |>
  autoplot() +
  labs(title = "Incidents per month: trend, seasonal pattern, and remainder")

# Figure 5B.5 Monthly incidents by call group
ec_by_group |>
  autoplot(incidents) +
  facet_wrap(vars(call_group), scales = "free_y") +
  theme(legend.position = "none") +
  labs(title = "Incidents per month by call group", x = NULL, y = "Incidents")

# Figure 5B.6 Seasonal plot, home medical calls
ec_by_group |>
  filter(call_group == "Medical (home)") |>
  gg_season(incidents, labels = "both") +
  labs(title = "Home medical calls per month, one line per year",
       x = NULL, y = "Calls")

# Table 5B.1 Strength of trend and yearly seasonality, by call group
bind_rows(
  ec_total |> features(incidents, feat_stl) |> mutate(call_group = "All incidents"),
  ec_by_group |> features(incidents, feat_stl)
) |>
  select(call_group, trend_strength, seasonal_strength_year) |>
  mutate(across(where(is.numeric), ~ round(.x, 2)))

# --- Series 2: incidents per month by city (host department's own
#     reports, fire units). Counts need no arrival times, so every
#     year can be used for Richmond too.
city_monthly <- loc_reports |>
  filter(is_host, !is.na(alarm)) |>
  mutate(month = yearmonth(as.Date(alarm))) |>
  filter(month >= ts_start, month <= ts_end) |>
  count(incident_city_clean, month, name = "incidents") |>
  as_tsibble(index = month, key = incident_city_clean) |>
  fill_gaps(incidents = 0L)

# Figure 5B.7 Seasonal plots by city
city_monthly |>
  gg_season(incidents) +
  labs(title = "Incidents per month by city, one line per year",
       x = NULL, y = "Incidents")

# Table 5B.2 Strength of trend and yearly seasonality, by city
city_monthly |>
  features(incidents, feat_stl) |>
  select(incident_city_clean, trend_strength, seasonal_strength_year) |>
  mutate(across(where(is.numeric), ~ round(.x, 2)))

# --- Series 3: monthly median first-truck response time (Phase 3B, M8)
#     El Cerrito and Kensington only. Flags: El Cerrito arrival times
#     on 61–66% of rows (D19); Kensington has about 30 calls a month,
#     so its monthly medians are noisy.
resp_monthly <- emergencies |>
  filter(incident_city_clean %in% c("EL CERRITO", "KENSINGTON"),
         !is.na(response_min), response_min >= 0) |>
  mutate(month = yearmonth(as.Date(start))) |>
  filter(month >= ts_start, month <= ts_end) |>
  group_by(incident_city_clean, month) |>
  summarize(median_min = median(response_min), n = n(), .groups = "drop") |>
  as_tsibble(index = month, key = incident_city_clean)

has_gaps(resp_monthly)   # expect FALSE for both cities

# Figure 5B.8 Monthly median first-truck response time
resp_monthly |>
  autoplot(median_min) +
  labs(title = "Median minutes to first truck, by month",
       subtitle = "Dispatch to arrival; fire units only; any department (M8)",
       x = NULL, y = "Minutes", color = NULL)

# Figure 5B.9 STL decomposition, El Cerrito median response time
resp_monthly |>
  filter(incident_city_clean == "EL CERRITO") |>
  model(STL(median_min ~ trend(window = 13) + season(window = "periodic"), robust = TRUE)) |>
  components() |>
  autoplot() +
  labs(title = "El Cerrito median response time: trend, seasonal pattern, and remainder")

# Table 5B.3 Strength of trend and yearly seasonality, response time
resp_monthly |>
  features(median_min, feat_stl) |>
  select(incident_city_clean, trend_strength, seasonal_strength_year) |>
  mutate(across(where(is.numeric), ~ round(.x, 2)))

# Table 5B.4 What is in "All other"? Top incident types by year (D33, D34)
ec_home_incidents |>
  add_response_group() |>
  filter(!response_group %in% c("Medical emergency (home)", "Service call",
                                "Good intent call", "False alarm/false call")) |>
  distinct(incident_key, incident_year, incident_type_code_and_description) |>
  count(incident_type_code_and_description, incident_year) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0) |>
  arrange(desc(`2023`)) |>
  head(10)

# ============================================================
# PHASE 6 — NEW NFIRS FILE (S2) AND MATCH WITH ORIGINAL EXPORT (D21)
# Overlap window: Jan 1, 2023 – Mar 31, 2025.
# Reviewed 9/24: see D29 and D27.
# ============================================================

new_nfirs <- read_city_export(new_nfirs_file) |>
  mutate(incident_number = basic_incident_number,
         incident_year  = as.integer(basic_incident_year),
         incident_month = as.integer(basic_incident_month),
         alarm_time     = parse_date_time(basic_incident_alarm_date_time, orders = "mdY IMS p", tz = "UTC"),
         psap_min       = as.numeric(basic_incident_psap_to_arrival_in_minutes),
         series_new     = as.integer(str_extract(basic_incident_type_category, "^\\d")))

dim(new_nfirs)                 # expect 11,904 rows
names(new_nfirs)

# One row per incident
new_nfirs_inc <- new_nfirs |>
  distinct(incident_number, incident_year, .keep_all = TRUE)

new_nfirs_inc |> count(incident_year)   # expect 2023 = 3,899; 2024 = 3,231; 2025 = 3,331

# Incident number format by year/month (D2, D24)
new_nfirs_inc |>
  mutate(n_digits = nchar(incident_number)) |>
  count(incident_year, incident_month, n_digits) |>
  print(n = Inf)

# --- Build both sides of the overlap ---
old_overlap <- fire |>
  filter(fdid == "07040",
         as.Date(incident_date) >= as.Date("2023-01-01"),
         as.Date(incident_date) <  as.Date("2025-04-01")) |>
  mutate(incident_number = id_chr(incident_number),
         incident_year = as.integer(incident_year)) |>
  arrange(incident_number, incident_year, apparatus_dispatch_time) |>
  distinct(incident_number, incident_year, .keep_all = TRUE) |>
  transmute(incident_number, incident_year,
            old_series = incident_type_num %/% 100,
            old_type   = incident_type_code_and_description,
            old_alarm  = incident_alarm_dispatch_time,
            old_city   = incident_city_clean)

new_overlap <- new_nfirs_inc |>
  filter(incident_year < 2025 | incident_month <= 3) |>
  transmute(incident_number, incident_year,
            series_new,
            new_type  = basic_incident_type,
            new_alarm = alarm_time,
            new_city  = basic_incident_city_name)

overlap_match <- full_join(old_overlap |> mutate(in_old = TRUE),
                           new_overlap |> mutate(in_new = TRUE),
                           by = c("incident_number", "incident_year")) |>
  mutate(across(c(in_old, in_new), ~ replace_na(.x, FALSE)),
         status = case_when(in_old & in_new ~ "both",
                            in_old ~ "old only",
                            TRUE ~ "new only"))

# 1. How many incidents are in both, old only, new only
overlap_match |>
  count(incident_year, status) |>
  pivot_wider(names_from = status, values_from = n, values_fill = 0) |>
  print(n = Inf)

# 2. For matched incidents: same NFIRS series (first digit of type code)?
#    Series used because description wording differs between systems
#    (e.g., "Dispatched & canceled enroute" vs "Dispatched and cancelled en route").
overlap_match |>
  filter(status == "both") |>
  summarize(n = n(),
            series_same = sum(old_series == series_new, na.rm = TRUE),
            pct_same = round(100 * series_same / n, 1))

overlap_match |>
  filter(status == "both", old_series != series_new) |>
  count(old_series, series_new, sort = TRUE) |>
  print(n = Inf)

# 3. For matched incidents: alarm times agree?
overlap_match |>
  filter(status == "both", !is.na(old_alarm), !is.na(new_alarm)) |>
  mutate(diff_min = abs(as.numeric(difftime(new_alarm, old_alarm, units = "mins")))) |>
  summarize(n = n(),
            within_1_min = sum(diff_min <= 1),
            pct_within_1_min = round(100 * within_1_min / n, 1),
            median_diff_min = median(diff_min))

# 4. What do unmatched incidents look like?
overlap_match |>
  filter(status == "old only") |>
  count(old_city, old_series, sort = TRUE) |>
  print(n = 30)

overlap_match |>
  filter(status == "new only") |>
  count(new_city, series_new, sort = TRUE) |>
  print(n = 30)

# (q) D27: were S1 code-500 incidents relabeled in S2?
#     For matched incidents coded 500 in S1, what does S2 call them?
overlap_match |>
  filter(status == "both", str_detect(old_type, "^500 ")) |>
  count(incident_year, new_type, sort = TRUE) |>
  print(n = 30)

# ============================================================
# PHASE 7 — EL CERRITO-ONLY UPDATE, 2023–2025 (S2)
# Incident-level only. No Richmond. No unit-level times (D20).
# ============================================================

# Incidents by NFIRS category and year
new_nfirs_inc |>
  count(basic_incident_type_category, incident_year) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0) |>
  print(n = Inf)
# expect, e.g., "3 - Rescue & EMS": 1,375 / 1,117 / 1,208;
#               "5 - Service Call":   833 /   632 /   734

# "Service call, other" by year and month (D7, D27)
new_nfirs_inc |>
  filter(basic_incident_type == "Service call, other") |>
  count(incident_year, incident_month) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0) |>
  arrange(incident_month) |>
  print(n = Inf)
# expect totals 2023 = 497, 2024 = 7, 2025 = 7

# 2023 -> 2024 change by incident type (D27)
new_nfirs_inc |>
  filter(incident_year %in% 2023:2024) |>
  count(basic_incident_type, incident_year) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0) |>
  mutate(change = `2024` - `2023`) |>
  arrange(change) |>
  head(10)

# PSAP-to-arrival coverage by year and month (D22)
new_nfirs_inc |>
  group_by(incident_year, incident_month) |>
  summarize(n = n(), n_psap = sum(!is.na(psap_min)), .groups = "drop") |>
  print(n = Inf)

# 90th percentile PSAP-to-arrival where available, 2025 (D22)
new_nfirs_inc |>
  filter(incident_year == 2025, !is.na(psap_min)) |>
  summarize(n = n(), p90_min = round(quantile(psap_min, 0.9), 2))
# expect n = 790, p90 = 9.35 (dashboard "2025": 9:18)

new_nfirs_inc |>
  filter(incident_year == 2025, !is.na(psap_min)) |>
  group_by(basic_primary_station_name) |>
  summarize(n = n(), p90_min = round(quantile(psap_min, 0.9), 2), .groups = "drop")
# expect St51 8.34, St52 10.02, St55 9.91 (dashboard 8:12 / 10:01 / 9:58)

# Kensington coded as automatic aid given, 2025 (D25)
new_nfirs_inc |>
  filter(incident_year == 2025, basic_aid_given_or_received == "Automatic aid given",
         str_detect(basic_aid_given_their_fire_department_name, "Cerrito|Kensington")) |>
  mutate(period = if_else(incident_month <= 4, "Jan-Apr", "May-Dec")) |>
  count(period, basic_aid_given_their_fire_department_name, basic_incident_city_name) |>
  print(n = Inf)

# Aid given/received by year
new_nfirs_inc |>
  count(incident_year, basic_aid_given_or_received) |>
  pivot_wider(names_from = incident_year, values_from = n, values_fill = 0)

# ============================================================
# PHASE 8 — NERIS 2026 (S3) — STANDALONE
# Not comparable with NFIRS years by type (D31). January missing
# (D30). September partial (file generated 9/23/2026).
# ============================================================

neris <- read_city_export(new_neris_file) |>
  mutate(incident_number = incident_number_id,
         incident_month  = as.integer(incident_month_number),
         psap_min        = as.numeric(incident_psap_to_arrival_in_minutes))

dim(neris)                     # expect 4,781 rows
names(neris)

neris_inc <- neris |> distinct(incident_number, .keep_all = TRUE)
nrow(neris_inc)                # expect 2,084

neris_inc |> count(incident_month)
neris_inc |> count(incident_type_primary_category_1, sort = TRUE)
# expect Medical 995, No Emergency 638, Public Service 243,
#        Hazardous Situation 100, Fire 86, Rescue 13, blank 9

neris_inc |> count(incident_primary_station, sort = TRUE)

# 90th percentile PSAP-to-arrival by primary station (D32)
neris_inc |>
  filter(!is.na(psap_min)) |>
  group_by(incident_primary_station) |>
  summarize(n = n(), p90_min = round(quantile(psap_min, 0.9), 2), .groups = "drop")
# expect St51 8.36, St52 10.48, St55 10.78, Mutual Aid 12.54
# dashboard: 8:24 / 10:30 / 11:12 / 12:10 — approximate, not exact

neris_inc |>
  filter(!is.na(psap_min)) |>
  summarize(n = n(), p90_min = round(quantile(psap_min, 0.9), 2))
# expect n = 1,859, p90 = 9.50 (dashboard overall 9:39)
