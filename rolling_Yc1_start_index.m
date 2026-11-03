function [startIdxY1, ok] = rolling_Yc1_start_index(t)
% Returns start month-index (relative to M01) of Yc1 delivery:
% Yc1 = first calendar year NOT yet started.
%
% Example:
% - t in Dec 2024 -> Yc1 = year 2025 -> starts Jan 2025
% - t in Feb 2025 -> Yc1 = year 2026 -> starts Jan 2026

    ok = true;

    m = month(t); y = year(t);

    % M01
    [m1, y1] = addMonthsToMY(m, y, 1);

    % if we are in year y, then year y has started -> front year is y+1
    frontYear = y + 1;

    startIdxY1 = monthsDiff(m1, y1, 1, frontYear) + 1; % Jan frontYear
end
