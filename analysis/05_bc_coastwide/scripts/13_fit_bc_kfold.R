# ============================================================================
# 13_fit_bc_kfold.R — Robust K-fold CV for m1_bc vs m3_bc
# analysis/05_bc_coastwide
#
# This is the fallback when positive-observation PSIS-LOO has many high
# Pareto-k points. It masks one deterministic fold of positive spawn
# observations, refits the model, and scores the held-out cells from the
# posterior latent state and observation error.
#
# Env:
#   BC_CV_MODEL = m1_bc | m3_bc
#   BC_CV_K     = number of folds, default 5
#   BC_CV_FOLD  = fold index, default 1
#   STAN_CHAINS/STAN_ITER/STAN_WARMUP/STAN_CORES via cloud_fit_control()
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(here)
  library(tidyverse)
})

source(here::here("R", "cloud_fit_control.R"))

rstan_options(auto_write = TRUE)

MODEL <- Sys.getenv("BC_CV_MODEL", unset = Sys.getenv("MODEL", unset = "m3_bc"))
K <- as.integer(Sys.getenv("BC_CV_K", unset = "5"))
FOLD <- as.integer(Sys.getenv("BC_CV_FOLD", unset = Sys.getenv("FOLD", unset = "1")))

if (!MODEL %in% c("m1_bc", "m3_bc")) {
  stop("BC_CV_MODEL must be m1_bc or m3_bc, not ", MODEL)
}
if (!is.finite(K) || K < 2L) stop("BC_CV_K must be >= 2")
if (!is.finite(FOLD) || FOLD < 1L || FOLD > K) {
  stop("BC_CV_FOLD must be in 1:BC_CV_K")
}

stan_data <- readRDS(here::here("Data", "processed", "bc_stan_data.rds"))

obs_tbl <- which(stan_data$obs_mask == 1L, arr.ind = TRUE) |>
  as.data.frame()
names(obs_tbl) <- c("section_row", "year_col")
obs_tbl <- obs_tbl |>
  as_tibble() |>
  mutate(
    section_idx = stan_data$section_meta$section_idx[section_row],
    section = stan_data$section_meta$section[section_row],
    stock_area = stan_data$section_meta$stock_area[section_row],
    year = stan_data$years[year_col],
    y_tonnes = stan_data$y[cbind(section_row, year_col)]
  ) |>
  group_by(stock_area) |>
  arrange(year, section_row, .by_group = TRUE) |>
  mutate(fold = ((row_number() - 1L) %% K) + 1L) |>
  ungroup()

validation <- obs_tbl |> filter(fold == FOLD)
if (nrow(validation) == 0L) {
  stop("No validation observations for fold ", FOLD, " of ", K)
}

stan_data$obs_mask[cbind(validation$section_row, validation$year_col)] <- 0L

stan_input <- stan_data[c("N_sections", "N_years", "N_stock_areas",
                          "stock_area_of", "y", "obs_mask",
                          "N_D", "D_blocks", "block_starts", "block_sizes")]

stan_file <- switch(
  MODEL,
  m1_bc = here::here("analysis", "05_bc_coastwide", "stan",
                     "herring_metapop_bc_m1.stan"),
  m3_bc = here::here("analysis", "05_bc_coastwide", "stan",
                     "herring_metapop_bc_m3.stan")
)

ctrl <- cloud_fit_control()
cat("BC K-fold fit\n")
cat("  model:", MODEL, "\n")
cat("  fold:", FOLD, "of", K, "\n")
cat("  validation positive obs:", nrow(validation), "\n")
cat("  chains/iter/warmup/cores:", ctrl$chains, ctrl$iter, ctrl$warmup,
    ctrl$cores, "\n")

mod <- stan_model(stan_file)
fit <- sampling(mod, data = stan_input,
                chains = ctrl$chains, iter = ctrl$iter,
                warmup = ctrl$warmup, cores = ctrl$cores,
                refresh = max(50L, ctrl$iter %/% 20L),
                control = list(adapt_delta = 0.95, max_treedepth = 12))

log_mean_exp <- function(x) {
  m <- max(x)
  m + log(mean(exp(x - m)))
}

draws <- rstan::extract(fit, pars = c("z", "sigma_obs"))
z <- draws$z
sigma_obs <- draws$sigma_obs
n_draws <- length(sigma_obs)

heldout_log_lik <- matrix(NA_real_, nrow = n_draws, ncol = nrow(validation))
pred_log_mean <- numeric(nrow(validation))
for (i in seq_len(nrow(validation))) {
  s <- validation$section_row[i]
  t <- validation$year_col[i]
  mu <- z[, s, t]
  heldout_log_lik[, i] <- dnorm(log(validation$y_tonnes[i]),
                                mean = mu, sd = sigma_obs, log = TRUE)
  pred_log_mean[i] <- mean(mu)
}

pointwise <- validation |>
  mutate(
    model = MODEL,
    k = K,
    fold = FOLD,
    obs_log = log(y_tonnes),
    pred_log_mean = pred_log_mean,
    residual_log = obs_log - pred_log_mean,
    residual_log10 = residual_log / log(10),
    elpd = apply(heldout_log_lik, 2, log_mean_exp)
  ) |>
  select(model, k, fold, stock_area, section_idx, section, year,
         y_tonnes, obs_log, pred_log_mean, residual_log, residual_log10,
         elpd)

diag_pars <- intersect(c("r_area", "beta_area", "K_area", "sigma_area",
                         "sigma_obs"),
                       fit@sim$pars_oi)
summ <- summary(fit, pars = diag_pars)$summary
sampler_params <- get_sampler_params(fit, inc_warmup = FALSE)
treedepth_hits <- sum(vapply(
  sampler_params,
  function(x) sum(x[, "treedepth__"] >= 12L, na.rm = TRUE),
  integer(1)
))

summary_tbl <- pointwise |>
  mutate(point_elpd = .data$elpd) |>
  summarise(
    model = first(model),
    k = first(k),
    fold = first(fold),
    n_validation = n(),
    elpd = sum(.data$point_elpd, na.rm = TRUE),
    se_elpd = sqrt(n() * var(.data$point_elpd, na.rm = TRUE)),
    rmse_log10 = sqrt(mean(residual_log10^2, na.rm = TRUE)),
    bias_log10 = mean(residual_log10, na.rm = TRUE),
    max_rhat = max(summ[, "Rhat"], na.rm = TRUE),
    min_ess = min(summ[, "n_eff"], na.rm = TRUE),
    divergences = sum(get_divergent_iterations(fit)),
    treedepth_hits = treedepth_hits
  )

out_dir <- here::here("analysis", "05_bc_coastwide", "output")
diag_dir <- here::here("Output", "diagnostics")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

tag <- paste0("bc_kfold_", MODEL, "_fold", FOLD, "_of", K)
saveRDS(list(summary = summary_tbl,
             pointwise = pointwise,
             sampler_summary = summ),
        file.path(out_dir, paste0(tag, ".rds")))
write_csv(summary_tbl, file.path(diag_dir, paste0(tag, "_summary.csv")))
write_csv(pointwise, file.path(diag_dir, paste0(tag, "_pointwise.csv")))

cat("Wrote K-fold outputs for", tag, "\n")
