clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace
clear all

local jobMethod="alt"
local jobMethod=""

* note: drop people who are present for first wave? or people with gaps?

foreach panel in 96 01 04 08 {
*foreach panel in 96  {

  use tmpdata/cw`panel'.dta, clear
  keep if wgt_merge==3
*  drop if typeZ==1
*  drop if no_pw
  drop wgt_merge
  
  
  egen ID = group(ssuid epppnum)
  sort ID swave srefmon
  
  gen undur = (rwkesr2==3 | rwkesr2==4) // unemployed in week 2
  
  by ID (swave srefmon): gen undur_eu = (undur==1 & (rwkesr2[_n-1]==1|rwkesr2[_n-1]==2)) // E to U
  gen tt = srefmon + (swave-1)*4
  
  * ---------------------------------------------------
  * Compute unemployment duration into "subset`panel'"
  * ---------------------------------------------------
  
  frame change default
  frames put ID tt undur undur_eu, into(subset`panel')
  frame change subset`panel'
  quietly sum tt
  local tmax = r(max)
  reshape wide undur undur_eu, i(ID) j(tt)
  *
  
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
  bys ID (spell_begin): gen eu_index = _n

  * Put index numbers into main dataset
  frame change subset`panel'
  frlink m:1 ID spell_begin, frame(subsubset)
  frget eu_index = eu_index, from(subsubset)
  
  * ----------------------------
  * Identify recalls from short samples, in "recall"
  * ----------------------------
  frame change default
  frames put ID ssuid epppnum tt swave srefmon rhcalyr rhcalmn eeno1 eeno2 tpmsum1 tpmsum2 tpearn tejdate1 tejdate2 tsjdate1 tsjdate2 rwkesr2, into(recall)
  frame change recall
  sort ID tt

  if "`jobMethod'"=="alt" {
    gen jbID1=0
    gen jbID2=0
    replace jbID1 = eeno1 if (rwkesr2==1 | rwkesr2==2) & (eeno2<=0 | eeno2==.)
    replace jbID2 = eeno2 if (rwkesr2==1 | rwkesr2==2) & (eeno1<=0 | eeno1==.)
  }
  else {
    gen jbID1 = eeno1*(tpmsum1!=0)
    gen jbID2 = eeno2*(tpmsum2!=0)
  }

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

  gen anyjob = (eeno1>0 & eeno1~=.) | (eeno2>0 & eeno2~=.)
  gen problem = (anyjob==1 & tpmsum1==0 & tpmsum2==0 & rwkesr2==1)
  gen nojob_havepay = (rwkesr2==3 | rwkesr2==4) & ((tpmsum1>0 & tpmsum1~=.) | (tpmsum2>0 & tpmsum2~=.))
  

  egen spellID = group(status jbID1 jbID2)
  * note, a single employment spells for an individual could potentially have _multiple_ IDs, 
  * whereas unemployment spells will have single ID, identifiable from E-U-E.
  * measure is NOT individual specific.
  
  frames put ID tt spellID, into(status_frm) // leave "recall"
  frame change status_frm
  quietly sum tt
  local tmax = r(max)

  reshape wide spellID, i(ID) j(tt)

  forvalues i=1/`tmax' {
    gen indx`i' = 1
  }

  forvalues i=2/`tmax' {
    local j = `i'-1
    replace indx`i' = indx`j' + 1*(spellID`i'~=spellID`j')
  }
  reshape long spellID indx, i(ID) j(tt)

  frame change recall
  frlink 1:1 ID spellID tt, frame(status_frm)
  frget indx = indx, from(status_frm)

  collapse (max) nojob_havepay last_rhcalyr = rhcalyr last_rhcalmn=rhcalmn (min) first_rhcalyr = rhcalyr first_rhcalmn=rhcalmn (max) problem eeno1 eeno2 tejdate1 tejdate2 tsjdate1 tsjdate2 (first) srefmonA=srefmon rwkesr2 status jbID1 jbID2 (sum) lngth (min) tt_begin=tt (max) tt_end=tt (last) srefmonZ=srefmon, by(ID ssuid epppnum indx)
  sort ID tt_begin
  order ID indx tt_begin tt_end lngth status jbID1 jbID2
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

  bys ID: egen total_recall = total(recall)
  replace total_recall = (total_recall>0 & total_recall~=.)
  bys ID (tt_begin): gen new_problem = EUE==1 & (problem[_n-1]==1 | problem[_n+1]==1)
  gen tm_first = ym(first_rhcalyr,first_rhcalmn)
  gen tm_last = ym(last_rhcalyr,last_rhcalmn)
  format %tm tm_last tm_first
  keep if EUE==1
  rename tt_begin spell_begin
  rename rwkesr2 unemp_type
  keep ID spell_begin recall EUE unemp_type problem srefmonA srefmonZ nojob_havepay

  * merge variables from frame recall to frame subsubset
  frame change subsubset
  drop undur undur_eu
  frlink m:1 ID spell_begin, frame(recall) gen(rlnk)
  frget recall = recall, from(rlnk)
  frget unemp_type = unemp_type, from(rlnk)
  frget EUE = EUE, from(rlnk)
  frget srefmonA = srefmonA, from(rlnk)
  frget srefmonZ = srefmonZ, from(rlnk)
  frget nojob_havepay = nojob_havepay, from(rlnk)

  
  * merge variables from frame subsubset to frame subset`panel'
  frame change subset`panel'
  frget recall     = recall, from(subsubset)
  frget unemp_type = unemp_type, from(subsubset)
  frget EUE = EUE, from(subsubset)
  frget srefmonA = srefmonA, from(subsubset)
  frget srefmonZ = srefmonZ, from(subsubset)
  frget nojob_havepay = nojob_havepay, from(subsubset)

  frlink 1:1 ID tt, frame(default)
  frget rwkesr2 = rwkesr2, from(default)
  frget swave = swave, from(default)
  frget srefmon = srefmon, from(default)
  frget rhcalyr = rhcalyr, from(default)
  frget rhcalmn = rhcalmn, from(default)
  frget lgtwgt = lgtwgt, from(default)
  frget no_pw = no_pw, from(default)
  frget typeZ = typeZ, from(default)

  gen UE=.
  gen TL_E=.
  gen JL_E=.
  gen E_U=.
  gen E_TL=.
  gen E_JL=.

  bys ID (tt): replace UE = 0 if (rwkesr2==3 | rwkesr2==4)
  bys ID (tt): replace UE = 1 if (rwkesr2==3 | rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
  *
  bys ID (tt): replace TL_E = 0 if (rwkesr2==3)
  bys ID (tt): replace TL_E = 1 if (rwkesr2==3) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)
  *
  bys ID (tt): replace JL_E = 0 if (rwkesr2==4)
  bys ID (tt): replace JL_E = 1 if (rwkesr2==4) & (rwkesr2[_n+1]==1 | rwkesr2[_n+1]==2)

  bys ID (tt): replace E_U = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_U = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3 | rwkesr2[_n+1]==4)
  *
  bys ID (tt): replace E_TL = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_TL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==3)
  *
  bys ID (tt): replace E_JL = 0 if (rwkesr2==1 | rwkesr2==2)
  bys ID (tt): replace E_JL = 1 if (rwkesr2==1 | rwkesr2==2) & (rwkesr2[_n+1]==4)


gen hire = 1-(recall==1)
drop if typeZ==1 | no_pw==1
  forvalues j=3/4 {
    if (`j'==3) {
      di "TL"
    }
    else {
      di "PS"
    }
    forvalues i=1/8 {
      gen tmp = (recall==1 & spell_length==`i')
      quietly reg tmp if unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt]
      local recallP = _b[_cons]
      drop tmp
      gen tmp = (recall==0 & spell_length==`i')
      quietly reg tmp if unemp_type==`j' & rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt ]
      local hireP = _b[_cons]
      drop tmp
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }

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

  if "`jobMethod'"=="alt" {
    save tmpdata/recall`panel'alt.dta, replace
  }
  else {
    save tmpdata/recall`panel'.dta, replace
  }
  clear all

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
