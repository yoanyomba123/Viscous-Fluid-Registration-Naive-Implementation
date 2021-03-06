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

% Source = addLandmark(Source, 1);
Source(140:200, 240:300) = 0;
Source = Source(:,:,1);

Source = imrotate(Source,-60,'bilinear','crop'); % rotate the template image

% display and visualize both images
figure; imagesc([Template, Source]); colormap gray;

% display and visualize difference between both images
figure; imshowpair(Template, Source);


% obtain MSE between images prior to registration
msePreReg = imageMSE(Template, Source);

% Workspace Setup
numpoints = 100;
iter = 500;
mu = 10; lambda = 10;

% tolerance definition
tolerance = struct();
tolerance.deformationTolerance = 50;
tolerance.jacobianTolerance = 0.5;
tolerance.distanceTolerance = 1e-5;

% setup workspace environment
setupWorkSpace(Template, Source, numpoints, iter, mu, lambda, tolerance.deformationTolerance, tolerance.jacobianTolerance, tolerance.distanceTolerance);

% load workspace variables
load("variables.mat");

% plot discretized grid
plot(X,Y,'*r');hold on;grid on
% figure; quiver(X(1:end-2, 1:end-1),Y(1:end-2,1:end-1),Vx,Vy');

%% Start Implementation
i = 1;

% Obtain Initial Interpolated Template
[interpT, U] = performLinearInterpolation(Template,Source,U,gridObject);

% Define The Jacobian Matrix
Jacobian = zeros(length(x), length(y));

numRegrids = 0;

dmin = immse(Template, Source);

initialMSE = 1;

while i < iter
    % store prior tolerance value for optimization
    deformationDistTolprevious = tolerance.deformationTolerance;
    
    % Minimization is performed in the forcefield function
    force = computeForceFieldJacMaps(Template, Source, U, gridObject);
    visualize(force.x, force.y, gridObject.grid.x, gridObject.grid.y, gridObject.sampleTemplate);

    % evaluate the velocity vector fields by solving the linear discretized
    % PDE
    V = computeVelocityVectorFields(stencil, force, gridObject);
    
    % compute the pertubation of the displacement field
    [perturbation, delta] = computePertubation(gridObject, U, V, tolerance);    
    
    U.x = U.x + (delta .* perturbation.x); 
    U.y = U.y + (delta .* perturbation.y);
    
    currentMSE = immse(Template, Source);
    if(i > 1)
       if norm((Source - Template) - (Source  - Template),2) <=  norm((Source  - Template) .* tolerance.distanceTolerance,2)
            return;
       end
    end
    
     % terminating condition (Max iteration reached or mse tolerance 
    mseRateOfChange = abs((currentMSE - initialMSE)/(initialMSE))
    if i > maxIter | mseRateOfChange <= tolerance.mse
       return
    end
    i = i + 1;
    if i > iter
       return 
    end
    
end

%% Warp The Image
TemplateOut = 0;
for d = 1: length(U.x)
    for j = 1: length(U.y)
        if(x(d) - U.x(d, j)) <= length(Template) & (y(j) - U.y(d, j)) <= length(Template) & (x(d) -  U.x(d, j)) > 0 & (y(j) - U.y(d, j)) > 0
            TemplateOut(ceil(x(d) -  U.x(d, j)),ceil(y(j) -  U.y(d, j))) =  Source(x(d),y(j)); 
            SourceOut(x(d), y(j)) = Source(x(d), y(j));
        end
    end
end

% plot the outputed image
figure; imagesc([Template, Source]); title("Template vs Source"); colormap gray
figure; imagesc(TemplateOut); colormap gray; title("Transformed Image");
figure; imshowpair(TemplateOut, Source); colormap gray; title("Transformed Image vs Source");
figure; imshowpair(TemplateOut, Template); colormap gray; title("Transformed Template vs Template")

% compute the mse of the deformed template post registration
msePostReg = imageMSE(TemplateOut, Source);

%% Sample Test
% compute image difference between 2 images
imDiff = imageIntensityDiff(TemplateOut, Source);
figure; imagesc(imDiff);