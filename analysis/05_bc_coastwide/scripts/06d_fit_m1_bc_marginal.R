# ============================================================================
# 06d_fit_m1_bc_marginal.R -- Fit marginalized hierarchical M1 BC-wide
# analysis/05_bc_coastwide
#
# Integrates over latent section-year states with a Kalman filter. SUBSET works
# as in 06_fit_m1_bc.R; generated quantities still include sampled z draws.
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(here)
  library(tidyverse)
})

source(here::here("R", "00_setup.R"))
source(here::here("R", "cloud_fit_control.R"))

rstan_options(auto_write = TRUE)

stan_data <- readRDS(here::here("Data", "processed", "bc_stan_data.rds"))

SUBSET <- Sys.getenv("SUBSET", unset = "HG_WCVI")
if (SUBSET != "ALL") {
  keep_codes <- strsplit(SUBSET, "_")[[1]]
  cat("Subsetting to stock areas:", paste(keep_codes, collapse = ", "), "\n")
  keep_idx <- which(stan_data$section_meta$stock_area %in% keep_codes)
  stock_area_remap <- setNames(seq_along(keep_codes), keep_codes)

  stan_data$N_sections <- length(keep_idx)
  stan_data$y <- stan_data$y[keep_idx, , drop = FALSE]
  stan_data$obs_mask <- stan_data$obs_mask[keep_idx, , drop = FALSE]
  stan_data$stock_area_of <- as.integer(
    stock_area_remap[stan_data$section_meta$stock_area[keep_idx]]
  )
  stan_data$N_stock_areas <- length(keep_codes)
  stan_data$stock_area_codes <- keep_codes
  stan_data$section_meta <- stan_data$section_meta[keep_idx, ]
}

stan_input <- stan_data[c("N_sections", "N_years", "N_stock_areas",
                          "stock_area_of", "y", "obs_mask")]

ctrl <- cloud_fit_control()
adapt_delta <- as.numeric(Sys.getenv("STAN_ADAPT_DELTA", unset = "0.9"))
max_treedepth <- as.integer(Sys.getenv("STAN_MAX_TREEDEPTH", unset = "12"))
if (!is.finite(adapt_delta) || adapt_delta <= 0 || adapt_delta >= 1) {
  stop("STAN_ADAPT_DELTA must be numeric and between 0 and 1.")
}
if (is.na(max_treedepth) || max_treedepth <= 0L) {
  stop("STAN_MAX_TREEDEPTH must be a positive integer.")
}

cat("Sampler config: chains=", ctrl$chains, " iter=", ctrl$iter,
    " warmup=", ctrl$warmup, " cores=", ctrl$cores,
    " adapt_delta=", adapt_delta, " max_treedepth=", max_treedepth, "\n")

mod <- stan_model(here::here("analysis", "05_bc_coastwide", "stan",
                             "herring_metapop_bc_m1_marginal.stan"))
fit <- sampling(mod, data = stan_input,
                chains = ctrl$chains, iter = ctrl$iter,
                warmup = ctrl$warmup, cores = ctrl$cores,
                refresh = max(50L, ctrl$iter %/% 20L),
                control = list(adapt_delta = adapt_delta,
                               max_treedepth = max_treedepth))

out_dir <- here::here("analysis", "05_bc_coastwide", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_name <- case_when(
  ctrl$smoke && SUBSET == "ALL" ~ "m1_bc_marginal_ALL_pilot_fit.rds",
  SUBSET == "ALL" ~ "m1_bc_marginal_fit.rds",
  TRUE ~ paste0("m1_bc_marginal_subset_", SUBSET, "_fit.rds")
)
out_path <- file.path(out_dir, out_name)

saveRDS(list(fit = fit, stock_areas = stan_data$stock_area_codes,
             section_meta = stan_data$section_meta),
        out_path)
cat("Wrote fit to", out_path, "\n")
