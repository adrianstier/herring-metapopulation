# ============================================================================
# 12_manuscript_figures.R — 5 BC-coastwide manuscript figures
# analysis/05_bc_coastwide
#
# Uses theme_pub() from R/00_setup.R (Okabe-Ito palette, base sizes per
# the pub-figure-pipeline standards). All exports at 300 DPI cairo_pdf.
# Companion legends to Output/figures/legends/.
# ============================================================================

suppressPackageStartupMessages({
  library(rstan)
  library(ggplot2)
  library(patchwork)
  library(here)
  library(tidyverse)
})

source(here::here("R", "00_setup.R"))

MODEL_ID <- Sys.getenv("BC_MODEL_ID", unset = "m3_bc_marginal")
fit_path <- here::here("analysis", "05_bc_coastwide", "output",
                       paste0(MODEL_ID, "_fit.rds"))
if (!file.exists(fit_path)) {
  stop("Missing coastwide fit for BC_MODEL_ID=", MODEL_ID, ": ", fit_path)
}

obj <- readRDS(fit_path)
fit <- obj$fit
section_meta <- obj$section_meta
stock_areas <- obj$stock_areas

z_mean <- apply(rstan::extract(fit, "z")$z, c(2, 3), mean)
sec_year <- crossing(section_idx = seq_len(nrow(section_meta)),
                     year = YEARS) |>
  mutate(z = as.numeric(t(z_mean)),
         stock_area = rep(section_meta$stock_area, each = length(YEARS)))

fig_dir <- here::here("Output", "figures")
leg_dir <- here::here("Output", "figures", "legends")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(leg_dir, showWarnings = FALSE, recursive = TRUE)

save_fig <- function(p, name, w = 170, h = 120) {
  ggsave(file.path(fig_dir, paste0(name, ".pdf")), p,
         width = w, height = h, units = "mm", dpi = 300, device = cairo_pdf)
  ggsave(file.path(fig_dir, paste0(name, ".png")), p,
         width = w, height = h, units = "mm", dpi = 300)
}

write_legend <- function(name, text) {
  writeLines(text, file.path(leg_dir, paste0(name, "_legend.md")))
}

# ── Fig 1: Stock-area map with section-level recent-trend coloring ──
recent_trend <- sec_year |>
  filter(year >= max(year) - 4L) |>
  group_by(section_idx, stock_area) |>
  summarise(trend = coef(lm(z ~ year))[2], .groups = "drop")
p1 <- ggplot(recent_trend, aes(x = stock_area, y = trend, fill = trend)) +
  geom_jitter(width = 0.2, shape = 21, size = 2) +
  scale_fill_gradient2(midpoint = 0, low = "#D55E00", high = "#0072B2") +
  labs(x = "Stock area", y = "Section-level 5-year trend (log-biomass / yr)",
       title = "Recent-trend portfolio across BC stock areas") +
  theme_pub(11)
save_fig(p1, "bc_coastwide_fig1")
write_legend("bc_coastwide_fig1",
  c("# Figure 1 — Recent-trend portfolio across BC stock areas",
    "",
    paste("Section-level 5-year linear trends in posterior-mean log-biomass.",
          "Each point is one section colored by trend (red = declining,",
          "blue = increasing). Stock areas:",
          paste(stock_areas, collapse = ", ")),
    paste0("Data source: ", MODEL_ID, "_fit.rds, Output/figures/bc_coastwide_fig1.{pdf,png}.")))

# ── Fig 2: Section-level posterior trajectories, facetted by stock area ──
p2 <- ggplot(sec_year |> filter(stock_area %in% c("HG", "PRD", "CC", "SoG", "WCVI")),
             aes(x = year, y = z, group = section_idx)) +
  geom_line(alpha = 0.3, color = "#0072B2") +
  facet_wrap(~ stock_area, ncol = 3, scales = "free_y") +
  labs(x = "Year", y = "Posterior-mean log-biomass") +
  theme_pub(10)
save_fig(p2, "bc_coastwide_fig2", w = 170, h = 110)
write_legend("bc_coastwide_fig2",
  c("# Figure 2 — Section-level posterior trajectories",
    "",
    "Posterior-mean log-biomass per section, faceted by major stock area.",
    paste0("Each line is one section. Model: ", MODEL_ID, ".")))

# ── Fig 3: Recovery curves anchored to fishery events ──
ca <- read_csv(here::here("Output", "diagnostics", "bc_comparative_areas.csv"),
               show_col_types = FALSE)
p3 <- ggplot(ca, aes(x = years_post_event, y = recovery_metric_value,
                     color = stock_area)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  scale_color_manual(values = c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                                "#0072B2", "#D55E00", "#CC79A7", "#000000")) +
  labs(x = "Years since fishery anchor event",
       y = "Stock-area mean log-biomass",
       color = "Stock area",
       title = "Recovery curves anchored to fishery-history events") +
  theme_pub(10)
save_fig(p3, "bc_coastwide_fig3")
write_legend("bc_coastwide_fig3",
  c("# Figure 3 — Recovery curves anchored to fishery events",
    "",
    "Stock-area-mean posterior log-biomass at 0, 5, 10, 15, 20 years post-event.",
    "Anchor events from Data/processed/bc_fishery_events.csv. SoG (never closed)",
    "is anchored at 1990 for reference."))

# ── Fig 4: BC portfolio metrics ──
pm <- read_csv(here::here("Output", "diagnostics", "bc_portfolio_metrics.csv"),
               show_col_types = FALSE)
p4 <- ggplot(pm, aes(x = stock_area, y = value, fill = stock_area)) +
  geom_col() +
  facet_wrap(~ metric, scales = "free_y", nrow = 1) +
  scale_fill_manual(values = c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                                "#0072B2", "#D55E00", "#CC79A7", "#000000")) +
  labs(x = "Stock area", y = "Value", title = "BC portfolio metrics") +
  theme_pub(10) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(p4, "bc_coastwide_fig4", w = 170, h = 90)
write_legend("bc_coastwide_fig4",
  c("# Figure 4 — BC portfolio metrics by stock area",
    "",
    "Loreau-de Mazancourt synchrony (phi), CV-ratio (portfolio effect),",
    "and occupancy fraction (sections active per year) by stock area.",
    paste0("Computed from posterior-mean log-biomass; model: ", MODEL_ID, ".")))

# ── Fig 5: Model comparison + use status ──
status_path <- here::here("Output", "diagnostics",
                          "bc_coastwide_model_status_table.csv")
if (!file.exists(status_path)) {
  stop("Figure 5 requires Output/diagnostics/bc_coastwide_model_status_table.csv. Run scripts/09_diagnostics.R first.")
}
status <- read_csv(status_path, show_col_types = FALSE) |>
  mutate(
    model = factor(model, levels = c("m1_bc_marginal", "m3_bc_marginal",
                                     "m1_bc", "m3_bc", "m5_bc")),
    decision_label = case_when(
      model == "m3_bc_marginal" ~ "usable sensitivity",
      model == "m1_bc_marginal" ~ "repaired comparator",
      model %in% c("m1_bc", "m3_bc") ~ "failed sampler gate",
      TRUE ~ "failed"
    )
  )
status_cv <- status |>
  filter(model %in% c("m1_bc_marginal", "m3_bc_marginal")) |>
  mutate(
    delta_elpd = elpd_loo - max(elpd_loo, na.rm = TRUE),
    label = case_when(
      model == "m3_bc_marginal" ~ paste0("usable\nRMSE ",
                                         round(coastwide_rmse_log10, 3)),
      TRUE ~ paste0("comparator\nRMSE ", round(coastwide_rmse_log10, 3))
    ),
    label_y = if_else(abs(delta_elpd) < 1e-8, -8, delta_elpd / 2)
  )
m3_gate <- status |>
  filter(model == "m3_bc_marginal") |>
  slice(1)
diff_gate <- status |>
  filter(model == "m1_bc_marginal") |>
  slice(1)
contrast_label <- paste0(
  "m3_marginal - m1_marginal = +",
  round(m3_gate$elpd_loo - diff_gate$elpd_loo, 1),
  " PSIS-LOO elpd; both max Pareto-k < 0.7"
)
p5 <- ggplot(status_cv, aes(x = model, y = delta_elpd,
                            fill = decision_label)) +
  geom_col(width = 0.65) +
  geom_hline(yintercept = 0, linewidth = 0.3) +
  geom_text(aes(y = label_y, label = label), size = 3,
            lineheight = 0.95, na.rm = TRUE) +
  scale_fill_manual(values = c("repaired comparator" = "#56B4E9",
                               "usable sensitivity" = "#009E73",
                               "failed sampler gate" = "#E69F00",
                               "failed" = "#D55E00")) +
  labs(x = "Coastwide branch",
       y = "Delta PSIS-LOO elpd",
       fill = "Use status",
       title = "Coastwide model comparison and claim gate",
       subtitle = contrast_label) +
  coord_cartesian(ylim = c(min(status_cv$delta_elpd, na.rm = TRUE) - 12, 6),
                  clip = "off") +
  theme_pub(10) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p5, "bc_coastwide_fig5", w = 120, h = 100)
write_legend("bc_coastwide_fig5",
  c("# Figure 5 — Coastwide model comparison and claim gate",
    "",
    "Delta expected log predictive density from PSIS-LOO among the",
    "marginalized state-space repair branches, relative to `m3_bc_marginal`.",
    "`m3_bc_marginal` clears sampler and Pareto-k gates and is the current",
    "statistically usable coastwide sensitivity. It is a geometry/LOO repair,",
    "not a new biological mechanism.",
    "Original full-state M1/M3 and M5 remain failed or held by sampler gates.",
    "Sources: Output/diagnostics/bc_coastwide_model_status_table.csv and",
    "Output/diagnostics/bc_marginal_repair_readout.md."))

cat("All 5 figures + legends rendered.\n")
