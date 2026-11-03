function x = solve_one_date_curve(T, rowIdx, pref, H, lambda)
% Unknowns: x = [M01 ... MH]' monthly flat curve values.

    t = T.date(rowIdx);
    A = [];
    b = [];

    % ---- Monthly constraints: ----
    for j = 1:3
        col = sprintf('%sMc%d', pref, j);
        if ismember(col, T.Properties.VariableNames)
            val = T{rowIdx, col};
            if ~isnan(val)
                rowA = zeros(1,H);
                rowA(j) = 1;
                A = [A; rowA];
                b = [b; val];
            end
        end
    end

    % ---- Rolling quarterly constraints: Qc1..Qc4 ----
    % Qc1 = first quarter not yet started (front quarter)
    [startIdxQ1, okQ1] = rolling_Qc1_start_index(t);
    if okQ1
        for q = 1:4
            col = sprintf('%sQc%d', pref, q);
            if ismember(col, T.Properties.VariableNames)
                val = T{rowIdx, col};
                if ~isnan(val)
                    s = startIdxQ1 + 3*(q-1);
                    idx = s:(s+2);
                    idx = idx(idx>=1 & idx<=H);
                    if numel(idx)==3
                        rowA = zeros(1,H);
                        rowA(idx) = 1/3;
                        A = [A; rowA];
                        b = [b; val];
                    end
                end
            end
        end
    end

    % ---- Rolling yearly constraints: Yc1, Yc2 ----
    % Yc1 = first calendar year not yet started (front year)
    [startIdxY1, okY1] = rolling_Yc1_start_index(t);
    if okY1
        for y = 1:2
            col = sprintf('%sYc%d', pref, y);
            if ismember(col, T.Properties.VariableNames)
                val = T{rowIdx, col};
                if ~isnan(val)
                    s = startIdxY1 + 12*(y-1);
                    idx = s:(s+11);
                    idx = idx(idx>=1 & idx<=H);
                    if numel(idx)==12
                        rowA = zeros(1,H);
                        rowA(idx) = 1/12;
                        A = [A; rowA];
                        b = [b; val];
                    end
                end
            end
        end
    end

    % ---- Regularization (second differences) to avoid underdetermined => zeros ----
    % Penalize curvature: D2 * x ~ 0  (flat-ish curve unless data says otherwise)
    if lambda > 0
        D2 = zeros(H-2, H);
        for i = 1:(H-2)
            D2(i,i)   = 1;
            D2(i,i+1) = -2;
            D2(i,i+2) = 1;
        end
        A = [A; sqrt(lambda) * D2];
        b = [b; zeros(H-2,1)];
    end

    if isempty(A)
        x = nan(H,1);
        return;
    end

    x = A \ b;
    x = x(:);
end