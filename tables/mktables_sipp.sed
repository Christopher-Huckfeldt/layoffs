#! /opt/local/bin/gsed -f

# gsed -f mktables.sed Tables_Template.tex > filled.tex


# Recall shares
s/\<recall_TL\>/0.763/g
s/\<recall_TL_1996\>/0.739/g
s/\<recall_TL_2001\>/0.755/g
s/\<recall_TL_2004\>/0.766/g
s/\<recall_TL_2008\>/0.783/g

# Recall shares
s/\<recall_PS\>/0.067/g
s/\<recall_PS_1996\>/0.060/g
s/\<recall_PS_2001\>/0.068/g
s/\<recall_PS_2004\>/0.089/g
s/\<recall_PS_2008\>/0.053/g

# Recall shares by duration & controlling for missing data, spell duration lte 2
s/\<rShare_TL_2\>/0.783/g
s/\<rShare_TL_2_1996\>/0.758/g
s/\<rShare_TL_2_2001\>/0.775/g
s/\<rShare_TL_2_2004\>/0.783/g
s/\<rShare_TL_2_2008\>/0.804/g
s/\<rShare_PS_2\>/0.085/g
s/\<rShare_PS_2_1996\>/0.077/g
s/\<rShare_PS_2_2001\>/0.087/g
s/\<rShare_PS_2_2004\>/0.102/g
s/\<rShare_PS_2_2008\>/0.072/g
s/\<rShare_PS_jinfo_2\>/0.085/g
s/\<rShare_PS_jinfo_2_1996\>/0.077/g
s/\<rShare_PS_jinfo_2_2001\>/0.087/g
s/\<rShare_PS_jinfo_2_2004\>/0.102/g
s/\<rShare_PS_jinfo_2_2008\>/0.072/g

# Recall shares by duration & controlling for missing data, spell duration lte 3
s/\<rShare_TL_3\>/0.779/g
s/\<rShare_TL_3_1996\>/0.753/g
s/\<rShare_TL_3_2001\>/0.770/g
s/\<rShare_TL_3_2004\>/0.784/g
s/\<rShare_TL_3_2008\>/0.798/g
s/\<rShare_PS_3\>/0.071/g
s/\<rShare_PS_3_1996\>/0.062/g
s/\<rShare_PS_3_2001\>/0.072/g
s/\<rShare_PS_3_2004\>/0.092/g
s/\<rShare_PS_3_2008\>/0.057/g
s/\<rShare_PS_jinfo_3\>/0.071/g
s/\<rShare_PS_jinfo_3_1996\>/0.062/g
s/\<rShare_PS_jinfo_3_2001\>/0.072/g
s/\<rShare_PS_jinfo_3_2004\>/0.092/g
s/\<rShare_PS_jinfo_3_2008\>/0.057/g

# Recall shares by duration & controlling for missing data, spell duration lte 4
s/\<rShare_TL_4\>/0.763/g
s/\<rShare_TL_4_1996\>/0.739/g
s/\<rShare_TL_4_2001\>/0.755/g
s/\<rShare_TL_4_2004\>/0.766/g
s/\<rShare_TL_4_2008\>/0.783/g
s/\<rShare_PS_4\>/0.066/g
s/\<rShare_PS_4_1996\>/0.064/g
s/\<rShare_PS_4_2001\>/0.070/g
s/\<rShare_PS_4_2004\>/0.083/g
s/\<rShare_PS_4_2008\>/0.048/g
s/\<rShare_PS_jinfo_4\>/0.067/g
s/\<rShare_PS_jinfo_4_1996\>/0.064/g
s/\<rShare_PS_jinfo_4_2001\>/0.070/g
s/\<rShare_PS_jinfo_4_2004\>/0.083/g
s/\<rShare_PS_jinfo_4_2008\>/0.048/g

# Recall shares by duration & controlling for missing data, spell duration lte 5
s/\<rShare_TL_5\>/0.761/g
s/\<rShare_TL_5_1996\>/0.738/g
s/\<rShare_TL_5_2001\>/0.755/g
s/\<rShare_TL_5_2004\>/0.765/g
s/\<rShare_TL_5_2008\>/0.777/g
s/\<rShare_PS_5\>/0.062/g
s/\<rShare_PS_5_1996\>/0.060/g
s/\<rShare_PS_5_2001\>/0.067/g
s/\<rShare_PS_5_2004\>/0.078/g
s/\<rShare_PS_5_2008\>/0.045/g
s/\<rShare_PS_jinfo_5\>/0.065/g
s/\<rShare_PS_jinfo_5_1996\>/0.060/g
s/\<rShare_PS_jinfo_5_2001\>/0.067/g
s/\<rShare_PS_jinfo_5_2004\>/0.078/g
s/\<rShare_PS_jinfo_5_2008\>/0.045/g

# Recall shares by duration & controlling for missing data, spell duration lte 6
s/\<rShare_TL_6\>/0.760/g
s/\<rShare_TL_6_1996\>/0.736/g
s/\<rShare_TL_6_2001\>/0.757/g
s/\<rShare_TL_6_2004\>/0.765/g
s/\<rShare_TL_6_2008\>/0.773/g
s/\<rShare_PS_6\>/0.059/g
s/\<rShare_PS_6_1996\>/0.058/g
s/\<rShare_PS_6_2001\>/0.065/g
s/\<rShare_PS_6_2004\>/0.075/g
s/\<rShare_PS_6_2008\>/0.042/g
s/\<rShare_PS_jinfo_6\>/0.064/g
s/\<rShare_PS_jinfo_6_1996\>/0.058/g
s/\<rShare_PS_jinfo_6_2001\>/0.065/g
s/\<rShare_PS_jinfo_6_2004\>/0.075/g
s/\<rShare_PS_jinfo_6_2008\>/0.042/g

# Recall shares by duration & controlling for missing data, spell duration lte 7
s/\<rShare_TL_7\>/0.758/g
s/\<rShare_TL_7_1996\>/0.734/g
s/\<rShare_TL_7_2001\>/0.757/g
s/\<rShare_TL_7_2004\>/0.763/g
s/\<rShare_TL_7_2008\>/0.770/g
s/\<rShare_PS_7\>/0.057/g
s/\<rShare_PS_7_1996\>/0.056/g
s/\<rShare_PS_7_2001\>/0.062/g
s/\<rShare_PS_7_2004\>/0.074/g
s/\<rShare_PS_7_2008\>/0.040/g
s/\<rShare_PS_jinfo_7\>/0.064/g
s/\<rShare_PS_jinfo_7_1996\>/0.056/g
s/\<rShare_PS_jinfo_7_2001\>/0.062/g
s/\<rShare_PS_jinfo_7_2004\>/0.074/g
s/\<rShare_PS_jinfo_7_2008\>/0.040/g

# Recall shares by duration & controlling for missing data, spell duration lte 8
s/\<rShare_TL_8\>/0.755/g
s/\<rShare_TL_8_1996\>/0.731/g
s/\<rShare_TL_8_2001\>/0.753/g
s/\<rShare_TL_8_2004\>/0.762/g
s/\<rShare_TL_8_2008\>/0.766/g
s/\<rShare_PS_8\>/0.056/g
s/\<rShare_PS_8_1996\>/0.056/g
s/\<rShare_PS_8_2001\>/0.061/g
s/\<rShare_PS_8_2004\>/0.072/g
s/\<rShare_PS_8_2008\>/0.038/g


# Distribution of first month
s/\<srefmonA1_TL\>/0.326/g
s/\<srefmonA1_PS\>/0.377/g
s/\<srefmonA2_TL\>/0.211/g
s/\<srefmonA2_PS\>/0.210/g
s/\<srefmonA3_TL\>/0.234/g
s/\<srefmonA3_PS\>/0.206/g
s/\<srefmonA4_TL\>/0.229/g
s/\<srefmonA4_PS\>/0.207/g


# Distribution of last month
s/\<srefmonZ1_TL\>/0.137/g
s/\<srefmonZ1_PS\>/0.204/g
s/\<srefmonZ2_TL\>/0.193/g
s/\<srefmonZ2_PS\>/0.210/g
s/\<srefmonZ3_TL\>/0.238/g
s/\<srefmonZ3_PS\>/0.226/g
s/\<srefmonZ4_TL\>/0.432/g
s/\<srefmonZ4_PS\>/0.360/g
