function [R,meanR,stdR,skewR,kurtR] = statistical_analysis(T)
%Take log-returns
R = real(diff(log(T{:,2:end})));

%% Distribution: Empirical fit vs theoretical gaussian
% basic statistics
meanR = mean(R);
stdR  = std(R);
skewR = skewness(R);
kurtR = kurtosis(R);

% descriptive table
stats = table(T.Properties.VariableNames(2:end)', meanR', stdR', skewR', kurtR', ...
    'VariableNames', {'Contract','Mean','Std','Skew','Kurtosis'});
disp(stats)

% Stationarity: test ADF
for i = 1:size(R,2)
    [h,p] = adftest(R(:,i)); % h=1 -> reject null hp, p is p-value
    fprintf('%s: adftest h=%d, p=%.3f\n', T.Properties.VariableNames{i}, h, p); % h=1 -> stationary
end

% Gaussianity: Jarque-Bera test
for i = 1:size(R,2)
    [h,p] = jbtest(R(:,i));
    fprintf('%s: jbtest h=%d, p=%.3f\n', T.Properties.VariableNames{i}, h, p);% h=1 -> not gaussian
end

% DO TO: outliers analysis

%%  Distribution and autocorrelation
for i = 1:size(R,2)
    figure;
    subplot(2,1,1);
    histogram(R(:,i),50,'Normalization','pdf'); hold on;
    x = linspace(min(R(:,i)),max(R(:,i)),100);
    y = normpdf(x, meanR(i), stdR(i));
    plot(x,y,'r','LineWidth',1.5);
    title(['Distribuzione log-return ', T.Properties.VariableNames{i+1}]);
    legend('Data','Normal');
    subplot(2,1,2);
    autocorr(R(:,i),NumLags=20);
    title(['Autocorrelation ', T.Properties.VariableNames{i+1}]);
end

%% Samuelson effect
figure();
bar(stdR);
set(gca,'XTickLabel', T.Properties.VariableNames(2:end), 'XTickLabelRotation',45);
ylabel('Volatility');
title('Samuelson effect: Vol goes down with delivery');
grid on;

%% Correlation surface 
C = corr(R, 'Rows','pairwise');
figure;
imagesc(C); colorbar;
xticks(1:length(C)); yticks(1:length(C));
xticklabels(T.Properties.VariableNames(2:end));
yticklabels(T.Properties.VariableNames(2:end));
xtickangle(45);
title('Superficie di correlazione tra log-returns');

%% Correlation on longer horizon
datesR = T.date(2:end);
TT = array2timetable(R, 'RowTimes', datesR, ...
    'VariableNames', T.Properties.VariableNames(2:end));
R_w = retime(TT, 'weekly', 'mean');
R_m = retime(TT, 'monthly', 'mean');
corr_w = corr(R_w.Variables,'Rows','pairwise');
corr_m = corr(R_m.Variables,'Rows','pairwise');