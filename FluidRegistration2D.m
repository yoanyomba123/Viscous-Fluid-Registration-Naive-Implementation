%% Viscous Fluid Image Registrion
% Author: D Yoan L. Mekontchou Yomba
% Date: 11/16/2018
% Purpose:  
%   The purpose of this script is to implement a fluid registration model
%   in matlab. The Registration model makes use of the Eularian reference
%   frame and uses the sum of square difference as a cost function.

% Clear Up Workspace
clc; clear; close all;

% Add all paths to current workspace recursively
currentFolder = pwd;
addpath(genpath(currentFolder));

%% Load In Images Into Workspace
[Template, Source] = loadImages("Data");

Template = mat2gray(Template);
Source = mat2gray(Source);

Template = imrotate(Template,-15,'bilinear','crop');
%Template  =  imrotate(Source,-1,'bilinear','crop');
templateSourceDiff = Template - Source;

% display and visualize both images
figure; imshow([Template, Source]);

% display and visualize difference between both images
% figure; imshowpair(Template, Source, "diff");

%% Define Initial Conditions 

% params
params = struct();
params.mu = 1;
params.lambda = 1;

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
tolerance.deformationTolerance = 0.5;
tolerance.jacobainTolerance = 0.025;
tolerance.distanceTolerance = 1e-5;

maxIter = 2;

% grid definition
[rows, cols] = size(Template);
gridObject = struct();
gridObject.numXPoints = 100;
gridObject.numYPoints = 100;
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
gridObject.dx = ceil(gridObject.rows/gridObject.numXPoints);
gridObject.dy = ceil(gridObject.cols/gridObject.numYPoints);

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
wRegrid.x = zeros(gridObject.numXPoints, gridObject.numYPoints);
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
%% Obtain True Template
for i = 2:length(x)
    for j = 2:length(y)
        sampleTemplate(i,j) = Template(x(i), y(j));
        sampleSource(i,j) = Source(x(i), y(j));
    end
end
gridObject.sampleTemplate = sampleTemplate;
gridObject.sampleSource = sampleSource;
figure; imshow([Template, Source]);
title("Template (Rotated) | Source")
% figure; imagesc([sampleSource]);
% title("Source Image");
% figure; imagesc([sampleTemplate]);
% title("Template Image");
%% Algorithm
wk = struct();
displacementVector = cell(1, maxIter);
for i = 1:1;
    % perform 2D interpolation
    % turn this into a function
    wRegrid.x = interp2(yQ{regridCounter}.x, gridObject.grid.x - U.x);
    wRegrid.y = interp2(yQ{regridCounter}.y, gridObject.grid.y - U.y);
    wK{i} = wRegrid;
    
    % turn this into a function
    tRegrid.x = interp2(Template, gridObject.grid.x - wRegrid.x - U.x);
    tRegrid.y = interp2(Template, gridObject.grid.y - wRegrid.y - U.y);
    tK{i} = tRegrid;
    
    if(i > 1)
       if((Source - tK{i-1}.x) <=  (Source - tK{i}.x).*tolerance.distanceTolerance & ...
               (Source - tK{i-1}.x) <=  (Source - tK{i}.x).*tolerance.distanceTolerance)
            exit;
       end
    end
    
    % make a change here and pass in tK{i} instead
    % TODO NEED TO FIX THIS
    force = forceField(tK{i}, Source, U, gridObject, "none");
    
    drawnow
    % visualize the force field on the image
    visualize(force.x, force.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    disp("Displaying force fields");
    pause(1);
    
    % obtain V
    % Turn this into a function
    Sx = stencil.S11 + stencil.S12;
    Sy = stencil.S21 + stencil.S22;
    
    A.x = conv2(gridObject.sampleTemplate, Sx, 'same');
    A.y = conv2(gridObject.sampleTemplate, Sy, 'same');
    A.FFTx = real(fftMatOperator .* A.x .* fftMatInvOperator);
    A.FFTy = real(fftMatOperator .* A.y .* fftMatInvOperator);
    
    Dx = pinv(A.FFTx);
    Dy = pinv(A.FFTy);
    
    V.x = Dx .* force.x;
    V.y = Dy .* force.y;
    % visualize the velocity field on the image
    visualize(V.x, V.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    disp("Displaying Velocity Vector fields");
    pause(1);
    
    U = computePertubationAndUpdateDisplacement(gridObject, U, V, tolerance);
%     displacementVector{i} = U;
%     
%     [Jacobianx, Jacobiany] = gradient(U.x*1000);
%     [Jacobianyx, Jacobianyy] = gradient(U.y*1000);
%     Jacobian.x = Jacobianx;
%     Jacobian.y = Jacobiany;
%     minJacobian = min(det(Jacobian.x), det(Jacobian.y));
%     
%     if(abs(minJacobian) < tolerance.jacobainTolerance)
%         regridCounter = regridCounter+1;
%         regridEntity = struct();
%         regridEntity.x = wK{i}.x + U.x;
%         regridEntity.y = wK{i}.y + U.y;
%         yQ{regridCounter} = regridEntity;
%         U.x = U.x .* 0;
%         U.y = U.y .* 0;
%     else
%         deltaU.x = Jacobian.x .* V.x;
%         deltaU.y = Jacobian.y .* V.y;
%         % TODO LOOK INTO THIS
%         delta = max(max(max(deltaU.x)), max(max(deltaU.y)));
%         deltaT = min(1, tolerance.deformationTolerance/delta);
%         U.x = U.x + deltaT .* deltaU.x;
%         U.y = U.y + deltaT .* deltaU.y;
%     end
    visualize(U.x, U.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);
    disp("Displaying Displacement Vector fields");
    pause(1);
    
end
%%
U.x = (wK{i}.x + real(U.x));
U.y = wK{i}.y + real(U.y);

displacement(:,:,1) = U.x;
displacement(:,:,2) = U.y;

output = imwarp(sampleTemplate, displacement);
figure; imshow([output,sampleTemplate]);
title("Registered Image vs Template");

figure; imshowpair(output, sampleSource,"ColorChannels", 'red-cyan');
title("difference between the Registered Image amd Source");

figure; imshowpair(output, sampleTemplate,"ColorChannels", 'red-cyan');
title("difference between the Output Image amd Template");


RegisteredImage = zeros(length(U.x), length(U.y));

for i = 1: length(U.x)
    for j =1: length(U.y)     
        x_hat = U.x(i,j);
        y_hat = U.y(i,j);
        x_def = ceil(i + x_hat);
        y_def = ceil(j + y_hat);
        if(x_def > 0 && y_def > 0)
           RegisteredImage(x_def, y_def) = sampleTemplate(i,j);
        end
    end
end

RegisteredImage = RegisteredImage(1:end-1,1:end-1);
figure; imagesc(RegisteredImage);
figure; imagesc(sampleTemplate);



% figure; imagesc([RegisteredImage sampleTemplate]);
% figure; imshowpair(RegisteredImage, sampleSource,'ColorChannels','red-cyan');
figure; imshowpair(RegisteredImage, sampleTemplate,'ColorChannels','red-cyan');

% tOut(:,:,1) = interp2(Template,  gridObject.grid.x - U.x);
% tOut(:,:,2) = interp2(Template, gridObject.grid.y - U.y);
% 
% for i = 2: length(U.x)
%     for j = 2: length(U.y);
%         output(i, j) = Template(x(i), y(j)) + U.x(i, j)+ U.y(i, j) ;
%     end
% end
