%% Viscous Fluid Image Registrion
% Author: D Yoan L. Mekontchou Yomba
% Date: 11/16/2018
% Purpose:  
%   The purpose of this script is to implement a fluid registration model
%   in matlab. The Registration model makes use of  the Eularian reference
%   frame and uses the sum of square difference as a cost function.
%% Clear Up Workspace
clc; clear; close all;

%% Add all paths to current workspace recursively

currentFolder = pwd;
addpath(genpath(currentFolder));

%% Load In Images Into Workspace
[Template, Source] = loadImages("Data");

Template =  Template;
Source =  Source;

% Source = addLandmark(Source, 1);
Source(180:200, 280:300) = 0;
Source = Source(:,:,1);

Template = imrotate(Source,-60,'bilinear','crop'); % rotate the template image

% display and visualize both images
figure; imagesc([Template, Source]); colormap gray;

% display and visualize difference between both images
 figure; imshowpair(Template, Source);
maxdiff = max(max(Template - Source));

%% Workspace Setup
numpoints = 200;
iter = 200;
mu = 400; lambda = 400;

% tolerance definition
tolerance = struct();
tolerance.deformationTolerance = 50;
tolerance.jacobianTolerance = 0.05;
tolerance.distanceTolerance = 0.01;

% setup workspace environment
setupWorkSpace(Template, Source, numpoints, iter, mu, lambda, tolerance.deformationTolerance, tolerance.jacobianTolerance, tolerance.distanceTolerance);

% load workspace variables
load("variables.mat");

%% Start Implementation
while 1
    % store prior tolerance value for optimization
    deformationDistTolprevious = tolerance.deformationTolerance;
    
    % perform 2D interpolation
    % turn this into a function
    wRegrid.x = interpn(yQ{regridCounter}.x,gridObject.grid.x - U.x,'linear');
    wRegrid.y =  interpn(yQ{regridCounter}.y,gridObject.grid.y - U.y,'linear');
    wK{i} = wRegrid;
    
    tRegrid.x = X - wRegrid.x - U.x;
    tRegrid.y = Y - wRegrid.y - U.y;
    [tK{i}, U] = performLinearInterpolation(Template,tRegrid,U,gridObject);

    % Minimization is performed in the forcefield function
end
%% TODO
% TODO
% ---------------------------------------------
% TIPS - After Each Function Created, Make Sure To Test For EFFICACY

% enter into while loop to perform registration
%   - write another force field computation function using Jacobian Maps


%% Define Initial Conditions 

% params
params = struct();
params.mu = 200;
params.lambda = 400;

% define stencils
stencil = struct();
stencil.S11 = [0, (params.lambda + 2*params.mu), 0;
       params.mu, -2*(params.lambda + 3*params.mu), params.mu;
       0, (params.lambda+2*params.mu), 0 ];
stencil.S12 = [1, 0, -1;
       0, 0 ,0;
       -1, 0, 1] .* ((params.lambda + params.mu)/4);
stencil.S22 = stencil.S11';
stencil.S21 = stencil.S12';

% tolerance definition
tolerance = struct();
tolerance.deformationTolerance = 50;
tolerance.jacobianTolerance = 0.05;
tolerance.distanceTolerance = 0.01;
tolerance.mse = 1e-13;

% max iteration terminating condition
maxIter = 210;

% grid definition
[rows, cols] = size(Template);
gridObject = struct();
gridObject.numXPoints = 200;
gridObject.numYPoints = 200;
gridObject.grid = struct();

% generate points that are not on the boundary of the image
x = linspace(0, rows-2, gridObject.numXPoints); x = ceil(x);
y = linspace(0, cols-2, gridObject.numYPoints); y = ceil(y);
[X,Y] = meshgrid(x, y);
gridObject.rows = rows;
gridObject.cols = cols;
gridObject.x = x;
gridObject.y = y;
gridObject.grid.x = X;
gridObject.grid.y = Y;
gridObject.width = 1;
gridObject.dx = 1*ceil(gridObject.rows/gridObject.numXPoints);
gridObject.dy = 1*ceil(gridObject.cols/gridObject.numYPoints);

% initilaze displacement field
U = struct();
U.x = zeros(gridObject.numXPoints, gridObject.numYPoints);
U.y = zeros(gridObject.numXPoints, gridObject.numYPoints);

% initialze regrid components
structVals = {'x', 'y', 'template'};
yQ = cell(1, maxIter);
yRegrid = struct();
yRegrid.x = zeros(gridObject.numXPoints, gridObject.numYPoints);
yRegrid.y = zeros(gridObject.numXPoints, gridObject.numYPoints);
yRegrid.template = [];
regridCounter = 1;
yQ{regridCounter} = yRegrid;

tK = cell(1, maxIter);
tRegrid = struct();
tRegrid.x = zeros(gridObject.numXPoints, gridObject.numYPoints);
tRegrid.y = zeros(gridObject.numXPoints, gridObject.numYPoints);

wK = cell(1, maxIter);
wRegrid = struct();
wRegrid.x = zeros(grifdObject.numXPoints, gridObject.numYPoints);
wRegrid.y = zeros(gridObject.numXPoints, gridObject.numYPoints);

% central Diffence Matrix Operator
centralDiffMatOperator = full(gallery('tridiag', length(gridObject.x), -1,2, -1));

% define fourier matrix and inverse fourier matrix operator
fftMatOperator = dftmtx(gridObject.numXPoints);
fftMatInvOperator = inv(fftMatOperator);

A = struct();
V = struct();
Jacobian = struct();
deltalU = struct();

% Obtain Template and Source Based On Grid Point Definitions 
gridObject.sampleTemplate = generateTrueGridImage(gridObject.x, gridObject.y, Template);
gridObject.sampleSource = generateTrueGridImage(gridObject.x, gridObject.y, Source);


wk = struct();
displacementVector = cell(1, maxIter);
x = x + 1;
y = y + 1;
TemplateSet = cell(1, maxIter);
%%
figure;
priorDelta = 0;
i = 1;
initialMSE = 1;
while 1;
    % store prior tolerance value for optimization
    deformationDistTolprevious = tolerance.deformationTolerance;
    
    % perform 2D interpolation
    % turn this into a function
    wRegrid.x = interpn(yQ{regridCounter}.x,gridObject.grid.x - U.x,'linear');
    wRegrid.y =  interpn(yQ{regridCounter}.y,gridObject.grid.y - U.y,'linear');
    wK{i} = wRegrid;
    
    tRegrid.x = X - wRegrid.x - U.x;
    tRegrid.y = Y - wRegrid.y - U.y;
    [tK{i}, U] = performLinearInterpolation(Template,tRegrid,U,gridObject);

    % Minimization is performed in the forcefield function
    force = forceField(tK{i}, Source, U, gridObject, "none");
    
    drawnow
    % visualize the force field on the image
    visualize(force.x, force.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    disp("Displaying force fields");
    pause(2);
   
    % obtain V
    % Turn this into a function
    Sx = stencil.S11 + stencil.S12;
    Sy = stencil.S21 + stencil.S22;
    
    A.x = conv2(gridObject.sampleTemplate, Sx, 'same');
    A.y = conv2(gridObject.sampleTemplate, Sy, 'same');
    A.FFTx = real(fft2(A.x));%real(fftMatOperator .* A.x .* fftMatInvOperator);
    A.FFTy = real(fft2(A.y)); %real(fftMatOperator .* A.y .* fftMatInvOperator);
    
    Dx = pinv(A.FFTx);
    Dy = pinv(A.FFTy);
    
    V.x = (Dx) .* force.x;
    V.y = (Dy) .* force.y;
    V = applyBC(V);

    % visualize the velocity field on the image
    %visualize(V.x, V.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    %disp("Displaying Velocity Vector fields");
    %pause(2);
 
   [perturbation, delta] = computePertubation(gridObject, U, V, tolerance);
   
   regridBool = computeJacobian(gridObject, U, delta, pertubation, tolerance);
   if regridBool == "false" || i == 1
        U.x = U.x + (pertubation.x .* delta);
        U.y = U.y + (pertubation.y .* delta);
   else
        singularityCount = 0;
        while regridBool == "True"
           [regridCounter, wK, U, yQ, tK, pertubation, delta, iteration] = perfromRegridding(gridObject, regridBool, regridCounter, wK, U, yQ, tK, pertubation, delta, i, Template);
           [pertubation, delta] = computePertubationAndUpdateDisplacement(gridObject, U, V, tolerance, regridCounter, wK, yQ, tK, i);
           regridBool = computeJacobian(gridObject, U, delta, pertubation, tolerance);
           singularityCount = singularityCount + 1;
           
           if(singularityCount > 5)
               break;
           end
        end
    end
  
    %visualize(U.x, U.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    %disp("Displaying Displacement Vector fields");
    %pause(2);
    
    currentMSE = immse(tK{i}, Source);
    if(i > 1)
       if norm((Source - tK{i-1}) - (Source  - tK{i}),2) <=  norm((Source  - tK{i}) .* tolerance.distanceTolerance,2)
            return;
       end
    end
    
     % terminating condition (Max iteration reached or mse tolerance 
    mseRateOfChange = abs((currentMSE - initialMSE)/(initialMSE))
    if i > maxIter | mseRateOfChange <= tolerance.mse
       return
    end
    
    initialMSE = currentMSE;
    i = i +1;
end
%% Warp The Image
TemplateOut = 0;
for d = 1: length(U.x)
    for j = 1: length(U.y)
        if(x(d) - U.x(d, j)) <= length(Template) & (y(j) - U.y(d, j)) <= length(Template) & (x(d) -  U.x(d, j)) > 0 & (y(j) - U.y(d, j)) > 0
            TemplateOut(x(d),y(j)) = Source(ceil(x(d) -  U.x(d, j)),ceil(y(j) -  U.y(d, j))); 
            SourceOut(x(d), y(j)) = Source(x(d), y(j));
        end
    end
end

% plot the outputed image

figure; imagesc([Template, Source]); title("Template vs Source"); colormap gray
figure; imagesc(TemplateOut); colormap gray; title("Transformed Image");
figure; imshowpair(TemplateOut, Source); colormap gray; title("Transformed Image vs Source");
figure; imshowpair(TemplateOut, Template); colormap gray; title("Transformed Template vs Template")