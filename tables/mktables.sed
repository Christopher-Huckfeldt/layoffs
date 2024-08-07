#! /opt/local/bin/gsed -f

# gsed -f mktables.sed Tables_Template.tex > filled.tex


# Recall rates
s/\<recall_TL\>/0.763/g
s/\<recall_TL_1996\>/0.740/g
s/\<recall_TL_2001\>/0.754/g
s/\<recall_TL_2004\>/0.766/g
s/\<recall_TL_2008\>/0.782/g
s/\<recall_PS\>/0.064/g
s/\<recall_PS_1996\>/0.063/g
s/\<recall_PS_2001\>/0.068/g
s/\<recall_PS_2004\>/0.080/g
s/\<recall_PS_2008\>/0.047/g


# Distribution of first month
s/\<srefmonA1_TL\>/0.328/g
s/\<srefmonA1_PS\>/0.387/g
s/\<srefmonA2_TL\>/0.210/g
s/\<srefmonA2_PS\>/0.205/g
s/\<srefmonA3_TL\>/0.233/g
s/\<srefmonA3_PS\>/0.202/g
s/\<srefmonA4_TL\>/0.230/g
s/\<srefmonA4_PS\>/0.207/g


# Distribution of last month
s/\<srefmonZ1_TL\>/0.137/g
s/\<srefmonZ1_PS\>/0.203/g
s/\<srefmonZ2_TL\>/0.190/g
s/\<srefmonZ2_PS\>/0.209/g
s/\<srefmonZ3_TL\>/0.236/g
s/\<srefmonZ3_PS\>/0.223/g
s/\<srefmonZ4_TL\>/0.437/g
s/\<srefmonZ4_PS\>/0.365/g
