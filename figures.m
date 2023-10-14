classdef figures
    properties
    end

    methods (Static)
        function wave_probability_histogram(...
            data, ...
            average_data, ...
            which_rwkesr2, ... 
            which_probability, ...
            title_name ...
            )

            data = data(data.rwkesr2 == which_rwkesr2, [which_probability, "spanel", "duration"]);
            average_data = average_data(average_data.rwkesr2 == which_rwkesr2, [which_probability, "duration"]);
            wide_data = unstack(data, which_probability, "spanel", "VariableNamingRule", "preserve");
            
            color1 = [0.2 0.4 0.6];
            color2 = [0.8 0.2 0.4];
            color3 = [0.1 0.6 0.3];
            color4 = [0.5 0.1 0.9];
            
            custom_colors = {color1, color2, color3, color4};
         
            waves = bar(wide_data{:,2:end});
            for i = 1:size(wide_data,2)-1
                waves(i).FaceColor = custom_colors{i};
            end
            legend({'1996' '2004', '2008', '2012'}, 'interpreter','Latex')
            
            hold on;
            plot(average_data.duration, average_data.(which_probability), "HandleVisibility", "off")
            xlabel("Months", 'interpreter','Latex')
            title(title_name, 'interpreter','Latex')
            hold off;
        end
    end
end