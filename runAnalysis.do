clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace

use tmpdata/cw96.dta, clear

egen pID = group(ssuseq ssuid epppnum )
gen id = ssuid+eentaid+epppnum

* -------------------------
* main table
* -------------------------

sort pID swave srefmon

gen SM_any3=0
gen SM_any4=0
forvalues imn=1/4 { // loop over reference month
  by pID swave srefmon: replace SM_any3 = 1 if (rwkesr2==3 & srefmon==`imn')
  by pID swave srefmon: replace SM_any4 = 1 if (rwkesr2==4 & srefmon==`imn')
}

gen sub_esr = 3 if rwkesr2==3
replace sub_esr = 4 if rwkesr2==4

tab elayoff sub_esr if elayoff~=-1, row col

egen ID = group(ssuid eentaid epppnum)
sort ID swave srefmon


by ID swave srefmon: gen undur = (rwkesr2==3 | rwkesr2==4)
gen tt = srefmon + (swave-1)*4
sum tt

* ----------------------------
* Compute unemployment duration
* ----------------------------

frames put ID tt undur, into(subset)
frame change subset
reshape wide undur, i(ID) j(tt)
*

sort ID
forvalues i=2/48 {
  local j=`i'-1
  by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
}

reshape long undur, i(ID) j(tt)
sort ID tt

frame change default
drop undur

frlink 1:1 ID tt, frame(subset)
frget undur = undur, from(subset)

sort ID

gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
gen jbID2 = eeno2*(tpmsum2!=0)
*gen jbID1 = eeno1*(rwkesr2==1) //  another option is to use rwkesr2==1
*gen jbID2 = eeno2*(rwkesr2==1)
replace jbID1=0 if jbID1<0
replace jbID2=0 if jbID2<0
gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)
* create a single job ID variable


by ID: gen jID_before = jID[_n-1] if undur==1
by ID: gen jID_after = jID[_n+1] if undur==1 & undur[_n+1]==0 & rwkesr2[_n+1]==1
gen recall = (jID_before==jID_after & jID_before~=. & jID_before~=-1 & jID_before~=0)

by ID: gen jID_after2 = jID[_n+1] if undur==2 & undur[_n+1]==0 & rwkesr2[_n+1]==1
gen recall2 = (jID_before==jID_after2[_n+1] & jID_before~=. & jID_before~=-1 & jID_before~=0)

by ID: gen jID_after3 = jID[_n+1] if undur==3 & undur[_n+1]==0 & rwkesr2[_n+1]==1
gen recall3 = (jID_before==jID_after3[_n+2] & jID_before~=. & jID_before~=-1 & jID_before~=0)

tab recall rwkesr2 if undur==1, col
tab rwkesr2 if undur[_n-1]==1 & rwkesr2[_n-1]==3
tab rwkesr2 if undur[_n-1]==1 & rwkesr2[_n-1]==4

tab recall2 rwkesr2 if undur[_n+1]==2, col
tab rwkesr2 if undur[_n-1]==2 & rwkesr2[_n-1]==3
tab rwkesr2 if undur[_n-1]==2 & rwkesr2[_n-1]==4

tab recall3 rwkesr2 if undur[_n+2]==3, col
tab rwkesr2 if undur[_n-1]==3 & rwkesr2[_n-1]==3
tab rwkesr2 if undur[_n-1]==3 & rwkesr2[_n-1]==4

tab rwkesr2 if undur[_n-1]==1 & rwkesr2[_n-1]==4
list ID if undur[_n-1]==1 & rwkesr2[_n-1]==3 & rwkesr2==1

* make sure that unemployment duration is preceded by employment


dflkj

reshape to wide instead!!

dflkj
drop if sub_esr==0
collapse (min) sub_esr (min) elayoff , by(ID)



dflkj

sort ssuid eentaid epppnum swave srefmon
merge ssuid eentaid epppnum swave srefmon using FM.dta
keep if _merge==3
drop _merge
*sort ssuid eentaid epppnum swave srefmon
*merge ssuid eentaid epppnum swave srefmon using FMrecalls.dta
*keep if _merge==3
dflkj

* -------------------------
* within wave comparison
* -------------------------

sort pID swave srefmon

gen any3 = 0  // varies over the wave
gen any4 = 0  // varies over the wave
forvalues imn=1/4 { // loop over reference month
  forvalues iwk=1/5 { // loop over weeks in a month
    by pID swave: replace any3 = 1 if (rwkesr`iwk'==3 & `iwk'<=rwksperm & srefmon==`imn')
    by pID swave: replace any4 = 1 if (rwkesr`iwk'==4 & `iwk'<=rwksperm & srefmon==`imn')
  }
}

sort pID swave srefmon
by pID swave: gen comb34 = (any3 == 1 & any4 == 1)  // rwkesr = 3 or 4 during wave
by pID swave: gen only3  = (any3 == 1 & any4 == 0)  // rwkesr = 3 and not 4 during wave
by pID swave: gen only4  = (any3 == 0 & any4 == 1)  // rwkesr = 4 and not 3 during wave

keep if any3==1 | any4==1
collapse (mean) any3 any4 only3 only4 comb34, by(swave)

list
* comb34 always less than one percent

capture log close
