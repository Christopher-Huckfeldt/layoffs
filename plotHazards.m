clear;
close all;
data = readtable('hazards.csv'); %,'Range','C1:H504');
TL = data(1:8,:);
JL = data(9:end,:);

blue   = '#0f7ba2';
yellow = '#f0e442';
green  = '#009e73';
red    = '#dd5129';


hf=figure('Position',[0 0 1000 600],'PaperPositionMode','Auto','DefaultAxesFontSize',13);

%figure(3)
subplot(1,2,2);
hold on;
plot(TL.duration , TL.pE , '-o' , 'MarkerSize', 10, 'Color' , red   , 'LineWidth' , 1.25)
plot(TL.duration , TL.pN , '-square' , 'MarkerSize', 10, 'Color' , green , 'LineWidth' , 1.25)
plot(TL.duration , TL.pR , '-diamond' , 'MarkerSize', 10, 'Color' , blue  , 'LineWidth' , 1.25)
yL = get(gca,'Ylim')
set(groot,'defaultAxesTickLabelInterpreter','latex');
title('{From Temporary-Layoff Unemployment}','Interpreter','latex','Fontsize',15)
%plot(dat,infm.stockE_mdl,'-o','Color',blue,'LineWidth',.75);
%plot(dat(1:irf.nplot),infm.stockE_dat,'-sk','LineWidth',.75)
set(gca,'XTick',TL.duration);
line([4.5,4.5],yL,'LineStyle','--','Color',[0.5, 0.5, 0.5], 'LineWidth',0.75);
ax=gca;
ax.GridColor = [0.5, 0.5, 0.5];  % [R, G, B]
ylim(yL);
grid on;
xlabel('Months unemployed')
l1 =legend({'Re-employment Probability, Total', 'Re-employment Probability, New Job', 'Re-employment Probability, Recall'},'Interpreter','latex','Fontsize',13);

subplot(1,2,1);
hold on;
plot(JL.duration , JL.pE , '-o' , 'MarkerSize', 10, 'Color' , red   , 'LineWidth' , 1.25)
plot(JL.duration , JL.pN , '-square' , 'MarkerSize', 10, 'Color' , green , 'LineWidth' , 1.25)
plot(JL.duration , JL.pR , '-diamond' , 'MarkerSize', 10, 'Color' , blue  , 'LineWidth' , 1.25)
ylim(yL);
set(groot,'defaultAxesTickLabelInterpreter','latex');
title('{From Jobless Unemployment}','Interpreter','latex','Fontsize',15)
set(gca,'XTick',TL.duration);
line([4.5,4.5],yL,'LineStyle','--','Color',[0.5, 0.5, 0.5], 'LineWidth',0.75);
ax=gca;
ax.GridColor = [0.5, 0.5, 0.5];  % [R, G, B]
grid on;

%print('Hazard_from_Unemployment','-fillpage','-dpdf');

hfig = gcf
set(hfig, 'WindowStyle', 'normal');
hax = findall(hfig, 'type', 'axes');
set(hax, 'Units', 'centimeters');
pos = cell2mat(get(hax, 'Position'));
figwidth = max(pos(:,1) + pos(:,3));
figheight = max(pos(:,2) + pos(:,4));
set(hfig, 'PaperUnits','centimeters');
set(hfig, 'PaperSize', [figwidth, figheight]);
set(hfig, 'PaperPositionMode', 'manual');
set(hfig, 'PaperPosition',[0 0 figwidth figheight]);

xlabel('Months unemployed')

sgtitle('Hazard Rates from Unemployment to Employment', 'Interpreter', 'latex', 'Fontsize', 18);
print('-dpdf', gcf, 'hazard');

