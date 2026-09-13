# ============================================================================
# 14_collect_bc_kfold.R — Collect BC coastwide K-fold CV outputs
# analysis/05_bc_coastwide
# ============================================================================

suppressPackageStartupMessages({
  library(here)
  library(tidyverse)
})

out_dir <- here::here("analysis", "05_bc_coastwide", "output")
diag_dir <- here::here("Output", "diagnostics")
dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

paths <- list.files(out_dir, pattern = "^bc_kfold_.*_fold[0-9]+_of[0-9]+\\.rds$",
                    full.names = TRUE)

if (length(paths) == 0L) {
  md <- c(
    "# BC Coastwide K-Fold CV",
    "",
    paste("Generated:", format(Sys.time())),
    "",
    "No K-fold result files were found in `analysis/05_bc_coastwide/output/`.",
    "",
    "Run or submit `analysis/05_bc_coastwide/scripts/13_fit_bc_kfold.R` for `m1_bc` and `m3_bc` before using PSIS-LOO differences for coastwide promotion."
  )
  writeLines(md, file.path(diag_dir, "bc_coastwide_kfold_summary.md"))
  write_csv(tibble(), file.path(diag_dir, "bc_coastwide_kfold_summary.csv"))
  quit(status = 0)
}

objs <- lapply(paths, readRDS)
summary_tbl <- bind_rows(lapply(objs, `[[`, "summary"))
pointwise_tbl <- bind_rows(lapply(objs, `[[`, "pointwise"))

fold_pointwise_summary <- pointwise_tbl |>
  group_by(model, k, fold) |>
  summarise(
    n_validation_pointwise_fold = n(),
    elpd_pointwise = sum(.data$elpd, na.rm = TRUE),
    se_elpd_pointwise = sqrt(n() * var(.data$elpd, na.rm = TRUE)),
    rmse_log10_pointwise = sqrt(mean(.data$residual_log10^2, na.rm = TRUE)),
    bias_log10_pointwise = mean(.data$residual_log10, na.rm = TRUE),
    .groups = "drop"
  )

summary_tbl <- summary_tbl |>
  select(-any_of(c("se_elpd", "rmse_log10", "bias_log10"))) |>
  left_join(fold_pointwise_summary, by = c("model", "k", "fold")) |>
  mutate(
    elpd_check_diff = .data$elpd - .data$elpd_pointwise,
    elpd = .data$elpd_pointwise,
    se_elpd = .data$se_elpd_pointwise,
    rmse_log10 = .data$rmse_log10_pointwise,
    bias_log10 = .data$bias_log10_pointwise
  ) |>
  select(-ends_with("_pointwise"))

sampler_summary <- summary_tbl |>
  mutate(fold_n_validation = .data$n_validation) |>
  group_by(model, k) |>
  summarise(
    folds_complete = paste(sort(unique(fold)), collapse = ","),
    n_folds_complete = n_distinct(fold),
    n_validation = sum(.data$fold_n_validation),
    elpd = sum(.data$elpd),
    se_elpd = sqrt(sum(.data$se_elpd^2)),
    max_rhat = max(.data$max_rhat, na.rm = TRUE),
    min_ess = min(.data$min_ess, na.rm = TRUE),
    divergences = sum(.data$divergences, na.rm = TRUE),
    treedepth_hits = sum(.data$treedepth_hits, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    expected_folds = k,
    all_folds_complete = n_folds_complete == expected_folds,
    sampler_ok = max_rhat < 1.05 &
      min_ess >= 100 &
      divergences == 0 &
      treedepth_hits == 0
  )

pointwise_summary <- pointwise_tbl |>
  group_by(model, k) |>
  summarise(
    n_validation_pointwise = n(),
    elpd_pointwise = sum(.data$elpd, na.rm = TRUE),
    se_elpd_pointwise = sqrt(n() * var(.data$elpd, na.rm = TRUE)),
    rmse_log10 = sqrt(mean(.data$residual_log10^2, na.rm = TRUE)),
    bias_log10 = mean(.data$residual_log10, na.rm = TRUE),
    .groups = "drop"
  )

model_summary <- sampler_summary |>
  left_join(pointwise_summary, by = c("model", "k")) |>
  mutate(
    elpd_check_diff = .data$elpd - .data$elpd_pointwise,
    se_elpd = .data$se_elpd_pointwise
  ) |>
  select(-elpd_pointwise, -se_elpd_pointwise) |>
  arrange(desc(elpd))

best_elpd <- max(model_summary$elpd, na.rm = TRUE)
model_summary <- model_summary |>
  mutate(delta_elpd = elpd - best_elpd)

comparison_ready <- all(c("m1_bc", "m3_bc") %in% model_summary$model) &&
  all(model_summary$all_folds_complete[model_summary$model %in% c("m1_bc", "m3_bc")]) &&
  all(model_summary$sampler_ok[model_summary$model %in% c("m1_bc", "m3_bc")])

if (comparison_ready) {
  diff_tbl <- model_summary |>
    select(model, elpd, se_elpd) |>
    pivot_wider(names_from = model, values_from = c(elpd, se_elpd)) |>
    transmute(
      contrast = "m3_bc - m1_bc",
      elpd_diff = elpd_m3_bc - elpd_m1_bc,
      approximate_se_diff = sqrt(se_elpd_m3_bc^2 + se_elpd_m1_bc^2),
      evidence_read = case_when(
        elpd_diff > 2 * approximate_se_diff ~ "m3_bc_clear",
        elpd_diff > 0 ~ "m3_bc_positive_but_uncertain",
        TRUE ~ "no_m3_gain"
      )
    )
} else {
  diff_tbl <- tibble(
    contrast = "m3_bc - m1_bc",
    elpd_diff = NA_real_,
    approximate_se_diff = NA_real_,
    evidence_read = "incomplete_or_sampler_blocked"
  )
}

write_csv(summary_tbl, file.path(diag_dir, "bc_coastwide_kfold_folds.csv"))
write_csv(model_summary, file.path(diag_dir, "bc_coastwide_kfold_summary.csv"))
write_csv(pointwise_tbl, file.path(diag_dir, "bc_coastwide_kfold_pointwise.csv"))
write_csv(diff_tbl, file.path(diag_dir, "bc_coastwide_kfold_contrast.csv"))

md <- c(
  "# BC Coastwide K-Fold CV",
  "",
  paste("Generated:", format(Sys.time())),
  "",
  "This is the robust comparison path for `m1_bc` versus `m3_bc` when positive-observation PSIS-LOO has high Pareto-k values.",
  "",
  "## Model Summary",
  "",
  knitr::kable(model_summary),
  "",
  "## M3 Versus M1",
  "",
  knitr::kable(diff_tbl),
  "",
  "## Fold Diagnostics",
  "",
  knitr::kable(summary_tbl |> arrange(model, fold)),
  "",
  "## Claim Gate",
  "",
  "- Promote `m3_bc` as the coastwide extension only if all folds complete, sampler diagnostics are acceptable, and the K-fold contrast remains positive enough to matter biologically.",
  "- If K-fold remains incomplete, use `m3_bc` only as a candidate supported by calibration, not as a robust predictive-comparison winner."
)
writeLines(md, file.path(diag_dir, "bc_coastwide_kfold_summary.md"))

cat("Wrote BC coastwide K-fold collection outputs.\n")
