function Tsyn = get_flat_month_curve(T, horizonMonths, lambda)
% GET_FLAT_MONTH_CURVE builds a flat (step-wise) monthly forward curve from
% monthly/quarterly/yearly continuation futures with rolling delivery periods.
%
% This implements the approach described in Gardini & Santilli, Sec. 4.1.1:
% build a step-wise monthly curve epsilon(u)=sum a_i 1_[tau_{i-1},tau_i](u)
% and impose no-arbitrage constraints: each quoted product equals the
% weighted average of the underlying monthly pieces. (Weights 1,1/3,1/12).
%
% Rolling convention:
% - Mc1 = next calendar month after observation date
% - Qc1 = first quarter NOT yet started (front quarter), Qc2 next, ...
% - Yc1 = first calendar year NOT yet started (front year), Yc2 next, ...
%
% INPUT:
% T:             table with variable 'date' (datetime) and columns with
%                Products' names
% horizonMonths: number of monthly points to build (2 years -> 24)
% lambda:        smoothing strength for uniqueness/stability (default 1e-4)
%                (penalizes second differences of monthly curve).
%
% OUTPUT:
% Tsyn: table with 'date' and synthetic monthly columns

    % infer market prefixes from Mc1 columns (e.g. TRDEB, TRFRB)
    vars = T.Properties.VariableNames;
    isMc1 = endsWith(vars, 'Mc1');
    prefixes = unique(extractBefore(vars(isMc1), 'Mc1'));

    % Preparation of the table
    Tsyn = table();
    Tsyn.date = T.date;

    for p = 1:numel(prefixes)
        pref = prefixes{p};
        X = nan(height(T), horizonMonths);

        for r = 1:height(T)
            X(r,:) = solve_one_date_curve(T, r, pref, horizonMonths, lambda).';
        end

        for m = 1:horizonMonths
            Tsyn.(sprintf('%sM%02d', pref, m)) = X(:,m);
        end
    end
end
