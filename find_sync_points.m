%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 7);

% Specify range and delimiter
opts.DataLines = [1, 8000000];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["Time", "X", "Y", "Z", "GX", "GY", "GZ"];
opts.VariableTypes = ["datetime", "double", "double", "double", "double", "double", "double"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "Time", "InputFormat", "yyyy-MM-dd HH:mm:ss.SSS");

ppt = "21";

%%
% Import the LEFT ANKLE
leftankle = readtable(strcat(ppt,"_LA.csv"), opts);
leftankle.mag = sqrt(leftankle.X.^2 + leftankle.Y.^2 + leftankle.Z.^2);
close all
clf
tiledlayout(4,1)
% First plot
ax1 = nexttile;
plot(leftankle.Time, leftankle.mag)
ax2 = nexttile;
plot(leftankle.Time, leftankle.X)
ax3 = nexttile;
plot(leftankle.Time, leftankle.Y)
ax4 = nexttile;
plot(leftankle.Time, leftankle.Z)
linkaxes([ax1 ax2 ax3 ax4],'x')
%%
% Import the RIGHT ANKLE
rightankle = readtable(strcat(ppt,"_RA.csv"), opts);
rightankle.mag = sqrt(rightankle.X.^2 + rightankle.Y.^2 + rightankle.Z.^2);

close all
clf
tiledlayout(4,1)
% First plot
ax1 = nexttile;
plot(rightankle.Time, rightankle.mag)
ax2 = nexttile;
plot(rightankle.Time, rightankle.X)
ax3 = nexttile;
plot(rightankle.Time, rightankle.Y)
ax4 = nexttile;
plot(rightankle.Time, rightankle.Z)
linkaxes([ax1 ax2 ax3 ax4],'x')
%%
% Import the LEFT HIP
lefthip = readtable(strcat(ppt,"_LH.csv"), opts);
lefthip.mag = sqrt(lefthip.X.^2 + lefthip.Y.^2 + lefthip.Z.^2);

close all
clf
tiledlayout(4,1)
% First plot
ax1 = nexttile;
plot(lefthip.Time, lefthip.mag)
ax2 = nexttile;
plot(lefthip.Time, lefthip.X)
ax3 = nexttile;
plot(lefthip.Time, lefthip.Y)
ax4 = nexttile;
plot(lefthip.Time, lefthip.Z)
linkaxes([ax1 ax2 ax3 ax4],'x')

%%
% Import the RIGHT HIP
righthip = readtable(strcat(ppt,"_RH.csv"), opts);
righthip.mag = sqrt(righthip.X.^2 + righthip.Y.^2 + righthip.Z.^2);

close all
clf
tiledlayout(4,1)
% First plot
ax1 = nexttile;
plot(righthip.Time, righthip.mag)
ax2 = nexttile;
plot(righthip.Time, righthip.X)
ax3 = nexttile;
plot(righthip.Time, righthip.Y)
ax4 = nexttile;
plot(righthip.Time, righthip.Z)
linkaxes([ax1 ax2 ax3 ax4],'x')
%%
% Import the CAREGIVER WRIST
lefthip = readtable(strcat(ppt,"_CW.csv"), opts);

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
% Import the CAREGIVER HIP
righthip = readtable(strcat(ppt,"_CH.csv"), opts);

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
