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


gen undur = (rwkesr2==3 | rwkesr2==4)
gen nedur = (rwkesr2==3 | rwkesr2==4 | rwkesr2==5)
by ID (swave srefmon): gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1|rwkesr2[_n-1]==2))
gen undur_en = undur_eu
gen tt = srefmon + (swave-1)*4
sum tt

* -------
* job information
* -------

frame put ID tt eeno1 eeno2 tsjdate1 tsjdate2 tejdate1 tejdate2 tpmsum1 tpmsum2, into(jobs)
frame change jobs
reshape long eeno tsjdate tejdate tpmsum, i(ID tt) j(j)
drop j
rename eeno job
rename tsjdate start_date
rename tejdate end_date
rename tpmsum pay
replace tt = tt * (pay>0)
drop if job==-1
drop if tt==0
collapse (min) start_date first_tt=tt (max) last_tt=tt end_date, by(ID job)

* ----------------------------
* Compute unemployment duration
* ----------------------------

frame change default
frames put ID tt nedur undur undur_eu undur_en, into(subset)
frame change subset
reshape wide undur nedur undur_eu undur_en, i(ID) j(tt)
*

sort ID
forvalues i=2/48 {
  local j=`i'-1
  by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
}

forvalues i=2/48 {
  local j=`i'-1
  by ID: replace undur_eu`i' = 1 + undur_eu`j' if undur_eu`j'~=0 & undur`i'~=0
  by ID: replace undur_en`i' = 1 + undur_en`j' if undur_en`j'~=0 & nedur`i'~=0
}

reshape long undur nedur undur_eu undur_en, i(ID) j(tt)
drop undur nedur
sort ID tt
gen spell_begin = tt if undur_en==1
by ID (tt), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_en>1 & undur_en~=.
by ID spell_begin (tt), sort: gen spell_end = tt[_N]
replace spell_end = . if spell_begin==.
gen spell_length = spell_end-spell_begin+1
replace undur_en=0 if undur_en==.

frame change default
drop undur undur_eu undur_en

frlink 1:1 ID tt, frame(subset)
frget undur_eu = undur_eu, from(subset)
frget undur_en = undur_en, from(subset)
frget spell_begin = spell_begin, from(subset)
frget spell_end = spell_end, from(subset)
frget spell_length = spell_length, from(subset)


bys ID (tt): gen emp_eu = ((rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3 | rwkesr2[_n+1]==4))

* ----------------------------
* Identify recalls from short samples
* ----------------------------
sort ID

gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
gen jbID2 = eeno2*(tpmsum2!=0)
replace jbID1=0 if jbID1<0 | jbID1==.
replace jbID2=0 if jbID2<0 | jbID2==.
gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)
* create a single job ID variable

* might be a limitation:
*tab undur if jbID1[_n+1]~=0 & jbID2[_n+1]~=0 & undur_eu~=0


by ID: gen jID_before = jID if undur_eu[_n+1]==1
by ID: gen jID_after = jID[_n+2] if undur_eu[_n+1]==1 & undur_eu[_n+2]==0 & (rwkesr2[_n+2]==1 | rwkesr2[_n+2]==2)
gen recall = (jID_before==jID_after & jID_before~=. & jID_before~=-1 & jID_before~=0)

#delimit;
gen recall_cmplx = ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=. & jbID1[_n-1]~=-1 & jbID1[_n-1]~=0) |
 (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=. & jbID1[_n-1]~=-1 & jbID1[_n-1]~=0) |
 (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=. & jbID2[_n-1]~=-1 & jbID2[_n-1]~=0) |
 (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=. & jbID2[_n-1]~=-1 & 
 jbID2[_n-1]~=0)) & undur_eu==1 & undur_eu[_n+1]==0 & rwkesr2[_n+1]==1;
gen recall_cmplx1 = ((jbID1==jbID1[_n+2] & jbID1~=. & jbID1~=-1 & jbID1~=0) |
 (jbID1==jbID2[_n+2] & jbID1~=. & jbID1~=-1 & jbID1~=0) |
 (jbID2==jbID1[_n+2] & jbID2~=. & jbID2~=-1 & jbID2~=0) |
 (jbID2==jbID2[_n+2] & jbID2~=. & jbID2~=-1 & 
 jbID2~=0)) & undur_eu[_n+1]==1 & undur_eu[_n+2]==0 & (rwkesr2[_n+2]==1| rwkesr2[_n+2]==2);
#delimit cr

#delimit;
gen recall_cmplx2 = ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=. & jbID1[_n-1]~=-1 & jbID1[_n-1]~=0) |
 (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=. & jbID1[_n-1]~=-1 & jbID1[_n-1]~=0) |
 (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=. & jbID2[_n-1]~=-1 & jbID2[_n-1]~=0) |
 (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=. & jbID2[_n-1]~=-1 & 
 jbID2[_n-1]~=0)) & undur_eu==1 & undur_eu[_n+1]==0 & rwkesr2[_n+1]==1;
#delimit cr

* TODO: throw non-employment spells in.
* christopherhuckfeldt Mon Dec 12 15:51:11 2022
gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
gen jbID2 = eeno2*(tpmsum2!=0)
replace jbID1=0 if jbID1<0 | jbID1==.
replace jbID2=0 if jbID2<0 | jbID2==.


capture drop EUE_GHT
capture drop EUEjob_GHT
capture drop EUEjob_GHTa
capture drop RecallJob_GHT
capture drop RecallJob_GHTa
capture drop recall_GHT
capture drop stillPaid
capture drop stillPaid_unc
capture drop stillPaidAll
capture drop recall

gen EUE_GHT = 0
gen EUEjob_GHT = 0
gen RecallJob_GHT = 0
gen RecallJob_GHTa = 0
gen recall_GHT = 0
gen recall = 0
gen stillPaid = 0
gen stillPaid_unc = 0
gen stillPaidAll = 0

forvalues ii=1/9 {

  #delimit;
  replace EUE_GHT = 1 if undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' 
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

  #delimit;
  replace EUEjob_GHT = 1 if (jbID1~=0 | jbID2~=0)
    & (jbID1[_n+1+`ii']~=0 | jbID2[_n+1+`ii']~=0)
    & undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' & undur_en[_n+1+`ii']==0 
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

  #delimit;
  replace RecallJob_GHT = jbID1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (jbID1==jbID2[_n+1+`ii'] & jbID1~=0)) 
    & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

  #delimit;
  replace RecallJob_GHT = jbID2 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
    RecallJob_GHT==0;
  #delimit cr

  #delimit;
  replace RecallJob_GHTa = jbID1 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
    RecallJob_GHT~=0;
  #delimit cr

  #delimit;
  replace stillPaid = 1 if ((tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

  #delimit;
  replace stillPaid_unc = 1 if ((tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
    & (rwkesr2==1 | rwkesr2==2);
  #delimit cr

  #delimit;
  replace stillPaidAll = 1 if ((tpmsum1[_n+`ii']>0 & tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

  #delimit;
  replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
    (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    & undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' & undur_en[_n+`ii'+1]==0
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr

capture drop jID
capture drop jID_before
capture drop jID_after

gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)

by ID: gen jID_before = jID if spell_length[_n+1]==1
by ID: gen jID_after = jID[_n+1+`ii'] if spell_length[_n+1]==`ii' & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2)

replace recall = 1 if (jID_before==jID_after & jID_before~=. & jID_before~=-1 & jID_before~=0)

capture drop jID
capture drop jID_before
capture drop jID_after

}

by ID (tt), sort: gen F1spell_length = spell_length[_n+1]

forvalues i=1/6 {
  capture drop F`i'rwkesr2
  
  bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
}

forvalues i=1/4 {
  tab recall_GHT F1rwkesr2 if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), col
  tab recall F1rwkesr2 if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), col
}

keep recall_GHT recall rwkesr2 F1rwkesr2 F1spell_length



tab recall_GHT F1rwkesr2 if stillPaid ==1 & F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaid ==0 & F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaid ==1 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaid ==0 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaidAll ==1 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaidAll ==0 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaid==1 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaid==0 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaidAll==1 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if stillPaidAll==0 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col


tab recall_GHT F1rwkesr2 if F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F4undur_en==4 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F5undur_en==5 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if F1undur_en==1 & (rwkesr2==1 | rwkesr2==2) & (F2rwkesr2==1 | F2rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F2undur_en==2 & (rwkesr2==1 | rwkesr2==2) & (F3rwkesr2==1 | F3rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F3undur_en==3 & (rwkesr2==1 | rwkesr2==2) & (F4rwkesr2==1 | F4rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F4undur_en==4 & (rwkesr2==1 | rwkesr2==2) & (F5rwkesr2==1 | F5rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F5undur_en==5 & (rwkesr2==1 | rwkesr2==2) & (F6rwkesr2==1 | F6rwkesr2==2), col




* need to make sure that "recall" is identified off of "job"







*tab recall Lrwkesr2 if Lundur_eu==1, col
*tab recall_GHT Lrwkesr2 if Lundur_eu==1, col
*tab recall_GHT Lrwkesr2 if Lundur_en==1, col

/* 
tab recall rwkesr2 if undur_eu==1, col
tab recall_cmplx rwkesr2 if undur_eu==1, col
tab recall rwkesr2 if undur_eu==1 & swave==swave[_n+1], col
tab recall rwkesr2 if undur_eu==1 & swave~=swave[_n+1], col
tab recall rwkesr2 if undur_eu==1 & elayoff~=1, col
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==3
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==4 & elayoff~=1
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==3 & swave[_n-1]~=swave
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==3 & swave[_n-1]==swave
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==4 & swave[_n-1]==swave
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==4 & swave[_n-1]~=swave
tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==4

tab recall2 rwkesr2 if undur_eu[_n+1]==2, col
tab recall_cmplx2 rwkesr2 if undur_eu[_n+1]==2, col
tab recall2 rwkesr2 if undur_eu[_n+1]==2 & swave==swave[_n+2], col
tab recall2 rwkesr2 if undur_eu[_n+1]==2 & swave!=swave[_n+2], col
*tab recall2 rwkesr2 if undur_eu[_n+1]==2 & elayoff==1, col
*tab recall2 rwkesr2 if undur_eu[_n+1]==2 & elayoff==2, col
*tab recall2 rwkesr2 if undur_eu[_n+1]==2 & elayoff==-1, col
tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==3 
tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==4

tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==3 & swave[_n-2]==swave
tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==3 & swave[_n-2]~=swave
tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==4 & swave[_n-2]==swave
tab rwkesr2 if undur_eu[_n-1]==2 & rwkesr2[_n-1]==4 & swave[_n-2]~=swave

tab recall3 rwkesr2 if undur_eu[_n+2]==3, col
tab recall_cmplx3 rwkesr2 if undur_eu[_n+2]==3, col
tab recall3 rwkesr2 if undur_eu[_n+2]==3 & swave==swave[_n+3], col
tab recall3 rwkesr2 if undur_eu[_n+2]==3 & swave!=swave[_n+3], col
tab rwkesr2 if undur_eu[_n-1]==3 & rwkesr2[_n-1]==3
tab rwkesr2 if undur_eu[_n-1]==3 & rwkesr2[_n-1]==4

tab rwkesr2 if undur_eu[_n-1]==1 & rwkesr2[_n-1]==4

*/

* need to account for difference between conditional and 
* unconditional: what is recall rate conditional on a one-month 
* spell, versus what is recall rate conditional on ONLY a one-month 
* spell.


sort ssuid eentaid epppnum swave srefmon
merge 1:1 ssuid eentaid epppnum swave srefmon using FMrecalls.dta

bysort ID (tt): gen nonE = (rwkesr2[_n+1]==5 & recallFM==1)

frlink m:1 ID job, frame(jobs)
frget end_date = end_date, from(jobs)
frget last_tt = last_tt, from(jobs)
frget start_date = start_date, from(jobs)
frget first_tt = first_tt, from(jobs)

bys ID: egen recallFM2 = total(recallFM)
replace recallFM2 = (recallFM2>0 & recallFM2~=.)
tab recall_GHT recallFM if undur<=3

tab recallFM F1rwkesr2 if F1undur_en==1 & (rwkesr2==1 | rwkesr2==2) & (F2rwkesr2==1 | F2rwkesr2==2), col
tab recallFM F1rwkesr2 if F2undur_en==2 & (rwkesr2==1 | rwkesr2==2) & (F3rwkesr2==1 | F3rwkesr2==2), col
tab recallFM F1rwkesr2 if F3undur_en==3 & (rwkesr2==1 | rwkesr2==2) & (F4rwkesr2==1 | F4rwkesr2==2), col
tab recallFM F1rwkesr2 if F4undur_en==4 & (rwkesr2==1 | rwkesr2==2) & (F5rwkesr2==1 | F5rwkesr2==2), col

tab recall_GHT F1rwkesr2 if (tpmsum1[_n+1]==0 | tpmsum2[_n+1]==0) & F1undur_en==1 & (rwkesr2==1 | rwkesr2==2) & (F2rwkesr2==1 | F2rwkesr2==2), col

tab recall_GHT F1rwkesr2 if (tpmsum1[_n+1]~=0 | tpmsum2[_n+1]~=0) & spell_length[_n+1]==2 & (rwkesr2==1 | rwkesr2==2) & (F3rwkesr2==1 | F3rwkesr2==2), col
tab recall_GHT F1rwkesr2 if (tpmsum1[_n+1]==0 | tpmsum2[_n+1]==0) & spell_length[_n+1]==2  & (rwkesr2==1 | rwkesr2==2) & (F3rwkesr2==1 | F3rwkesr2==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]==2  & (rwkesr2==1 | rwkesr2==2) & (F3rwkesr2==1 | F3rwkesr2==2), col

tab recall_GHT F1rwkesr2 if (tpmsum1[_n+1]==0 | tpmsum2[_n+1]==0) & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2) & (F4rwkesr2==1 | F4rwkesr2==2), col
tab recall_GHT F1rwkesr2 if (tpmsum1[_n+1]==0 | tpmsum2[_n+1]==0) & F4undur_en==4 & (rwkesr2==1 | rwkesr2==2) & (F5rwkesr2==1 | F5rwkesr2==2), col


* all but 45 instances occur when there is not a complete job spell
tab recall_GHT recallFM if EUEjob_GHT & undur<=3
tab recall_GHT recallFM if EUEjob_GHT==0 & undur<=3

* next, try to figure whether an individual is ever observed with 
* earnings on the FM job again.
capture drop never_again
capture drop never_before
bys ID (tt): gen never_again = (last_tt <= tt & recallFM==1)
bys ID (tt): gen never_before = (first_tt > tt & recallFM==1)
replace never_before=0 if never_again==1

count if recall_GHT==0 & recallFM==1 & EUEjob_GHT==1 & undur<=3
tab never_again if recall_GHT==0 & recallFM==1 & EUEjob_GHT==0 & undur<=3
tab never_before if recall_GHT==0 & recallFM==1 & EUEjob_GHT==0 & undur<=3

*bys ID: egen recallGHT = total(recall+recall2+recall3)
*replace recallGHT = (recallGHT>0 & recallGHT~=.)

*bys ID: egen recallGHT_cmplx = total(recall_cmplx + recall_cmplx2 + recall_cmplx3)
*replace recallGHT_cmplx = (recallGHT_cmplx>0 & recallGHT_cmplx~=.)

bysort ID (tt): gen candidate = (recallFM==1 & rwkesr2[_n+1]==4 & unemp_length <4)
gen recall_date = tt+unemp_length+1 if recallFM==1
tab recall_GHT candidate  if recall_date<last_tt-1

* tab recallGHT candidate  if recall_date<last_tt & tt>first_tt

* also no earnings on recall date
* temporary work is different from recall.
*ecflag, emoonlit

* need employed if rwkesr2==2

* list ID if undur[_n-1]==1 & rwkesr2[_n-1]==3 & rwkesr2==1

* the major flaw: you are not using information that workers NOT on 
* temporary layoff have lower job-finding probabilities because they 
* are less likely to be recalled. This is information that you would 
* like to use, but that you aren't.

* check month after

* validation exercise is only done for temporary layoffs. Not for 
* permanent separations.

* make sure that unemployment duration is preceded by employment
* look at absent without pay
* look at cases where there are two jobs listed.

* broader employment is rwkesr2==1 | rwkesr2==2

forvalues j = 1/5 {
  tostring rwkesr`j', generate(rwkesr`j'_str)
}
gen rwkesr_seq = rwkesr1_str + "-" + rwkesr2_str + "-" + rwkesr3_str + "-" + rwkesr4_str + "-" + rwkesr5_str if rwkesr5~=-1
replace rwkesr_seq = rwkesr1_str + "-" + rwkesr2_str + "-" + rwkesr3_str + "-" + rwkesr4_str + "-9" if rwkesr5==-1
tostring swave, generate(swave_str)
tostring srefmon, generate(srefmon_str)

gen WM = swave_str + "-" + srefmon_str
gen date = rhcalyr*100 + rhcalmn

* create a dataset of job id's and reported end dates (and create a 
* window, as people put end dates to the beginning of the month 
* after they stop their job). create 
* another dataset of jobids and defacto end dates. merge to giuseppe 
* recall dataset.

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

* zero earnings job: list swave srefmon rwkesr2 eeno1 eeno2 tpmsum1 
* tpmsum2 recallGHT recallFM unemp_length if ID == 113817

* can only infer recalls when the job information accords with the 
* survey-based measures

list swave srefmon rwkesr1 rwkesr2 rwkesr3 rwkesr4 rwkesr5 eeno1 
eeno2 tpmsum1 tpmsum2 recallGHT recallGHT_cmplx recallFM 
unemp_length if ID == 112894

list swave srefmon rwkesr1 rwkesr2 rwkesr3 rwkesr4 rwkesr5 eeno1 
eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length if ID == 
112049

list rhcalyr rhcalmn swave srefmon rwkesr1 rwkesr2 rwkesr3 rwkesr4 
rwkesr5 eeno1 eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length 
tsjdate1 if ID == 110416 /*start date is off*/

list rhcalyr rhcalmn swave srefmon rwkesr1 rwkesr2 rwkesr3 rwkesr4 
rwkesr5 eeno1 eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length 
tsjdate1 if ID == 100792 /*start date is off/*

* We use the job identifiers plus the self-reported timing of 
* earnings to ascertain when an individual is recalled. This 
* implicitly requires that the workers self-reported employment 
* status is consistent with the pattern of employment. 

* for FM data:
* create list of recall dates. then, check whether the worker 
* reports an earnings on the date where employment is resumed. If 
* no earnings: a) questionable whether the worker is employed, but 
* also, b) we have no data indicating that the worker was working at 
* that job for a particular month.

* If a job identifier is given, we know that a worker is working at 
* some point within a four-month period. However, we do not know 
* when in the month the worker is employed at that job. To generate 
* within-wave information, one must use additional data to infer the 
* timing: e.g., a) which months the worker is generating earnings, 
* or b) the start date. We use the months when a worker is producing 
* earnings, for the simple fact that start dates might precede the 
* if the worker is returning to a prior job from recall, and thus 
* will not clarify when a worker is returning to a previous job.

* GM do not impose that the timing of employment within the wave 
* matches the timing of jobs. Relatedly, they don't check which job 
* of the two jobID fields the worker is returning to after 
* unemployment.

tab recall_GHT elayoff if F1rwkesr2==4 & F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT elayoff if F1rwkesr2==4 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT elayoff if F1rwkesr2==4 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT elayoff if F1rwkesr2==4 & F4undur_en==4 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F4undur_en==4 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if srot==4 & F1undur_en==1 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if srot==4 & F2undur_en==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if srot==4 & F3undur_en==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if srot==4 & F4undur_en==4 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if unemp_length<=4 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if unemp_length>1 & unemp_length<=4 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]<=4 & (rwkesr2==1 | rwkesr2==2), col
tab recall F1rwkesr2 if spell_length[_n+1]<=4 & (rwkesr2==1 | rwkesr2==2), col

tab recall_GHT F1rwkesr2 if spell_length[_n+1]<=4 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col

tab recall_GHT F1rwkesr2 if spell_length[_n+1]==1 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]==2 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]==3 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]==4 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recall_GHT F1rwkesr2 if spell_length[_n+1]==5 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recall_GHT F1rwkesr2 if (rwkesr2==1 | rwkesr2==2), col

tab recallFM F1rwkesr2 if spell_length[_n+1]==1 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recallFM F1rwkesr2 if spell_length[_n+1]==2 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recallFM F1rwkesr2 if spell_length[_n+1]==3 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recallFM F1rwkesr2 if spell_length[_n+1]==4 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recallFM F1rwkesr2 if spell_length[_n+1]==5 & (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+5]==1 | rwkesr2[_n+5]==2), col
tab recallFM F1rwkesr2 if (rwkesr2==1 | rwkesr2==2), col


* contingent work is explicitly not included
* epdjbthn    %2f "Paid job ..." important!

* A really good one: 
list date WM rwkesr_seq eeno1 eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length job jID ecflag emoonlit  if ID == 87986
* was moonlighting

A subtle one:
list date WM rwkesr_seq eeno1 eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length tsjdate1 tsjdate2 job jID if ID == 112049, header(40)


forvalues j = 1/5 {
  tostring rwkesr`j', generate(rwkesr`j'_str)
}


tostring swave, generate(swave_str)
tostring srefmon, generate(srefmon_str)

gen WM = swave_str + "-" + srefmon_str
gen date = rhcalyr*100 + rhcalmn
show that job variable is wrong

* really good one: tejdate* shows the job ending, reflected in 
* tpmsum*, bk
list date swave srefmon rwkesr_seq tpearn eeno1 eeno2 tpmsum1 tpmsum2 recallGHT recallFM unemp_length tpyrate1 tpyrate2 job jID tejdate1 tejdate2 if ID == 87986, header(20)

* try to capture cases where person is still making money from 
* recall job. if more likely when rwkesr2==4, more likely to be 
* "mistake"




* infer recalls when: earnings data does not indicate that the 
* worker is at a particular job (and often, start date is consistent 
* with the timing of earnings)

* infer recalls when: pattern of earnings does not allow you to 
* discern the timing of recalls within a wave.

look at FM recalls where tpmsum1==0 and tpmsum2==0
by ID (tt), sort: gen FM_recall_date = (recall
