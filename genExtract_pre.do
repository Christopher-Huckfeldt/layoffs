set more off
clear all

capture log close

log using ./logfiles/genExtract_pre.log, replace

set seed 19840317


local year = 93

* I.	Append Corrected JobID variables to Core Wave files

* Ia.  Prepare core wave files for merge with jobid corrections
use panel suid entry pnum wave ws12002 ws22102 refmth using ./tmpdata/p`year'.dta, clear
rename ws12002 jobid1
rename ws22102 jobid2
keep if refmth==4
reshape long jobid, i(panel suid entry pnum wave)
sort panel suid entry pnum wave jobid
rename _j j
save ./tmpdata/JobIDprep`year'.dta, replace

local year = 93
* Ib.	Prepare jobid revision file for merge
use ./tmpdata/jid`year'.dta, clear
use panel suid entry pnum wave jobid jobid_revised flag_jobid_chan using ./tmpdata/jid`year'.dta, clear
sort panel suid entry pnum wave jobid
merge 1:m panel suid entry pnum wave jobid using ./tmpdata/JobIDprep`year'.dta, keepusing(j)
rename _merge JobIDMerge

tab JobIDMerge
drop if JobIDMerge==1 // drop if individual is only in jobid file (master), not core wave file
drop JobIDMerge
drop flag_jobid_chan // 10% of jobid's are revised
reshape wide jobid jobid_revised, i(panel suid entry pnum wave) j(j)
sort panel suid entry pnum wave jobid1 jobid2
save ./tmpdata/JobIDindex`year'.dta, replace


* Ic.	Merge outputs from Ia and Ib
use suid pnum entry panel wave refmth njobs ws12002 ///
  ws22102	year month refmth using ./tmpdata/p`year'.dta, clear
rename ws12002 jobid1
rename ws22102 jobid2
sort panel suid entry pnum wave jobid1 jobid2
merge panel suid entry pnum wave jobid1 jobid2 using ./tmpdata/JobIDindex`year'.dta
tab _merge
keep if _merge==3
drop _merge
sort panel suid pnum entry wave refmth
save ./tmpdata/p`year'_goodID.dta, replace

sh rm ./tmpdata/JobIDprep`year'.dta
sh rm ./tmpdata/JobIDindex`year'.dta


* II. Within-month jobid records
#delimit;
use panel suid pnum entry wave refmth 
  year month weeks
  wesr1-wesr5 wksjob wkswop reasab
  intvw fnlwgt p5wgt
	ws1amt ws2amt njobs 
  ws1occ ws2occ ws1ind ws2ind
	using ./tmpdata/p`year'.dta, replace;
#delimit cr

sort panel suid pnum entry wave refmth
merge m:1 panel suid pnum entry wave refmth using ./tmpdata/p`year'_goodID.dta
drop _merge

*jobid1 jobid2
rename jobid_revised1 ej1
rename jobid_revised2 ej2
rename ws1amt tpmsum1
rename ws2amt tpmsum2

replace year = year + 1900 if year<100
gen tt = ym(year,month)
format tt %tm

save ./tmpdata/p93_extract.dta, replace

  * -------
  * job information
  * -------
  
  use ./tmpdata/p93_extract.dta, clear
  egen ID = group(suid pnum entry)
  drop if ID==.

  gen ti = refmth + (wave-1)*4
  drop if ti==0
  
  frame put ID ti ej1 ej2 tpmsum1 tpmsum2, into(jobs)
  frame change jobs
  keep ID ti ej1 ej2 tpmsum1 tpmsum2
  reshape long ej tpmsum, i(ID ti) j(j)
  drop j
  rename tpmsum pay
  replace ti = ti * (pay>0)
  rename ej job
  collapse (min) first_ti=ti (max) last_ti=ti, by(ID job)

  * ----------------------------
  * Compute unemployment duration
  * ----------------------------
  
  frame change default
  gen rwkesr2 = 0
  replace rwkesr2 = 1 if wesr2==1
  replace rwkesr2 = 1 if wesr2==3 & reasab==6
  replace rwkesr2 = 2 if wesr2==2
  replace rwkesr2 = 3 if wesr2==3 & reasab~=0 & reasab~=6
  replace rwkesr2 = 3 if wesr2==4 & reasab==1
  // note: reasab==1 is layoff, but for 1993, reasab==1|6 if // wesr2==3
  replace rwkesr2 = 4 if wesr2==4 & reasab~=1
  replace rwkesr2 = 5 if wesr2==5
  gen undur = (rwkesr2==3 | rwkesr2==4)
  by ID (wave refmth), sort: gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1|rwkesr2[_n-1]==2))

  frames put ID ti undur undur_eu, into(subset)
  frame change subset
  reshape wide undur undur_eu, i(ID) j(ti)
  *
  
  sort ID
  forvalues i=2/36 { // need max value
    local j=`i'-1
    by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
  }
  
  forvalues i=2/36 {
    local j=`i'-1
    by ID: replace undur_eu`i' = 1 + undur_eu`j' if undur_eu`j'~=0 & undur`i'~=0
  }

  reshape long undur undur_eu, i(ID) j(ti)
  drop undur
  sort ID ti
  gen spell_begin = ti if undur_eu==1

  by ID (ti), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_eu>1 & undur_eu~=.
  by ID spell_begin (ti), sort: gen spell_end = ti[_N]
  replace spell_end = . if spell_begin==.
  gen spell_length = spell_end-spell_begin+1
  replace undur_eu=0 if undur_eu==.

* ws12002, ws22103 -- same employer last wave
* ws12012, ws22112 -- type of employer
* ws12026, ws22126 -- paid hourly
* ws12028, ws22128 -- hourly rate
* ws1amt, ws2amt   -- earnings
* ws1ind, ws2ind   -- industry
* ws1occ, ws2occ   -- occupation
* ws1wks, ws2wks   -- weeks employed

* important variables:
*  wesr1-wesr5 wksjob wkswop reasab inaf
*  age brthmn brthyr sex race higrade grdcmpl enrold
*  intvw fnlwgt p5wgt
*	ws1amt ws2amt njobs 
  
  frame change default
  drop undur undur_eu
  
  frlink 1:1 ID ti, frame(subset)
  frget undur_eu     = undur_eu, from(subset)
  frget spell_begin  = spell_begin, from(subset)
  frget spell_end    = spell_end, from(subset)
  frget spell_length = spell_length, from(subset)
  
  * ----------------------------
  * Identify recalls from short samples
  * ----------------------------
  sort ID
  
  gen jbID1 = ej1*(tpmsum1!=0) //  another option is to use rwkesr2==1
  gen jbID2 = ej2*(tpmsum2!=0)
  replace jbID1=0 if jbID1<0 | jbID1==.
  replace jbID2=0 if jbID2<0 | jbID2==.
  gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)

  capture drop recall_GHT
  gen recall_GHT     = 0

  forvalues ii=1/9 {
  
    #delimit;
  
  
    #delimit;
    replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
      (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
      (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
      (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
      & undur_eu[_n+1]==1 & undur_eu[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
      & (rwkesr2==1 | rwkesr2==2)
      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
    #delimit cr
  
  }
  
  forvalues i=1/10 {
    capture drop F`i'rwkesr2
    
    bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
    bys ID (tt): gen F`i'emp = (F`i'rwkesr2==1 | F`i'rwkesr2==2)
  }

  by ID (tt), sort: gen F1spell_length = spell_length[_n+1]

tab recall_GHT F1rwkesr2 if F1spell_length<=3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F1spell_length==2 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F1spell_length==3 & (rwkesr2==1 | rwkesr2==2), col
tab recall_GHT F1rwkesr2 if F1spell_length==4 & (rwkesr2==1 | rwkesr2==2), col

merge panel

* IIa.  Within month records
egen ID = group(suid pnum entry)  // temporary ID variable

