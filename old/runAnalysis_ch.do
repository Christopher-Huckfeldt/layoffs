clear all
set more off
* capture log close

* log using "logfiles/runAnalysis.log", replace
clear all


* note: drop people who are present for first wave? or people with gaps?

*foreach panel in 96 01 04 08 {
foreach panel in 96 {

  local panel = 96
  use tmpdata/cw`panel'.dta, clear
  
  egen ID = group(ssuid epppnum)
  sort ID swave srefmon
  
  * NOTE: 1 if employment status in week 2 is equal to  3 or 4
  gen undur = (rwkesr2==3 | rwkesr2==4) // unemployed in week 2
  
  * NOTE: For every ID in each swave and srefmon undur_eu is 1 if rwkesr2 is 3, 4 and the previous value of rwkesr2 is 1 or 2. 
  by ID (swave srefmon): gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1|rwkesr2[_n-1]==2)) // E to U
  * NOTE: Is this like total time or something?
  gen tt = srefmon + (swave-1)*4
  sum tt
  
  
  * ---------------------------------------------------
  * Compute unemployment duration into "subset`panel'"
  * ---------------------------------------------------

  local panel = 96
  
  frame change default
  frames put ID tt undur undur_eu, into(subset`panel')
  frame change subset`panel'
  quietly sum tt
  local tmax = r(max) 
  * NOTE: 48 different undur and undur_eu each one for the tt. 
  reshape wide undur undur_eu, i(ID) j(tt)
  *
  
  * get unemployment duration for contiguous spells
  sort ID
  forvalues i=2/`tmax' {
    local j=`i'-1
    * NOTE: If undur(x) and undur(x-1) are both not 0 then undur(x) + undur(x-1) 
    * NOTE: Counting the duration of a period of unemployment based on just week 2 unemployment
    by ID: replace undur`i' = undur`i' + undur`j' if undur`j'~=0 & undur`i'~=0
  }
  
  * get unemployment duration for contiguous spells that begin with layoff
  forvalues i=2/`tmax' {
    local j=`i'-1
    * NOTE: If undur_eu(x-1) and undur(x) are both not 0 then +1
    * NOTE: Count if you went from employed to unemployed
    * We calculate how many months you have been unemployed in your 
    * current spell, conditional on that spell being preceeded by 
    * employment.
    by ID: replace undur_eu`i' = 1 + undur_eu`j' if undur_eu`j'~=0 & undur`i'~=0
  }
  
  * spell level descriptors
  reshape long undur undur_eu, i(ID) j(tt)
  sort ID tt
  * NOTE: spell begin is the period where the E to U transition happened
  gen spell_begin = tt if undur_eu==1
  * NOTE: If a transition began in the previous period and undur_eu is at least 2 then make every subsequent spell_begin the same tt. 
  by ID (tt), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_eu>1 & undur_eu~=.
  * NOTE: Spell end would calculated from the final value in the column tt
  by ID spell_begin (tt), sort: gen spell_end = tt[_N]
  replace spell_end = . if spell_begin==.
  gen spell_length = spell_end-spell_begin+1

  * Index contiguous unemployment spells beginning with "EU" transition
  frames put ID tt spell_begin spell_end undur_eu, into(subsubset)
  frame change subsubset
  drop if undur_eu==. | undur_eu==0
  * NOTE: For every ID, spell_begin, spell_end collapse by the max unemployment transition length, since we currently have 48 tt
  collapse (max) undur_eu, by(ID spell_begin spell_end)
  * NOTE: A count of the number of unemployment spells by ID 
  bys ID (spell_begin): gen eu_index = _n

  * Put index numbers into main dataset
  local panel=96
  frame change subset`panel'
  frlink m:1 ID spell_begin, frame(subsubset)
  frget eu_index = eu_index, from(subsubset)
  
  * ----------------------------
  * Identify recalls from short samples, in "recall"
  * ----------------------------
  frame change default
  frames put ID ssuid epppnum tt eeno1 eeno2 tpmsum1 tpmsum2 rwkesr2, into(recall)
  frame change recall
  sort ID tt
  
  * NOTE: jbID is based off the code for either two jobs and whether the earning associated with either job is not 0 
  * NOTE: eeno is -1 if no job?
  gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
  gen jbID2 = eeno2*(tpmsum2!=0)
  * NOTE: Replace with 0 if the individual had no job
  replace jbID1=0 if jbID1<0 | jbID1==. // redundant
  replace jbID2=0 if jbID2<0 | jbID2==. // redundant
  gen lngth = 1

  * _temporarily_ simplify employment status
  gen status     = "E" if rwkesr2 == 1 | rwkesr2 == 2
  replace status = "U" if rwkesr2 == 3 | rwkesr2 == 4
  replace status = "N" if rwkesr2 == 5
  replace status = "X" if rwkesr2 == -1

  * simplify: some workers might have a jobid even though they don't 
  * work in second week of month.
  * NOTE: If the individual reported that they were unemployed then we should make their jbID 0
  replace jbID1=0 if status=="U" | status=="N"
  replace jbID2=0 if status=="U" | status=="N"

  * NOTE: Different groupings for every combination of employment and earnings amount
  egen spellID = group(status jbID1 jbID2)
  * note, a single employment spells for an individual could potentially have _multiple_ IDs, 
  * whereas unemployment spells will have single ID, identifiable from E-U-E.
  * measure is NOT individual specific.
  * question: what is this for?
  
  frames put ID tt spellID, into(status_frm) // leave "recall"
  * what does frm stand for?
  frame change status_frm
  quietly sum tt
  local tmax = r(max)

  reshape wide spellID, i(ID) j(tt)

  forvalues i=1/`tmax' {
    gen indx`i' = 1
  }

  forvalues i=2/`tmax' {
    local j = `i'-1
    * NOTE: A count of the spellID transitions for an ID -> (1 * tmax) 1 1 2 2 2 3 3 3 3 4
    replace indx`i' = indx`j' + 1*(spellID`i'~=spellID`j')
  }
  reshape long spellID indx, i(ID) j(tt)
  * spellID was not specific to individuals. but indx tracks changes 
  * in spellID within a given individual.

  frame change recall
  frlink 1:1 ID spellID tt, frame(status_frm)
  frget indx = indx, from(status_frm)

  * NOTE: Collapse into each unique indx for every unique group ID ssuid epppnum. 
  * NOTE: First unemployment status value, and Job ID values -> Bascially, we get to look at the U-E-X-N transitions and the different job ID changes for each transition
  * NOTE: Total length of each indx -> E and 74 would mean employed for 4 periods
  * NOTE: tt_being and tt_end just tell us the stand and end of each indx. 
  collapse (first) rwkesr2 status jbID1 jbID2 (sum) lngth (min) tt_begin=tt (max) tt_end=tt, by(ID ssuid epppnum indx)
  sort ID tt_begin
  order ID indx tt_begin tt_end lngth status jbID1 jbID2
  bys ID: egen max_indx = max(indx)

  * WARNING: What is delimit doing here? I don't know what this is? delimiter?
  * NOTE: E-U-E for where it is U will be 1
  #delimit;
  gen EUE = (indx>1 & indx<max_indx 
    & status=="U" & status[_n-1]=="E" & status[_n+1]=="E");
  gen recall = .; // missing value
  // NOTE: Starting our identification of whether we go from the same E to E.
  replace recall = 0 if EUE==1;
  // NOTE: If the previous job in either ID1 and ID2 match if EUE is detected. 
  // NOTE: However, be sure that the values that are matched are not 0. This is for the case where the individual only has 1 job across the E and E periods. 
  bys ID (tt_begin): replace recall = 1 if EUE==1
    & ((jbID1[_n-1]==jbID1[_n+1] & jbID1[_n-1]~=0)
     | (jbID1[_n-1]==jbID2[_n+1] & jbID1[_n-1]~=0)
     | (jbID2[_n-1]==jbID2[_n+1] & jbID2[_n-1]~=0)
     | (jbID2[_n-1]==jbID1[_n+1] & jbID2[_n-1]~=0));
  #delimit cr

  bys ID: egen total_recall = total(recall)
  * WARNING: Why are we replacing the total value of recell with a boolean for recall existence?
  replace total_recall = (total_recall>0 & total_recall~=.)
  keep if EUE==1
  rename tt_begin spell_begin
  rename rwkesr2 unemp_type
  keep ID spell_begin recall EUE unemp_type

  * merge variables from frame recall to frame subsubset
  frame change subsubset
  drop undur undur_eu
  frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
  frget recall = recall, from(rlnk)
  frget unemp_type = unemp_type, from(rlnk)
  frget EUE = EUE, from(rlnk)

  
  * merge variables from frame subsubset to frame subset`panel'
  local panel = 96
  frame change subset`panel'
  frget recall     = recall, from(subsubset)
  frget unemp_type = unemp_type, from(subsubset)
  frget EUE = EUE, from(subsubset)

  frlink 1:1 ID tt, frame(default)
  frget rwkesr2 = rwkesr2, from(default)
  frget swave = swave, from(default)
  frget srefmon = srefmon, from(default)
  frget rhcalyr = rhcalyr, from(default)
  frget rhcalmn = rhcalmn, from(default)

  * Problems:
  * spell_length collects information past point where individual left sample
  * spell_length collects information before point where individual entered sample
  * e.g., see "list if ID == 115101"

  gen UE=.
  gen TL_E=.
  gen JL_E=.
  gen E_U=.
  gen E_TL=.
  gen E_JL=.

  # NOTE: Unemployed to Employed
  bys ID (tt): replace UE = 0 if (rwkesr2==3 | rwkesr2==4)
  bys ID (tt): replace UE = 1 if (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
  *
  # NOTE: Temporarily Unemployed , but you expect to be remployed in the following period
  bys ID (tt): replace TL_E = 0 if (rwkesr2==3)
  bys ID (tt): replace TL_E = 1 if (rwkesr2==3) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
  *
  # NOTE: Job Loss to employed
  bys ID (tt): replace JL_E = 0 if (rwkesr2==4)
  bys ID (tt): replace JL_E = 1 if (rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)

  # NOTE: Employed to Unemployed
  bys ID (tt): replace E_U = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_U = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3 | rwkesr2[_n+1]==4)
  *
  # NOTE: Temporarily Employed
  bys ID (tt): replace E_TL = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_TL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3)
  *
  # NOTE: Employed to Job Loss
  bys ID (tt): replace E_JL = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_JL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==4)


  forvalues j=3/4 {
    if (`j'==3) {
      di "TL"
    }
    else {
      di "PS"
    }
    forvalues i=1/8 {
      # NOTE: If you were Temporarily Unemployed(unemp_type and rwkesr2), and recalled to the same job?
      # WARNING: Why does swave have to be less than 6?
      # WARNING: Why does spell length have to be less than 8?
      quietly count if recall==1 & unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
      local denom = r(N)
      local recallP = `numer'/`denom'
      *
      quietly count if recall==0 & unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
      local denom = r(N)
      local hireP = `numer'/`denom'
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }
  # WARNING: What is the purpose for the second calculation? Why are there for cases where the unemp_type doesn't match the rwkesr2?
  forvalues j=3/4 {
    if (`j'==3) {
      di "TL"
    }
    else {
      di "PS"
    }
    forvalues i=1/8 {
      quietly count if recall==1 & unemp_type==`j' & spell_end==tt & spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if unemp_type==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
      local denom = r(N)
      local recallP = `numer'/`denom'
      *
      quietly count if recall==0 & unemp_type==`j' & spell_end==tt & spell_length==`i' & swave<=6
      local numer = r(N)
      quietly count if unemp_type==`j' & spell_length>=`i' & spell_begin==tt & swave<=6
      local denom = r(N)
      local hireP = `numer'/`denom'
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }

  tab E_U E_TL if swave<=6, row
  tab recall if UE==1 & swave<=6 // condition on observing EUE?

  tab srefmon UE if swave<=6, col
  tab srefmon UE if swave<=6 & rwkesr2==3, col
  tab srefmon UE if swave<=6 & rwkesr2==4, col
  sum spell_length if undur_eu>0 & recall==1 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & recall==0 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & rwkesr2==3 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & rwkesr2==4 & tt==spell_begin, d

  sum spell_length if undur_eu>0 & rwkesr2==3 & recall==0 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & rwkesr2==3 & recall==1 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & rwkesr2==4 & recall==0 & tt==spell_begin, d
  sum spell_length if undur_eu>0 & rwkesr2==4 & recall==1 & tt==spell_begin, d


  tab spell_length rwkesr2 if undur_eu>0 & tt==spell_begin
  tab spell_length rwkesr2 if spell_length<=4 & undur_eu>0 & tt==spell_begin & recall==1, col

  * look at seam effect
  gen loss_month_tmp=0 
  replace loss_month_tmp = srefmon if spell_begin==tt
  by ID eu_index, sort: egen loss_month = max(loss_month_tmp)
  forvalues irefmth = 1/4 {
    forvalues j=3/4 {
      if (`j'==3) {
        di "TL"
      }
      else {
        di "PS"
      }
      forvalues i=1/8 {
        quietly count if recall==1 & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6 & loss_month==`irefmth'
        local numer = r(N)
        quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6 & loss_month==`irefmth'
        local denom = r(N)
        local recallP = `numer'/`denom'
        *
        quietly count if recall==0 & rwkesr2==`j' & spell_end==tt & spell_length==`i' & swave<=6 & loss_month==`irefmth'
        local numer = r(N)
        quietly count if rwkesr2==`j' & spell_length>=`i' & spell_begin==tt & swave<=6 & loss_month==`irefmth'
        local denom = r(N)
        local hireP = `numer'/`denom'
        di "year is `panel', t=`i', `recallP', `hireP', srefmon = `irefmth'" 
      }
    }
  }
  * seam effect!

  save tmpdata/recall`panel'.dta, replace
  clear all

}




}


foreach panel in 96 01 04 08 {
frame change subset`panel'
gen spanel = panel
sort f

year is 01, t=1, .3388400702987698, .1096660808435852
year is 01, t=2, .2628294036061026, .0908460471567268
year is 01, t=3, .1988372093023256, .077906976744186
year is 01, t=4, .2099827882960413, .1222030981067126


* fraction of ET/EU should be lower in SIPP
* actual recalls should go down.

* look at fraction of TL finding a job within 4 months. Should be HIGHER fraction of temporary-layoffs, but lower fraction of total unemployed.
* gen TL_lt_4 = (rwkesr2==3 & spell_begin==tt & swave<=6 & spell_length<=4)
*tab TL_lt_4 if rwkesr2==3 & spell_begin==tt & swave<=6 & spell_length<=4

*   dflkj
* 
*   frame change default
*   drop undur_eu
*   frlink 1:1 ID tt, frame(subset`panel') gen(slnk)
*   frget recall       = recall, from(slnk)
*   frget spell_begin  = spell_begin, from(slnk)
*   frget spell_end    = spell_end, from(slnk)
*   frget spell_length = spell_length, from(slnk)
*   frget undur_eu     = undur_eu, from(slnk)
*   bys ID (tt): gen UE = (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
* 
*   
* dflkj
* 
* 
*   dflkj
*   frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
*   frget recall = recall, from(rlnk)
*   dflkj
*   
*   fr
* 
*      
* 
*   #delimit;
*   replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*     (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*     (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*     (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
*     & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
*     & (rwkesr2==1 | rwkesr2==2)
*     & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*   #delimit cr
*   
*   
*   
*   
*   capture drop recall_GHT
*   
*   gen recall_GHT = 0
* 
*   quietly sum tt
*   local tmax = r(max)
*   forvalues ii=1/9 {
*   
*     #delimit;
*     replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*       (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*       (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*       (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
*       & undur_eu[_n+1]==1 & spell_length[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
*       & (rwkesr2==1 | rwkesr2==2)
*       & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*     #delimit cr
* 
*   }
*   
* *  sort ssuid eentaid epppnum swave srefmon
* *  *merge 1:1 ssuid eentaid epppnum swave srefmon using FMrecalls.dta
* *  sort ID eeno1
* *  merge m:1 ID eeno1 using ./rawdata/jobs1_`panel'.dta
* *  tab _merge
* *  drop _merge
* *  *
* *  sort ID eeno2
* *  merge m:1 ID eeno1 using ./rawdata/jobs2_`panel'.dta
* *  tab _merge
* *  drop _merge
*   
* *  frlink m:1 ID job, frame(jobs)
* *  frget end_date = end_date, from(jobs)
* *  frget last_tt = last_tt, from(jobs)
* *  frget start_date = start_date, from(jobs)
* *  frget first_tt = first_tt, from(jobs)
*   
*   by ID (tt), sort: gen F1spell_length = spell_length[_n+1]
*   
*   forvalues i=1/10 {
*     capture drop F`i'rwkesr2
*     
*     bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
*     bys ID (tt): gen F`i'emp = (F`i'rwkesr2==1 | F`i'rwkesr2==2)
*   }
*   
*   
*   tab recall_GHT F1rwkesr2 if F1spell_length<=3 & (rwkesr2==1 | rwkesr2==2), col
*   save ./tmpdata/extract`panel'.dta, replace
*   
*   keep ID recall_GHT /*recallFM*/ rwkesr2 F1rwkesr2 F1spell_length F*rwkesr2 srot swave rwkesr* F*emp srefmon
*   keep if (rwkesr2==1 | rwkesr2==2) & F1spell_length~=0 & F1spell_length~=.
*   
*   gen TL = (F1rwkesr2==3)
*   gen PS = (F1rwkesr2==4)
* 
*   gen TL_m1 = (F1rwkesr2==3 & srefmon==1)
*   gen PS_m1 = (F1rwkesr2==4 & srefmon==1)
* 
*   *save this.dta, replace ("ne" durations)
*   *save that.dta, replace
*   } // quietly done
* 
*   tab recall_GHT F1rwkesr2 if F1spell_length==1
*   forvalues j=3/4 {
*     if (`j'==3) {
*       di "PS"
*     }
*     else {
*       di "TL"
*     }
*     forvalues i=1/8 {
*       quietly count if recall_GHT==1 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
*       local numer = r(N)
*       quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
*       local denom = r(N)
*       local recallP = `numer'/`denom'
*       *
*       quietly count if recall_GHT==0 & F1rwkesr2==`j' & F1spell_length==`i' & swave<=6
*       local numer = r(N)
*       quietly count if F1rwkesr2==`j' & F1spell_length>=`i' & swave<=6
*       local denom = r(N)
*       local recallP = `numer'/`denom'
*       di "year is `panel', t=`i', `rate'" 
*     }
*   }
* 
* 
* } //loop done
* dflkj
*   
*   
*   *good * checking for seam effect!
*   *good forvalues i=1/2 {
*   *good   di "`i'"
*   *good   reg recall_GHT PS TL if srefmon<4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
*   *good   reg recall_GHT PS TL if srefmon>4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
*   *good }
* 
*   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   
*   * all of them
*   forvalues i=1/4 {
*     di "`i'"
*     reg recall_GHT PS TL if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
*   }
*   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   
*   reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
* *  reg recallFM PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*   
*   forvalues i=1/9 {
*   
*     local j=`i'+1
*     replace F`j'rwkesr2=. if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2 | F`i'rwkesr2==.)
*     replace F`i'rwkesr2 = 0 if (F`i'rwkesr2 == 1 | F`i'rwkesr2 == 2) & recall_GHT==1
*   
*     di "`i'"
*     tab F`i'rwkesr2 F`j'rwkesr2, row
*     tab F`i'rwkesr2 F`j'emp, row
*   
*   }
*   
*   forvalues i=1/9 {
*   
*     local j=`i'+1
*   
*     di "`i'"
*     tab F`i'rwkesr2 F`j'rwkesr2 if (F`i'rwkesr2==3 | F`i'rwkesr2==4) , row
*   
*   }
*   
*   forvalues i=1/9 {
*   
*     local j=`i'+1
*   
*     di "`i'"
*     tab F`i'rwkesr2 F`j'emp if (F`i'rwkesr2==3 | F`i'rwkesr2==4), row
*   
*   }
* 
* }
* * seam bias!
