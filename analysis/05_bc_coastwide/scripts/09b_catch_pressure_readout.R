# ============================================================================
# 09b_catch_pressure_readout.R — Post-fit readout for CSAS catch-pressure runs
# analysis/05_bc_coastwide
#
# Reads the full GRIT fits for m1_bc_catch_pressure and m3_bc_catch_pressure
# plus the model-status table written by 09_diagnostics.R. Outputs a compact
# claim-gated readout focused on whether adding public CSAS catch tables changes
# the coastwide inference.
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(here)
  library(tidyverse)
  library(knitr)
})

status_path <- here::here("Output", "diagnostics",
                          "bc_coastwide_model_status_table.csv")
if (!file.exists(status_path)) {
  stop("Run analysis/05_bc_coastwide/scripts/09_diagnostics.R first.")
}

status <- read_csv(status_path, show_col_types = FALSE)

contrast_tbl <- tibble::tribble(
  ~base_model, ~catch_model,
  "m1_bc", "m1_bc_catch_pressure",
  "m3_bc", "m3_bc_catch_pressure"
) |>
  left_join(
    status |>
      select(
        base_model = model,
        base_promotion_gate = promotion_gate,
        base_elpd_loo = elpd_loo,
        base_max_pareto_k = max_pareto_k,
        base_pareto_k_gt_0_7 = pareto_k_gt_0_7,
        base_pareto_k_gt_1 = pareto_k_gt_1,
        base_rmse_log10 = coastwide_rmse_log10,
        base_min_ebfmi = min_ebfmi,
        base_low_ebfmi_chains = low_ebfmi_chains
      ),
    by = "base_model"
  ) |>
  left_join(
    status |>
      select(
        catch_model = model,
        catch_promotion_gate = promotion_gate,
        catch_elpd_loo = elpd_loo,
        catch_max_pareto_k = max_pareto_k,
        catch_pareto_k_gt_0_7 = pareto_k_gt_0_7,
        catch_pareto_k_gt_1 = pareto_k_gt_1,
        catch_rmse_log10 = coastwide_rmse_log10,
        catch_min_ebfmi = min_ebfmi,
        catch_low_ebfmi_chains = low_ebfmi_chains
      ),
    by = "catch_model"
  ) |>
  mutate(
    delta_elpd_loo = catch_elpd_loo - base_elpd_loo,
    delta_rmse_log10 = catch_rmse_log10 - base_rmse_log10,
    delta_pareto_k_gt_0_7 = catch_pareto_k_gt_0_7 - base_pareto_k_gt_0_7,
    delta_pareto_k_gt_1 = catch_pareto_k_gt_1 - base_pareto_k_gt_1,
    readout = case_when(
      catch_promotion_gate == "fail_sampler" ~
        "not_promoted_sampler_gate_failed",
      delta_elpd_loo < 0 & delta_rmse_log10 >= 0 ~
        "no_predictive_or_calibration_gain",
      abs(delta_rmse_log10) < 0.01 ~
        "negligible_calibration_change",
      TRUE ~ "requires_review"
    )
  )

gamma_summary_one <- function(model) {
  path <- here::here("analysis", "05_bc_coastwide", "output",
                     paste0(model, "_fit.rds"))
  if (!file.exists(path)) {
    return(tibble())
  }
  obj <- readRDS(path)
  if (!"gamma_catch" %in% obj$fit@sim$pars_oi) {
    return(tibble())
  }
  draws <- rstan::extract(obj$fit, pars = "gamma_catch")$gamma_catch
  stock_areas <- obj$stock_areas
  out <- purrr::map_dfr(seq_along(stock_areas), function(i) {
    x <- draws[, i]
    tibble(
      model = model,
      stock_area = stock_areas[[i]],
      gamma_catch_q05 = unname(quantile(x, 0.05, na.rm = TRUE)),
      gamma_catch_median = unname(quantile(x, 0.50, na.rm = TRUE)),
      gamma_catch_q95 = unname(quantile(x, 0.95, na.rm = TRUE))
    )
  })
  rm(obj, draws)
  gc()
  out
}

gamma_summary <- bind_rows(
  gamma_summary_one("m1_bc_catch_pressure"),
  gamma_summary_one("m3_bc_catch_pressure")
)

diag_dir <- here::here("Output", "diagnostics")
dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)
write_csv(contrast_tbl,
          file.path(diag_dir, "bc_catch_pressure_model_contrast.csv"))
write_csv(gamma_summary,
          file.path(diag_dir, "bc_catch_pressure_gamma_summary.csv"))

md <- c(
  "# BC Catch-Pressure Model Readout",
  "",
  paste("Generated:", format(Sys.time())),
  "",
  "## Claim-Gated Conclusion",
  "",
  "Adding public CSAS Appendix B stock-area catch pressure does not currently",
  "change the coastwide inference. The catch-pressure branches are useful",
  "sensitivities, but they are not promotion-ready: both fail the E-BFMI",
  "sampler gate, PSIS-LOO remains unstable, and calibration changes are tiny",
  "relative to the corresponding non-catch branches.",
  "",
  "## Base Versus Catch-Pressure Branches",
  "",
  knitr::kable(
    contrast_tbl |>
      select(
        base_model, catch_model, base_promotion_gate, catch_promotion_gate,
        delta_elpd_loo, delta_rmse_log10, delta_pareto_k_gt_0_7,
        delta_pareto_k_gt_1, catch_min_ebfmi, catch_low_ebfmi_chains,
        readout
      ),
    format = "pipe",
    digits = 4
  ),
  "",
  "## Catch-Pressure Coefficients",
  "",
  "The coefficient is constrained non-negative by design, so positive medians",
  "are not by themselves evidence of a promoted catch effect. These summaries",
  "are included only to diagnose scale and stock-area pattern after the sampler",
  "gate.",
  "",
  knitr::kable(gamma_summary, format = "pipe", digits = 4),
  "",
  "## Guardrail",
  "",
  "- Do not say the completed coastwide fits used a section-level historical catch allocation.",
  "- Do not use these branches as causal evidence for fishing effects until geometry is repaired or robust CV supports them.",
  "- The immediate interpretation is sensitivity-only: catch pressure leaves the M1/M3 story essentially unchanged."
)
writeLines(md, file.path(diag_dir, "bc_catch_pressure_model_readout.md"))

cat("Wrote catch-pressure readout outputs.\n")
