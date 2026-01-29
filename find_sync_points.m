%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 7);

% Specify range and delimiter
opts.DataLines = [1, 500000];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Time", "X", "Y", "Z", "GX", "GY", "GZ"];
opts.VariableTypes = ["datetime", "double", "double", "double", "double", "double", "double"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "Time", "InputFormat", "yyyy-MM-dd HH:mm:ss.SSS");

ppt = "01";

%%
% Import the LEFT ANKLE
leftankle = readtable(strcat(ppt,"/",ppt,"_left_ankle.csv"), opts);

close all
clf
tiledlayout(3,1)
% First plot
ax1 = nexttile;
plot(leftankle.Time, leftankle.X)
ax2 = nexttile;
plot(leftankle.Time, leftankle.Y)
ax3 = nexttile;
plot(leftankle.Time, leftankle.Z)
linkaxes([ax1 ax2 ax3],'x')
%%
% Import the LEFT HIP
lefthip = readtable(strcat(ppt,"/",ppt,"_left_hip.csv"), opts);

close all
clf
tiledlayout(3,1)
% First plot
ax1 = nexttile;
plot(lefthip.Time, lefthip.X)
ax2 = nexttile;
plot(lefthip.Time, lefthip.Y)
ax3 = nexttile;
plot(lefthip.Time, lefthip.Z)
linkaxes([ax1 ax2 ax3],'x')
%%
% Import the RIGHT ANKLE
rightankle = readtable(strcat(ppt,"/",ppt,"_right_ankle.csv"), opts);

close all
clf
tiledlayout(3,1)
% First plot
ax1 = nexttile;
plot(rightankle.Time, rightankle.X)
ax2 = nexttile;
plot(rightankle.Time, rightankle.Y)
ax3 = nexttile;
plot(rightankle.Time, rightankle.Z)
linkaxes([ax1 ax2 ax3],'x')
%%
% Import the RIGHT HIP
righthip = readtable(strcat(ppt,"/",ppt,"_right_hip.csv"), opts);

close all
clf
tiledlayout(3,1)
% First plot
ax1 = nexttile;
plot(righthip.Time, righthip.X)
ax2 = nexttile;
plot(righthip.Time, righthip.Y)
ax3 = nexttile;
plot(righthip.Time, righthip.Z)
linkaxes([ax1 ax2 ax3],'x')
