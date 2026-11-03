%% ENERGY FINANCE PROJECT
clear all 
clc

T = readtable('power_DE_FR.csv');

% We drop Yc3 of both markets because we won't need vols that far in the
% future; we drop Mc4 for both markets because too many NaNs -> we will
% rebuild from Qc1
T(:, {'TRDEBYc3','TRFRBYc3','TRDEBMc4','TRFRBMc4'}) = [];

dates = T.date;
F = T{:, 2:end};% 20 columns : 9 German Market + 9 French Market

%% Plot time series
figure()
nCols = size(F,2);
for j=1:nCols
plot(dates,F(:,j));
hold on
grid on
end
title('Time series plot')
legend('GE_m1','GE_m2','GE_m3','GE_q1','GE_q2','GE_q3','GE_q4','GE_y1','GE_y2', ...
    'FR_m1','FR_m2','FR_m3','FR_q1','FR_q2','FR_q3','FR_q4','FR_y1','FR_y2',location='best')

%% Handling Nan
fprintf('=== Missing Data Analysis ===\n');
for j = 1:nCols
    x = F(:,j);
    isn = isnan(x);
    
    % Total number of NaN
    totalNan = sum(isn);

    fprintf('%-10s | NaN : %4d |\n ', ...
        T.Properties.VariableNames{j+1}, totalNan);
end
figure()
spy(isnan(F))
xlabel('Series');
ylabel('Time');
title('NaN map');
pbaspect([1 1 1]); %just for visualization

% dealing with NaN in our case: we will build the missing Mc4 data from Qc1
% so we don't fill those values

for j = 2:width(T)
   T{:,j} = fillmissing(T{:,j}, 'linear'); 
end

%% Statistical Analysis
[R,meanR,stdR,skewR,kurtR] = statistical_analysis(T);


%% Syntetic futures construction: flat month curve
Tsyn = get_flat_month_curve(T, 24, 1e-4);
Tsyn{:,2:end} = real(Tsyn{:,2:end});

%% New Statistical Analysis
[R_syn,meanR_syn,stdR_syn,skewR_syn,kurtR_syn] = statistical_analysis(Tsyn);

%% PCA 
[coeff, score, latent, tsq, explained] = pca(R_syn, 'Centered', true);

% explained variance
figure;
bar(explained);
title('Variance explained by principal components');

% Loadings (first two)
disp('Loadings (coeff):');
disp(coeff(:,1:2));

% Projection on first two components
figure;
plot(score(:,1), score(:,2), '.');
xlabel('PC1'); ylabel('PC2');
title('PCA projection');

%% iv. Pricing Chooser Option via Monte Carlo (CORRETTO)
% 1. Setup Date e Sottostanti
current_date = datetime(2025, 11, 5);
expiry_date = datetime(2027, 2, 5);
all_days = current_date:expiry_date;
T_days = sum(~isweekend(all_days));
T_years = double(T_days) / 252; 

r = 0.03; 

% Identificazione indici
idx_DE = 17; 
idx_FR = 17 + 24; 
F0_DE = Tsyn{end, idx_DE + 1}; 
F0_FR = Tsyn{end, idx_FR + 1}; 

% 2. Simulazione Monte Carlo con PCA
nSim = 100000;
cum_var = cumsum(explained);
nFactors = find(cum_var > 95, 1); 

sub_coeff = coeff(:, 1:nFactors);
sub_latent = latent(1:nFactors);

% IMPORTANTE: Se R_syn sono rendimenti giornalieri, 'latent' è varianza giornaliera.
% Dobbiamo scalare per il numero di giorni lavorativi alla scadenza (T_days).
Z = randn(nSim, nFactors); 
% Rendimento simulato = Shock * sqrt(Varianza_Fattore * Numero_Giorni) * Caricamenti_PCA
simulated_returns = (Z .* sqrt(sub_latent' * T_days)) * sub_coeff';

% 3. Calcolo Volatilità e Drift (per consistenza)
% Calcoliamo la volatilità totale (non annualizzata) per il periodo T_days
% sigma_T^2 = Var(R_syn) * T_days
var_daily = var(R_syn); 
drift_DE = -0.5 * var_daily(idx_DE) * T_days;
drift_FR = -0.5 * var_daily(idx_FR) * T_days;

% 4. Prezzi alla scadenza
FT_DE = F0_DE * exp(drift_DE + simulated_returns(:, idx_DE));
FT_FR = F0_FR * exp(drift_FR + simulated_returns(:, idx_FR));

% 5. Payoff e Prezzo
payoffs = max(FT_DE, FT_FR);
option_price = exp(-r * T_years) * mean(payoffs);

% 6. Bounds
lower_bound = exp(-r * T_years) * max(F0_DE, F0_FR);
upper_bound = exp(-r * T_years) * (F0_DE + F0_FR);

% Output
fprintf('\n=== Chooser Option Pricing ===\n');
fprintf('Prezzo stimato (MC): %.4f\n', option_price);
fprintf('Lower Bound:         %.4f\n', lower_bound);
fprintf('Upper Bound:         %.4f\n', upper_bound);

%% v. Swing Option Pricing - ONLY UPSWINGS
K = 40; 
Q = 1; 
startDate = datetime(2027, 11, 1);
endDate = datetime(2027, 11, 30);
t_days = days(endDate - startDate) + 1;

nSim = 10000;
N_factors = find(cumsum(explained) > 95, 1); 
dt = 1/252; 
r = 0.03; % Tasso di sconto

% Indice per Novembre 2027 (Mc24)
idx_spot = 24; 
F_target = Tsyn{end, idx_spot + 1}; 

% 1. Simulazione dello Spot (Eq. 12)
sigma_scaled = coeff(:, 1:N_factors) .* sqrt(latent(1:N_factors))';
X_spot = zeros(nSim, t_days);
for d = 1:t_days
    Z = randn(nSim, N_factors);
    X_spot(:, d) = Z * sigma_scaled(idx_spot, :)' * sqrt(dt);
end
cum_X = cumsum(X_spot, 2); 
var_acc = cumsum(repmat(sum(sigma_scaled(idx_spot, :).^2) * dt, 1, t_days));
S_spot = F_target * exp(cum_X - 0.5 * var_acc);

% 2. Valutazione Swing con soli Upswings
N_range = [1, 5, 10, 15, 20, 25, 30]; 
swing_values = zeros(length(N_range), 1);
LB = zeros(length(N_range), 1);
UB = zeros(length(N_range), 1);

% Calcolo Call Europee per Upper Bound
% Se solo upswings, UB = sum(CEu)
call_eu = mean(max(S_spot - K, 0)); 

for j = 1:length(N_range)
    N = N_range(j);
    payoffs = zeros(nSim, 1);
    
    for s = 1:nSim
        % SOLO UPSWING: max(S - K, 0)
        daily_val = max(S_spot(s,:) - K, 0);
        sorted_val = sort(daily_val, 'descend');
        % Sommiamo i migliori N giorni
        payoffs(s) = Q * sum(sorted_val(1:min(N, t_days)));
    end
    
    swing_values(j) = exp(-r * 2) * mean(payoffs);
    
    % Lower Bound: Valore con 1 solo upswing (American/European Call)
    if N == 1, LB(:) = swing_values(j); end
    
    % Upper Bound: Somma di tutte le Call Europee del mese
    UB(j) = exp(-r * 2) * sum(call_eu);
end

% 3. Plot
figure;
plot(N_range, swing_values, 'b-s', 'DisplayName', 'Swing (Only Upswings)'); hold on;
plot(N_range, repmat(UB(end), size(N_range)), 'r--', 'DisplayName', 'Upper Bound (Sum of Calls)');
plot(N_range, repmat(LB(1), size(N_range)), 'g--', 'DisplayName', 'Lower Bound (Single Call)');
grid on; xlabel('N (Max Daily Upswings)'); ylabel('Price [EUR]');
title('Swing Option Value: Only Upswings Analysis');
legend(location='best');