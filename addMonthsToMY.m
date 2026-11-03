
function [m2, y2] = addMonthsToMY(m, y, k)
% add k months to (m,y), m in 1..12
    tot = (y*12 + (m-1)) + k;
    y2  = floor(tot/12);
    m2  = mod(tot,12) + 1;
end