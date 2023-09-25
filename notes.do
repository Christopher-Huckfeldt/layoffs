count if (jbID1==0 & jbID2==0 ) & status=="E"
count if (eeno1==0 & eeno2==0 ) & status=="E"
count if (eeno1==-1 | eeno1==0) & ( eeno2==0 | eeno2==-1 ) & status=="E"
count if (eeno1==-1 | eeno1==0) & ( eeno2==0 | eeno2==-1 ) & rwkesr2==1
count if (eeno1==-1 | eeno1==0) & ( eeno2==0 | eeno2==-1 ) & rwkesr2==1
count if (eeno1==-1 | eeno1==0) & ( eeno2==0 | eeno2==-1 ) & rwkesr2==2
gen anyjob = (eeno1>0 & eeno1~=.) | (eeno2>0 & eeno2~=.)
frame put tejdate1 tejdate2 tsjdate1 tsjdate2, into(recall)

gen problem = (anyjob==1 & tpmsum1==0 & tpmsum2==0 & rwkesr2==1)
gen problem2 = anyjob==0 & (rwkesr2==1 | rwkesr==2)

list ID if problem
xtset ID tt
xttab problem

sort ID tt
list ID tt eeno1 eeno2 tpmsum1 tpmsum2 tejdate1 tejdate2 tsjdate1 tsjdate2 rwkesr2 anyjob problem if ID==114119, header(30)

- only a "problem" if the job bookends an unemployment spell.
- see suid=="955925471470" & epppnum=="0101" for example where tpmsum*==0 but tpearn~=0.
