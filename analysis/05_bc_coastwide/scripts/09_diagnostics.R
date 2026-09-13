# ============================================================================
# 09_diagnostics.R — MCMC + posterior-predictive + LOO across M1/M3/M5
# analysis/05_bc_coastwide
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(loo)
  library(posterior)
  library(here)
  library(tidyverse)
})

source(here::here("R", "00_setup.R"))

models <- c(m1_bc = "m1_bc_fit.rds",
            m1_bc_geom = "m1_bc_geom_fit.rds",
            m1_bc_marginal = "m1_bc_marginal_fit.rds",
            m3_bc = "m3_bc_fit.rds",
            m3_bc_geom = "m3_bc_geom_fit.rds",
            m3_bc_marginal = "m3_bc_marginal_fit.rds",
            m1_bc_catch_pressure = "m1_bc_catch_pressure_fit.rds",
            m3_bc_catch_pressure = "m3_bc_catch_pressure_fit.rds",
            m5_bc = "m5_bc_fit.rds")

stan_data_full <- readRDS(here::here("Data", "processed", "bc_stan_data.rds"))

model_spec <- tibble::tribble(
  ~model, ~branch_family, ~decision, ~use_class, ~claim_guardrail,
  "m1_bc", "coastwide_baseline", "supporting_sensitivity", "baseline_context",
  "Use as the coastwide baseline comparator, not as the promoted Haida Gwaii paper model.",
  "m1_bc_geom", "coastwide_baseline_geometry_repair", "geometry_repair_candidate", "coastwide_sensitivity",
  "Use only to test whether conservative geometry repair clears the coastwide sampler gate; not promoted until full post-fit and robust CV clear.",
  "m1_bc_marginal", "coastwide_baseline_marginal_state_space", "supporting_sensitivity", "coastwide_sensitivity",
  "Use as the marginalized coastwide M1 comparator. It integrates latent states with a Kalman filter and is a sampler-geometry repair, not a new biological mechanism.",
  "m3_bc", "coastwide_density_dependence", "calibration_supported_candidate", "coastwide_sensitivity",
  "Use as a coastwide transfer/generality sensitivity; robust K-fold was positive but uncertain, not promotion-grade.",
  "m3_bc_geom", "coastwide_density_geometry_repair", "geometry_repair_candidate", "coastwide_sensitivity",
  "Use only to test whether conservative M3 geometry repair clears the coastwide sampler gate; not promoted until full post-fit and robust CV clear.",
  "m3_bc_marginal", "coastwide_density_marginal_state_space", "supporting_sensitivity", "coastwide_sensitivity",
  "Use as the current statistically usable coastwide transfer/generality sensitivity. It integrates latent Gompertz states with a Kalman filter and is a sampler-geometry repair, not a new biological mechanism.",
  "m1_bc_catch_pressure", "coastwide_catch_pressure", "new_candidate_requires_postfit_gate", "coastwide_sensitivity",
  "Use only to test whether public assessment catch tables change the coastwide recovery inference; do not treat as a section-level fishing allocation.",
  "m3_bc_catch_pressure", "coastwide_density_plus_catch_pressure", "new_candidate_requires_postfit_gate", "coastwide_sensitivity",
  "Use only to test whether public assessment catch tables change the coastwide recovery inference; do not treat as a section-level fishing allocation.",
  "m5_bc", "coastwide_predator", "failed_sampler_geometry", "do_not_interpret",
  "Do not interpret predator coefficients or driver decomposition from this branch unless a future refit clears sampler and calibration gates."
)

extract_obs_mask_for_fit <- function(obj, stan_data = stan_data_full) {
  section_ids <- obj$section_meta$section_idx
  list(
    y = stan_data$y[section_ids, , drop = FALSE],
    obs_mask = stan_data$obs_mask[section_ids, , drop = FALSE],
    years = stan_data$years,
    section_meta = obj$section_meta
  )
}

loo_for_positive_observations <- function(fit, obs_mask) {
  # rstan stores array[N_sections, N_years] as flattened columns
  # log_lik[1,1], log_lik[2,1], ..., log_lik[N_sections, 1], log_lik[1,2].
  obs_cols <- which(as.vector(obs_mask) == 1L)
  log_lik_arr <- rstan::extract(fit, pars = "log_lik", permuted = FALSE)
  log_lik_obs_arr <- log_lik_arr[, , obs_cols, drop = FALSE]
  n_iter <- dim(log_lik_obs_arr)[1]
  n_chains <- dim(log_lik_obs_arr)[2]
  n_obs <- dim(log_lik_obs_arr)[3]
  log_lik_obs <- matrix(log_lik_obs_arr, nrow = n_iter * n_chains,
                        ncol = n_obs)
  r_eff <- tryCatch(
    loo::relative_eff(exp(log_lik_obs_arr), cores = 1),
    error = function(e) NULL
  )
  loo_res <- loo::loo(log_lik_obs, r_eff = r_eff)
  pareto_k <- loo_res$diagnostics$pareto_k
  list(
    loo = loo_res,
    n_obs = n_obs,
    max_pareto_k = max(pareto_k, na.rm = TRUE),
    pareto_k_gt_0_7 = sum(pareto_k > 0.7, na.rm = TRUE),
    pareto_k_gt_1 = sum(pareto_k > 1, na.rm = TRUE),
    pareto_k = pareto_k
  )
}

positive_spawn_calibration <- function(fit, obj, model_id) {
  fit_data <- extract_obs_mask_for_fit(obj)
  z_mean <- apply(rstan::extract(fit, pars = "z")$z, c(2, 3), mean)
  idx <- which(fit_data$obs_mask == 1L, arr.ind = TRUE)
  idx <- as.data.frame(idx)
  names(idx) <- c("section_row", "year_col")
  idx |>
    as_tibble() |>
    mutate(
      model = model_id,
      section_idx = fit_data$section_meta$section_idx[section_row],
      section = fit_data$section_meta$section[section_row],
      stock_area = fit_data$section_meta$stock_area[section_row],
      year = fit_data$years[year_col],
      y_tonnes = fit_data$y[cbind(section_row, year_col)],
      obs_log = log(y_tonnes),
      pred_log = z_mean[cbind(section_row, year_col)],
      residual_log = obs_log - pred_log,
      residual_log10 = residual_log / log(10),
      period = case_when(
        year <= 1988L ~ "1951-1988 early/surface-era",
        year <= 2004L ~ "1989-2004 pre-closure-modern",
        year <= 2013L ~ "2005-2013 closure/pre-Blob",
        year <= 2016L ~ "2014-2016 Blob/MHW",
        TRUE ~ "2017-2025 post-Blob"
      )
    )
}

summarise_calibration <- function(dat, group_vars, grain) {
  dat |>
    group_by(across(all_of(group_vars))) |>
    summarise(
      n_obs = n(),
      rmse_log = sqrt(mean(residual_log^2, na.rm = TRUE)),
      rmse_log10 = sqrt(mean(residual_log10^2, na.rm = TRUE)),
      bias_log10 = mean(residual_log10, na.rm = TRUE),
      median_abs_log10_error = median(abs(residual_log10), na.rm = TRUE),
      observed_median_tonnes = median(y_tonnes, na.rm = TRUE),
      predicted_median_tonnes = median(exp(pred_log), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(grain = grain, .before = 1)
}

mcmc_lines <- c("# BC-coastwide MCMC diagnostics",
                "",
                paste("Generated:", format(Sys.time())),
                "")
loo_rows <- list()
calibration_obs_rows <- list()
calibration_summary_rows <- list()
status_rows <- list()
pareto_point_rows <- list()

for (m in names(models)) {
  path <- here::here("analysis", "05_bc_coastwide", "output", models[[m]])
  if (!file.exists(path)) {
    mcmc_lines <- c(mcmc_lines, sprintf("## %s — MISSING (%s)", m, path))
    next
  }
  obj <- readRDS(path)
  fit <- obj$fit
  fit_data <- extract_obs_mask_for_fit(obj)

  diag_pars <- intersect(c("r_area", "mu0_area", "beta_area", "K_area", "sigma_area",
                           "sigma_obs", "gamma_pred", "gamma_catch"),
                         fit@sim$pars_oi)
  summ <- summary(fit, pars = diag_pars)$summary
  bad_rhat <- sum(summ[, "Rhat"] > 1.01, na.rm = TRUE)
  low_ess  <- sum(summ[, "n_eff"] < 400,  na.rm = TRUE)
  max_rhat <- max(summ[, "Rhat"], na.rm = TRUE)
  min_ess <- min(summ[, "n_eff"], na.rm = TRUE)
  divs <- sum(get_divergent_iterations(fit))
  sampler_params <- get_sampler_params(fit, inc_warmup = FALSE)
  treedepth_hits <- sum(vapply(
    sampler_params,
    function(x) sum(x[, "treedepth__"] >= 12L, na.rm = TRUE),
    integer(1)
  ))
  ebfmi <- vapply(
    sampler_params,
    function(x) {
      if (!"energy__" %in% colnames(x)) {
        return(NA_real_)
      }
      energy <- x[, "energy__"]
      energy_var <- stats::var(energy, na.rm = TRUE)
      if (is.finite(energy_var) && energy_var > 0) {
        mean(diff(energy)^2, na.rm = TRUE) / energy_var
      } else {
        NA_real_
      }
    },
    numeric(1)
  )
  min_ebfmi <- min(ebfmi, na.rm = TRUE)
  low_ebfmi_chains <- sum(ebfmi < 0.3, na.rm = TRUE)

  mcmc_lines <- c(mcmc_lines,
                  sprintf("## %s", m),
                  sprintf("- bad Rhat (>1.01): %d", bad_rhat),
                  sprintf("- max Rhat: %.3f", max_rhat),
                  sprintf("- low ESS (<400):   %d", low_ess),
                  sprintf("- min ESS: %.1f", min_ess),
                  sprintf("- divergent transitions: %d", divs),
                  sprintf("- max-treedepth hits (>=12): %d", treedepth_hits),
                  sprintf("- min E-BFMI: %.3f; chains <0.3 = %d",
                          min_ebfmi, low_ebfmi_chains),
                  "")

  sampler_failed <- isTRUE(max_rhat > 1.05) || isTRUE(min_ess < 100) ||
    isTRUE(treedepth_hits > 0) || isTRUE(min_ebfmi < 0.3)

  loo_res <- tryCatch(
    loo_for_positive_observations(fit, fit_data$obs_mask),
    error = function(e) NULL
  )
  if (!is.null(loo_res)) {
    loo_rows[[m]] <- tibble(
      model = m,
      n_positive_obs = loo_res$n_obs,
      elpd_loo = loo_res$loo$estimates["elpd_loo", "Estimate"],
      se_elpd_loo = loo_res$loo$estimates["elpd_loo", "SE"],
      max_pareto_k = loo_res$max_pareto_k,
      pareto_k_gt_0_7 = loo_res$pareto_k_gt_0_7,
      pareto_k_gt_1 = loo_res$pareto_k_gt_1,
      loo_valid_for_decision = !sampler_failed)
    mcmc_lines <- c(mcmc_lines,
                    sprintf("- positive-observation LOO elpd: %.2f (SE %.2f)",
                            loo_res$loo$estimates["elpd_loo", "Estimate"],
                            loo_res$loo$estimates["elpd_loo", "SE"]),
                    sprintf("- Pareto k: max %.3f; >0.7 = %d; >1 = %d",
                            loo_res$max_pareto_k,
                            loo_res$pareto_k_gt_0_7,
                            loo_res$pareto_k_gt_1),
                    sprintf("- LOO valid for model decision: %s",
                            ifelse(!sampler_failed, "yes", "no - sampler gate failed")),
                    "")

    obs_idx <- which(fit_data$obs_mask == 1L, arr.ind = TRUE) |>
      as.data.frame()
    names(obs_idx) <- c("section_row", "year_col")
    pareto_point_rows[[m]] <- obs_idx |>
      as_tibble() |>
      mutate(
        model = m,
        section_idx = fit_data$section_meta$section_idx[section_row],
        section = fit_data$section_meta$section[section_row],
        stock_area = fit_data$section_meta$stock_area[section_row],
        year = fit_data$years[year_col],
        y_tonnes = fit_data$y[cbind(section_row, year_col)],
        pareto_k = loo_res$pareto_k
      ) |>
      filter(pareto_k > 0.7) |>
      arrange(desc(pareto_k))
  }

  cal_obs <- positive_spawn_calibration(fit, obj, m)
  calibration_obs_rows[[m]] <- cal_obs
  calibration_summary_rows[[m]] <- bind_rows(
    summarise_calibration(cal_obs, c("model", "stock_area", "period"),
                          "stock_area_period"),
    summarise_calibration(cal_obs |> mutate(period = "all_years"),
                          c("model", "stock_area", "period"),
                          "stock_area_all_years"),
    summarise_calibration(cal_obs, c("model", "period"),
                          "coastwide_period") |>
      mutate(stock_area = "ALL", .after = model),
    summarise_calibration(cal_obs |> mutate(period = "all_years"),
                          c("model", "period"),
                          "coastwide_all_years") |>
      mutate(stock_area = "ALL", .after = model)
  )

  status_rows[[m]] <- tibble(
    model = m,
    max_rhat = max_rhat,
    min_ess = min_ess,
    bad_rhat_gt_1_01 = bad_rhat,
    low_ess_lt_400 = low_ess,
    divergences = divs,
    treedepth_hits = treedepth_hits,
    min_ebfmi = min_ebfmi,
    low_ebfmi_chains = low_ebfmi_chains,
    sampler_failed = sampler_failed
  )

  rm(obj, fit, fit_data, summ, cal_obs)
  gc()
}

dir.create(here::here("Output", "diagnostics"), showWarnings = FALSE, recursive = TRUE)
writeLines(mcmc_lines,
           here::here("Output", "diagnostics",
                      "bc_coastwide_mcmc_diagnostics.md"))

if (length(loo_rows) > 0) {
  loo_tab <- bind_rows(loo_rows)
  write_csv(loo_tab,
            here::here("Output", "diagnostics", "bc_coastwide_loo_table.csv"))
} else {
  write_csv(tibble(model = names(models),
                   elpd_loo = NA_real_,
                   se_elpd_loo = NA_real_),
            here::here("Output", "diagnostics", "bc_coastwide_loo_table.csv"))
}

if (length(calibration_obs_rows) > 0) {
  calibration_obs <- bind_rows(calibration_obs_rows)
  calibration_summary <- bind_rows(calibration_summary_rows)
  write_csv(calibration_obs,
            here::here("Output", "diagnostics",
                       "bc_coastwide_positive_spawn_calibration_observations.csv"))
  write_csv(calibration_summary,
            here::here("Output", "diagnostics",
                       "bc_coastwide_positive_spawn_calibration.csv"))
} else {
  calibration_summary <- tibble()
}

if (length(pareto_point_rows) > 0) {
  write_csv(bind_rows(pareto_point_rows),
            here::here("Output", "diagnostics",
                       "bc_coastwide_high_pareto_points.csv"))
}

kfold_summary_path <- here::here("Output", "diagnostics",
                                 "bc_coastwide_kfold_summary.csv")
kfold_contrast_path <- here::here("Output", "diagnostics",
                                  "bc_coastwide_kfold_contrast.csv")
kfold_summary <- if (file.exists(kfold_summary_path)) {
  read_csv(
    kfold_summary_path,
    col_types = cols(folds_complete = col_character(), .default = col_guess()),
    show_col_types = FALSE
  ) |>
    transmute(
      model,
      kfold_folds_complete = folds_complete,
      kfold_elpd = elpd,
      kfold_se_elpd = se_elpd,
      kfold_rmse_log10 = rmse_log10,
      kfold_all_folds_complete = all_folds_complete,
      kfold_sampler_ok = sampler_ok
    )
} else {
  tibble(model = character())
}
kfold_contrast <- if (file.exists(kfold_contrast_path)) {
  read_csv(kfold_contrast_path, show_col_types = FALSE)
} else {
  tibble(elpd_diff = NA_real_,
         approximate_se_diff = NA_real_,
         evidence_read = NA_character_)
}
kfold_elpd_diff <- kfold_contrast$elpd_diff[1]
kfold_approx_se_diff <- kfold_contrast$approximate_se_diff[1]
kfold_evidence_read <- kfold_contrast$evidence_read[1]

status_tab <- bind_rows(status_rows) |>
  left_join(model_spec, by = "model") |>
  left_join(if (exists("loo_tab")) loo_tab else tibble(model = character()),
            by = "model") |>
  left_join(
    calibration_summary |>
      filter(grain == "coastwide_all_years") |>
	      select(model, coastwide_rmse_log10 = rmse_log10,
	             coastwide_bias_log10 = bias_log10),
	    by = "model"
	  ) |>
  left_join(kfold_summary, by = "model") |>
  mutate(
    kfold_elpd_diff_m3_minus_m1 = if_else(model == "m3_bc",
                                          kfold_elpd_diff, NA_real_),
    kfold_approx_se_diff = if_else(model == "m3_bc",
                                   kfold_approx_se_diff, NA_real_),
    kfold_evidence_read = if_else(model %in% c("m1_bc", "m3_bc"),
                                  kfold_evidence_read, NA_character_),
    promotion_gate = case_when(
      sampler_failed ~ "fail_sampler",
      model == "m3_bc" &
        !is.na(kfold_evidence_read) &
        kfold_evidence_read != "m3_bc_clear" ~ "kfold_positive_uncertain",
      !is.na(max_pareto_k) & max_pareto_k > 0.7 ~ "needs_pareto_review",
      !is.na(coastwide_rmse_log10) & coastwide_rmse_log10 > 0.75 ~ "weak_calibration",
      TRUE ~ "passes_initial_postfit_gates"
    )
  ) |>
  select(model, branch_family, decision, use_class, promotion_gate,
         max_rhat, min_ess, divergences, treedepth_hits,
         min_ebfmi, low_ebfmi_chains,
         n_positive_obs, elpd_loo, se_elpd_loo, max_pareto_k,
         pareto_k_gt_0_7, pareto_k_gt_1, loo_valid_for_decision,
         kfold_folds_complete, kfold_elpd, kfold_se_elpd,
         kfold_elpd_diff_m3_minus_m1, kfold_approx_se_diff,
         kfold_evidence_read, kfold_rmse_log10,
         kfold_all_folds_complete, kfold_sampler_ok,
         coastwide_rmse_log10, coastwide_bias_log10, claim_guardrail)

write_csv(status_tab,
          here::here("Output", "diagnostics",
                     "bc_coastwide_model_status_table.csv"))

top_cal <- calibration_summary |>
  filter(grain == "stock_area_all_years") |>
  arrange(model, desc(rmse_log10)) |>
  group_by(model) |>
  slice_head(n = 3) |>
  ungroup()

md <- c(
  "# BC Coastwide Model Status",
  "",
  paste("Generated:", format(Sys.time())),
  "",
  "## Decision Table",
  "",
  knitr::kable(status_tab),
  "",
  "## Positive-Spawn Calibration",
  "",
  "Calibration uses positive spawn-index observations only. Residuals are observed log spawn tonnes minus posterior-mean latent log biomass.",
  "",
  knitr::kable(
    calibration_summary |>
      filter(grain %in% c("coastwide_all_years", "stock_area_all_years")) |>
      select(model, grain, stock_area, period, n_obs, rmse_log10,
             bias_log10, median_abs_log10_error)
  ),
  "",
  "## Worst Stock-Area Calibration Rows",
  "",
  knitr::kable(top_cal |> select(model, stock_area, n_obs, rmse_log10,
                                 bias_log10, median_abs_log10_error)),
  "",
  "## Guardrail",
  "",
  "- `m3_bc` may be used as a coastwide transfer/generality sensitivity, but the completed K-fold comparison is positive and uncertain rather than promotion-grade.",
  "- `m1_bc_marginal` and `m3_bc_marginal` are completed marginalized geometry-repair branches. Their production fits clear sampler and PSIS-LOO gates; `m3_bc_marginal` is the current statistically usable coastwide sensitivity, not a new biological mechanism.",
  "- `m5_bc` is a failed predator branch in this run. Do not use it for predator-effect claims or driver-decomposition figures."
)
writeLines(md, here::here("Output", "diagnostics",
                          "bc_coastwide_model_status_table.md"))

cat("Wrote diagnostics, LOO, calibration, and model-status outputs.\n")
