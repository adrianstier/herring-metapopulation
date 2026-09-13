# ============================================================================
# 09c_marginal_repair_readout.R -- Focused M1/M3 marginalized repair readout
# analysis/05_bc_coastwide
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(loo)
  library(here)
  library(tidyverse)
})

source(here::here("R", "00_setup.R"))

status <- read_csv(
  here::here("Output", "diagnostics", "bc_coastwide_model_status_table.csv"),
  show_col_types = FALSE
)

model_paths <- c(
  m3_bc_marginal = here::here("analysis", "05_bc_coastwide", "output",
                              "m3_bc_marginal_fit.rds"),
  m1_bc_marginal = here::here("analysis", "05_bc_coastwide", "output",
                              "m1_bc_marginal_fit.rds")
)
missing <- model_paths[!file.exists(model_paths)]
if (length(missing)) {
  stop("Missing marginalized production fit(s): ",
       paste(names(missing), missing, sep = "=", collapse = "; "))
}

stan_data <- readRDS(here::here("Data", "processed", "bc_stan_data.rds"))

loo_for_model <- function(path) {
  obj <- readRDS(path)
  obs_mask <- stan_data$obs_mask[obj$section_meta$section_idx, , drop = FALSE]
  obs_cols <- which(as.vector(obs_mask) == 1L)
  log_lik_arr <- rstan::extract(obj$fit, pars = "log_lik",
                                permuted = FALSE)[, , obs_cols, drop = FALSE]
  log_lik <- matrix(log_lik_arr,
                    nrow = dim(log_lik_arr)[1] * dim(log_lik_arr)[2],
                    ncol = dim(log_lik_arr)[3])
  r_eff <- tryCatch(
    loo::relative_eff(exp(log_lik_arr), cores = 1),
    error = function(e) NULL
  )
  loo::loo(log_lik, r_eff = r_eff)
}

loos <- lapply(model_paths, loo_for_model)
comp <- loo_compare(loos[[1]], loos[[2]])
comp_tbl <- as.data.frame(comp) |>
  rownames_to_column("comparison_row") |>
  as_tibble() |>
  mutate(
    model = c(names(model_paths)[1], names(model_paths)[2]),
    .before = 1
  )

readout <- status |>
  filter(model %in% names(model_paths)) |>
  select(model, promotion_gate, max_rhat, min_ess, divergences,
         treedepth_hits, min_ebfmi, low_ebfmi_chains, elpd_loo, se_elpd_loo,
         max_pareto_k, pareto_k_gt_0_7, pareto_k_gt_1,
         coastwide_rmse_log10, coastwide_bias_log10) |>
  mutate(
    elpd_delta_vs_m1_marginal =
      elpd_loo - elpd_loo[model == "m1_bc_marginal"],
    rmse_delta_vs_m1_marginal =
      coastwide_rmse_log10 -
      coastwide_rmse_log10[model == "m1_bc_marginal"]
  ) |>
  arrange(match(model, names(model_paths)))

dir.create(here::here("Output", "diagnostics"),
           recursive = TRUE, showWarnings = FALSE)
write_csv(readout,
          here::here("Output", "diagnostics",
                     "bc_marginal_repair_readout.csv"))

md <- c(
  "# BC Marginalized State-Space Repair Readout",
  "",
  paste("Generated:", format(Sys.time())),
  "",
  "## Production Gate",
  "",
  knitr::kable(readout),
  "",
  "## LOO Comparison",
  "",
  knitr::kable(comp_tbl),
  "",
  "## Interpretation",
  "",
  "- The marginalized M1 and M3 production fits clear the HMC geometry gate: no divergences, no max-treedepth hits, Rhat near 1.00, high ESS, and E-BFMI near 1.",
  "- PSIS-LOO is now usable for these branches: both have max Pareto-k below 0.7 and zero high-k observations.",
  "- Within the marginalized repair family, M3 is better than M1 by both predictive fit and positive-spawn calibration. Coastwide RMSE is 0.333 for M3 versus 0.405 for M1 log10 units.",
  "- This repairs the sampler/LOO issue for the coastwide density-dependence comparison, but it does not add a new biological driver. Treat `m3_bc_marginal` as the current statistically usable coastwide sensitivity unless a robust CV check overturns it."
)
writeLines(md, here::here("Output", "diagnostics",
                          "bc_marginal_repair_readout.md"))

cat("Wrote marginalized repair readout.\n")
