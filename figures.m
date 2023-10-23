classdef figures
    properties
    end

    methods (Static)
        function wave_probability_histogram(...
            data, ...
            average_data, ...
            which_rwkesr2, ... 
            which_probability, ...
            title_name, ...
            legend_status)

            data = data(data.rwkesr2 == which_rwkesr2, [which_probability, "spanel", "duration"]);
            average_data = average_data(average_data.rwkesr2 == which_rwkesr2, [which_probability, "duration"]);
            wide_data = unstack(data, which_probability, "spanel", "VariableNamingRule", "preserve");
            
            color1 = "#7fc97f";
            color2 = "#beaed4";
            color3 = "#fdc086";
            color4 = "#ffff99";
            % https://colorbrewer2.org/#type=qualitative&scheme=Accent&n=4
            
            custom_colors = {color1, color2, color3, color4};
         
            waves = bar(wide_data{:,2:end});
            for i = 1:size(wide_data,2)-1
                waves(i).FaceColor = custom_colors{i};
            end
            if (legend_status==1)
            legend_here = legend({'1996' '2001', '2004', '2008'}, 'interpreter','Latex')
              set(legend_here,...
                  'Position',[0.914736842105263 0.0672546857772878 0.07 0.141124586549063],...
                  'Interpreter','latex');
            end
         
            hold on;
            plot(average_data.duration, average_data.(which_probability), '-ks', 'HandleVisibility', 'off',...
              'LineWidth', 2, 'MarkerSize', 10)
            xlabel("Months", 'interpreter','Latex')
            title(title_name, 'interpreter','Latex')
            hold off;
        end

        function this(...
            data, ...
            avg_data, ...
            which_rwkesr2, ... 
            which_srefmonA, ... 
            which_probability, ...
            title_name)

            if (which_srefmonA>0)
              use_data = data([data.rwkesr2==which_rwkesr2 & data.srefmonA==which_srefmonA], [which_probability, "duration"]);
            else
              use_data = avg_data([avg_data.rwkesr2==which_rwkesr2], [which_probability, "duration"]);
            end
 
            hold on;
            grid on;
            plot(use_data.duration, use_data.(which_probability), '-ks', 'HandleVisibility', 'off',...
              'LineWidth', 2, 'MarkerSize', 10)
            xlabel("Months", 'interpreter','Latex')
            xlim([0,8])
            xticks([1:1:8])
            xtickangle(0)
            title(title_name, 'interpreter','Latex')
            hold off;
        end
    end

end
