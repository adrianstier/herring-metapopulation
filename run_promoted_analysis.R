# =============================================================================
# Purpose: Regenerate promoted-baseline diagnostics and figures.
# Input:   Data/processed/jags_model_inputs_v2.RData plus saved/refit
#          m1_stier_11 artifacts, depending on mode.
# Output:  Output/diagnostics/run_promoted_analysis_summary.{csv,md}
#          Output/diagnostics/promoted_analysis_sessionInfo.txt
# =============================================================================

usage <- function() {
  cat(
    "Usage: Rscript --vanilla run_promoted_analysis.R [--mode=minimal|ledgers|refit] [--dry-run] [--continue-on-error]\n",
    "\n",
    "Modes:\n",
    "  minimal  Regenerate core m1_stier_11 fit, portfolio, and fit-caveat outputs from saved fits.\n",
    "  ledgers  Run minimal mode, then refresh model-branch and decision ledgers from saved fits.\n",
    "  refit    Refit m1_stier_11 locally with Stan, then run ledgers. This is slow.\n",
    sep = ""
  )
}

parse_args <- function(args) {
  out <- list(mode = "minimal", dry_run = FALSE, continue_on_error = FALSE)
  for (arg in args) {
    if (arg %in% c("-h", "--help")) {
      usage()
      quit(status = 0)
    } else if (arg == "--dry-run") {
      out$dry_run <- TRUE
    } else if (arg == "--continue-on-error") {
      out$continue_on_error <- TRUE
    } else if (startsWith(arg, "--mode=")) {
      out$mode <- sub("^--mode=", "", arg)
    } else if (!startsWith(arg, "-")) {
      out$mode <- arg
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }
  out
}

repo_root <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)
  required <- c("README.md", "_targets.R", "Data", "Code", "R")
  missing <- required[!file.exists(file.path(root, required))]
  if (length(missing)) {
    stop(
      "Run from the repository root. Missing expected paths: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  root
}

run_script <- function(rscript, script, continue_on_error) {
  start <- Sys.time()
  cat("\n==> ", script, "\n", sep = "")
  status <- system2(rscript, c("--vanilla", script))
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  ok <- identical(status, 0L)
  if (!ok && !continue_on_error) {
    stop("Script failed with exit status ", status, ": ", script, call. = FALSE)
  }
  data.frame(
    script = script,
    status = if (ok) "ok" else paste0("failed_", status),
    elapsed_sec = round(elapsed, 2),
    stringsAsFactors = FALSE
  )
}

write_session_info <- function(path, mode, root, scripts, results = NULL) {
  run_lines <- if (is.null(results)) {
    "No script results were recorded; the run likely stopped before completion."
  } else {
    c(
      "| Script | Status | Elapsed sec |",
      "|---|---:|---:|",
      sprintf("| `%s` | %s | %.2f |", results$script, results$status, results$elapsed_sec)
    )
  }

  lines <- c(
    "# Promoted Analysis Session Info",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("Mode: ", mode),
    paste0("Root: ", root),
    paste0("R executable: ", file.path(R.home("bin"), "R")),
    "",
    "## Scripts",
    paste0("- ", scripts),
    "",
    "## Run Results",
    run_lines,
    "",
    "## sessionInfo()",
    capture.output(utils::sessionInfo())
  )
  writeLines(lines, path)
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
root <- repo_root()
setwd(root)

script_groups <- list(
  minimal = c(
    "Code/06d_m1_stier_11_fit_figures.R",
    "Code/probes/07d_m1_stier_11_fit_quality_summary.R",
    "Code/probes/07e_m1_stier_11_spatial_concentration.R",
    "Code/06e_m1_stier_9_focal_reporting.R",
    "Code/06f_m1_stier_11_portfolio_figures.R",
    "Code/probes/07al_positive_spawn_fit_caveat.R"
  ),
  ledgers = c(
    "Code/06d_m1_stier_11_fit_figures.R",
    "Code/probes/07d_m1_stier_11_fit_quality_summary.R",
    "Code/probes/07e_m1_stier_11_spatial_concentration.R",
    "Code/06e_m1_stier_9_focal_reporting.R",
    "Code/06f_m1_stier_11_portfolio_figures.R",
    "Code/probes/07al_positive_spawn_fit_caveat.R",
    "Code/probes/07ak_model_branch_status_table.R",
    "Code/probes/07bi_model_decision_ledger.R"
  ),
  refit = c(
    "Code/03_fit_m1_stier_11.R",
    "Code/06d_m1_stier_11_fit_figures.R",
    "Code/probes/07d_m1_stier_11_fit_quality_summary.R",
    "Code/probes/07e_m1_stier_11_spatial_concentration.R",
    "Code/06e_m1_stier_9_focal_reporting.R",
    "Code/06f_m1_stier_11_portfolio_figures.R",
    "Code/probes/07al_positive_spawn_fit_caveat.R",
    "Code/probes/07ak_model_branch_status_table.R",
    "Code/probes/07bi_model_decision_ledger.R"
  )
)

if (!args$mode %in% names(script_groups)) {
  usage()
  stop("Unknown mode: ", args$mode, call. = FALSE)
}

required_inputs <- list(
  minimal = c(
    "Data/processed/jags_model_inputs_v2.RData",
    "Data/processed/m1_stier_11_fit.rds"
  ),
  ledgers = c(
    "Data/processed/jags_model_inputs_v2.RData",
    "Data/processed/m1_stier_11_fit.rds"
  ),
  refit = c(
    "Data/processed/jags_model_inputs_v2.RData"
  )
)
missing_inputs <- required_inputs[[args$mode]][!file.exists(file.path(root, required_inputs[[args$mode]]))]
if (length(missing_inputs)) {
  stop(
    "Missing required input(s): ",
    paste(missing_inputs, collapse = ", "),
    if (args$mode %in% c("minimal", "ledgers")) {
      ". Restore ignored saved-fit artifacts or run `--mode=refit` before using saved-fit modes."
    } else {
      ". Rebuild model input data before refitting."
    },
    call. = FALSE
  )
}

scripts <- script_groups[[args$mode]]
missing_scripts <- scripts[!file.exists(file.path(root, scripts))]
if (length(missing_scripts)) {
  stop("Missing runner script(s): ", paste(missing_scripts, collapse = ", "), call. = FALSE)
}

rscript <- Sys.which("Rscript")
if (!nzchar(rscript)) {
  rscript <- file.path(R.home("bin"), "Rscript")
}
if (!file.exists(rscript)) {
  stop("Could not find Rscript.", call. = FALSE)
}

cat("Promoted analysis runner\n")
cat("  mode: ", args$mode, "\n", sep = "")
cat("  root: ", root, "\n", sep = "")
cat("  scripts: ", length(scripts), "\n", sep = "")

if (args$dry_run) {
  cat("\nDry run only. Script order:\n")
  cat(paste0("  - ", scripts, collapse = "\n"), "\n", sep = "")
  quit(status = 0)
}

dir.create(file.path(root, "Output", "diagnostics"), recursive = TRUE, showWarnings = FALSE)

session_info_txt <- file.path(root, "Output", "diagnostics", "promoted_analysis_sessionInfo.txt")

if (identical(args$mode, "refit")) {
  cat("\nRefit mode runs full local Stan MCMC for m1_stier_11 before diagnostics.\n")
  cat("Use minimal or ledgers mode when saved fit artifacts are already restored.\n")
}

results <- do.call(
  rbind,
  lapply(scripts, run_script, rscript = rscript, continue_on_error = args$continue_on_error)
)

summary_csv <- file.path(root, "Output", "diagnostics", "run_promoted_analysis_summary.csv")
summary_md <- file.path(root, "Output", "diagnostics", "run_promoted_analysis_summary.md")
write.csv(results, summary_csv, row.names = FALSE)

md <- c(
  "# Promoted Analysis Run Summary",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  paste0("- Mode: `", args$mode, "`"),
  paste0("- Scripts run: ", nrow(results)),
  paste0("- Failures: ", sum(results$status != "ok")),
  "",
  "| Script | Status | Elapsed sec |",
  "|---|---:|---:|",
  sprintf("| `%s` | %s | %.2f |", results$script, results$status, results$elapsed_sec)
)
writeLines(md, summary_md)
write_session_info(session_info_txt, args$mode, root, scripts, results)

cat("\nWrote:\n")
cat("  ", summary_csv, "\n", sep = "")
cat("  ", summary_md, "\n", sep = "")
cat("  ", session_info_txt, "\n", sep = "")

if (any(results$status != "ok")) {
  quit(status = 1)
}
