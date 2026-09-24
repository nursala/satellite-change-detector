classdef AlignmentApp < matlab.apps.AppBase
    % Properties
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        GridLayout           matlab.ui.container.GridLayout
        LeftPanel            matlab.ui.container.Panel
        RightPanel           matlab.ui.container.Panel
        
        % Data Source Buttons
        btnLoadRef           matlab.ui.control.Button
        btnLoadMov           matlab.ui.control.Button
        
        % Example Controls
        lblSelectEx          matlab.ui.control.Label
        ddlExamples          matlab.ui.control.DropDown
        
        % Action Buttons
        btnRunAuto           matlab.ui.control.Button
        btnDetectChange      matlab.ui.control.Button
        
        % Status
        lblStatus            matlab.ui.control.Label
        
        % 4 Axes for Visualization
        AxRef                matlab.ui.control.UIAxes
        AxAligned            matlab.ui.control.UIAxes
        AxDiff               matlab.ui.control.UIAxes 
        AxResult             matlab.ui.control.UIAxes
        
        % Data Variables
        ImgRef               
        ImgMov               
        ImgAligned           
    end

    methods (Access = private)
        % -----------------------------------------------------------------
        % HELPER: Setup Axes
        % -----------------------------------------------------------------
        function setupAxis(~, ax, titleText)
            title(ax, titleText, 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');
            ax.XColor = 'none'; 
            ax.YColor = 'none';
            ax.Color = [0.1 0.1 0.1]; 
            ax.XTick = [];
            ax.YTick = [];
        end

        % -----------------------------------------------------------------
        % 1. LOAD SELECTED EXAMPLE
        % -----------------------------------------------------------------
        function loadExampleData(app, ~, ~)
            selectedEx = app.ddlExamples.Value;
            
            % Do nothing if the default placeholder is selected
            if strcmp(selectedEx, '- Select Example -')
                app.lblStatus.Text = 'Status: Ready';
                return;
            end
            
            app.lblStatus.Text = ['Status: Loading ' selectedEx '...'];
            drawnow;
            
            try
                refName = ''; movName = '';
                switch selectedEx
                    case 'Desert - Case 1'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov1.jpg';
                    case 'Desert - Case 2'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov2.jpg';
                    case 'Desert - Case 3'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov3.jpg';
                    case 'Desert - Case 4'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov4.jpg';
                    case 'Desert - Case 5'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov5.jpg';
                    case 'Desert - Case 6'
                        refName = 'Desert_Ref.jpg'; movName = 'Desert_Mov6.jpg';
                end
                
                % Check if files exist before loading
                if exist(refName, 'file') && exist(movName, 'file')
                    app.ImgRef = imread(refName);
                    app.ImgMov = imread(movName);
                else
                    errMsg = sprintf('Cannot find the following files in the current folder:\n\n1. %s\n2. %s\n\nPlease make sure they are placed correctly.', refName, movName);
                    uialert(app.UIFigure, errMsg, 'Files Missing');
                    app.lblStatus.Text = 'Status: Load Aborted.';
                    
                    % Reset dropdown to default if files are missing
                    app.ddlExamples.Value = '- Select Example -';
                    return; 
                end
                
                app.ImgAligned = [];
                cla(app.AxRef); imshow(app.ImgRef, 'Parent', app.AxRef);
                cla(app.AxAligned); imshow(app.ImgMov, 'Parent', app.AxAligned);
                title(app.AxAligned, 'Input (Un-aligned)', 'Color', 'w');
                cla(app.AxDiff); cla(app.AxResult);
                app.lblStatus.Text = ['Status: ' selectedEx ' Loaded.'];
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        % -----------------------------------------------------------------
        % 2. AUTO ALIGNMENT
        % -----------------------------------------------------------------
        function runAutoAlignment(app, ~, ~)
            if isempty(app.ImgRef) || isempty(app.ImgMov)
                uialert(app.UIFigure, 'Please load images first.', 'Error');
                return;
            end
            
            app.lblStatus.Text = 'Status: Aligning...';
            drawnow;
            
            try
                % Convert to grayscale for feature extraction algorithms
                if size(app.ImgRef, 3) == 3
                    grayRef = rgb2gray(app.ImgRef); 
                else
                    grayRef = app.ImgRef; 
                end
                
                if size(app.ImgMov, 3) == 3
                    grayMov = rgb2gray(app.ImgMov); 
                else
                    grayMov = app.ImgMov; 
                end
                
                % Step 1: Feature-based alignment using SURF
                ptsRef = detectSURFFeatures(grayRef, 'MetricThreshold', 500);
                ptsMov = detectSURFFeatures(grayMov, 'MetricThreshold', 500);
                [featuresRef, validPtsRef] = extractFeatures(grayRef, ptsRef);
                [featuresMov, validPtsMov] = extractFeatures(grayMov, ptsMov);
                
                % Match extracted features between the two images
                indexPairs = matchFeatures(featuresRef, featuresMov, 'Unique', true, 'MatchThreshold', 10.0);
                matchedRef = validPtsRef(indexPairs(:, 1));
                matchedMov = validPtsMov(indexPairs(:, 2));
                
                % Apply geometric transformation if enough matches are found
                if matchedRef.Count >= 5
                    [tform, ~, ~] = estimateGeometricTransform2D(matchedMov, matchedRef, 'projective', 'MaxNumTrials', 2000);
                    app.ImgAligned = imwarp(app.ImgMov, tform, 'OutputView', imref2d(size(app.ImgRef(:,:,1))), 'FillValues', 0);
                    app.lblStatus.Text = 'Status: Aligned (Features).';
                else
                    % Step 2: Fallback to Intensity-based registration
                    [optimizer, metric] = imregconfig('multimodal');
                    optimizer.MaximumIterations = 300;
                    tform = imregtform(grayMov, grayRef, 'affine', optimizer, metric);
                    app.ImgAligned = imwarp(app.ImgMov, tform, 'OutputView', imref2d(size(app.ImgRef(:,:,1))), 'FillValues', 0);
                    app.lblStatus.Text = 'Status: Aligned (Intensity).';
                end
                
                imshow(app.ImgAligned, 'Parent', app.AxAligned);
                title(app.AxAligned, 'After Alignment', 'Color', 'w');
                linkaxes([app.AxRef, app.AxAligned, app.AxResult], 'xy');
                
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        % -----------------------------------------------------------------
        % 3. CHANGE DETECTION (HIGH PRECISION)
        % -----------------------------------------------------------------
        function detectChanges(app, ~, ~)
            if isempty(app.ImgRef) || isempty(app.ImgAligned)
                uialert(app.UIFigure, 'Please align images first.', 'Warning');
                return;
            end
            
            app.lblStatus.Text = 'Status: Detecting...';
            drawnow;
            
            try
                if size(app.ImgRef, 3) == 3
                    I1 = im2double(rgb2gray(app.ImgRef));
                else
                    I1 = im2double(app.ImgRef);
                end
                
                if size(app.ImgAligned, 3) == 3
                    I2 = im2double(rgb2gray(app.ImgAligned));
                else
                    I2 = im2double(app.ImgAligned);
                end
                
                % Create a safe zone mask to ignore alignment borders (black edges)
                Mask1 = I1 > 0.01;
                Mask2 = I2 > 0.01;
                SafeZone = imerode(Mask1 & Mask2, strel('disk', 3)); 
                
                % Illumination matching and Gaussian smoothing to reduce noise
                I2_matched = imhistmatch(I2, I1);
                sigma = 2.0; 
                I1_s = imgaussfilt(I1, sigma);
                I2_s = imgaussfilt(I2_matched, sigma);
                
                % Structural Similarity Index (SSIM) for robust difference calculation
                [~, ssimMap] = ssim(I2_s, I1_s);
                Diff = max(0, 1 - ssimMap);
                Diff(~SafeZone) = 0; % Apply safe zone mask
                
                imshow(Diff, [], 'Parent', app.AxDiff);
                colormap(app.AxDiff, 'hot'); 
                colorbar(app.AxDiff, 'Color', 'w');
                title(app.AxDiff, 'Difference Heatmap', 'Color', 'w');
                
                % Thresholding and Morphological operations to clean up artifacts
                BW = Diff > 0.55;
                BW = bwareaopen(BW, 100);             % Remove small pixel noise
                BW = imopen(BW, strel('disk', 2));    % Detach loosely connected objects
                BW = imclose(BW, strel('disk', 4));   % Fill gaps in detected changes
                BW = bwareaopen(BW, 250);             % Final filter for significant changes
                
                % Extract bounding boxes for valid detected regions
                stats = regionprops(BW, 'BoundingBox');
                numChanges = numel(stats);
                
                % Overlay the results on the original reference image
                imshow(app.ImgRef, 'Parent', app.AxResult);
                hold(app.AxResult, 'on');
                greenChannel = cat(3, zeros(size(BW)), ones(size(BW)), zeros(size(BW)));
                h = imshow(greenChannel, 'Parent', app.AxResult);
                set(h, 'AlphaData', BW * 0.4); 
                
                for k = 1:numChanges
                    bb = stats(k).BoundingBox;
                    rectangle(app.AxResult, 'Position', bb, 'EdgeColor', 'r', 'LineWidth', 2);
                end
                hold(app.AxResult, 'off');
                
                title(app.AxResult, sprintf('Final Result: %d Changes', numChanges), 'Color', 'w');
                app.lblStatus.Text = sprintf('Status: Found %d changes.', numChanges);
                
                linkaxes([app.AxRef, app.AxAligned, app.AxResult], 'xy');
                
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        % -----------------------------------------------------------------
        % Callbacks
        % -----------------------------------------------------------------
        function onLoadRef(app, ~, ~)
            [file, path] = uigetfile({'*.jpg;*.png;*.tif', 'Images'});
            if isequal(file, 0), return; end
            linkaxes([app.AxRef, app.AxAligned, app.AxResult], 'off');
            app.ImgRef = imread(fullfile(path, file));
            cla(app.AxRef); imshow(app.ImgRef, 'Parent', app.AxRef);
            
            % Reset dropdown if manual load is used
            app.ddlExamples.Value = '- Select Example -';
            app.lblStatus.Text = 'Status: Ref Loaded.';
        end

        function onLoadMov(app, ~, ~)
            [file, path] = uigetfile({'*.jpg;*.png;*.tif', 'Images'});
            if isequal(file, 0), return; end
            linkaxes([app.AxRef, app.AxAligned, app.AxResult], 'off');
            app.ImgMov = imread(fullfile(path, file));
            cla(app.AxAligned); imshow(app.ImgMov, 'Parent', app.AxAligned);
            title(app.AxAligned, 'Input (Before Align)', 'Color', 'w');
            app.ImgAligned = []; 
            
            % Reset dropdown if manual load is used
            app.ddlExamples.Value = '- Select Example -';
            app.lblStatus.Text = 'Status: Input Loaded.';
        end
    end

    % ---------------------------------------------------------------------
    % App Initialization
    % ---------------------------------------------------------------------
    methods (Access = public)
        function app = AlignmentApp
            app.UIFigure = uifigure('Name', 'Change Detector', 'Position', [100 100 1250 750]);
            app.UIFigure.Color = [0.15 0.15 0.15];
            
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {270, '1x'}; 
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.BackgroundColor = [0.15 0.15 0.15];
            
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.Title = 'CONTROLS';
            app.LeftPanel.TitlePosition = 'centertop';
            app.LeftPanel.FontSize = 14;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.BackgroundColor = [0.2 0.2 0.2];
            app.LeftPanel.ForegroundColor = [1 1 1];
            
            lpGrid = uigridlayout(app.LeftPanel, [10, 1]); 
            lpGrid.RowHeight = {40, 40, 20, 25, 30, 20, 50, 20, 50, '1x'};
            lpGrid.BackgroundColor = [0.2 0.2 0.2];
            
            btnBg = [0.3 0.3 0.3];
            btnTxt = [1 1 1];
            
            app.btnLoadRef = uibutton(lpGrid, 'Text', '1. Load Reference');
            app.btnLoadRef.Layout.Row = 1; app.btnLoadRef.BackgroundColor = btnBg; app.btnLoadRef.FontColor = btnTxt;
            app.btnLoadRef.ButtonPushedFcn = @app.onLoadRef;
            
            app.btnLoadMov = uibutton(lpGrid, 'Text', '2. Load Input');
            app.btnLoadMov.Layout.Row = 2; app.btnLoadMov.BackgroundColor = btnBg; app.btnLoadMov.FontColor = btnTxt;
            app.btnLoadMov.ButtonPushedFcn = @app.onLoadMov;
            
            l1 = uilabel(lpGrid); l1.Text = '______________________'; l1.Layout.Row = 3; l1.FontColor = 'w'; l1.HorizontalAlignment = 'center';
            
            lblEx = uilabel(lpGrid); lblEx.Text = 'Select Example:'; lblEx.FontColor = 'w'; lblEx.Layout.Row = 4;
            app.ddlExamples = uidropdown(lpGrid);
            
            % Added placeholder at the beginning
            app.ddlExamples.Items = { ...
                '- Select Example -', ...
                'Desert - Case 1', 'Desert - Case 2', 'Desert - Case 3', ...
                'Desert - Case 4', 'Desert - Case 5', 'Desert - Case 6'};
            app.ddlExamples.Value = '- Select Example -';
            app.ddlExamples.Layout.Row = 5;
            app.ddlExamples.ValueChangedFcn = @app.loadExampleData;
            
            l2 = uilabel(lpGrid); l2.Text = ''; l2.Layout.Row = 6;
            
            app.btnRunAuto = uibutton(lpGrid, 'Text', 'RUN AUTO ALIGN');
            app.btnRunAuto.Layout.Row = 7; app.btnRunAuto.BackgroundColor = [0.0 0.5 0.8]; app.btnRunAuto.FontColor = 'w'; app.btnRunAuto.FontSize = 16; app.btnRunAuto.FontWeight = 'bold';
            app.btnRunAuto.ButtonPushedFcn = @app.runAutoAlignment;
            
            l3 = uilabel(lpGrid); l3.Text = ''; l3.Layout.Row = 8;
            
            app.btnDetectChange = uibutton(lpGrid, 'Text', 'DETECT CHANGES');
            app.btnDetectChange.Layout.Row = 9; app.btnDetectChange.BackgroundColor = [0.2 0.7 0.3]; app.btnDetectChange.FontColor = 'w'; app.btnDetectChange.FontSize = 16; app.btnDetectChange.FontWeight = 'bold';
            app.btnDetectChange.ButtonPushedFcn = @app.detectChanges;
            
            app.lblStatus = uilabel(lpGrid, 'Text', 'Status: Ready');
            app.lblStatus.Layout.Row = 10; app.lblStatus.VerticalAlignment = 'bottom'; app.lblStatus.FontColor = 'w'; app.lblStatus.FontWeight = 'bold';
            
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1; app.RightPanel.Layout.Column = 2;
            app.RightPanel.BackgroundColor = [0.15 0.15 0.15]; app.RightPanel.BorderType = 'none';
            
            rpGrid = uigridlayout(app.RightPanel, [2, 2]);
            rpGrid.BackgroundColor = [0.15 0.15 0.15];
            rpGrid.RowSpacing = 10; rpGrid.ColumnSpacing = 10;
            
            app.AxRef = uiaxes(rpGrid); app.AxRef.Layout.Row = 1; app.AxRef.Layout.Column = 1; app.setupAxis(app.AxRef, 'Reference (Before)');
            app.AxAligned = uiaxes(rpGrid); app.AxAligned.Layout.Row = 1; app.AxAligned.Layout.Column = 2; app.setupAxis(app.AxAligned, 'Input / Aligned');
            app.AxDiff = uiaxes(rpGrid); app.AxDiff.Layout.Row = 2; app.AxDiff.Layout.Column = 1; app.setupAxis(app.AxDiff, 'Difference Heatmap');
            app.AxResult = uiaxes(rpGrid); app.AxResult.Layout.Row = 2; app.AxResult.Layout.Column = 2; app.setupAxis(app.AxResult, 'Final Detection Result');
        end
    end
end