# ============================================================================
# 02_assemble_bc_catch.R — Assemble BC-wide catch panel from Open Data
# analysis/05_bc_coastwide
#
# Input:  Data/raw/dfo-catch/bc_commercial_catch_OPEN_DATA.csv
#         (from scripts/00_data_acquisition.R)
# Output: Data/processed/bc_catch_by_section_year_gear.csv
#         (one row per section-year-gear with catch in metric tonnes)
#
# Schema target: year, stock_area, statistical_area, section, gear, catch_tonnes.
# The DFO Open Data raw column names vary release-to-release; this script does
# name harmonization via clean_names() + an explicit rename map.
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(janitor)
})

source(here::here("R", "00_setup.R"))

raw_path <- here::here("Data", "raw", "dfo-catch", "bc_commercial_catch_OPEN_DATA.csv")
stopifnot(file.exists(raw_path))

raw <- read_csv(raw_path,
                locale = locale(encoding = "ISO-8859-1"),
                show_col_types = FALSE) |>
  clean_names()

cat("Raw catch columns:", paste(names(raw), collapse = ", "), "\n")

# Map common DFO column names to the canonical schema. The bilingual source
# headers have changed encoding across releases, so use stable prefixes instead
# of exact cleaned names.
find_col <- function(patterns, required = TRUE) {
  hits <- unique(unlist(lapply(patterns, grep, names(raw), value = TRUE)))
  if (length(hits) == 0L) {
    if (required) {
      stop("Could not find required catch column matching: ",
           paste(patterns, collapse = " | "))
    }
    return(NA_character_)
  }
  hits[[1]]
}

year_col <- find_col(c("^year", "^calendar_year", "^fishing_year"))
stock_col <- find_col(c("^stock_assessment_region", "^stock_area$", "^region$"))
area_col <- find_col(c("^statistical_area", "^stat_area$", "^area$"))
section_col <- find_col(c("^section"))
gear_col <- find_col(c("^gear", "^gear_type"))
catch_col <- find_col(c("^sum_of_catch_metric_tonnes", "^catch_tonnes$",
                        "^catch$", "^catch_t$"))

panel <- tibble(
  year = as.integer(raw[[year_col]]),
  stock_area = as.character(raw[[stock_col]]),
  statistical_area = as.character(raw[[area_col]]),
  section = as.character(raw[[section_col]]),
  gear = as.character(raw[[gear_col]]),
  catch_tonnes = as.numeric(raw[[catch_col]])
) |>
  mutate(stock_area = case_when(
    stock_area == "Haida Gwaii" ~ "HG",
    stock_area == "Prince Rupert District" ~ "PRD",
    stock_area == "Central Coast" ~ "CC",
    stock_area == "Strait of Georgia" ~ "SoG",
    stock_area == "West Coast Vancouver Island" ~ "WCVI",
    stock_area == "Area 27" ~ "A27",
    stock_area == "Area 2W" ~ "A2W",
    stock_area == "Other" ~ "NA",
    TRUE ~ stock_area
  )) |>
  filter(!is.na(year), !is.na(stock_area)) |>
  select(year, stock_area, statistical_area, section, gear, catch_tonnes) |>
  arrange(year, stock_area, statistical_area, section, gear)

out_path <- here::here("Data", "processed", "bc_catch_by_section_year_gear.csv")
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
write_csv(panel, out_path)

cat("Wrote", nrow(panel), "rows to", out_path, "\n")
cat("Stock-area distribution:\n")
print(panel |> count(stock_area))
cat("Gear distribution:\n")
print(panel |> count(gear))
