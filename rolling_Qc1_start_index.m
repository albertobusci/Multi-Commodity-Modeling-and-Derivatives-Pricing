function [startIdxQ1, ok] = rolling_Qc1_start_index(t)
% Returns the start month-index (relative to M01) of Qc1 delivery:
% Qc1 = first quarter NOT yet started.
%
% Example:
% - t in Dec 2024 -> Qc1 = Jan-Mar 2025 -> startIdxQ1 = 1 (M01=Jan)
% - t in Feb 2025 -> Qc1 = Apr-Jun 2025 -> startIdxQ1 = 2 (M01=Mar, Apr is M02)

    ok = true;

    m = month(t); y = year(t);

    % M01 is the next calendar month after observation month
    [m1, y1] = addMonthsToMY(m, y, 1);

    % first month of current quarter
    qStart = 3*floor((m-1)/3) + 1;      % 1,4,7,10
    % next quarter start = qStart+3
    [mq, yq] = addMonthsToMY(qStart, y, 3);

    % if we are already exactly at quarter start month, that quarter has started -> still choose NEXT quarter
    % (this matches "not yet started": at Apr 1, Q2 has started, so front is Q3)
    if m == qStart
        [mq, yq] = addMonthsToMY(mq, yq, 3);
    end

    startIdxQ1 = monthsDiff(m1, y1, mq, yq) + 1; % +1 because index is 1-based (M01)
end