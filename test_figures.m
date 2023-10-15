clear; clc; 
%addpath("/if/research-gms/Chris/layoffs")

%% Load in Data

hazard_panel = readtable("hazard_panel.csv");
hazard_average = readtable("hazard.csv");
hazard_srefmonA = readtable("hazard_srefmonA.csv");

%% Plotting Figures

opt.rwkesr2 = {3,3,3,4,4,4}; % 3 or 4 
opt.prob_col = {'pR','pN','pE','pR','pN','pE'}; % pR, pN, pE
opt.tmp = {'Recall', 'New Job', 'Recall + New Job', 'Recall', 'New Job', '(Recall or New Job)'};
opt.lgnd = {0,0,0,0,0,1};

figure('Position',[0 0 3500 600],'PaperPositionMode','Auto','DefaultAxesFontSize',17);
for ii=1:6
  opt.title_name{ii} = strcat("Probability of ",opt.tmp{ii});
end

figure('Position',[0 0 3500 600],'PaperPositionMode','Auto','DefaultAxesFontSize',17);
hold on;
clf;
for ii=1:6
subplot(2,3,ii)
figures.wave_probability_histogram(hazard_panel, hazard_average, opt.rwkesr2{ii}, opt.prob_col{ii}, opt.title_name{ii},opt.lgnd{ii})
end

opt.srefmonA = {0,1,2,3,4,0,1,2,3,4,0,1,2,3,4}; % 3 or 4 
opt.prob_col = {'pE','pE','pE','pE','pE','pR','pR','pR','pR','pR','pN','pN','pN','pN','pN'}; % pE, pR, pN
print('-dpdf', gcf, join(['figures/','all']));

figure('Position',[0 0 3500 600],'PaperPositionMode','Auto','DefaultAxesFontSize',17);
clf
for ii=1:15
  subplot (3,5,ii)
  figures.this(hazard_srefmonA,hazard_average, 3, opt.srefmonA{ii},opt.prob_col{ii}, '')  
  if (ii<=5)
    yL = [0,1.0];
    ylim(yL);
    yticks([0:.25:1])
  elseif (ii>5)
    yL = [0, 0.75]
    ylim(yL);
    yticks([0:.25:.75])
  end
  if (opt.srefmonA{ii}>0)
    line([5-opt.srefmonA{ii},5-opt.srefmonA{ii}],yL,'LineStyle',':','Color','Red','LineWidth',2)
    line([9-opt.srefmonA{ii},9-opt.srefmonA{ii}],yL,'LineStyle',':','Color','Red','LineWidth',2)
  end
end
print('-dpdf', gcf, join(['figures/','TL']));

figure('Position',[0 0 3500 600],'PaperPositionMode','Auto','DefaultAxesFontSize',17);
for ii=1:15
  subplot (3,5,ii)
  figures.this(hazard_srefmonA,hazard_average, 4, opt.srefmonA{ii},opt.prob_col{ii}, '')  
  if (ii<=5)
    yL = [0, 0.6]
    ylim(yL);
    yticks([0:.2:.6]);
  elseif (ii<=10)
    yL = [0, 0.10]
    ylim(yL);
    yticks([0:.02:.10]);
  else
    yL = [0, 0.6]
    ylim(yL);
    yticks([0:.2:.6]);
  end
  if (opt.srefmonA{ii}>0)
    line([5-opt.srefmonA{ii},5-opt.srefmonA{ii}],yL,'Color','Red','LineWidth',1)
    line([9-opt.srefmonA{ii},9-opt.srefmonA{ii}],yL,'Color','Red','LineWidth',1)
  end
  xticks([0:1:8]);
  xlim([0.5,8.5]);
end
print('-dpdf', gcf, join(['figures/','JL']));
