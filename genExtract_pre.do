set more off
clear all
capture log close

log using "`base'/logfiles/genExtract_pre.log", replace

set seed 19840317

forvalues year=90 {

* I.	Append Corrected JobID variables to Core Wave files

* Ia.  Prepare core wave files for merge with jobid corrections
use panel suid entry pnum wave ws12002 ws22102 refmth if refmth==4 using "`tbase'/p`year'.dta", clear
drop refmth
rename ws12002 jobid1
rename ws22102 jobid2
reshape long jobid, i(panel suid entry pnum wave)
sort panel suid entry pnum wave jobid
rename _j j
save "`tbase'/JobIDprep`year'.dta", replace

* Ib.	Prepare jobid revision file for merge
use panel suid entry pnum wave jobid jobid_revised using "`tbase'/jid`year'.dta", clear
sort panel suid entry pnum wave jobid
merge 1:m panel suid entry pnum wave jobid using "`tbase'/JobIDprep`year'.dta", keepusing(j)
rename _merge JobIDMerge
tab JobIDMerge
drop if JobIDMerge==1 // drop if individual is only in jobid file (master), not core wave file
drop JobIDMerge
reshape wide jobid jobid_revised, i(panel suid entry pnum wave) j(j)
sort panel suid entry pnum wave jobid1 jobid2
save "`tbase'/JobIDindex`year'.dta", replace

* Ic.	Merge outputs from Ia and Ib
use suid pnum entry panel wave refmth ws1amt ws2amt njobs ws12002 ///
  ws22102	year month refmth using "`tbase'/p`year'.dta", clear
rename ws12002 jobid1
rename ws22102 jobid2
sort panel suid entry pnum wave jobid1 jobid2
merge panel suid entry pnum wave jobid1 jobid2 using "`tbase'/JobIDindex`year'.dta"
tab _merge
keep if _merge==3
drop _merge
sort panel suid entry pnum wave
save "`tbase'/p`year'_goodID.dta", replace

rm "`tbase'/JobIDprep`year'.dta"
rm "`tbase'/JobIDindex`year'.dta"


* II. Within-month jobid records
use suid pnum entry panel wave refmth jobid1 jobid_revised1 jobid2 jobid_revised2 ///
	ws1amt ws2amt njobs year month ///
	using "`tbase'/p`year'_goodID.dta", replace

replace year = year + 1900 if year<100
gen tt = ym(year,month)
format tt %tm

* IIa.  Within month records
egen ID = group(suid pnum entry)  // temporary ID variable
rename jobid1 j1
rename jobid_revised1 j1r
rename jobid2 j2
rename jobid_revised2 j2r

gen mj=0  // "major job"
replace mj = 1 if ws1amt>0 & ws2amt==0
replace mj = 2 if ws2amt>0 & ws1amt==0

gen tj=0  // "two jobs"
replace tj=1 if ws1amt>0 & ws2amt>0

by panel ID wave (refmth), sort: egen j1t=total(ws1amt>0)  // within month job tenure
by panel ID wave (refmth), sort: egen j2t=total(ws2amt>0)

by panel ID wave (refmth), sort: egen j1r_fm = min(refmth*(ws1amt>0)+10*(ws1amt<=0)) //find starting refmth within wave
by panel ID wave (refmth), sort: egen j1r_lm = max(refmth*(ws1amt>0)-10*(ws1amt<=0))
replace j1r_fm = 0 if ws1amt==.  // precaution
replace j1r_lm = 0 if ws1amt==.
replace j1r_fm = 0 if j1r_fm==10
replace j1r_lm = 0 if j1r_lm==-10

by panel ID wave (refmth), sort: egen j2r_fm = min(refmth*(ws2amt>0)+10*(ws2amt<=0)) //find starting refmth within wave
by panel ID wave (refmth), sort: egen j2r_lm = max(refmth*(ws2amt>0)-10*(ws2amt<=0)) //find starting refmth within wave
replace j2r_fm = 0 if ws2amt==.  // precaution
replace j2r_lm = 0 if ws2amt==.  
replace j2r_fm = 0 if j2r_fm==10
replace j2r_lm = 0 if j2r_lm==-10

forvalues j=1/4 {
by panel ID wave (refmth), sort: gen njmth`j'=njob[`j']
}
*this is the point to stop
keep if refmth==4

by panel suid entry pnum (wave), sort: egen mw=min(wave)
by panel suid entry pnum (wave), sort: gen wflag=wave-mw+1-_n
gen wflag2=wflag
by panel suid entry pnum (wave), sort: replace wflag=0 if wflag2[_n]==wflag2[_n-1] & _n~=1
drop wflag2 mw
replace wflag=0 if (j1r==. | j1r==0) & (j2r==. | j2r==0)
xtset ID wave
tsfill
sort ID suid entry pnum
by ID: replace suid=suid[_N] if suid==""
by ID: replace entry=entry[_N] if entry==""
by ID: replace pnum=pnum[_N] if pnum==""
by ID: replace panel=panel[_N] if panel==.



// IIb. Tenure flags
replace wflag = -1 if wflag==.

gen j1rflag=0
gen j2rflag=0

gen twoj_before=0
by ID (wave), sort: replace twoj_before = 1 if (j1r_lm[_n-1]==4 & j2r_lm[_n-1]==4) & wflag==-1
gen twoj_after=0
by ID (wave), sort: replace twoj_after = 1 if (j1r_fm[_n+1]==1 & j2r_fm[_n+1]==1) & wflag==-1
by ID (wave), sort: gen twoj_before_onej_after = (twoj_before==1 & (j1r[_n+1]~=. | j2r[_n+1]~=.))
by ID (wave), sort: gen twoj_after_onej_before = (twoj_after==1 & (j1r[_n-1]~=. | j2r[_n-1]~=.))
by ID (wave), sort: gen badflag=(twoj_before_onej_after==1 | twoj_after_onej_before==1)

// Type 1 change: ending job in wave[_n-1] is beginning job in wave[_n]
by ID (wave), sort: replace j1rflag=1 if ((j1r_lm[_n-1]==4 & j1r_fm[_n+1]==1 & j1r[_n-1]==j1r[_n+1])  | ///
  (j1r_lm[_n-1]==4 & j2r_fm[_n+1]==1 & j1r[_n-1]==j2r[_n+1])) & j1r[_n-1]~=. & wflag[_n+1]==1 & wflag[_n]==-1

by ID (wave), sort: replace j1r = j1r[_n-1] if j1rflag==1
by ID (wave), sort: replace j1r_fm = 1 if j1rflag==1
by ID (wave), sort: replace j1r_lm = 4 if j1rflag==1

by ID (wave), sort: replace j2rflag = 1 if ((j2r_lm[_n-1]==4 & j2r_fm[_n+1]==1 & j2r[_n-1]==j2r[_n+1]) | ///
  (j2r_lm[_n-1]==4 & j1r_fm[_n+1]==1 & j2r[_n-1]==j1r[_n+1])) & j2r[_n-1]~=. & wflag[_n+1]==1 & wflag[_n]==-1

by ID (wave), sort: replace j2r = j2r[_n-1] if j2rflag==1
by ID (wave), sort: replace j2r_fm = 1 if j2rflag==1
by ID (wave), sort: replace j2r_lm = 4 if j2rflag==1


// Type 2 change: End of job not observed.
by ID (wave), sort: replace j1rflag = 2 if (j1r_lm[_n-1]==4 & j1r[_n-1]~=j1r[_n+1] & j1r[_n-1]~=j2r[_n+1]) ///
  & j1r[_n-1]~=. & wflag[_n+1]==1 & j1rflag==0 & wflag[_n]==-1 & badflag==0

replace j1r = j1r[_n-1] if j1rflag==2
replace j1r_fm = 1 if j1rflag==2
replace j1r_lm = 2 if j1rflag==2

by ID (wave), sort: replace j2rflag = 2 if (j2r_lm[_n-1]==4 & j2r[_n-1]~=j1r[_n+1] & j2r[_n-1]~=j2r[_n+1]) ///
  & j2r[_n-1]~=. & wflag[_n+1]==1 & j2rflag==0 & wflag[_n]==-1 & badflag==0

replace j2r = j2r[_n-1] if j2rflag==2
replace j2r_fm = 1 if j2rflag==2
replace j2r_lm = 2 if j2rflag==2

// Type 3 change: Beginning of job not observed.
by ID (wave), sort: replace j1rflag=3 if (j1r_fm[_n+1]==1 & j1r[_n-1]~=j1r[_n+1] & j2r[_n-1]~=j1r[_n+1]) ///
  & j1r[_n+1]~=. & wflag[_n+1]==1 & wflag==-1 & j1rflag==0 & badflag==0
replace j1r = j1r[_n+1] if j1rflag==3
replace j1r_fm = 3 if j1rflag==3
replace j1r_lm = 4 if j1rflag==3

by ID (wave), sort: replace j2rflag=4 if (j1r_fm[_n+1]==1 & j1r[_n-1]~=j1r[_n+1] & j2r[_n-1]~=j1r[_n+1]) ///
  & j1r[_n+1]~=. & wflag[_n+1]==1 & wflag==-1 & j1rflag==2 & j2rflag==0 & badflag==0
replace j2r = j1r[_n+1] if j2rflag==4
replace j2r_fm = 3 if j2rflag==4
replace j2r_lm = 4 if j2rflag==4

by ID (wave), sort: replace j2rflag=3 if (j2r_fm[_n+1]==1 & j1r[_n-1]~=j2r[_n+1] & j2r[_n-1]~=j2r[_n+1]) ///
  & j2r[_n+1]~=. & wflag[_n+1]==1 & wflag==-1 & j2rflag==0 & badflag==0
replace j2r = j2r[_n+1] if j2rflag==3
replace j2r_fm = 3 if j2rflag==3
replace j2r_lm = 4 if j2rflag==3

replace j1rflag=-1 if badflag==1 & j1rflag==0 & wflag==-1
replace j2rflag=-1 if badflag==1 & j2rflag==0 & wflag==-1
replace badflag=0 if j1rflag==1 | j2rflag==1

replace j1r_fm = 0 if j1r_fm==. & j1rflag==0 & j2rflag==0 & wflag==-1
replace j1r_lm = 0 if j1r_lm==. & j1rflag==0 & j2rflag==0 & wflag==-1
replace j2r_fm = 0 if j2r_fm==. & j1rflag==0 & j2rflag==0 & wflag==-1
replace j2r_lm = 0 if j2r_lm==. & j1rflag==0 & j2rflag==0 & wflag==-1

replace j1t=j1r_lm-j1r_fm+1 if wflag==-1 & j1r_fm==. & j1r_lm==.
replace j2t=j2r_lm-j2r_fm+1 if wflag==-1 & j2r_fm==. & j2r_lm==.

forvalues i=1(1)4 {
gen m`i'=0
replace m`i'=1 if (j1r_fm<=`i' & j1r_lm>=`i') | (j2r_fm<=`i' & j2r_lm>=`i')
}

drop njob ID
sort panel suid entry pnum wave refmth
save "`tbase'/p`year'_jobs.dta", replace
rm "`tbase'/p`year'_goodID.dta"



* IIb. Across month records


use panel suid entry pnum wave tt j1r j2r j1t j2t j1r_fm j2r_fm j1r_lm j2r_lm j1rflag j2rflag wflag using "`tbase'/p`year'_jobs.dta", clear
 
*calculate job tenure
rename j1r jr1
rename j2r jr2
rename j1t jt1
rename j2t jt2
rename j1r_fm jfm1
rename j2r_fm jfm2
rename j1r_lm jlm1
rename j2r_lm jlm2
rename j1rflag jflag1
rename j2rflag jflag2
reshape long jr jt jfm jlm jflag, i(panel suid entry pnum wave wflag tt) j(jobt)

egen ID = group(panel suid entry pnum)
by ID jr (wave), sort: replace jt=jt-1 if _n==1 // count from zero
replace jt=0 if jt==-1
by ID jr (wave), sort: egen jmd=min(tt)  // "job min date" - kind of lame for an acronym, I know
by ID jr (wave), sort: gen fa=jfm[1]
by ID jr (wave), sort: replace jmd=jmd-(4-fa) 
by ID jr (wave), sort: gen ct=sum(jt)
replace jmd=. if jr==.
drop ID
reshape wide jr jt jfm fa ct jlm jflag jmd, i(panel suid entry pnum wave tt wflag) j(jobt)
rename fa1 j1fa
rename fa2 j2fa
rename ct1 j1ct
rename ct2 j2ct
rename jflag1 j1rflag
rename jflag2 j2rflag
rename jmd1 j1md
rename jmd2 j2md
rename jr1 j1r
rename jr2 j2r
rename jfm1 j1r_fm 
rename jfm2 j2r_fm
rename jlm1 j1r_lm
rename jlm2 j2r_lm
keep panel suid entry pnum wave j1r j2r j1ct j2ct j1rflag j2rflag wflag j1r_fm j1r_lm j2r_fm j2r_lm j1md j2md
sort panel suid entry pnum wave
save "`tbase'/p`year'jt.dta", replace // say what this is.

// merging topical module to get start dates

use "`tbase'/p`year'_jobs.dta", clear 
sort panel suid entry pnum wave
merge 1:1 panel suid entry pnum wave using "`tbase'/p`year'jt.dta"
tab _merge
keep if _merge==3
drop _merge
sort panel suid entry pnum wave 

save "`tbase'/temp.dta", replace

if `year'==90 | `year'== 91 {
// 

use panel suid entry pnum panel wave tt wflag j1 j2 j1r j2r j1r_fm j2r_fm j1r_lm j2r_lm j1ct j2ct j1md j2md  ///
	 j1rflag j2rflag using "`tbase'/temp.dta", clear
sort panel suid entry pnum wave

merge 1:m panel suid entry pnum wave using "`tbase'/tm`year'.dta", keepusing(tmjob tmjobp TJyr TJmth)
tab _merge
drop if _merge==2 // only in using data.
drop _merge

sort panel suid entry pnum wave
save "`tbase'/temp.dta", replace //overwrite previous temp
drop wflag
egen ID= group(suid entry pnum)

replace TJyr=. if TJyr==0
replace TJmth=. if TJmth==0
gen TJst=ym(TJyr,TJmth)
drop TJyr TJmth
format %tm TJst
capture drop j1sd
capture drop j2sd
gen j1sd=.
gen j2sd=.
format %tm j1sd j2sd

* start date flag
gen sdflag1=0
gen sdflag2=0

by ID (wave), sort: replace sdflag1 = 1 if tt-3>TJst & j1==tmjobp & (tmjobp>0 & tmjobp<.) 
by ID (wave), sort: replace j1sd = TJst if tt-3>TJst & j1==tmjobp & (tmjobp>0 & tmjobp<.)

by ID (wave), sort: replace sdflag1 = 1 if tt[_n+1]-3>TJst[_n+1] & j1[_n]==tmjobp[_n+1] & (tmjobp[_n+1]>0 & tmjobp[_n+1]<.) 
by ID (wave), sort: replace j1sd = TJst[_n+1] if tt[_n+1]-3>TJst[_n+1] & j1[_n]==tmjobp[_n+1] & (tmjobp[_n+1]>0 & tmjobp[_n+1]<.)

by ID (wave), sort: replace sdflag2 = 2 if tt-3>TJst & j2==tmjobp & (tmjobp>0 & tmjobp<.)
by ID (wave), sort: replace j2sd = TJst if tt-3>TJst & j2==tmjobp & (tmjobp>0 & tmjobp<.)

by ID (wave), sort: replace sdflag2 = 2 if tt[_n+1]-3>TJst[_n+1] & j2[_n]==tmjobp[_n+1] & (tmjobp[_n+1]>0 & tmjobp[_n+1]<.) 
by ID (wave), sort: replace j2sd = TJst[_n+1] if tt[_n+1]-3>TJst[_n+1] & j2[_n]==tmjobp[_n+1] & (tmjobp[_n+1]>0 & tmjobp[_n+1]<.)

by ID (wave), sort: replace sdflag1 = 1 if tt-3>TJst & j1==tmjob & (tmjob>0 & tmjob<.)
by ID (wave), sort: replace j1sd = TJst if tt-3>TJst & j1==tmjob & (tmjob>0 & tmjob<.)

by ID (wave), sort: replace sdflag1 = 1 if tt[_n+1]-3>TJst[_n+1] & j1[_n]==tmjob[_n+1] & (tmjob[_n+1]>0 & tmjob[_n+1]<.)
by ID (wave), sort: replace j1sd = TJst[_n+1] if tt[_n+1]-3>TJst[_n+1] & j1[_n]==tmjob[_n+1] & (tmjob[_n+1]>0 & tmjob[_n+1]<.)

by ID (wave), sort: replace sdflag2 = 1 if tt-3>TJst & j2==tmjob & (tmjob>0 & tmjob<.)
by ID (wave), sort: replace j2sd = TJst if tt-3>TJst & j2==tmjob & (tmjob>0 & tmjob<.)

by ID (wave), sort: replace sdflag2 = 1 if tt[_n+1]-3>TJst[_n+1] & j2[_n]==tmjob[_n+1] & (tmjob[_n+1]>0 & tmjob[_n+1]<.) 
by ID (wave), sort: replace j2sd = TJst[_n+1] if tt[_n+1]-3>TJst[_n+1] & j2[_n]==tmjob[_n+1] & (tmjob[_n+1]>0 & tmjob[_n+1]<.)

by ID (wave), sort: replace sdflag1 = 1 if j1[_n]==j1[_n-1] & wave==2 & tmjob==0 & tmjobp==0 & tt-3>TJst 
by ID (wave), sort: replace j1sd=TJst if j1[_n]==j1[_n-1] & wave==2 & tmjob==0 & tmjobp==0 & tt-3>TJst

by ID (wave), sort: replace sdflag1= 1 if j1[_n]~=j1[_n-1] & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1] & j1sd==. & j1ct==3 
by ID (wave), sort: replace j1sd=TJst[_n+1] if j1[_n]~=j1[_n-1] & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1] & j1sd==. & j1ct==3

by ID (wave), sort: replace sdflag1 = 1 if j1[_n]~=0 & j1[_n+1]==0 & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1] 
by ID (wave), sort: replace j1sd=TJst[_n+1] if j1[_n]~=0 & j1[_n+1]==0 & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1]

by ID (wave), sort: replace sdflag1 = 1 if j1[_n]~=j1[_n-1] & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1] & j1sd==. & j1ct==3 
by ID (wave), sort: replace j1sd=TJst[_n+1] if j1[_n]~=j1[_n-1] & wave==1 & tmjob[_n+1]==0 & tmjobp[_n+1]==0 & tt[_n+1]-3>TJst[_n+1] & j1sd==. & j1ct==3

by ID (wave), sort: replace sdflag1 = 2 if wave==1 & ((j1[_n]==tmjob[_n+1]) | (j1[_n]==tmjobp[_n+1])) & ((j1sd[_n+1]>tt[_n]-3 & j1sd[_n]~=.) | (j1sd[_n]>tt[_n]-3 & j1sd[_n]~=.))
by ID (wave), sort: replace sdflag1 = 2 if wave==2 & sdflag1[_n-1]==2 

by ID (wave), sort: replace sdflag1 = 2 if wave==2 & (j1==tmjob | j1==tmjobp) & (j1sd[_n]>tt[_n-1]-3 & j1sd~=. | j1sd[_n-1]>tt[_n-1]-3 & j1sd~=.)
by ID (wave), sort: replace sdflag1 = 2 if wave==1 & sdflag1[_n-1]==2

by ID (wave), sort: replace sdflag2 = 2 if wave==1 & ((j2[_n]==tmjob[_n+1]) | (j2[_n]==tmjobp[_n+1])) & ((j2sd[_n+1]>tt[_n]-3 & j2sd[_n]~=.) | (j2sd[_n]>tt[_n]-3 & j2sd[_n]~=.))
by ID (wave), sort: replace sdflag2 = 2 if wave==2 & sdflag2[_n-1]==2 

by ID (wave), sort: replace sdflag2 = 2 if wave==2 & (j2==tmjob | j2==tmjobp) & (j2sd[_n]>tt[_n-1]-3 & j2sd~=. | j2sd[_n-1]>tt[_n-1]-3 & j2sd~=.)
by ID (wave), sort: replace sdflag2 = 2 if wave==1 & sdflag2[_n-1]==2

by ID (wave), sort: replace sdflag1 = 2 if wave==1 & tmjob[_n+1]==0 & tmjob[_n]==0 & TJst[_n+1]>tt[_n]-3
by ID (wave), sort: replace sdflag1 = 2 if wave==2 & sdflag1[_n-1]==2

by ID (wave), sort: replace sdflag2 = 2 if wave==1 & tmjob[_n+1]==0 & tmjob[_n]==0 & TJst[_n+1]>tt[_n]-3
by ID (wave), sort: replace sdflag2 = 2 if wave==2 & sdflag2[_n-1]==2


by ID (wave), sort: replace sdflag1 = 2 if j1sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j1ct==3 & (tmjobp[_n+1]==j1[_n] | tmjob[_n+1]==j1[_n]) 

by ID (wave), sort: replace sdflag1 = 2 if j1sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j1ct==3 & (tmjobp[_n+1]==j1[_n] | tmjob[_n+1]==j1[_n]) 
by ID (wave), sort: replace j1sd=tt-4+j1r_fm if j1sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j1ct==3


by ID (wave), sort: replace sdflag2 = 2 if j2sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j2ct==3 & (tmjobp[_n+1]==j2[_n] | tmjob[_n+1]==j2[_n]) 
by ID (wave), sort: replace j2sd=tt-4+j2r_fm if j2sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j2ct==3

rename j1r jr1
rename j2r jr2
rename j1r_fm jfm1
rename j2r_fm jfm2
rename j1r_lm jlm1
rename j2r_lm jlm2
rename j1ct jct1
rename j2ct jct2
rename j1md jmd1
rename j2md jmd2
rename j1sd jsd1
rename j2sd jsd2

reshape long jr jct jfm jlm jmd jsd sdflag, i(panel suid entry pnum wave tt TJst) j(t)
by ID jr (wave), sort: egen jsdt = max(jsd)
replace jsd = jsdt
drop jsdt
replace sdflag=3 if jsd==. & jmd~=.

gen fjsd=.
by ID jr (wave), sort: replace fjsd = jsd if ((sdflag[1]==1 | sdflag[2]==1)|(sdflag[1]==2 | sdflag[2]==2))
by ID jr (wave), sort: replace fjsd = jmd if (sdflag[1]==3 | sdflag[2]==3)
gen jfct=0  // job final cumulative tenure
by ID jr (wave), sort: replace jfct=jct if ((sdflag[1]==2 | sdflag[2]==2) | (sdflag[1]==3 | sdflag[2]==3))
by ID jr (wave), sort: replace jfct=jct+(tt[1]-3-fjsd[1]) if (sdflag[1]==1 & (sdflag[2]~=2 & sdflag[2]~=3) | sdflag[2]==1) 
by ID jr (sdflag), sort: replace sdflag=sdflag[_N]

sort panel suid entry pnum jr


reshape wide jr jct jfm jlm jmd jsd sdflag fjsd jfct, i(panel suid entry pnum wave tt TJst) j(t)
rename sdflag1 j1sdflag
rename sdflag2 j2sdflag
rename jsd1 j1sd
rename jsd2 j2sd
rename fjsd1 j1fsd
rename fjsd2 j2fsd
rename jfct1 j1fct
rename jfct2 j2fct

keep panel suid entry pnum wave j1r j2r j1sdflag j2sdflag j1fsd j2fsd TJst j1fct j2fct j1sdflag j2sdflag
sort panel suid entry pnum wave
}

if `year'==92 | `year'==93 {

use panel suid entry pnum panel wave wflag tt j1 j2 j1r j2r j1r_fm j2r_fm j1r_lm j2r_lm j1ct j2ct j1md j2md  ///
  j1rflag j2rflag using "`tbase'/temp.dta", clear
sort panel suid entry pnum wave
merge 1:m panel suid entry pnum wave using "`tbase'/tm`year'.dta", keepusing(tmjob tmjobp TJyr TJmth)
tab _merge
drop if _merge==2 // only in using data.
drop _merge

sort panel suid entry pnum wave
save "`tbase'/temp.dta", replace // overwrite previous temp
drop wflag

egen ID= group(suid entry pnum)

replace TJyr=. if TJyr==0
replace TJmth=. if TJmth==0
gen TJst=ym(TJyr,TJmth)
drop TJyr TJmth
format %tm TJst
capture drop j1sd
capture drop j2sd
gen j1sd=.
gen j2sd=.
format %tm j1sd j2sd
format %tm j1md j2md

*start date flag
gen sdflag1=0
gen sdflag2=0
by ID (wave), sort: replace sdflag1 = 1 if tt-3>TJst & j1==tmjob & (tmjob>0 & tmjob<.) & wave==1
by ID (wave), sort: replace sdflag2 = 1 if tt-3>TJst & j2==tmjob & (tmjob>0 & tmjob<.)
by ID (wave), sort: replace sdflag1 = 1 if j1[_n]~=0 & wave==1 & tmjob==0 & tt-3>TJst

by ID (wave), sort: replace j1sd = TJst if tt-3>TJst & j1==tmjob & (tmjob>0 & tmjob<.) & wave==1
by ID (wave), sort: replace j2sd = TJst if tt-3>TJst & j2==tmjob & (tmjob>0 & tmjob<.)
by ID (wave), sort: replace j1sd=TJst if j1[_n]~=0 & wave==1 & tmjob==0 & tt-3>TJst

by ID (wave), sort: replace sdflag1 = 2 if (j1sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j1ct==3)
by ID (wave), sort: replace j1sd=tt-4+j1r_fm if (j1sd==. & wave==1 & TJst[_n+1]>tt[_n]-3 & j1ct==3)

rename j1r jr1
rename j2r jr2
rename j1r_fm jfm1
rename j2r_fm jfm2
rename j1r_lm jlm1
rename j2r_lm jlm2
rename j1ct jct1
rename j2ct jct2
rename j1md jmd1
rename j2md jmd2
rename j1sd jsd1
rename j2sd jsd2

reshape long jr jct jfm jlm jmd jsd sdflag, i(panel suid entry pnum wave tt TJst) j(t)
by ID jr (wave), sort: egen jsdt = max(jsd)
replace jsd = jsdt
drop jsdt
replace sdflag=3 if jsd==. & jmd~=.

gen fjsd=.
by ID jr (wave), sort: replace fjsd = jsd if ((sdflag[1]==1 | sdflag[2]==1)|(sdflag[1]==2 | sdflag[2]==2))
by ID jr (wave), sort: replace fjsd = jmd if (sdflag[1]==3 | sdflag[2]==3)
gen jfct=0  // job final cumulative tenure
by ID jr (wave), sort: replace jfct=jct if ((sdflag[1]==2 | sdflag[2]==2) | (sdflag[1]==3 | sdflag[2]==3))
by ID jr (wave), sort: replace jfct=jct+(tt[1]-3-fjsd[1]) if (sdflag[1]==1 | sdflag[2]==1)
by ID jr (sdflag), sort: replace sdflag=sdflag[_N]

reshape wide jr jct jfm jlm jmd jsd sdflag fjsd jfct, i(panel suid entry pnum wave tt TJst) j(t)
rename sdflag1 j1sdflag
rename sdflag2 j2sdflag
rename jsd1 j1sd
rename jsd2 j2sd
rename fjsd1 j1fsd
rename fjsd2 j2fsd
rename jfct1 j1fct
rename jfct2 j2fct

sort panel suid entry pnum, stable
by panel suid entry pnum: egen has_job_flag = total((j1sdflag~=0 & j1sdflag~=.) + (j2sdflag~=0 & j2sdflag~=.))
replace has_job_flag = (has_job_flag>0 & has_job_flag~=.)

keep panel suid entry pnum wave j1sdflag j2sdflag j1sd j2sd j1fsd j2fsd TJst j1fct j2fct j1sdflag j2sdflag
sort panel suid entry pnum wave
}


merge 1:1 panel suid entry pnum wave using "`tbase'/temp.dta"
tab _merge
drop _merge
save "`tbase'/p`year'sd.dta", replace

 }

forvalues year=90(1)93 {
use panel suid entry pnum wave ethnicty age ms higrade grd_cmp att_sch disab in_af jobid1 jobid2 wksem1 wksem2 ernam1 ernam2 wshrs1 wshrs2 /// 
	pp_mis hrrat1 hrrat2 busid1 busid2 pp_intv ws_i1 ws_i2 refmth pnlwgt using "`tbase'/fp`year'.dta", clear 
sort panel suid entry pnum wave refmth

#delimit;
merge m:m panel suid entry pnum wave refmth using 
"`tbase'/p`year'.dta", keepusing(refmth sex race esr inaf  
  brthyr wkswop wksjob h5mis se12202 
	fnlwgt p5wgt year month 
  ws1wks ws12025 ws12026 ws12028 iws12028
	ws2wks ws22125 ws22126 ws22128 iws22128 
  ws1amt ws2amt ws1calc ws2calc 
  ws12044 ws12046 ws22144 ws22146);
#delimit cr
rename ws1wks j1wks
rename ws12025 j1hrs
rename ws12026 j1hrly
rename ws12028 j1hrat
rename iws12028 ij1hrat
rename ws2wks j2wks
rename ws22125 j2hrs
rename ws22126 j2hrly
rename ws22128 j2hrat
rename iws22128 ij2hrat
rename ws1amt j1amt
rename ws2amt j2amt
rename ws1calc ij1amt
rename ws2calc ij2amt 
gen union1 = (ws12044==1 | ws12046==1)
gen union2 = (ws22144==1 | ws22146==1)
drop ws12044 ws12046 ws22144 ws22146
rename _merge wmerge
sum j1wks if wmerge==1 // should be empty

keep if refmth==4
drop refmth

sort panel suid entry pnum wave
merge 1:1 panel suid entry pnum wave using "`tbase'/p`year'sd.dta", ///
 keepusing(j1r j2r j1rflag j2rflag wflag j1fct j2fct j1fsd j2fsd ///
  j1sdflag j2sdflag)
save "`tbase'/final`year'.dta", replace
tab _merge 
drop _merge


merge 1:1 panel suid entry pnum wave using "`tbase'/p`year'_jobs.dta", ///
 keepusing(mj njmth1 njmth2 njmth3 njmth4)
tab _merge 
drop _merge


save "`tbase'/final`year'.dta", replace
}

* V. Append all files
use "`tbase'/final90.dta", replace
forvalues year=91/93 {
append using "`tbase'/final`year'.dta"
}

sort panel suid entry pnum wave
egen ID=group(panel suid entry pnum)

save "`tbase'/ad.1990t93.dta", replace

save "`tbase'/ad1990t93tmp.dta", replace
/* -- Previous duration -- */
use "`tbase'/ad.1990t93.dta", clear

use "`tbase'/ad1990t93tmp.dta", clear

rename j1r jr
sort panel suid entry pnum jr
merge m:1 panel suid entry pnum jr using "`tbase'/index_y90t93.dta" 

tab _merge
drop if _merge==2
drop _merge
sort panel suid entry pnum wave jr
merge m:m panel suid entry pnum wave jr using "`tbase'/spell_y90t93.dta"
tab _merge
drop if _merge==2
drop _merge


rename spell spell_j1
rename spell_length spell_length_j1
rename jr j1r
rename pdur pdur1
rename pudur pudur1
rename occ occ_j1
rename ind ind_j1
rename jstart_tt jstart_tt1
rename jend_tt jend_tt1
rename occ_switch occ_switch_j1
rename ind_switch ind_switch_j1

rename j2r jr
sort panel suid entry pnum jr
merge m:1 panel suid entry pnum jr using "`tbase'/index_y90t93.dta" 
tab _merge
drop if _merge==2
drop _merge
sort panel suid entry pnum wave jr
merge m:m panel suid entry pnum wave jr using "`tbase'/spell_y90t93.dta"
tab _merge
drop if _merge==2
drop _merge
rename jr j2r
rename pdur pdur2
rename pudur pudur2
rename spell spell_j2
rename spell_length spell_length_j2
rename occ occ_j2
rename ind ind_j2
rename jstart_tt jstart_tt2
rename jend_tt jend_tt2
rename occ_switch occ_switch_j2
rename ind_switch ind_switch_j2

save "`tbase'/ad.1990t93.dta", replace
