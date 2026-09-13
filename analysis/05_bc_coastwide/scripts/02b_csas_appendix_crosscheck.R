# ============================================================================
# 02b_csas_appendix_crosscheck.R — Extract CSAS Appendix B catch tables
# analysis/05_bc_coastwide
#
# Input:  DFO CSAS Research Document 2018/028 text/PDF
# Output: Data/processed/bc_catch_csas_appendix.csv
#         Data/processed/bc_pre_roe_catch_assessment_tables.csv
#         Output/diagnostics/bc_catch_csas_concordance.md
#
# Tables B.1-B.7 in DFO CSAS Res. Doc. 2018/028 are the public assessment
# catch tables for the five major and two minor BC Pacific herring SARs. They
# cover 1951-2017 and include Gear1 ("Other" = reduction, food and bait,
# special use), Gear2 (roe seine), and Gear3 (roe gillnet). This script extracts
# those public tables from the PDF text and keeps them separate from the
# section-level Open Data roe-catch input used by the current coastwide models.
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(knitr)
})

source(here::here("R", "00_setup.R"))

processed_dir <- here::here("Data", "processed")
raw_dir <- here::here("Data", "raw", "dfo-catch", "csas-2018-028")
diag_dir <- here::here("Output", "diagnostics")
dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

source_document <- "DFO CSAS Research Document 2018/028"
source_title <- paste(
  "Stock assessment for Pacific Herring (Clupea pallasii) in British Columbia",
  "in 2017 and forecast for 2018"
)
source_url <- "https://waves-vagues.dfo-mpo.gc.ca/library-bibliotheque/40944670.pdf"
source_local_pdf <- file.path(raw_dir, "dfo_herring_scad_2018_028.pdf")
source_local_text <- file.path(raw_dir, "dfo_herring_scad_2018_028.txt")
source_local_layout <- file.path(raw_dir, "dfo_herring_scad_2018_028_layout.txt")

legacy_pdf <- here::here(
  "Output", "diagnostics", "dfo_assessment_public_sources",
  "dfo_herring_scad_2018_028.pdf"
)
legacy_text <- here::here(
  "Output", "diagnostics", "dfo_assessment_public_sources",
  "dfo_herring_scad_2018_028.txt"
)
legacy_layout <- here::here(
  "Output", "diagnostics", "dfo_assessment_public_sources",
  "dfo_herring_scad_2018_028_layout.txt"
)

is_pdf_file <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    return(FALSE)
  }
  identical(rawToChar(readBin(path, what = "raw", n = 4)), "%PDF")
}

ensure_source_text <- function() {
  if (file.exists(source_local_layout) && file.info(source_local_layout)$size > 0) {
    return("raw_layout_text_already_present")
  }

  if (file.exists(legacy_layout) && file.info(legacy_layout)$size > 0) {
    file.copy(legacy_layout, source_local_layout, overwrite = TRUE)
    if (file.exists(legacy_text) && file.info(legacy_text)$size > 0) {
      file.copy(legacy_text, source_local_text, overwrite = TRUE)
    }
    if (file.exists(legacy_pdf) && is_pdf_file(legacy_pdf)) {
      file.copy(legacy_pdf, source_local_pdf, overwrite = TRUE)
    }
    return("copied_existing_public_source_layout_text_from_Output_diagnostics")
  }

  if (!is_pdf_file(source_local_pdf)) {
    message("Downloading public CSAS source PDF: ", source_url)
    download.file(source_url, source_local_pdf, mode = "wb", quiet = TRUE)
  }
  if (!is_pdf_file(source_local_pdf)) {
    stop("Could not locate or download a valid CSAS 2018/028 PDF.")
  }

  pdftotext <- Sys.which("pdftotext")
  if (!nzchar(pdftotext)) {
    stop("pdftotext is required to extract Appendix B catch tables.")
  }
  status_plain <- system2(pdftotext, c(source_local_pdf, source_local_text))
  status_layout <- system2(pdftotext, c("-layout", source_local_pdf, source_local_layout))
  if (!identical(status_plain, 0L) && !is.null(status_plain)) {
    stop("pdftotext plain extraction failed for ", source_local_pdf)
  }
  if (!identical(status_layout, 0L) && !is.null(status_layout)) {
    stop("pdftotext layout extraction failed for ", source_local_pdf)
  }
  if (!file.exists(source_local_layout) || file.info(source_local_layout)$size == 0) {
    stop("pdftotext produced no layout text for ", source_local_pdf)
  }
  "downloaded_or_extracted_public_source_layout_text"
}

clean_line <- function(x) {
  x |>
    str_replace_all("\f", " ") |>
    str_squish()
}

table_manifest <- tribble(
  ~source_table, ~stock_area, ~stock_area_name,
  "Table B.1", "HG", "Haida Gwaii",
  "Table B.2", "PRD", "Prince Rupert District",
  "Table B.3", "CC", "Central Coast",
  "Table B.4", "SoG", "Strait of Georgia",
  "Table B.5", "WCVI", "West Coast Vancouver Island",
  "Table B.6", "A27", "Area 27",
  "Table B.7", "A2W", "Area 2 West"
) |>
  mutate(
    table_number = as.integer(str_extract(source_table, "\\d+$")),
    start_pattern = paste0("^Table B\\.", table_number, "\\."),
    end_pattern = paste0("^Table B\\.", table_number + 1L, "\\.")
  )

gear_lut <- tribble(
  ~gear_number, ~gear, ~gear_description,
  1L, "Gear1_Other",
  "Reduction fishery, food and bait fishery, and special use fishery",
  2L, "Gear2_RoeSN", "Roe seine fishery",
  3L, "Gear3_RoeGN", "Roe gillnet fishery"
)

catch_row_pattern <- paste0(
  "^\\s*(195[1-9]|196[0-9]|197[0-9]|198[0-9]|199[0-9]|200[0-9]|201[0-7])",
  "\\s+([0-9]+\\.[0-9]{3})\\s+([0-9]+\\.[0-9]{3})\\s+([0-9]+\\.[0-9]{3})\\s*$"
)

parse_layout_rows <- function(block, source_table) {
  matches <- str_match(block, catch_row_pattern)
  keep <- !is.na(matches[, 1])
  if (!any(keep)) {
    stop("No catch rows parsed in ", source_table)
  }

  as_tibble(matches[keep, -1, drop = FALSE], .name_repair = ~ c("year", "Gear1", "Gear2", "Gear3")) |>
    mutate(
      year = as.integer(year),
      across(starts_with("Gear"), as.numeric)
    ) |>
    pivot_longer(
      cols = starts_with("Gear"),
      names_to = "gear_col",
      values_to = "catch_kt"
    ) |>
    mutate(gear_number = as.integer(str_remove(gear_col, "^Gear"))) |>
    select(year, gear_number, catch_kt)
}

extract_table <- function(lines, manifest_row) {
  start_idx <- str_which(lines, manifest_row$start_pattern)[1]
  end_idx <- str_which(lines, manifest_row$end_pattern)[1]
  if (is.na(start_idx) || is.na(end_idx) || end_idx <= start_idx) {
    stop("Could not isolate ", manifest_row$source_table, " in ", source_local_layout)
  }

  block <- lines[start_idx:(end_idx - 1L)]
  excerpt_path <- file.path(
    raw_dir,
    paste0("csas_2018_028_", str_replace_all(manifest_row$source_table, "[ .]", "_"),
           "_", manifest_row$stock_area, "_raw_excerpt.txt")
  )
  writeLines(block, excerpt_path)

  parsed <- parse_layout_rows(block, manifest_row$source_table)

  expected_years <- 1951:2017
  missing_years <- setdiff(expected_years, parsed$year)
  extra_years <- setdiff(unique(parsed$year), expected_years)
  if (length(missing_years) > 0L || length(extra_years) > 0L) {
    stop(
      manifest_row$source_table, " year coverage mismatch. Missing: ",
      paste(missing_years, collapse = ", "), "; extra: ",
      paste(extra_years, collapse = ", ")
    )
  }

  parsed |>
    left_join(gear_lut, by = "gear_number") |>
    mutate(
      stock_area = manifest_row$stock_area,
      stock_area_name = manifest_row$stock_area_name,
      catch_tonnes = catch_kt * 1000,
      source_document = source_document,
      source_title = source_title,
      source_table = manifest_row$source_table,
      source_url = source_url,
      source_local_text = source_local_layout,
      source_raw_excerpt = excerpt_path,
      extraction_method = "pdftotext -layout row-regex extraction with annual row checks",
      extraction_notes = paste(
        "Catch values are published in thousands of metric tonnes.",
        "Gear1 is Other fisheries; Gear2 is roe seine; Gear3 is roe gillnet.",
        "This public assessment table is a stock-area annual source, not a",
        "section-level roe-catch table."
      ),
      model_use_status = "candidate_input_requires_concordance_and_area_mapping_audit"
    ) |>
    select(
      year, stock_area, stock_area_name, gear_number, gear, gear_description,
      catch_kt, catch_tonnes,
      source_document, source_title, source_table, source_url,
      source_local_text, source_raw_excerpt, extraction_method,
      extraction_notes, model_use_status
    ) |>
    arrange(stock_area, year, gear_number)
}

source_status <- ensure_source_text()
source_lines <- readLines(source_local_layout, warn = FALSE) |> clean_line()

csas_catch <- pmap_dfr(table_manifest, function(...) {
  extract_table(source_lines, tibble(...) |> slice(1))
})

pre_roe_catch <- csas_catch |>
  filter(year < 1972)

pre_1972_roe_check <- pre_roe_catch |>
  filter(gear_number %in% c(2L, 3L), catch_tonnes != 0)
if (nrow(pre_1972_roe_check) > 0L) {
  print(pre_1972_roe_check |> select(year, stock_area, source_table, gear, catch_kt) |> head(30))
  stop("Expected Gear2/Gear3 to be zero before 1972; found non-zero rows.")
}

dup_check <- csas_catch |>
  count(year, stock_area, gear_number) |>
  filter(n != 1L)
if (nrow(dup_check) > 0L) {
  stop("Duplicate or missing annual gear rows detected in CSAS catch extraction.")
}

catch_out <- file.path(processed_dir, "bc_catch_csas_appendix.csv")
pre_roe_out <- file.path(processed_dir, "bc_pre_roe_catch_assessment_tables.csv")
write_csv(csas_catch, catch_out)
write_csv(pre_roe_catch, pre_roe_out)

open_data_path <- file.path(processed_dir, "bc_catch_by_section_year_gear.csv")
concordance <- tibble()
if (file.exists(open_data_path)) {
  open_data <- read_csv(open_data_path, na = character(), show_col_types = FALSE) |>
    mutate(
      stock_area = if_else(is.na(stock_area), "NA", stock_area),
      catch_tonnes = readr::parse_number(as.character(catch_tonnes)),
      csas_gear = case_when(
        gear == "Seine" ~ "Gear2_RoeSN",
        gear == "Gillnet" ~ "Gear3_RoeGN",
        TRUE ~ NA_character_
      )
    ) |>
    filter(!is.na(csas_gear), year <= 2017)

  od_sum <- open_data |>
    group_by(year, stock_area, csas_gear) |>
    summarise(open_data_tonnes = sum(catch_tonnes, na.rm = TRUE), .groups = "drop")

  csas_roe <- csas_catch |>
    filter(gear_number %in% c(2L, 3L)) |>
    transmute(
      year, stock_area, csas_gear = gear,
      csas_tonnes = catch_tonnes
    )

  concordance <- inner_join(od_sum, csas_roe, by = c("year", "stock_area", "csas_gear")) |>
    mutate(
      diff_tonnes = open_data_tonnes - csas_tonnes,
      abs_diff_tonnes = abs(diff_tonnes),
      rel_diff = if_else(csas_tonnes > 0, abs_diff_tonnes / csas_tonnes, NA_real_),
      concordance_note = case_when(
        is.na(rel_diff) & open_data_tonnes == 0 ~ "both_zero_or_csas_zero",
        is.na(rel_diff) ~ "csas_zero_open_data_nonzero",
        rel_diff <= 0.02 ~ "within_2_percent",
        TRUE ~ "differs_more_than_2_percent"
      )
    ) |>
    arrange(desc(abs_diff_tonnes))
}

pre_roe_summary <- pre_roe_catch |>
  group_by(stock_area, stock_area_name) |>
  summarise(
    years = paste(range(year), collapse = "-"),
    total_pre_roe_tonnes = sum(catch_tonnes),
    max_pre_roe_tonnes = max(catch_tonnes),
    max_pre_roe_year = year[which.max(catch_tonnes)],
    .groups = "drop"
  ) |>
  arrange(desc(total_pre_roe_tonnes))

full_summary <- csas_catch |>
  group_by(stock_area, stock_area_name, gear) |>
  summarise(
    years = paste(range(year), collapse = "-"),
    n_rows = n(),
    total_tonnes = sum(catch_tonnes),
    .groups = "drop"
  ) |>
  arrange(stock_area, gear)

if (nrow(concordance) > 0L) {
  concordance_out <- file.path(diag_dir, "bc_catch_csas_open_data_concordance.csv")
  write_csv(concordance, concordance_out)
}

diag_path <- file.path(diag_dir, "bc_catch_csas_concordance.md")
report_lines <- c(
  "# BC Catch CSAS Appendix Extraction",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Source",
  "",
  paste0("- Source document: ", source_document),
  paste0("- Title: ", source_title),
  paste0("- Source URL: ", source_url),
  paste0("- Local source layout text: `", source_local_layout, "`"),
  paste0("- Source acquisition status: `", source_status, "`"),
  "",
  "## Products",
  "",
  paste0("- Full CSAS catch table: `", catch_out, "`"),
  paste0("- Pre-roe subset: `", pre_roe_out, "`"),
  "- Raw table excerpts: `Data/raw/dfo-catch/csas-2018-028/csas_2018_028_Table_B_*_raw_excerpt.txt`",
  "",
  "## Extraction Checks",
  "",
  paste0("- Extracted rows: ", nrow(csas_catch)),
  paste0("- Stock areas: ", paste(unique(csas_catch$stock_area), collapse = ", ")),
  paste0("- Year range: ", paste(range(csas_catch$year), collapse = "-")),
  "- Expected structure: 7 stock areas x 67 years x 3 gears = 1407 rows.",
  "- Pre-1972 Gear2/Gear3 check: all zero.",
  "",
  "## Pre-Roe Catch Summary",
  "",
  knitr::kable(pre_roe_summary, format = "pipe"),
  "",
  "## Full Table Summary By Gear",
  "",
  knitr::kable(full_summary, format = "pipe"),
  "",
  "## Open Data Concordance",
  ""
)

if (nrow(concordance) > 0L) {
  concordance_summary <- concordance |>
    group_by(csas_gear) |>
    summarise(
      joint_rows = n(),
      within_2_percent = sum(concordance_note == "within_2_percent", na.rm = TRUE),
      median_abs_diff_tonnes = median(abs_diff_tonnes, na.rm = TRUE),
      max_abs_diff_tonnes = max(abs_diff_tonnes, na.rm = TRUE),
      .groups = "drop"
    )
  report_lines <- c(
    report_lines,
    "The Open Data roe-catch product is section-level and covers roe seine/gillnet",
    "from 1972 onward. The CSAS Appendix B tables are stock-area assessment-input",
    "summaries through 2017. Concordance is therefore a diagnostic, not an",
    "automatic merge rule; withheld Open Data cells (`WP`) are currently `NA` in",
    "`bc_catch_by_section_year_gear.csv` and sum as zero here.",
    "",
    paste0("- Concordance CSV: `", concordance_out, "`"),
    "",
    knitr::kable(concordance_summary, format = "pipe"),
    "",
    "Largest absolute differences:",
    "",
    knitr::kable(
      concordance |>
        select(year, stock_area, csas_gear, open_data_tonnes, csas_tonnes,
               diff_tonnes, rel_diff, concordance_note) |>
        slice_head(n = 12),
      format = "pipe"
    )
  )
} else {
  report_lines <- c(
    report_lines,
    "No Open Data concordance was run because `bc_catch_by_section_year_gear.csv`",
    "was not present."
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Model-Use Gate",
  "",
  "These tables have been acquired and parsed, but they are not yet wired into",
  "`bc_stan_data.rds`. Before using them in a coastwide refit, decide whether the",
  "model should use stock-area annual catch only, distribute pre-roe Gear1 catch",
  "to sections, or keep the current section-level roe-catch likelihood and use",
  "Appendix B only as a historical fishing-pressure covariate."
)

writeLines(report_lines, diag_path)

cat("Wrote CSAS Appendix B catch products:\n")
cat("  ", catch_out, "\n")
cat("  ", pre_roe_out, "\n")
cat("  ", diag_path, "\n")
