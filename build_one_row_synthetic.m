function x = build_one_row_synthetic(T, rowIdx, pref, horizon)
% Returns x (horizon x 1) synthetic monthly prices for one prefix and one row,
% using rolling mapping for quarterly/yearly products.

    W_HARD = 1e6;

    t = T.date(rowIdx);
    if ~isdatetime(t)
        error('T.date must be datetime.');
    end

    A = [];
    b = [];

    % ---------- Monthly constraints Mc1..Mc4 ----------
    for j = 1:4
        col = sprintf('%sMc%d', pref, j);
        if ismember(col, T.Properties.VariableNames)
            val = T{rowIdx, col};
            if ~isnan(val)
                rowA = zeros(1, horizon);
                rowA(j) = 1;

                w = W_HARD; % hard constraint (Mc4 only if observed because NaN skipped)
                A = [A; w * rowA];
                b = [b; w * val];
            end
        end
    end

    % ---------- Rolling quarterly mapping ----------
    % Qc1 = first quarter not yet started.
    % We map it into month indices relative to "next month" (M01).
    % Steps:
    % - let m0 = month(t)
    % - next month start is M01
    % - next quarter start month is the first month of the next quarter (Jan/Apr/Jul/Oct) AFTER current quarter
    % - compute offset = months_between(M01_month, next_quarter_start_month)
    % - Qc1 covers indices (offset+1):(offset+3), Qc2 is +3 months, etc.
    m0 = month(t);
    y0 = year(t);

    % month/year of M01 (the month immediately after observation month)
    [m1, y1] = addMonthsToMY(m0, y0, 1);

    % next quarter start (month/year)
    [mq, yq] = nextQuarterStart(m0, y0);

    % offset from M01 to start of Qc1 in months (0,1,2,...)
    offQ1 = monthsDiff(m1, y1, mq, yq);

    for q = 1:4
        col = sprintf('%sQc%d', pref, q);
        if ismember(col, T.Properties.VariableNames)
            val = T{rowIdx, col};
            if ~isnan(val)
                startIdx = offQ1 + 1 + 3*(q-1);
                idx = startIdx:(startIdx+2);

                idx = idx(idx >= 1 & idx <= horizon);
                if numel(idx) == 3
                    rowA = zeros(1, horizon);
                    rowA(idx) = 1/3;
                    A = [A; rowA];
                    b = [b; val];
                end
            end
        end
    end

    % ---------- Rolling yearly mapping ----------
    % Yc1 = first calendar year not yet started.
    % If we are in any month of year y0, then the current year has started,
    % so front year is y0+1 (delivery Jan..Dec of y0+1).
    % Map months Jan..Dec of (y0+1) into indices relative to M01.
    frontYear = y0 + 1;
    startYearMonth = 1; % January
    startYearYear  = frontYear;

    offY1 = monthsDiff(m1, y1, startYearMonth, startYearYear);
    idxY1 = (offY1+1):(offY1+12);
    idxY1 = idxY1(idxY1 >= 1 & idxY1 <= horizon);

    for y = 1:5
        col = sprintf('%sYc%d', pref, y);
        if ismember(col, T.Properties.VariableNames)
            val = T{rowIdx, col};
            if ~isnan(val)
                % each Yc increases by 12 months
                idx = idxY1 + 12*(y-1);
                idx = idx(idx >= 1 & idx <= horizon);
                if numel(idx) == 12
                    rowA = zeros(1, horizon);
                    rowA(idx) = 1/12;
                    A = [A; rowA];
                    b = [b; val];
                end
            end
        end
    end

    if isempty(A)
        x = nan(horizon,1);
        return;
    end

    x = A \ b;
    x = x(:);

    if any(~isfinite(x))
        x = nan(horizon,1);
    end
end

% ===================== date helpers (month-year arithmetic) =====================

function [m2, y2] = addMonthsToMY(m, y, k)
% add k months to (m,y), m in 1..12
    tot = (y*12 + (m-1)) + k;
    y2  = floor(tot/12);
    m2  = mod(tot,12) + 1;
end

function d = monthsDiff(mA, yA, mB, yB)
% months from (mA,yA) to (mB,yB): B - A
% e.g. A=Mar2025, B=Apr2025 -> d=1
    d = (yB*12 + (mB-1)) - (yA*12 + (mA-1));
end

function [mq, yq] = nextQuarterStart(m, y)
% returns the start month/year of the next quarter AFTER the current quarter
% current quarter start: 1,4,7,10
    qStart = 3*floor((m-1)/3) + 1;   % 1/4/7/10
    nextQStartMonth = qStart + 3;    % next quarter
    mq = nextQStartMonth;
    yq = y;
    if mq > 12
        mq = mq - 12;
        yq = y + 1;
    end
end
