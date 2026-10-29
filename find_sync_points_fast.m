%% SET THE PARTICIPANT AND EXPECTED SYNC POINT TIME
ppt = "62";
targetTime = datetime("2026-09-23 12:25:00", "InputFormat", "yyyy-MM-dd HH:mm:ss");

halfWindow = minutes(8);
startTime  = targetTime - halfWindow;
endTime    = targetTime + halfWindow;

%% Read only the target time window using byte-offset binary search
leftankle  = read_time_window(strcat(ppt, "_LA.csv"), startTime, endTime);
rightankle = read_time_window(strcat(ppt, "_RA.csv"), startTime, endTime);
lefthip    = read_time_window(strcat(ppt, "_LH.csv"), startTime, endTime);
righthip   = read_time_window(strcat(ppt, "_RH.csv"), startTime, endTime);

% Uncomment if caregiver sensors are present:
% cgwrist  = read_time_window(strcat(ppt, "_CW.csv"), startTime, endTime);
% cghip    = read_time_window(strcat(ppt, "_CH.csv"), startTime, endTime);

%% Plot each sensor
figure;
plot(leftankle.Time, leftankle.mag);
title('Left Ankle');
xlabel('Time'); ylabel('Magnitude (g)');

figure;
plot(rightankle.Time, rightankle.mag);
title('Right Ankle');
xlabel('Time'); ylabel('Magnitude (g)');

figure;
plot(lefthip.Time, lefthip.mag);
title('Left Hip');
xlabel('Time'); ylabel('Magnitude (g)');

figure;
plot(righthip.Time, righthip.mag);
title('Right Hip');
xlabel('Time'); ylabel('Magnitude (g)');

% figure;
% plot(cgwrist.Time, cgwrist.mag);
% title('CG Wrist');
% xlabel('Time'); ylabel('Magnitude (g)');
%
% figure;
% plot(cghip.Time, cghip.mag);
% title('CG Hip');
% xlabel('Time'); ylabel('Magnitude (g)');

%% Local Helper Functions
function T = read_time_window(filename, startTime, endTime)
    % Format target timestamps to match the CSV ISO-8601 format
    startStr = string(datetime(startTime, "Format", "yyyy-MM-dd HH:mm:ss.SSS"));
    endStr   = string(datetime(endTime,   "Format", "yyyy-MM-dd HH:mm:ss.SSS"));

    fid = fopen(filename, 'r');
    if fid == -1
        error("Could not open file: %s", filename);
    end
    cleanup = onCleanup(@() fclose(fid));

    % Get total file size in bytes
    fseek(fid, 0, 'eof');
    fileSize = ftell(fid);

    % Binary search for the start and end byte offsets
    startByte = find_byte_offset(fid, fileSize, startStr);
    endByte   = find_byte_offset(fid, fileSize, endStr);

    if endByte <= startByte
        warning("No rows found in %s between %s and %s.", filename, startStr, endStr);
        T = table('Size', [0 5], ...
            'VariableTypes', ["datetime", "double", "double", "double", "double"], ...
            'VariableNames', ["Time", "X", "Y", "Z", "mag"]);
        return;
    end

    % Read only the bytes within [startByte, endByte]
    fseek(fid, startByte, 'bof');
    rawText = fread(fid, endByte - startByte, '*char')';

    % Parse Time, X, Y, Z and skip GX, GY, GZ (%*f)
    C = textscan(rawText, '%{yyyy-MM-dd HH:mm:ss.SSS}D %f %f %f %*f %*f %*f', ...
        'Delimiter', ',');

    % Handle potential trailing incomplete line
    n = min([ numel(C{1}), numel(C{2}), numel(C{3}), numel(C{4}) ]);
    T = table(C{1}(1:n), C{2}(1:n), C{3}(1:n), C{4}(1:n), ...
        'VariableNames', ["Time", "X", "Y", "Z"]);

    % Exact filter on the boundary rows and compute magnitude
    idx = (T.Time >= startTime) & (T.Time <= endTime);
    T = T(idx, :);
    T.mag = sqrt(T.X.^2 + T.Y.^2 + T.Z.^2);
end

function offset = find_byte_offset(fid, fileSize, targetTimeStr)
    low = 0;
    high = fileSize;

    % Binary search down to a ~2 KB bracket
    while (high - low) > 2048
        mid = floor((low + high) / 2);
        fseek(fid, mid, 'bof');
        if mid > 0
            fgetl(fid); % Discard partial line after seeking into the middle
        end
        pos = ftell(fid);
        line = fgetl(fid);

        if ischar(line) && length(line) >= 23
            ts = string(line(1:23));
            if ts < targetTimeStr
                low = pos;
            else
                high = mid;
            end
        else
            high = mid;
        end
    end

    % Align cleanly to the start of a line at `low`
    fseek(fid, low, 'bof');
    if low > 0
        fgetl(fid);
    end
    offset = ftell(fid);
end
