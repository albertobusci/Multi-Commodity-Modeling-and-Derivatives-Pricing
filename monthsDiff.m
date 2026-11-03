function d = monthsDiff(mA, yA, mB, yB)
% months from (mA,yA) to (mB,yB): B - A
    d = (yB*12 + (mB-1)) - (yA*12 + (mA-1));
end
