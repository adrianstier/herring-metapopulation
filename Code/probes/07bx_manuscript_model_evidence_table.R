# =============================================================================
# Purpose: Build a manuscript-facing model and screen evidence table.
# Input:   Output/diagnostics/model_branch_status_table.csv
#          Output/diagnostics/bc_coastwide_model_status_table.csv
#          Output/diagnostics/heatwave_bottomup_signal_screen.csv
#          Output/diagnostics/bloom_phenology_herring_link_screen.csv
# Output:  Output/diagnostics/manuscript_model_evidence_table.{csv,md}
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

diag_dir <- here::here("Output", "diagnostics")
dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)

read_diag <- function(filename, required = TRUE) {
  path <- file.path(diag_dir, filename)
  if (!file.exists(path)) {
    if (required) {
      stop("Missing required diagnostic file: ", path, call. = FALSE)
    }
    return(tibble())
  }
  read_csv(path, show_col_types = FALSE)
}

fmt_num <- function(x, digits = 3) {
  if (length(x) == 0 || is.na(x[1])) {
    return("NA")
  }
  format(round(x[1], digits), trim = TRUE, scientific = FALSE)
}

fmt_int <- function(x) {
  if (length(x) == 0 || is.na(x[1])) {
    return("NA")
  }
  format(round(x[1]), trim = TRUE, big.mark = ",")
}

one_row <- function(tbl, ...) {
  out <- tbl |> filter(...) |> slice_head(n = 1)
  if (nrow(out) == 0) {
    tibble()
  } else {
    out
  }
}

metric_string <- function(...) {
  vals <- c(...)
  vals <- vals[nzchar(vals)]
  paste(vals, collapse = "; ")
}

hg_status <- read_diag("model_branch_status_table.csv")
bc_status <- read_diag("bc_coastwide_model_status_table.csv")
heat <- read_diag("heatwave_bottomup_signal_screen.csv", required = FALSE)
bloom <- read_diag("bloom_phenology_herring_link_screen.csv", required = FALSE)

hg_m1 <- one_row(hg_status, model == "m1_stier_11")
hg_pred <- hg_status |> filter(str_detect(model, "^m5_stier_"))
hg_distance <- one_row(hg_status, model == "m3_stier_distance")
hg_obs <- hg_status |> filter(model %in% c("m1_stier_obs_hier", "m1_stier_method_sensitivity"))

bc_m1_marg <- one_row(bc_status, model == "m1_bc_marginal")
bc_m3_marg <- one_row(bc_status, model == "m3_bc_marginal")
bc_m5 <- one_row(bc_status, model == "m5_bc")
bc_catch <- bc_status |> filter(model %in% c("m1_bc_catch_pressure", "m3_bc_catch_pressure"))

pdo_row <- one_row(heat, predictor == "pdo_lag1")
mhw_lag <- one_row(heat, predictor == "mhw_lag1")
chla_mean <- one_row(bloom, predictor == "chla_spring_mean_8day")

evidence <- tribble(
  ~evidence_family, ~analysis_product, ~primary_question, ~decision, ~manuscript_claim, ~key_numbers, ~claim_limit, ~next_action, ~source_files,
  "Primary HG population model",
  "m1_stier_11",
  "What is the baseline population and portfolio state for Haida Gwaii?",
  "promoted_primary_baseline",
  "Use `m1_stier_11` as the promoted Haida Gwaii baseline: ambiguous zeros, two-era survey q, catch accounting, and lag-1 PDO context.",
  metric_string(
    paste0("max Rhat ", fmt_num(hg_m1$max_rhat, 3)),
    paste0("min E-BFMI ", fmt_num(hg_m1$min_ebfmi, 3)),
    paste0("positive log RMSE ", fmt_num(hg_m1$positive_signal_log_rmse, 3)),
    paste0("LOO resolved ", as.character(hg_m1$loo_resolved[1]))
  ),
  "Do not replace this with held branches unless a new branch clears sampler, calibration, and comparison gates.",
  "Keep as the core manuscript baseline; use fit-caveat outputs for early surface-era magnitude limits.",
  "Output/diagnostics/model_branch_status_table.csv; Output/diagnostics/latest_model_status.md",

  "HG observation sensitivities",
  "m1_stier_obs_hier; m1_stier_method_sensitivity",
  "Do survey method or extra observation variance explain the result?",
  "held_sensitivity",
  "Observation alternatives are useful caveats but do not improve positive-spawn calibration enough to replace the baseline.",
  metric_string(
    paste0("rows ", fmt_int(nrow(hg_obs))),
    paste0("best positive log RMSE ", fmt_num(min(hg_obs$positive_signal_log_rmse, na.rm = TRUE), 3))
  ),
  "Do not present extra observation variance or three-era q as the preferred model.",
  "Report as robustness/caveat evidence in methods or supplement.",
  "Output/diagnostics/model_branch_status_table.csv",

  "HG spatial-process sensitivity",
  "m3_stier_distance",
  "Is spatial correlation important enough to change inference?",
  "held_context",
  "Spatial process structure is plausible context for portfolio design, but it remains held because fit gain is small and exact refit diagnostics had treedepth pressure.",
  metric_string(
    paste0("positive log RMSE ", fmt_num(hg_distance$positive_signal_log_rmse, 3)),
    paste0("max Pareto-k ", fmt_num(hg_distance$max_pareto_k, 3)),
    paste0("exact re-LOO resolved ", as.character(hg_distance$loo_resolved[1]))
  ),
  "Do not promote it as the main Haida Gwaii model.",
  "Use posterior states from the promoted baseline for scenario design unless a future spatial branch clears stronger gates.",
  "Output/diagnostics/model_branch_status_table.csv; Output/diagnostics/m3_stier_distance_postfit.md",

  "Predator mechanisms",
  "HG predator branches; BC m5_bc",
  "Isn't it just predators?",
  "no_promoted_predator_coefficient",
  "Predation is plausible ecological context, but no current predator coefficient is promoted for causal attribution.",
  metric_string(
    paste0("HG predator rows ", fmt_int(nrow(hg_pred))),
    paste0("BC m5 max Rhat ", fmt_num(bc_m5$max_rhat, 3)),
    paste0("BC m5 treedepth hits ", fmt_int(bc_m5$treedepth_hits))
  ),
  "Do not say predators explain failed recovery from the current Stan branches.",
  "Build a section-year predator exposure product, especially for humpbacks, and require future-lag and section-control gates before refitting.",
  "Output/diagnostics/model_branch_status_table.csv; Output/diagnostics/bc_coastwide_model_status_table.csv; Output/diagnostics/predator_talk_brief.md",

  "Coastwide transfer/generality",
  "m3_bc_marginal",
  "Does the spatial portfolio logic transfer beyond Haida Gwaii?",
  "usable_coastwide_sensitivity",
  "Use `m3_bc_marginal` as the current statistically usable coastwide transfer/generality sensitivity.",
  metric_string(
    paste0("max Rhat ", fmt_num(bc_m3_marg$max_rhat, 3)),
    paste0("min E-BFMI ", fmt_num(bc_m3_marg$min_ebfmi, 3)),
    paste0("max Pareto-k ", fmt_num(bc_m3_marg$max_pareto_k, 3)),
    paste0("coastwide RMSE log10 ", fmt_num(bc_m3_marg$coastwide_rmse_log10, 3))
  ),
  "This is a geometry/LOO repair and coastwide sensitivity, not a new biological mechanism or a replacement for `m1_stier_11`.",
  "Use in transfer/generality figures and discussion; run robust CV only if reviewers require a second comparison layer after clean PSIS-LOO.",
  "Output/diagnostics/bc_marginal_repair_readout.md; Output/diagnostics/bc_coastwide_model_status_table.csv",

  "Coastwide baseline comparator",
  "m1_bc_marginal",
  "What is the valid coastwide M1 comparator after geometry repair?",
  "usable_comparator",
  "Use `m1_bc_marginal` as the marginalized coastwide M1 comparator for `m3_bc_marginal`.",
  metric_string(
    paste0("max Rhat ", fmt_num(bc_m1_marg$max_rhat, 3)),
    paste0("min E-BFMI ", fmt_num(bc_m1_marg$min_ebfmi, 3)),
    paste0("max Pareto-k ", fmt_num(bc_m1_marg$max_pareto_k, 3)),
    paste0("coastwide RMSE log10 ", fmt_num(bc_m1_marg$coastwide_rmse_log10, 3))
  ),
  "Do not use original `m1_bc` PSIS-LOO as the clean comparison because the full-state fit failed E-BFMI/PSIS gates.",
  "Keep as the comparison row in coastwide reporting.",
  "Output/diagnostics/bc_marginal_repair_readout.md; Output/diagnostics/bc_coastwide_model_status_table.csv",

  "Coastwide catch pressure",
  "m1_bc_catch_pressure; m3_bc_catch_pressure",
  "Does public stock-area catch pressure change the coastwide conclusion?",
  "negative_sampler_limited_sensitivity",
  "Catch-pressure branches are negative sensitivity evidence and fail the E-BFMI sampler gate.",
  metric_string(
    paste0("rows ", fmt_int(nrow(bc_catch))),
    paste0("best coastwide RMSE log10 ", fmt_num(min(bc_catch$coastwide_rmse_log10, na.rm = TRUE), 3)),
    paste0("low E-BFMI chains ", fmt_int(sum(bc_catch$low_ebfmi_chains, na.rm = TRUE)))
  ),
  "Do not use these branches as causal fishing-effect evidence.",
  "Leave in supplement as a data/source sensitivity unless a reparameterized version is needed.",
  "Output/diagnostics/bc_catch_pressure_model_readout.md; Output/diagnostics/bc_coastwide_model_status_table.csv",

  "Heatwave and bottom-up timing",
  "heatwave_bottomup_screen; bloom_phenology_screen",
  "Is failed recovery caused by the Blob or a simple bloom-intensity failure?",
  "context_only_not_promoted",
  "The Blob likely added stress to an already eroded portfolio, but current MHW and satellite Chl-a screens do not promote a direct bottom-up adult-biomass mechanism.",
  metric_string(
    paste0("lag-1 PDO rho ", fmt_num(pdo_row$spearman_rho, 3)),
    paste0("lag-1 MHW adjusted beta ", fmt_num(mhw_lag$adjusted_beta, 3)),
    paste0("spring Chl-a adjusted beta ", fmt_num(chla_mean$adjusted_beta, 3))
  ),
  "Do not call satellite Chl-a a zooplankton or prey-quality test.",
  "Acquire in-situ zooplankton biomass/community/prey-quality data before adding a bottom-up Stan covariate.",
  "Output/diagnostics/heatwave_bottomup_scope.md; Output/diagnostics/bloom_phenology_herring_screen.md; docs/bottom-up-plankton-data-scope.md"
)

write_csv(evidence, file.path(diag_dir, "manuscript_model_evidence_table.csv"))

md <- c(
  "# Manuscript Model Evidence Table",
  "",
  paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "This table is the manuscript-facing claim gate. It separates promoted models, usable sensitivities, held context, failed branches, and diagnostic screens.",
  "",
  "## Evidence Rows",
  "",
  knitr::kable(evidence),
  "",
  "## Bottom Line",
  "",
  "- `m1_stier_11` remains the only promoted Haida Gwaii baseline.",
  "- `m3_bc_marginal` is now the statistically usable coastwide transfer/generality sensitivity.",
  "- No predator coefficient, heatwave pulse, or satellite bloom metric is currently promoted as the recovery mechanism.",
  "- The next bottom-up model is data-gated by in-situ zooplankton or prey-quality covariates, not by another binary Blob branch."
)
writeLines(md, file.path(diag_dir, "manuscript_model_evidence_table.md"))

cat("Wrote manuscript model evidence table.\n")
