# ============================================================================
# 05_prepare_stan_data.R — Assemble BC-wide Stan data list
# analysis/05_bc_coastwide
#
# Input:  Data/processed/bc_spawn_by_section_year.csv
#         Data/processed/bc_catch_by_section_year_gear.csv
#         Data/processed/bc_predator_covariates.csv
#         Data/processed/bc_distance_within_stock_area.rds
#         Data/processed/bc_fishery_events.csv
# Output: Data/processed/bc_stan_data.rds (named list ready for rstan::sampling())
#
# The list contains:
#   N_sections, N_years, N_stock_areas, stock_area_of[N_sections]
#   y[N_sections, N_years]      spawn-index tonnes (positive-only; zeros NA)
#   obs_mask[N_sections, N_years]  1 if y observed positive, 0 otherwise
#   D_blocks: long vector of within-area distances
#   block_starts, block_sizes: indices that reconstruct D as block-diagonal
#   predator_covs[N_stock_areas, N_years, P]
#   fishery_active[N_sections, N_years]   0/1 indicator using bc_fishery_events
#   n_years_active[N_sections]            count, for prior scaling
# ============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

source(here::here("R", "00_setup.R"))

spawn <- read_csv(here::here("Data", "processed",
                             "bc_spawn_by_section_year.csv"),
                  na = character(),
                  show_col_types = FALSE)
catch <- read_csv(here::here("Data", "processed",
                             "bc_catch_by_section_year_gear.csv"),
                  na = character(),
                  show_col_types = FALSE)
covs  <- read_csv(here::here("Data", "processed",
                             "bc_predator_covariates.csv"),
                  na = character(),
                  show_col_types = FALSE) |>
  mutate(across(any_of(c("harbour_seal_index", "steller_index",
                         "humpback_index")),
                ~ suppressWarnings(as.numeric(.x))))
D_list <- readRDS(here::here("Data", "processed",
                             "bc_distance_within_stock_area.rds"))
events <- read_csv(here::here("Data", "processed",
                              "bc_fishery_events.csv"),
                   na = character(),
                   show_col_types = FALSE)

section_key <- spawn |>
  distinct(stock_area, statistical_area, section) |>
  arrange(stock_area, statistical_area, section) |>
  mutate(section_idx = row_number())

stock_areas <- sort(unique(section_key$stock_area))
section_key <- section_key |>
  mutate(stock_area_idx = match(stock_area, stock_areas))

N_sections <- nrow(section_key)
N_years    <- length(YEARS)
N_stock_areas <- length(stock_areas)

# y matrix (positive spawn only; zeros → NA → masked)
y_mat <- matrix(NA_real_, nrow = N_sections, ncol = N_years,
                dimnames = list(section_key$section_idx, YEARS))
spawn_keyed <- spawn |>
  inner_join(section_key, by = c("stock_area", "statistical_area", "section"))
for (i in seq_len(nrow(spawn_keyed))) {
  r <- spawn_keyed[i, ]
  if (!is.na(r$spawn_index_tonnes) && r$spawn_index_tonnes > 0) {
    y_mat[r$section_idx, as.character(r$year)] <- r$spawn_index_tonnes
  }
}
obs_mask <- (!is.na(y_mat)) * 1L
y_mat[is.na(y_mat)] <- 0  # Stan can't take NA; mask gates the likelihood

# Block-diagonal D: stack within-area matrices in stock-area order
D_blocks <- numeric()
block_starts <- integer()
block_sizes <- integer()
cur <- 0L
for (sa in stock_areas) {
  D <- D_list[[sa]]
  if (is.null(D)) D <- matrix(0, 0, 0)
  block_starts <- c(block_starts, cur + 1L)
  block_sizes <- c(block_sizes, nrow(D))
  D_blocks <- c(D_blocks, as.numeric(D))
  cur <- cur + length(D)
}

# Predator covariates: collapse to stock-area-year (predator data is
# stock-area-level per provenance file)
pred_pivot <- covs |>
  group_by(stock_area, year) |>
  summarise(across(any_of(c("harbour_seal_index", "steller_index",
                            "humpback_index")),
                   ~ mean(.x, na.rm = TRUE)),
            .groups = "drop")
pred_cols <- intersect(c("harbour_seal_index", "steller_index", "humpback_index"),
                       names(pred_pivot))
P <- length(pred_cols)
pred_arr <- array(0.0, dim = c(N_stock_areas, N_years, P),
                  dimnames = list(stock_areas, YEARS, pred_cols))
for (sa in stock_areas) {
  for (yr in YEARS) {
    row <- pred_pivot |> filter(stock_area == sa, year == yr)
    if (nrow(row) == 1L) {
      for (p in pred_cols) {
        v <- row[[p]]
        pred_arr[sa, as.character(yr), p] <- ifelse(is.finite(v), v, 0.0)
      }
    }
  }
}

# Stock-area catch pressure from public assessment catch tables. The CSAS
# Appendix B tables are stock-area annual totals, so this is a stock-area
# covariate, not a section-level catch allocation.
csas_catch_path <- here::here("Data", "processed", "bc_catch_csas_appendix.csv")
csas_stock_catch <- if (file.exists(csas_catch_path)) {
  read_csv(csas_catch_path, na = character(), show_col_types = FALSE) |>
    mutate(
      year = as.integer(year),
      catch_tonnes = readr::parse_number(as.character(catch_tonnes))
    ) |>
    group_by(stock_area, year) |>
    summarise(
      csas_catch_tonnes = sum(catch_tonnes, na.rm = TRUE),
      csas_source_tables = paste(sort(unique(source_table)), collapse = "; "),
      .groups = "drop"
    )
} else {
  warning(
    "Missing CSAS Appendix B catch table: ", csas_catch_path,
    ". Catch-pressure model inputs will use Open Data where available and zero otherwise."
  )
  tibble(stock_area = character(), year = integer(),
         csas_catch_tonnes = numeric(), csas_source_tables = character())
}

open_stock_catch <- catch |>
  mutate(
    year = as.integer(year),
    catch_tonnes = readr::parse_number(as.character(catch_tonnes))
  ) |>
  group_by(stock_area, year) |>
  summarise(
    open_data_catch_tonnes = sum(catch_tonnes, na.rm = TRUE),
    open_data_rows = n(),
    .groups = "drop"
  )

catch_pressure_panel <- tidyr::expand_grid(
  stock_area = stock_areas,
  year = as.integer(YEARS)
) |>
  left_join(csas_stock_catch, by = c("stock_area", "year")) |>
  left_join(open_stock_catch, by = c("stock_area", "year")) |>
  mutate(
    catch_source_class = case_when(
      !is.na(csas_catch_tonnes) ~ "csas_appendix_total_gear1_gear2_gear3",
      is.na(csas_catch_tonnes) & !is.na(open_data_catch_tonnes) ~
        "open_data_roe_total_when_csas_unavailable",
      TRUE ~ "no_catch_source_set_zero"
    ),
    catch_tonnes_for_model = case_when(
      !is.na(csas_catch_tonnes) ~ csas_catch_tonnes,
      !is.na(open_data_catch_tonnes) ~ open_data_catch_tonnes,
      TRUE ~ 0
    )
  ) |>
  group_by(stock_area) |>
  mutate(
    catch_log1p = log1p(catch_tonnes_for_model),
    catch_pressure_max_log1p = max(catch_log1p, na.rm = TRUE),
    catch_pressure = if_else(
      is.finite(catch_pressure_max_log1p) & catch_pressure_max_log1p > 0,
      catch_log1p / catch_pressure_max_log1p,
      0
    )
  ) |>
  ungroup() |>
  arrange(stock_area, year) |>
  mutate(
    source_document = case_when(
      catch_source_class == "csas_appendix_total_gear1_gear2_gear3" ~
        "DFO CSAS Research Document 2018/028 Appendix B.1-B.7",
      catch_source_class == "open_data_roe_total_when_csas_unavailable" ~
        "DFO Open Data herring roe fishery catch dataset",
      TRUE ~ NA_character_
    ),
    extraction_notes = paste(
      "For catch-pressure Stan sensitivities only.",
      "CSAS Appendix B is stock-area annual catch through 2017.",
      "Open Data roe catch fills years/areas without CSAS coverage.",
      "Scaled pressure is log1p(catch_tonnes_for_model) divided by the",
      "stock-area maximum log1p catch; it is not a section-level allocation."
    )
  )

catch_pressure_mat <- matrix(
  0,
  nrow = N_stock_areas,
  ncol = N_years,
  dimnames = list(stock_areas, YEARS)
)
catch_tonnes_area_year <- catch_pressure_mat
for (i in seq_len(nrow(catch_pressure_panel))) {
  r <- catch_pressure_panel[i, ]
  catch_pressure_mat[r$stock_area, as.character(r$year)] <- r$catch_pressure
  catch_tonnes_area_year[r$stock_area, as.character(r$year)] <-
    r$catch_tonnes_for_model
}

catch_pressure_out <- here::here(
  "Data", "processed", "bc_catch_pressure_stock_area_year.csv"
)
write_csv(catch_pressure_panel, catch_pressure_out)

catch_pressure_report <- c(
  "# BC Catch Pressure Input For Stan Sensitivities",
  "",
  paste("Generated:", format(Sys.time())),
  "",
  "## Use",
  "",
  "This is a stock-area annual covariate for catch-pressure sensitivity branches.",
  "It is not a section-level catch allocation and is not used by the original",
  "`m1_bc` or `m3_bc` branches.",
  "",
  "## Source Rule",
  "",
  "- 1951-2017 stock areas in CSAS Appendix B use total Gear1 + Gear2 + Gear3 catch from DFO CSAS Research Document 2018/028.",
  "- Years/areas without CSAS coverage use the existing DFO Open Data roe-catch panel where available.",
  "- Missing stock-area years are set to zero catch pressure.",
  "- The Stan covariate is `log1p(catch_tonnes_for_model)` scaled by the stock-area maximum.",
  "",
  "## Source Class Summary",
  "",
  knitr::kable(
    catch_pressure_panel |>
      count(stock_area, catch_source_class, name = "n_years") |>
      arrange(stock_area, catch_source_class),
    format = "pipe"
  ),
  "",
  "## Catch Summary",
  "",
  knitr::kable(
    catch_pressure_panel |>
      group_by(stock_area) |>
      summarise(
        total_tonnes = sum(catch_tonnes_for_model, na.rm = TRUE),
        max_tonnes = max(catch_tonnes_for_model, na.rm = TRUE),
        max_year = year[which.max(catch_tonnes_for_model)],
        n_nonzero_years = sum(catch_tonnes_for_model > 0, na.rm = TRUE),
        .groups = "drop"
      ) |>
      arrange(desc(total_tonnes)),
    format = "pipe"
  )
)
writeLines(
  catch_pressure_report,
  here::here("Output", "diagnostics", "bc_catch_pressure_for_stan.md")
)

# Fishery-active matrix from bc_fishery_events
fishery_active <- matrix(1L, nrow = N_sections, ncol = N_years,
                         dimnames = list(section_key$section_idx, YEARS))
for (i in seq_len(nrow(events))) {
  r <- events[i, ]
  if (r$event_kind == "closure" && !is.na(r$event_year)) {
    sec_mask <- section_key$stock_area == r$stock_area
    year_mask <- as.integer(YEARS) >= r$event_year
    fishery_active[sec_mask, year_mask] <- 0L
  }
}
n_years_active <- rowSums(fishery_active)

stan_data <- list(
  N_sections     = N_sections,
  N_years        = N_years,
  N_stock_areas  = N_stock_areas,
  N_pred_covs    = P,
  N_D            = length(D_blocks),
  stock_area_of  = section_key$stock_area_idx,
  y              = y_mat,
  obs_mask       = obs_mask,
  D_blocks       = D_blocks,
  block_starts   = block_starts,
  block_sizes    = block_sizes,
  predator_covs  = pred_arr,
  catch_pressure = catch_pressure_mat,
  catch_tonnes_area_year = catch_tonnes_area_year,
  fishery_active = fishery_active,
  n_years_active = n_years_active,
  era_break_year = rep(1988L, N_stock_areas),  # placeholder; per-area in M3+
  section_meta   = section_key,
  catch_pressure_meta = catch_pressure_panel,
  stock_area_codes = stock_areas,
  years          = YEARS
)

out_path <- here::here("Data", "processed", "bc_stan_data.rds")
saveRDS(stan_data, out_path)
cat("Wrote Stan data list to", out_path, "\n")
cat("  N_sections:", N_sections, "\n")
cat("  N_years:", N_years, "\n")
cat("  N_stock_areas:", N_stock_areas, "\n")
cat("  Total positive obs:", sum(obs_mask), "\n")
cat("  Catch pressure matrix:", nrow(catch_pressure_mat), "x",
    ncol(catch_pressure_mat), "\n")
