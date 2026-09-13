# =============================================================================
# Purpose: Convert heatwave, satellite Chl-a, and plankton-data screens into a
#          clear bottom-up model-readiness decision.
# Input:   Output/diagnostics/heatwave_bottomup_signal_screen.csv
#          Output/diagnostics/bloom_phenology_herring_link_screen.csv
# Output:  Output/diagnostics/bottomup_covariate_model_readiness.{csv,md}
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

diag_dir <- here::here("Output", "diagnostics")
dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

read_diag <- function(filename) {
  path <- file.path(diag_dir, filename)
  if (!file.exists(path)) {
    stop("Missing required diagnostic file: ", path, call. = FALSE)
  }
  read_csv(path, show_col_types = FALSE)
}

fmt_num <- function(x, digits = 3) {
  if (length(x) == 0 || is.na(x[1])) {
    return("NA")
  }
  format(round(x[1], digits), trim = TRUE, scientific = FALSE)
}

row_for <- function(tbl, col, value) {
  out <- tbl |> filter(.data[[col]] == value) |> slice_head(n = 1)
  if (nrow(out) == 0) {
    tibble()
  } else {
    out
  }
}

decision_from_screen <- function(n, gate, adjusted_beta, expected_match) {
  case_when(
    is.na(n) ~ "data_absent",
    n < 15 ~ "do_not_model_too_short",
    gate %in% c("negative_control") ~ "do_not_model_negative_control",
    gate %in% c("too_short_for_stan", "data_short") ~ "do_not_model_too_short",
    gate %in% c("weak_adjusted_effect", "weak_screen_only") ~ "do_not_model_weak_screen",
    isFALSE(expected_match) ~ "do_not_model_wrong_direction",
    is.finite(adjusted_beta) & abs(adjusted_beta) >= 0.15 ~ "candidate_for_active_window_sensitivity",
    TRUE ~ "context_only"
  )
}

heat <- read_diag("heatwave_bottomup_signal_screen.csv")
bloom <- read_diag("bloom_phenology_herring_link_screen.csv")

pdo <- row_for(heat, "predictor", "pdo_lag1")
pdo_window <- row_for(heat, "predictor", "pdo_mean_lag0_1")
mhw <- row_for(heat, "predictor", "mhw")
mhw_lag <- row_for(heat, "predictor", "mhw_lag1")
sst <- row_for(heat, "predictor", "sst_spring_anom_lag1")
chla_heat <- row_for(heat, "predictor", "chla_spring_mean_lag1")
chla_mean <- row_for(bloom, "predictor", "chla_spring_mean_8day")
chla_integral <- row_for(bloom, "predictor", "chla_spring_integral_8day")
chla_timing <- row_for(bloom, "predictor", "abs_larval_20d_minus_spring_peak_days")

readiness <- tribble(
  ~covariate_product, ~coverage, ~target_pathway, ~current_screen, ~model_entry_decision, ~why, ~branch_if_ready, ~required_next_step,
  "Lag-1 PDO",
  paste0("n=", pdo$n[1], ", ", pdo$year_min[1], "-", pdo$year_max[1]),
  "regional climate/process context",
  paste0("rho=", fmt_num(pdo$spearman_rho), "; detrended r=", fmt_num(pdo$detrended_r), "; adjusted beta=", fmt_num(pdo$adjusted_beta)),
  "already_in_promoted_baseline",
  "This is the only long climate covariate already embedded in the promoted Haida Gwaii model.",
  "none",
  "Do not run a redundant PDO-only branch unless a reviewer asks for a lag-window sensitivity.",

  "PDO mean lag 0-1",
  paste0("n=", pdo_window$n[1], ", ", pdo_window$year_min[1], "-", pdo_window$year_max[1]),
  "regional climate/process context",
  paste0("rho=", fmt_num(pdo_window$spearman_rho), "; detrended r=", fmt_num(pdo_window$detrended_r), "; adjusted beta=", fmt_num(pdo_window$adjusted_beta)),
  "optional_window_sensitivity_only",
  "The cheap screen is similar to lag-1 PDO, so it can test lag choice but would not add a new mechanism.",
  "m1_stier_climate_window",
  "Run only if exact PDO-window wording becomes important.",

  "2014-2016 MHW pulse",
  paste0("n=", mhw$n[1], ", event years=", mhw$event_years[1]),
  "event-pulse heat stress",
  paste0("adjusted beta=", fmt_num(mhw$adjusted_beta), "; gate=", mhw$gate[1]),
  "do_not_model_weak_screen",
  "A three-year pulse is too short and has near-zero adjusted adult-growth signal.",
  "none",
  "Use as temporal context, not as a Stan branch.",

  "2014-2016 MHW pulse lag 1",
  paste0("n=", mhw_lag$n[1], ", event years=", mhw_lag$event_years[1]),
  "lagged event-pulse heat stress",
  paste0("adjusted beta=", fmt_num(mhw_lag$adjusted_beta), "; gate=", mhw_lag$gate[1]),
  "do_not_model_weak_screen",
  "Lagging the event does not create a meaningful adjusted signal.",
  "none",
  "Keep the claim: Blob likely added stress but is not the promoted recovery mechanism.",

  "Spring SST anomaly lag 1",
  paste0("n=", sst$n[1], ", ", sst$year_min[1], "-", sst$year_max[1]),
  "short-window satellite temperature",
  paste0("adjusted beta=", fmt_num(sst$adjusted_beta), "; gate=", sst$gate[1]),
  "do_not_model_too_short",
  "The OISST anomaly product is too short for a full-era Stan process covariate.",
  "none",
  "Use descriptively until a longer regional SST anomaly product is harmonized.",

  "Spring Chl-a mean lag 1",
  paste0("n=", chla_heat$n[1], ", ", chla_heat$year_min[1], "-", chla_heat$year_max[1]),
  "short-window phytoplankton biomass proxy",
  paste0("adjusted beta=", fmt_num(chla_heat$adjusted_beta), "; gate=", chla_heat$gate[1]),
  "do_not_model_weak_screen",
  "Lagged satellite Chl-a does not explain adult growth after year/PDO/fishing adjustment.",
  "none",
  "Do not treat Chl-a as a zooplankton-energy covariate.",

  "8-day spring Chl-a mean",
  paste0("n=", chla_mean$n[1], ", ", chla_mean$year_min[1], "-", chla_mean$year_max[1]),
  "phytoplankton bloom intensity",
  paste0("detrended r=", fmt_num(chla_mean$detrended_r), "; adjusted beta=", fmt_num(chla_mean$adjusted_beta), "; gate=", chla_mean$screen_gate[1]),
  decision_from_screen(chla_mean$n[1], chla_mean$screen_gate[1], chla_mean$adjusted_beta[1], TRUE),
  "Same-year Chl-a has a modest detrended association but no strong adjusted effect.",
  "m1_stier_chla_post2003",
  "Only fit as a labelled short-window sensitivity if a reviewer specifically asks for satellite-bloom modeling.",

  "8-day spring Chl-a integral",
  paste0("n=", chla_integral$n[1], ", ", chla_integral$year_min[1], "-", chla_integral$year_max[1]),
  "phytoplankton bloom dose",
  paste0("detrended r=", fmt_num(chla_integral$detrended_r), "; adjusted beta=", fmt_num(chla_integral$adjusted_beta), "; gate=", chla_integral$screen_gate[1]),
  decision_from_screen(chla_integral$n[1], chla_integral$screen_gate[1], chla_integral$adjusted_beta[1], TRUE),
  "The bloom-integral proxy remains weak after controls.",
  "m1_stier_chla_post2003",
  "Do not run unless paired with a clear short-window sensitivity objective.",

  "Larval/bloom timing mismatch",
  paste0("n=", chla_timing$n[1], ", ", chla_timing$year_min[1], "-", chla_timing$year_max[1]),
  "match-mismatch timing proxy",
  paste0("detrended r=", fmt_num(chla_timing$detrended_r), "; adjusted beta=", fmt_num(chla_timing$adjusted_beta), "; gate=", chla_timing$screen_gate[1]),
  decision_from_screen(chla_timing$n[1], chla_timing$screen_gate[1], chla_timing$adjusted_beta[1], TRUE),
  "Timing mismatch from satellite Chl-a is not a strong adult-growth predictor.",
  "m1_stier_chla_post2003",
  "Use only as a bridge to real larval/zooplankton timing data.",

  "In-situ zooplankton biomass/community/prey quality",
  "data product not yet in repo",
  "secondary production and prey-quality mechanism",
  "not estimable yet",
  "data_blocked_best_next_science",
  "This is the biologically sharp bottom-up test: large calanoid copepods, Neocalanus, euphausiids, southern copepods, gelatinous plankton, and lipid/prey-quality structure.",
  "m1_stier_zoop_energy_active_window or m3_bc_marginal_zoop_context",
  "Request and audit DFO BioChem/IOS Haida Gwaii/Hecate Strait zooplankton extracts before fitting."
)

write_csv(readiness, file.path(diag_dir, "bottomup_covariate_model_readiness.csv"))

test_design <- c(
  "## Clear Test Definition",
  "",
  "A clean bottom-up test needs a source-traceable annual or seasonal lower-trophic covariate and a predeclared model-entry rule.",
  "",
  "1. Define the biological window before looking at the coefficient: winter/spring prey field for larval or early juvenile survival, plus a lag convention.",
  "2. Preserve missing years as inactive or missing; do not interpolate a full-era covariate from sparse plankton samples.",
  "3. Screen first against promoted `m1_stier_11` latent growth using Spearman, detrended correlation, and year/PDO/fishing-adjusted beta.",
  "4. Require negative controls: future-lag covariate, shuffled-year sensitivity, and a check that the signal is not only a year trend.",
  "5. Fit one active-window process covariate only if the data product clears coverage and screen gates.",
  "6. Interpret an adult-biomass process coefficient as a proxy unless age/recruitment data support a juvenile-survival pathway.",
  "",
  "Candidate Stan process form, if data clear the gate:",
  "",
  "```text",
  "z[s,t] ~ normal(process_mean[s,t] + beta_bottomup * x_bottomup[t-1] * active[t-1], sigma_process)",
  "```",
  "",
  "For coastwide transfer, the same logic can use `m3_bc_marginal` only if the covariate is available on a broad stock-area scale. A Haida Gwaii-only plankton extract should stay on the HG baseline first."
)

md <- c(
  "# Bottom-Up Covariate Model Readiness",
  "",
  paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Decision",
  "",
  "Do not launch a new heatwave, SST, or satellite Chl-a Stan branch now. The current screens are context-only or weak. The next real bottom-up model is data-blocked by the need for in-situ zooplankton biomass/community/prey-quality covariates.",
  "",
  "## Readiness Table",
  "",
  knitr::kable(readiness),
  "",
  test_design,
  "",
  "## Talk/Manuscript Wording",
  "",
  "The Blob likely added climate stress to an already eroded portfolio, but the available satellite-bloom evidence does not make the heatwave or simple Chl-a intensity the promoted recovery mechanism. The unresolved bottom-up test is secondary production and prey quality, not just whether the ocean was warm."
)
writeLines(md, file.path(diag_dir, "bottomup_covariate_model_readiness.md"))

cat("Wrote bottom-up covariate model-readiness table.\n")
