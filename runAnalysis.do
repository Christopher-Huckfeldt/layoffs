clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace
clear all


* note: drop people who are present for first wave? or people with gaps?

foreach panel in 96 01 04 08 {

  clear all
  use tmpdata/cw`panel'.dta, clear
  
  
  egen ID = group(ssuid epppnum)
  sort ID swave srefmon
  
  gen undur = (rwkesr2==3 | rwkesr2==4) // unemployed in week 2
  
  by ID (swave srefmon): gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1 | rwkesr2[_n-1]==2)) // E to U
  gen tt = srefmon + (swave-1)*4
  xtset ID tt
  tsfill

*tmp remove! drop ID's with missing observations
*tmp remove!  count if rwkesr2==.
*tmp remove!  gen single_missing_wave = (rwkesr2==.)
*tmp remove!  by ID, sort: egen missing_waves = total(single_missing_wave)
*tmp remove!  drop if missing_waves>0
*tmp remove!  drop missing_waves single_missing_wave
  
  * ---------------------------------------------------
  * Compute unemployment duration into "subset`panel'"
  * ---------------------------------------------------
  
  frame change default
  frames put ID tt undur undur_eu, into(subset`panel')
  frame change subset`panel'
  quietly sum tt
  local tmax = r(max)
  reshape wide undur undur_eu, i(ID) j(tt)
  
  * get unemployment duration for contiguous spells
  sort ID
  forvalues i=2/`tmax' {
    local j=`i'-1
    by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
  }
  
  * get unemployment duration for contiguous spells that begin with layoff
  forvalues i=2/`tmax' {
    local j=`i'-1
    by ID: replace undur_eu`i' = 1 + undur_eu`j' if undur_eu`j'~=0 & undur`i'~=0
  }
  
  * spell level descriptors
  reshape long undur undur_eu, i(ID) j(tt)
  sort ID tt
  gen spell_begin = tt if undur_eu==1
  by ID (tt), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_eu>1 & undur_eu~=.
  by ID spell_begin (tt), sort: gen spell_end = tt[_N]
  replace spell_end = . if spell_begin==.
  gen spell_length = spell_end-spell_begin+1

  * Index contiguous unemployment spells beginning with "EU" transition
  frames put ID tt spell_begin spell_end undur_eu, into(subsubset)
  frame change subsubset
  drop if undur_eu==.
  collapse (max) undur_eu, by(ID spell_begin spell_end)
  * drop if spell_begin==.
  bys ID (spell_begin): gen eu_index = _n

  * Put index numbers into main dataset
  frame change subset`panel'
  frlink m:1 ID spell_begin, frame(subsubset)
  frget eu_index = eu_index, from(subsubset)
  
  * ----------------------------
  * Identify recalls from short samples, in "recall"
  * ----------------------------
  frame change default
  frames put ID ssuid epppnum tt srefmon eeno1 eeno2 tpmsum1 tpmsum2 rwkesr2, into(recall)
  frame change recall
  sort ID tt
  
  * identify main job
  gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
  gen jbID2 = eeno2*(tpmsum2!=0)
  replace jbID1=0 if jbID1<0 | jbID1==.
  replace jbID2=0 if jbID2<0 | jbID2==.

  gen lngth = 1

  * _temporarily_ simplify employment status
  gen status     = "E" if rwkesr2 == 1 | rwkesr2 == 2
  replace status = "U" if rwkesr2 == 3 | rwkesr2 == 4
  replace status = "N" if rwkesr2 == 5
  replace status = "X" if rwkesr2 == -1

  * simplify: some workers might have a jobid even though they don't 
  * work in second week of month.
  replace jbID1=0 if status=="U" | status=="N"
  replace jbID2=0 if status=="U" | status=="N"

  egen spellID = group(status jbID1 jbID2)
  * job/lfs indicator.
  * note, a single employment spells for an individual could potentially have _multiple_ IDs, 
  * whereas unemployment spells will have single ID, identifiable from E-U-E.
  * measure is NOT individual specific.

  * saved in frame "recall"
  
  * now generate variable "indx" for consecutive periods with same spellID
  frames put ID tt spellID, into(status_frm) // leave "recall"
  frame change status_frm
  quietly sum tt
  local tmax = r(max)

  reshape wide spellID, i(ID) j(tt)

  * "indx" will report changes in spellID.
  forvalues i=1/`tmax' {
    gen indx`i' = 1
  }

  forvalues i=2/`tmax' {
    local j = `i'-1
    replace indx`i' = indx`j' + 1*(spellID`i'~=spellID`j')
  }
  reshape long spellID indx, i(ID) j(tt)

  * Report instances of each spell (recorded by separate values of 
  * "indx"), generate new variables
  frame change recall
  frlink 1:1 ID spellID tt, frame(status_frm)
  frget indx = indx, from(status_frm)
  collapse (first) rwkesr2 status jbID1 jbID2 (sum) lngth (min) tt_begin=tt (max) tt_end=tt (first) srefmonA=srefmon (last) srefmonZ=srefmon, by(ID ssuid epppnum indx)

  sort ID tt_begin
  order ID indx tt_begin tt_end lngth status jbID1 jbID2
  bys ID: egen max_indx = max(indx)

  * identify EUE's and find recalls
  #delimit;
  gen EUE = (indx>1 & indx<max_indx & status=="U" & status[_n-1]=="E" & status[_n+1]=="E");
  gen EUN = (indx>1 & indx<max_indx & status=="U" & status[_n-1]=="E" & status[_n+1]=="N");
  gen recall = .;
  replace recall = 0 if EUE==1;
  replace recall = 0 if EUN==1;
  bys ID (tt_begin): replace recall = 1 if EUE==1
    & ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=0)
     | (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=0)
     | (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=0)
     | (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=0));
  #delimit cr

  * not really necessary, but record total number of recalls
  bys ID: egen total_recall = total(recall)
  replace total_recall = (total_recall>0 & total_recall~=.)

  * data measuring start and end of all EUE spells, and whether it 
  * ends in recall
  keep if EUE==1 | EUN==1
  rename tt_begin spell_begin
  rename rwkesr2 unemp_type
  keep ID spell_begin recall EUE EUN unemp_type srefmonA srefmonZ

  * merge variables from frame recall to frame subsubset
  * "subsubset" has index of all undur_eu spells with length, link 
  * to recall info
  frame change subsubset
  drop undur undur_eu
  frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
  frget recall = recall, from(rlnk)
  frget unemp_type = unemp_type, from(rlnk)
  frget EUE = EUE, from(rlnk)
  frget EUN = EUN, from(rlnk)
  frget srefmonA = srefmonA, from(rlnk)
  frget srefmonZ = srefmonZ, from(rlnk)
  *delete just done drop if EUE==.

  
  * merge variables from frame subsubset to frame subset`panel':
  * data has recall info, unemployment duration, unemployment 
  * type, and start/end of unemployment spell
  frame change subset`panel'
  frget recall     = recall, from(subsubset)
  frget unemp_type = unemp_type, from(subsubset)
  frget EUE = EUE, from(subsubset)
  frget EUN = EUN, from(subsubset)
  frget srefmonA = srefmonA, from(subsubset)
  frget srefmonZ = srefmonZ, from(subsubset)

  frlink 1:1 ID tt, frame(default)
  frget rwkesr2 = rwkesr2, from(default)
  frget swave   = swave, from(default)
  frget srefmon = srefmon, from(default)
  frget rhcalyr = rhcalyr, from(default)
  frget rhcalmn = rhcalmn, from(default)
  frget lgtwgt = lgtwgt, from(default)
  frget no_pw = no_pw, from(default)

  drop if recall==. // not in dataset of measurable recalls/new-jobs
  drop if EUE==. & EUN==.

  by ID spell_begin, sort: egen multiple_Ucodes = sd(rwkesr2)
  replace multiple_Ucodes=. if EUE~=1
  replace multiple_Ucodes = (multiple_Ucodes>0 & multiple_Ucodes~=.)

  save tmpdata/recall`panel'.dta, replace

}

* delete all  * just sum summary stats
* delete all
* delete all  gen UE=.
* delete all  gen TL_E=.
* delete all  gen JL_E=.
* delete all  gen E_U=.
* delete all  gen E_TL=.
* delete all  gen E_JL=.
* delete all
* delete all  bys ID (tt): replace UE = 0 if (rwkesr2==3 | rwkesr2==4)
* delete all  bys ID (tt): replace UE = 1 if (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
* delete all  *
* delete all  bys ID (tt): replace TL_E = 0 if (rwkesr2==3)
* delete all  bys ID (tt): replace TL_E = 1 if (rwkesr2==3) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
* delete all  *
* delete all  bys ID (tt): replace JL_E = 0 if (rwkesr2==4)
* delete all  bys ID (tt): replace JL_E = 1 if (rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
* delete all
* delete all  bys ID (tt): replace E_U = 0 if (rwkesr2==1 | rwkesr2==2)
* delete all  bys ID (tt): replace E_U = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3 | rwkesr2[_n+1]==4)
* delete all  *
* delete all  bys ID (tt): replace E_TL = 0 if (rwkesr2==1 | rwkesr2==2)
* delete all  bys ID (tt): replace E_TL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3)
* delete all  *
* delete all  bys ID (tt): replace E_JL = 0 if (rwkesr2==1 | rwkesr2==2)
* delete all  bys ID (tt): replace E_JL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==4)
* delete all
* delete all
* delete all  forvalues j=3/4 {
* delete all    if (`j'==3) {
* delete all      di "TL"
* delete all    }
* delete all    else {
* delete all      di "PS"
* delete all    }
* delete all    forvalues i=1/8 {
* delete all      quietly count if recall==1 & unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6
* delete all      local numer = r(N)
* delete all      quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
* delete all      local denom = r(N)
* delete all      local recallP = `numer'/`denom'
* delete all      *
* delete all      quietly count if recall==0 & unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6
* delete all      local numer = r(N)
* delete all      quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
* delete all      local denom = r(N)
* delete all      local hireP = `numer'/`denom'
* delete all      di "year is `panel', t=`i', `recallP', `hireP'" 
* delete all    }
* delete all  }
* delete all  forvalues j=3/4 {
* delete all    if (`j'==3) {
* delete all      di "TL"
* delete all    }
* delete all    else {
* delete all      di "PS"
* delete all    }
* delete all    forvalues i=1/8 {
* delete all      quietly count if recall==1 & unemp_type==`j' & spell_end==tt & spell_length==`i' & swave<=6
* delete all      local numer = r(N)
* delete all      quietly count if unemp_type==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
* delete all      local denom = r(N)
* delete all      local recallP = `numer'/`denom'
* delete all      *
* delete all      quietly count if recall==0 & unemp_type==`j' & spell_end==tt & spell_length==`i' & swave<=6
* delete all      local numer = r(N)
* delete all      quietly count if unemp_type==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
* delete all      local denom = r(N)
* delete all      local hireP = `numer'/`denom'
* delete all      di "year is `panel', t=`i', `recallP', `hireP'" 
* delete all    }
* delete all  }
* delete all
* delete all  tab E_U E_TL if swave<=6, row
* delete all  tab recall if UE==1 & swave<=6 // condition on observing EUE?
* delete all
* delete all  tab srefmon UE if swave<=6, col
* delete all  tab srefmon UE if swave<=6 & rwkesr2==3, col
* delete all  tab srefmon UE if swave<=6 & rwkesr2==4, col
* delete all  sum spell_length if undur_eu>0 & recall==1 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & recall==0 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & rwkesr2==3 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & rwkesr2==4 & tt==spell_begin, d
* delete all
* delete all  sum spell_length if undur_eu>0 & rwkesr2==3 & recall==0 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & rwkesr2==3 & recall==1 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & rwkesr2==4 & recall==0 & tt==spell_begin, d
* delete all  sum spell_length if undur_eu>0 & rwkesr2==4 & recall==1 & tt==spell_begin, d
* delete all
* delete all
* delete all  tab spell_length rwkesr2 if undur_eu>0 & tt==spell_begin
* delete all  tab spell_length rwkesr2 if spell_length<=4 & undur_eu>0 & tt==spell_begin & recall==1, col
* delete all
* delete all  * look at seam effect
* delete all  gen loss_month_tmp=0 
* delete all  replace loss_month_tmp = srefmon if spell_begin==tt
* delete all  by ID eu_index, sort: egen loss_month = max(loss_month_tmp)
* delete all  forvalues irefmth = 1/4 {
* delete all    forvalues j=3/4 {
* delete all      if (`j'==3) {
* delete all        di "TL"
* delete all      }
* delete all      else {
* delete all        di "PS"
* delete all      }
* delete all      forvalues i=1/8 {
* delete all        quietly count if recall==1 & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6 & loss_month==`irefmth'
* delete all        local numer = r(N)
* delete all        quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6 & loss_month==`irefmth'
* delete all        local denom = r(N)
* delete all        local recallP = `numer'/`denom'
* delete all        *
* delete all        quietly count if recall==0 & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6 & loss_month==`irefmth'
* delete all        local numer = r(N)
* delete all        quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6 & loss_month==`irefmth'
* delete all        local denom = r(N)
* delete all        local hireP = `numer'/`denom'
* delete all        di "year is `panel', t=`i', `recallP', `hireP', srefmon = `irefmth'" 
* delete all      }
* delete all    }
* delete all  }
* delete all  * seam effect!
* delete all
* delete all  clear all
* delete all}
* delete all
* delete all
* delete all
* delete all* dflkj
* delete all* 
* delete all* }
* delete all* 
* delete all* 
* delete all* foreach panel in 96 01 04 08 {
* delete all* frame change subset`panel'
* delete all* gen spanel = panel
* delete all* sort f
* delete all* 
* delete all* year is 01, t=1, .3388400702987698, .1096660808435852
* delete all* year is 01, t=2, .2628294036061026, .0908460471567268
* delete all* year is 01, t=3, .1988372093023256, .077906976744186
* delete all* year is 01, t=4, .2099827882960413, .1222030981067126
* delete all* 
* delete all* 
* delete all* * fraction of ET/EU should be lower in SIPP
* delete all* * actual recalls should go down.
* delete all* 
* delete all* * look at fraction of TL finding a job within 4 months. Should be HIGHER fraction of temporary-layoffs, but lower fraction of total unemployed.
* delete all* * gen TL_lt_4 = (rwkesr2==3 & spell_begin==tt & swave<=6 & spell_length<=4)
* delete all* *tab TL_lt_4 if rwkesr2==3 & spell_begin==tt & swave<=6 & spell_length<=4
* delete all* 
* delete all* *   dflkj
* delete all* * 
* delete all* *   frame change default
* delete all* *   drop undur_eu
* delete all* *   frlink 1:1 ID tt, frame(subset`panel') gen(slnk)
* delete all* *   frget recall       = recall, from(slnk)
* delete all* *   frget spell_begin  = spell_begin, from(slnk)
* delete all* *   frget spell_end    = spell_end, from(slnk)
* delete all* *   frget spell_length = spell_length, from(slnk)
* delete all* *   frget undur_eu     = undur_eu, from(slnk)
* delete all* *   bys ID (tt): gen UE = (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
* delete all* * 
* delete all* *   
* delete all* * dflkj
* delete all* * 
* delete all* * 
* delete all* *   dflkj
* delete all* *   frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
* delete all* *   frget recall = recall, from(rlnk)
* delete all* *   dflkj
* delete all* *   
* delete all* *   fr
* delete all* * 
* delete all* *      
* delete all* * 
* delete all* *   #delimit;
* delete all* *   replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
* delete all* *     (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
* delete all* *     (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
* delete all* *     (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
* delete all* *     & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
* delete all* *     & (rwkesr2==1 | rwkesr2==2)
* delete all* *     & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
* delete all* *   #delimit cr
* delete all* *   
* delete all* *   
* delete all* *   
* delete all* *   
* delete all* *   capture drop recall_GHT
* delete all* *   
* delete all* *   gen recall_GHT = 0
* delete all* * 
* delete all* *   quietly sum tt
* delete all* *   local tmax = r(max)
* delete all* *   forvalues ii=1/9 {
* delete all* *   
* delete all* *     #delimit;
* delete all* *     replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
* delete all* *       (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
* delete all* *       (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
* delete all* *       (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
* delete all* *       & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
* delete all* *       & (rwkesr2==1 | rwkesr2==2)
* delete all* *       & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
* delete all* *     #delimit cr
* delete all* * 
* delete all* *   }
* delete all* *   
* delete all* * *  sort ssuid eentaid epppnum swave srefmon
* delete all* * *  *merge 1:1 ssuid eentaid epppnum swave srefmon using FMrecalls.dta
* delete all* * *  sort ID eeno1
* delete all* * *  merge m:1 ID eeno1 using ./rawdata/jobs1_`panel'.dta
* delete all* * *  tab _merge
* delete all* * *  drop _merge
* delete all* * *  *
* delete all* * *  sort ID eeno2
* delete all* * *  merge m:1 ID eeno1 using ./rawdata/jobs2_`panel'.dta
* delete all* * *  tab _merge
* delete all* * *  drop _merge
* delete all* *   
* delete all* * *  frlink m:1 ID job, frame(jobs)
* delete all* * *  frget end_date = end_date, from(jobs)
* delete all* * *  frget last_tt = last_tt, from(jobs)
* delete all* * *  frget start_date = start_date, from(jobs)
* delete all* * *  frget first_tt = first_tt, from(jobs)
* delete all* *   
* delete all* *   by ID (tt), sort: gen F1spell_length = spell_length[_n+1]
* delete all* *   
* delete all* *   forvalues i=1/10 {
* delete all* *     capture drop F`i'rwkesr2
* delete all* *     
* delete all* *     bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
* delete all* *     bys ID (tt): gen F`i'emp = (F`i'rwkesr2==1 | F`i'rwkesr2==2)
* delete all* *   }
* delete all* *   
* delete all* *   
* delete all* *   tab recall_GHT F1rwkesr2 if F1spell_length<=3 & (rwkesr2==1 | rwkesr2==2), col
* delete all* *   save ./tmpdata/extract`panel'.dta, replace
* delete all* *   
* delete all* *   keep ID recall_GHT /*recallFM*/ rwkesr2 F1rwkesr2 F1spell_length F*rwkesr2 srot swave rwkesr* F*emp srefmon
* delete all* *   keep if (rwkesr2==1 | rwkesr2==2) & F1spell_length~=0 & F1spell_length~=.
* delete all* *   
* delete all* *   gen TL = (F1rwkesr2==3)
* delete all* *   gen PS = (F1rwkesr2==4)
* delete all* * 
* delete all* *   gen TL_m1 = (F1rwkesr2==3 & srefmon==1)
* delete all* *   gen PS_m1 = (F1rwkesr2==4 & srefmon==1)
* delete all* * 
* delete all* *   *save this.dta, replace ("ne" durations)
* delete all* *   *save that.dta, replace
* delete all* *   } // quietly done
* delete all* * 
* delete all* *   tab recall_GHT F1rwkesr2 if F1spell_length==1
* delete all* *   forvalues j=3/4 {
* delete all* *     if (`j'==3) {
* delete all* *       di "PS"
* delete all* *     }
* delete all* *     else {
* delete all* *       di "TL"
* delete all* *     }
* delete all* *     forvalues i=1/8 {
* delete all* *       quietly count if recall_GHT==1 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
* delete all* *       local numer = r(N)
* delete all* *       quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
* delete all* *       local denom = r(N)
* delete all* *       local recallP = `numer'/`denom'
* delete all* *       *
* delete all* *       quietly count if recall_GHT==0 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
* delete all* *       local numer = r(N)
* delete all* *       quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
* delete all* *       local denom = r(N)
* delete all* *       local recallP = `numer'/`denom'
* delete all* *       di "year is `panel', t=`i', `rate'" 
* delete all* *     }
* delete all* *   }
* delete all* * 
* delete all* * 
* delete all* * } //loop done
* delete all* * dflkj
* delete all* *   
* delete all* *   
* delete all* *   *good * checking for seam effect!
* delete all* *   *good forvalues i=1/2 {
* delete all* *   *good   di "`i'"
* delete all* *   *good   reg recall_GHT PS TL if srefmon<4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
* delete all* *   *good   reg recall_GHT PS TL if srefmon>4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
* delete all* *   *good }
* delete all* * 
* delete all* *   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   
* delete all* *   * all of them
* delete all* *   forvalues i=1/4 {
* delete all* *     di "`i'"
* delete all* *     reg recall_GHT PS TL if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
* delete all* *   }
* delete all* *   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   
* delete all* *   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* * *  reg recallFM PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* delete all* *   
* delete all* *   forvalues i=1/9 {
* delete all* *   
* delete all* *     local j=`i'+1
* delete all* *     replace F`j'rwkesr2=. if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2 | F`i'rwkesr2==.)
* delete all* *     replace F`i'rwkesr2 = 0 if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2) & recall_GHT==1
* delete all* *   
* delete all* *     di "`i'"
* delete all* *     tab F`i'rwkesr2 F`j'rwkesr2, row
* delete all* *     tab F`i'rwkesr2 F`j'emp, row
* delete all* *   
* delete all* *   }
* delete all* *   
* delete all* *   forvalues i=1/9 {
* delete all* *   
* delete all* *     local j=`i'+1
* delete all* *   
* delete all* *     di "`i'"
* delete all* *     tab F`i'rwkesr2 F`j'rwkesr2 if (F`i'rwkesr2==3 | F`i'rwkesr2==4) , row
* delete all* *   
* delete all* *   }
* delete all* *   
* delete all* *   forvalues i=1/9 {
* delete all* *   
* delete all* *     local j=`i'+1
* delete all* *   
* delete all* *     di "`i'"
* delete all* *     tab F`i'rwkesr2 F`j'emp if (F`i'rwkesr2==3 | F`i'rwkesr2==4), row
* delete all* *   
* delete all* *   }
* delete all* * 
* delete all* * }
* delete all* * * seam bias!
