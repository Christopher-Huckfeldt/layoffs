clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace

*foreach panel in 96 01 04 08 {
foreach panel in 96 {


quietly {

  clear all

  use tmpdata/cw`panel'.dta, clear
  
  egen pID = group(ssuid epppnum )
  *gen id = ssuid+eentaid+epppnum
  
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
  
  egen ID = group(ssuid epppnum)
  sort ID swave srefmon
  
  
  gen undur = (rwkesr2==3 | rwkesr2==4)
  *gen nedur = (rwkesr2==3 | rwkesr2==4 | rwkesr2==5)
  
  by ID (swave srefmon): gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1|rwkesr2[_n-1]==2))
  gen tt = srefmon + (swave-1)*4
  sum tt
  
  * -------
  * job information into "jobs"
  * -------
  
*  frame put ID tt eeno1 eeno2 tsjdate1 tsjdate2 tejdate1 tejdate2 tpmsum1 tpmsum2, into(jobs)
*  frame change jobs
*  reshape long eeno tsjdate tejdate tpmsum, i(ID tt) j(j)
*  drop j
*  rename eeno job
*  rename tsjdate start_date
*  rename tejdate end_date
*  rename tpmsum pay
*  replace tt = tt * (pay>0)
*  drop if job==-1
*  drop if tt==0
*  collapse (min) start_date first_tt=tt (max) last_tt=tt end_date, by(ID job)
*
*  rename job eeno1
*  sort ID eeno1
*  save ./tmpdata/jobs1_`panel'.dta, replace
*
*  rename eeno1 eeno2
*  sort ID eeno2
*  save ./tmpdata/jobs2_`panel'.dta, replace
  
  * ----------------------------
  * Compute unemployment duration into "subset"
  * ----------------------------
  
  frame change default
  frames put ID tt undur undur_eu, into(subset)
  frame change subset
  quietly sum tt
  local tmax = r(max)
  reshape wide undur undur_eu, i(ID) j(tt)
  *
  
  sort ID
  forvalues i=2/`tmax' {
    local j=`i'-1
    by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
  }
  
  forvalues i=2/`tmax' {
    local j=`i'-1
    by ID: replace undur_eu`i' = 1 + undur_eu`j' if undur_eu`j'~=0 & undur`i'~=0
  }
  
  reshape long undur undur_eu, i(ID) j(tt)
  drop undur
  sort ID tt
  gen spell_begin = tt if undur_eu==1
  by ID (tt), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_eu>1 & undur_eu~=.
  by ID spell_begin (tt), sort: gen spell_end = tt[_N]
  replace spell_end = . if spell_begin==.
  gen spell_length = spell_end-spell_begin+1

  * Index contiguous unemployment spells beginning with "EU" 
  * transition
  frames put ID tt spell_begin spell_end undur_eu, into(subsubset)
  frame change subsubset
  drop if undur_eu==.
  collapse (max) undur_eu, by(ID spell_begin spell_end)
  bys ID (spell_begin): gen eu_index = _n

  frame change subset
  frlink m:1 ID spell_begin, frame(subsubset)
  frget eu_index = eu_index, from(subsubset)
  
  * ----------------------------
  * Identify recalls from short samples, in "recall"
  * ----------------------------
  frame change default
  frames put ID ssuid epppnum tt eeno1 eeno2 tpmsum1 tpmsum2 rwkesr2, into(recall)
  frame change recall
  sort ID tt
  
  gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
  gen jbID2 = eeno2*(tpmsum2!=0)
  replace jbID1=0 if jbID1<0 | jbID1==.
  replace jbID2=0 if jbID2<0 | jbID2==.
  gen lngth = 1

  * _temporarily_ simplify employment status
  gen status = "E" if rwkesr2==1 | rwkesr2==2
  replace status = "U" if rwkesr2==3 | rwkesr2==4
  replace status = "N" if rwkesr2==5
  replace status = "X" if rwkesr2==-1

  * simplify: some workers might have a jobid even though they don't 
  * work in second month.
  replace jbID1=0 if status=="U"
  replace jbID2=0 if status=="U"

  collapse (firstnm) rwkesr2 (sum) lngth (min) tt_begin=tt (max) tt_end=tt, by(ID ssuid epppnum status jbID1 jbID2)
  sort ID tt_begin
  bys ID (tt_begin): gen indx = _n
  order ID indx tt_begin tt_end lngth status jbID1 jbID2
  save temp.dta, replace
  bys ID: egen max_indx = max(indx)

  #delimit;
  gen EUE = (indx>1 & indx<max_indx 
    & status=="U" & status[_n-1]=="E" & status[_n+1]=="E");
  gen recall = .;
  replace recall = 0 if EUE==1;
  bys ID (tt_begin): replace recall = 1 if EUE==1
    & ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=0)
     | (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=0)
     | (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=0)
     | (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=0));
  #delimit cr
  dflkj
  #delimit;
  bys ID (tt_begin): gen stupid = 1 if _n~=1
     & ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=0)
     | (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=0)
     | (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=0)
     | (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=0));
  #delimit cr

  bys ID: egen total_recall = total(recall)
  replace total_recall = (total_recall>0 & total_recall~=.)
  keep if EUE==1
  rename tt_begin spell_begin
  keep ID spell_begin recall

  * merge variables from frame recall to frame subsubset
  frame change subsubset
  drop undur undur_eu
  frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
  frget recall = recall, from(rlnk)
  
  * merge variables from frame subsubset to frame subset
  frame change subset
  frlink m:1 ID spell_begin, frame(subsubset)
  frget recall     = recall, from(subsubset)

  frame change default
  drop undur_eu
  frlink 1:1 ID tt, frame(subset) gen(slnk)
  frget recall       = recall, from(slnk)
  frget spell_begin  = spell_begin, from(slnk)
  frget spell_end    = spell_end, from(slnk)
  frget spell_length = spell_length, from(slnk)
  frget undur_eu     = undur_eu, from(slnk)
  bys ID (tt): gen UE = (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)

  forvalues j=3/4 {
    if (`j'==3) {
      di "PS"
    }
    else {
      di "TL"
    }
    forvalues i=1/8 {
      count if recall==1 & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6
      local numer = r(N)
      count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
      local denom = r(N)
      local recallP = `numer'/`denom'
      *
      quietly count if recall==0 & rwkesr2==`j' & spell_length==`i' & UE==1 & swave<=6
      local numer = r(N)
      quietly count if rwkesr2==`j' & spell_length>=`i' & swave<=6
      local denom = r(N)
      local hireP = `numer'/`denom'
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }
  
dflkj


  dflkj
  frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
  frget recall = recall, from(rlnk)
  dflkj
  
  fr

     

  #delimit;
  replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
    (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
    (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
    & (rwkesr2==1 | rwkesr2==2)
    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
  #delimit cr
  
  
  
  
  capture drop recall_GHT
  
  gen recall_GHT = 0

  quietly sum tt
  local tmax = r(max)
  forvalues ii=1/9 {
  
    #delimit;
    replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
      (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
      (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
      (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
      & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
      & (rwkesr2==1 | rwkesr2==2)
      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
    #delimit cr

  }
  
*  sort ssuid eentaid epppnum swave srefmon
*  *merge 1:1 ssuid eentaid epppnum swave srefmon using FMrecalls.dta
*  sort ID eeno1
*  merge m:1 ID eeno1 using ./rawdata/jobs1_`panel'.dta
*  tab _merge
*  drop _merge
*  *
*  sort ID eeno2
*  merge m:1 ID eeno1 using ./rawdata/jobs2_`panel'.dta
*  tab _merge
*  drop _merge
  
*  frlink m:1 ID job, frame(jobs)
*  frget end_date = end_date, from(jobs)
*  frget last_tt = last_tt, from(jobs)
*  frget start_date = start_date, from(jobs)
*  frget first_tt = first_tt, from(jobs)
  
  by ID (tt), sort: gen F1spell_length = spell_length[_n+1]
  
  forvalues i=1/10 {
    capture drop F`i'rwkesr2
    
    bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
    bys ID (tt): gen F`i'emp = (F`i'rwkesr2==1 | F`i'rwkesr2==2)
  }
  
  
  tab recall_GHT F1rwkesr2 if F1spell_length<=3 & (rwkesr2==1 | rwkesr2==2), col
  save ./tmpdata/extract`panel'.dta, replace
  
  keep ID recall_GHT /*recallFM*/ rwkesr2 F1rwkesr2 F1spell_length F*rwkesr2 srot swave rwkesr* F*emp srefmon
  keep if (rwkesr2==1 | rwkesr2==2) & F1spell_length~=0 & F1spell_length~=.
  
  gen TL = (F1rwkesr2==3)
  gen PS = (F1rwkesr2==4)

  gen TL_m1 = (F1rwkesr2==3 & srefmon==1)
  gen PS_m1 = (F1rwkesr2==4 & srefmon==1)

  *save this.dta, replace ("ne" durations)
  *save that.dta, replace
  } // quietly done

  tab recall_GHT F1rwkesr2 if F1spell_length==1
  forvalues j=3/4 {
    if (`j'==3) {
      di "PS"
    }
    else {
      di "TL"
    }
    forvalues i=1/8 {
      quietly count if recall_GHT==1 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
      local denom = r(N)
      local recallP = `numer'/`denom'
      *
      quietly count if recall_GHT==0 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
      local denom = r(N)
      local recallP = `numer'/`denom'
      di "year is `panel', t=`i', `rate'" 
    }
  }


} //loop done
dflkj
  
  
  *good * checking for seam effect!
  *good forvalues i=1/2 {
  *good   di "`i'"
  *good   reg recall_GHT PS TL if srefmon<4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  *good   reg recall_GHT PS TL if srefmon>4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  *good }

  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  * all of them
  forvalues i=1/4 {
    di "`i'"
    reg recall_GHT PS TL if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  }
  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*  reg recallFM PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  forvalues i=1/9 {
  
    local j=`i'+1
    replace F`j'rwkesr2=. if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2 | F`i'rwkesr2==.)
    replace F`i'rwkesr2 = 0 if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2) & recall_GHT==1
  
    di "`i'"
    tab F`i'rwkesr2 F`j'rwkesr2, row
    tab F`i'rwkesr2 F`j'emp, row
  
  }
  
  forvalues i=1/9 {
  
    local j=`i'+1
  
    di "`i'"
    tab F`i'rwkesr2 F`j'rwkesr2 if (F`i'rwkesr2==3 | F`i'rwkesr2==4) , row
  
  }
  
  forvalues i=1/9 {
  
    local j=`i'+1
  
    di "`i'"
    tab F`i'rwkesr2 F`j'emp if (F`i'rwkesr2==3 | F`i'rwkesr2==4), row
  
  }

}
* seam bias!
