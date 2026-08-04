%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 7);
% Specify range and delimiter
opts.DataLines = [1, 15000000];
opts.Delimiter = ",";
% Specify column names and types
opts.VariableNames = ["Time", "X", "Y", "Z", "GX", "GY", "GZ"];
opts.VariableTypes = ["datetime", "double", "double", "double", "double", "double", "double"];
% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
% Specify variable properties
opts = setvaropts(opts, "Time", "InputFormat", "yyyy-MM-dd HH:mm:ss.SSS");

% SET THE PARTICIPANT AND EXPECTED SYNC POINT TIME
ppt = "45";
targetTime = datetime("2026-08-01 09:09:39", "InputFormat", "yyyy-MM-dd HH:mm:ss");


leftankle = readtable(strcat(ppt,"_LA.csv"), opts);
leftankle.mag = sqrt(leftankle.X.^2 + leftankle.Y.^2 + leftankle.Z.^2);

rightankle = readtable(strcat(ppt,"_RA.csv"), opts);
rightankle.mag = sqrt(rightankle.X.^2 + rightankle.Y.^2 + rightankle.Z.^2);

lefthip = readtable(strcat(ppt,"_LH.csv"), opts);
lefthip.mag = sqrt(lefthip.X.^2 + lefthip.Y.^2 + lefthip.Z.^2);

righthip = readtable(strcat(ppt,"_RH.csv"), opts);
righthip.mag = sqrt(righthip.X.^2 + righthip.Y.^2 + righthip.Z.^2);

cgwrist = readtable(strcat(ppt,"_CW.csv"), opts);
cgwrist.mag = sqrt(cgwrist.X.^2 + cgwrist.Y.^2 + cgwrist.Z.^2);

cghip = readtable(strcat(ppt,"_CH.csv"), opts);
cghip.mag = sqrt(cghip.X.^2 + cghip.Y.^2 + cghip.Z.^2);

halfWindow = minutes(15);
startTime = targetTime - halfWindow;
endTime   = targetTime + halfWindow;

figure;
idx = (leftankle.Time >= startTime) & (leftankle.Time <= endTime);
plot(leftankle.Time(idx), leftankle.mag(idx));
title(['Left Ankle']);

figure;
idx = (rightankle.Time >= startTime) & (rightankle.Time <= endTime);
plot(rightankle.Time(idx), rightankle.mag(idx));
title(['Right Ankle']);

figure;
idx = (lefthip.Time >= startTime) & (lefthip.Time <= endTime);
plot(lefthip.Time(idx), lefthip.mag(idx));
title(['Left Hip']);

figure;
idx = (righthip.Time >= startTime) & (righthip.Time <= endTime);
plot(righthip.Time(idx), righthip.mag(idx));
title(['Right Hip']);

figure;
idx = (cgwrist.Time >= startTime) & (cgwrist.Time <= endTime);
plot(cgwrist.Time(idx), cgwrist.mag(idx));
title(['CG Wrist']);

figure;
idx = (cghip.Time >= startTime) & (cghip.Time <= endTime);
plot(cghip.Time(idx), cghip.mag(idx));
title(['CG Hip']);