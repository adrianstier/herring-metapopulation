// ============================================================================
// herring_metapop_bc_m1_catch_pressure.stan
// Hierarchical M1 baseline plus lagged stock-area catch pressure
// analysis/05_bc_coastwide
//
// Catch pressure is a stock-area annual covariate assembled from DFO CSAS
// Appendix B assessment catch tables. It enters next-year latent growth as a
// non-positive fishing-pressure term; it does not allocate historical catch to
// individual sections.
// ============================================================================

data {
  int<lower=1> N_sections;
  int<lower=1> N_years;
  int<lower=1> N_stock_areas;
  array[N_sections] int<lower=1, upper=N_stock_areas> stock_area_of;

  array[N_sections, N_years] real<lower=0> y;
  array[N_sections, N_years] int<lower=0, upper=1> obs_mask;

  int<lower=0> N_D;
  vector[N_D] D_blocks;
  array[N_stock_areas] int<lower=1> block_starts;
  array[N_stock_areas] int<lower=0> block_sizes;

  matrix<lower=0, upper=1>[N_stock_areas, N_years] catch_pressure;
}

transformed data {
  array[N_sections, N_years] real log_y;
  for (s in 1:N_sections)
    for (t in 1:N_years)
      log_y[s, t] = obs_mask[s, t] == 1 ? log(y[s, t]) : 0.0;
}

parameters {
  vector[N_stock_areas] r_area;
  vector<lower=0>[N_stock_areas] gamma_catch;
  vector<lower=0>[N_stock_areas] sigma_area;
  vector<lower=0>[N_stock_areas] range_area;
  real<lower=0> sigma_obs;
  array[N_sections, N_years] real z;
  vector[N_sections] z0;
}

model {
  r_area ~ normal(0, 0.5);
  gamma_catch ~ normal(0, 0.5);
  sigma_area ~ normal(0, 1);
  range_area ~ normal(50, 50);
  sigma_obs ~ normal(0, 1);
  z0 ~ normal(log(100), 2);

  for (s in 1:N_sections) {
    int a = stock_area_of[s];
    z[s, 1] ~ normal(z0[s], sigma_area[a]);
    for (t in 2:N_years) {
      real fishing_term = gamma_catch[a] * catch_pressure[a, t - 1];
      z[s, t] ~ normal(z[s, t - 1] + r_area[a] - fishing_term,
                       sigma_area[a]);
    }
  }

  for (s in 1:N_sections)
    for (t in 1:N_years)
      if (obs_mask[s, t] == 1)
        log_y[s, t] ~ normal(z[s, t], sigma_obs);
}

generated quantities {
  array[N_sections, N_years] real y_rep;
  array[N_sections, N_years] real log_lik;
  for (s in 1:N_sections) {
    for (t in 1:N_years) {
      y_rep[s, t] = lognormal_rng(z[s, t], sigma_obs);
      log_lik[s, t] = obs_mask[s, t] == 1
        ? normal_lpdf(log_y[s, t] | z[s, t], sigma_obs) : 0.0;
    }
  }
}
