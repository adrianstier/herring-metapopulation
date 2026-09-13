# ============================================================================
# 00_data_acquisition.R — Refresh BC-wide DFO datasets
# analysis/05_bc_coastwide
#
# Downloads/refreshes:
#   - Pacific Herring spawn index (BC-wide; already present, re-download for refresh)
#   - Pacific Herring commercial catch (BC-wide, Open Data Portal)
#
# Open Data Portal landing:
#   https://open.canada.ca/data/en/dataset?q=pacific+herring
#
# IMPORTANT: DFO occasionally rotates the resource URL on the portal. If the
# request returns a 404, browse the portal, find the most recent "Pacific
# Herring Commercial Catch" resource, update CATCH_URL below, and re-run.
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(httr)
  library(jsonlite)
})

source(here::here("R", "00_setup.R"))

raw_dir <- here::here("Data", "raw", "dfo-catch")
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

# The Open Canada package is split into one CSV per stock area.
package_id <- Sys.getenv(
  "DFO_HERRING_CATCH_PACKAGE_ID",
  unset = "71c25df1-0577-43f7-b9f8-95cc321e7cbc"
)
package_url <- paste0(
  "https://open.canada.ca/data/api/action/package_show?id=", package_id
)

cat("Fetching DFO herring roe catch package metadata:\n  ", package_url, "\n")
pkg_resp <- httr::GET(package_url)
if (httr::status_code(pkg_resp) != 200L) {
  stop("Open Canada package metadata request failed (HTTP ",
       httr::status_code(pkg_resp), ").")
}

pkg <- jsonlite::fromJSON(httr::content(pkg_resp, as = "text", encoding = "UTF-8"),
                          flatten = TRUE)
resources <- pkg$result$resources |>
  as_tibble() |>
  filter(toupper(format) == "CSV",
         grepl("Herring roe fishery catch data", name, ignore.case = TRUE))

if (nrow(resources) == 0L) {
  stop("No herring roe catch CSV resources found in package ", package_id, ".")
}

cat("Found", nrow(resources), "catch CSV resources.\n")

downloaded <- vector("list", nrow(resources))
for (i in seq_len(nrow(resources))) {
  resource_name <- resources$name[[i]]
  resource_url <- resources$url[[i]]
  safe_name <- resource_name |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("^_|_$", "")
  local_path <- file.path(raw_dir, paste0(safe_name, ".csv"))

  cat("Downloading", resource_name, "\n  ", resource_url, "\n")
  resp <- httr::GET(resource_url, httr::write_disk(local_path, overwrite = TRUE))
  if (httr::status_code(resp) != 200L) {
    stop("Download failed for ", resource_name, " (HTTP ",
         httr::status_code(resp), ").")
  }

  first_line <- readLines(local_path, n = 1L, warn = FALSE)
  if (grepl("^<", first_line)) {
    stop("Downloaded file appears to be HTML, not CSV: ", local_path)
  }

  downloaded[[i]] <- readr::read_csv(
    local_path,
    locale = readr::locale(encoding = "ISO-8859-1"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  ) |>
    mutate(source_resource_name = resource_name,
           source_resource_url = resource_url,
           source_local_path = file.path("Data", "raw", "dfo-catch",
                                         basename(local_path)))
}

combined <- bind_rows(downloaded)
dest_path <- file.path(raw_dir, "bc_commercial_catch_OPEN_DATA.csv")
readr::write_csv(combined, dest_path)

cat("Wrote combined catch CSV with", nrow(combined), "rows to", dest_path, "\n")
cat("First line preview:",
    substring(readLines(dest_path, n = 1L, warn = FALSE), 1L, 120L), "\n")
