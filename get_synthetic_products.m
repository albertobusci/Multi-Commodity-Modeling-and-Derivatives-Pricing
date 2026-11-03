function Tsyn = get_synthetic_products(T)
% Build synthetic monthly products (M01..M24) from monthly/quarterly/yearly futures
% using least squares with coherence constraints.
%
% INPUT:
% T:    table with a 'date' column and futures columns for the two markets
%
% OUTPUT:
% Tsyn: table with 'date' and synthetic monthly columns:
%       TRDEBM01..TRDEBM24, TRFRBM01..TRFRBM24
%
% LOGIC (horizon = 24 months):
% - Monthly instruments:
%   Mc1..Mc3 always used as strong constraints (if available),
%   Mc4 used as strong constraint ONLY if not NaN (otherwise it is left to LS).
% - Quarterly instruments:
%   Qc1 constrains mean(M04..M06), Qc2 mean(M07..M09), Qc3 mean(M10..M12), Qc4 mean(M13..M15)
% - Yearly instruments:
%   Yc1 constrains mean(M13..M24). (Yc2 would start at M25, ignored here)
%
% Solve: minimize ||A x - b||_2 with weighted hard constraints for known months.
%
    horizon = 24;

    % --- detect market prefixes from variable names (everything before 'Mc1') ---
    vars = T.Properties.VariableNames;
    isMc1 = endsWith(vars, 'Mc1');
    prefixes = unique(extractBefore(vars(isMc1), 'Mc1'));

    if isempty(prefixes)
        error('No market prefixes found (expected columns ending with Mc1).');
    end

    % Prepare output container
    Tsyn = table();
    Tsyn.date = T.date;

    % Loop markets
    for p = 1:numel(prefixes)
        pref = prefixes{p};

        % Build synthetic monthly matrix (nObs x 24)
        Xsyn = nan(height(T), horizon);

        for t = 1:height(T)
            x = build_one_row_synthetic(T, t, pref, horizon);
            Xsyn(t,:) = x(:).';
        end

        % Add columns to output table
        for m = 1:horizon
            colName = sprintf('%sM%02d', pref, m);
            Tsyn.(colName) = Xsyn(:, m);
        end
    end
end

