clear; clc; 
addpath("/if/research-gms/Chris/layoffs")

%% Load in Data

hazard_panel = readtable("hazard_panel.csv");
hazard_average = readtable("hazard.csv");

%% Plotting Figures

opt.rwkesr2 = {4}; % 3 or 4 
opt.prob_col = {'pR'}; % pR, pN, pE
opt.title_name = {'Panel B. Probability of Recall'};

figure(1);
clf;
% subplot(2,3,1)
figures.wave_probability_histogram(hazard_panel, hazard_average, opt.rwkesr2{1}, opt.prob_col{1}, opt.title_name{1})
