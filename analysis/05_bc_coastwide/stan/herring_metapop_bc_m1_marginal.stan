// ============================================================================
// herring_metapop_bc_m1_marginal.stan -- Marginalized BC M1 state-space model
// analysis/05_bc_coastwide
//
// Integrates over section-year latent states with a Kalman filter instead of
// sampling every z[s, t]. Generated quantities use FFBS to draw latent states
// for downstream calibration and portfolio summaries.
// ============================================================================

data {
  int<lower=1> N_sections;
  int<lower=1> N_years;
  int<lower=1> N_stock_areas;
  array[N_sections] int<lower=1, upper=N_stock_areas> stock_area_of;

  array[N_sections, N_years] real<lower=0> y;
  array[N_sections, N_years] int<lower=0, upper=1> obs_mask;
}

transformed data {
  array[N_sections, N_years] real log_y;
  real init_var = square(2.5);
  for (s in 1:N_sections)
    for (t in 1:N_years)
      log_y[s, t] = obs_mask[s, t] == 1 ? log(y[s, t]) : 0.0;
}

parameters {
  vector[N_stock_areas] r_area;
  vector[N_stock_areas] mu0_area;
  vector<lower=0.05>[N_stock_areas] sigma_area;
  real<lower=0.05> sigma_obs;
}

model {
  r_area ~ normal(0, 0.35);
  mu0_area ~ normal(log(100), 2);
  sigma_area ~ exponential(1.5);
  sigma_obs ~ exponential(1);

  for (s in 1:N_sections) {
    int a = stock_area_of[s];
    real m = mu0_area[a];
    real C = init_var;
    real q = square(sigma_area[a]);
    real R = square(sigma_obs);

    for (t in 1:N_years) {
      if (obs_mask[s, t] == 1) {
        real S = C + R;
        real K = C / S;
        target += normal_lpdf(log_y[s, t] | m, sqrt(S));
        m += K * (log_y[s, t] - m);
        C = (1 - K) * C;
      }
      if (t < N_years) {
        m += r_area[a];
        C += q;
      }
    }
  }
}

generated quantities {
  array[N_sections, N_years] real z;
  array[N_sections, N_years] real y_rep;
  array[N_sections, N_years] real log_lik;

  for (s in 1:N_sections) {
    int a = stock_area_of[s];
    real q = square(sigma_area[a]);
    real R = square(sigma_obs);
    array[N_years] real filt_m;
    array[N_years] real filt_C;
    real m = mu0_area[a];
    real C = init_var;

    for (t in 1:N_years) {
      if (obs_mask[s, t] == 1) {
        real S = C + R;
        real K = C / S;
        log_lik[s, t] = normal_lpdf(log_y[s, t] | m, sqrt(S));
        m += K * (log_y[s, t] - m);
        C = (1 - K) * C;
      } else {
        log_lik[s, t] = 0.0;
      }
      filt_m[t] = m;
      filt_C[t] = C;
      if (t < N_years) {
        m += r_area[a];
        C += q;
      }
    }

    z[s, N_years] = normal_rng(filt_m[N_years],
                               sqrt(fmax(filt_C[N_years], 1e-9)));
    if (N_years > 1) {
      for (t_rev in 1:(N_years - 1)) {
        int t = N_years - t_rev;
        real pred_m = filt_m[t] + r_area[a];
        real pred_C = filt_C[t] + q;
        real J = filt_C[t] / pred_C;
        real smooth_m = filt_m[t] + J * (z[s, t + 1] - pred_m);
        real smooth_C = filt_C[t] - square(J) * pred_C;
        z[s, t] = normal_rng(smooth_m, sqrt(fmax(smooth_C, 1e-9)));
      }
    }

    for (t in 1:N_years)
      y_rep[s, t] = lognormal_rng(z[s, t], sigma_obs);
  }
}
