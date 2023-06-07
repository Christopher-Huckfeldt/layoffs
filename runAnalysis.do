clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace

*foreach panel in 96 01 04 08 {

local panel = "01"
{

  use tmpdata/cw`panel'.dta, clear
  
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
  gen undur_en = undur_eu // restrict attention to non-employment spells that begin with unemployment
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
  gen spell_begin = tt if undur_eu==1
  by ID (tt), sort: replace spell_begin = spell_begin[_n-1] if spell_begin[_n-1]>0 & spell_begin[_n-1]~=. & undur_eu>1 & undur_eu~=.
  by ID spell_begin (tt), sort: gen spell_end = tt[_N]
  replace spell_end = . if spell_begin==.
  gen spell_length = spell_end-spell_begin+1
  replace undur_eu=0 if undur_eu==.
  
  frame change default
  drop undur undur_eu undur_en
  
  frlink 1:1 ID tt, frame(subset)
  frget undur_eu     = undur_eu, from(subset)
  frget undur_en     = undur_en, from(subset)
  frget spell_begin  = spell_begin, from(subset)
  frget spell_end    = spell_end, from(subset)
  frget spell_length = spell_length, from(subset)
  
  * ----------------------------
  * Identify recalls from short samples
  * ----------------------------
  sort ID
  
  gen jbID1 = eeno1*(tpmsum1!=0) //  another option is to use rwkesr2==1
  gen jbID2 = eeno2*(tpmsum2!=0)
  replace jbID1=0 if jbID1<0 | jbID1==.
  replace jbID2=0 if jbID2<0 | jbID2==.
  gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)
  
  
  
  * capture drop EUE_GHT
  * capture drop EUEjob_GHT
  * capture drop EUEjob_GHTa
*  capture drop RecallJob_GHT
*  capture drop RecallJob_GHTa
  capture drop recall_GHT
  capture drop stillPaid
  capture drop stillPaid_any
  capture drop stillPaidAll
  capture drop recall
  
  * gen EUE_GHT        = 0
  * gen EUEjob_GHT     = 0
  * gen RecallJob_GHT  = 0
  * gen RecallJob_GHTa = 0
  gen recall_GHT     = 0
  gen recall         = 0
  gen stillPaid      = 0
  gen stillPaid_any  = 0
  gen stillPaidAll   = 0

  forvalues ii=1/9 {
  
*    #delimit;
*    replace EUE_GHT = 1 if undur_eu[_n+1]==1 & undur_eu[_n+`ii']==`ii' 
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
  
*    #delimit;
*    replace EUEjob_GHT = 1 if (jbID1~=0 | jbID2~=0)
*      & (jbID1[_n+1+`ii']~=0 | jbID2[_n+1+`ii']~=0)
*      & undur_eu[_n+1]==1 & undur_eu[_n+`ii']==`ii' & undur_eu[_n+1+`ii']==0 
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
  
*    #delimit;
*    replace RecallJob_GHT = jbID1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*      (jbID1==jbID2[_n+1+`ii'] & jbID1~=0)) 
*      & undur_eu[_n+1]==`ii' & undur_eu[_n+1+`ii']==0 
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
  
    * #delimit;
    * replace RecallJob_GHT = jbID2 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    *   (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    *   & undur_eu[_n+1]==`ii' & undur_eu[_n+1+`ii']==0 
    *   & (rwkesr2==1 | rwkesr2==2)
    *   & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
    *   RecallJob_GHT==0;
    * #delimit cr
  
    * #delimit;
    * replace RecallJob_GHTa = jbID1 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
    *   (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
    *   & undur_eu[_n+1]==`ii' & undur_eu[_n+1+`ii']==0 
    *   & (rwkesr2==1 | rwkesr2==2)
    *   & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
    *   RecallJob_GHT~=0;
    * #delimit cr
  
    #delimit;
    replace stillPaid = 1 if ((tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
      (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
      (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
      (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
      & (rwkesr2==1 | rwkesr2==2)
      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
    #delimit cr
  
    #delimit;
    replace stillPaid_any = 1 if ((tpmsum1[_n+`ii']>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
      (tpmsum1[_n+`ii']>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
      (tpmsum2[_n+`ii']>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
      (tpmsum2[_n+`ii']>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
      & (rwkesr2==1 | rwkesr2==2)
      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
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
      & undur_eu[_n+1]==1 & undur_eu[_n+`ii']==`ii' & undur_eu[_n+`ii'+1]==0
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
  
*  forvalues ii=1/9 {
*  
*  *  #delimit;
*  *  replace EUE_GHT = 1 if undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' 
*  *    & (rwkesr2==1 | rwkesr2==2)
*  *    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*  *  #delimit cr
*  
*  *  #delimit;
*  *  replace EUEjob_GHT = 1 if (jbID1~=0 | jbID2~=0)
*  *    & (jbID1[_n+1+`ii']~=0 | jbID2[_n+1+`ii']~=0)
*  *    & undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' & undur_en[_n+1+`ii']==0 
*  *    & (rwkesr2==1 | rwkesr2==2)
*  *    & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*  *  #delimit cr
*  
*  *   #delimit;
*  *   replace RecallJob_GHT = jbID1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*  *     (jbID1==jbID2[_n+1+`ii'] & jbID1~=0)) 
*  *     & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
*  *     & (rwkesr2==1 | rwkesr2==2)
*  *     & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*  *   #delimit cr
*  * 
*  *   #delimit;
*  *   replace RecallJob_GHT = jbID2 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*  *     (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
*  *     & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
*  *     & (rwkesr2==1 | rwkesr2==2)
*  *     & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
*  *     RecallJob_GHT==0;
*  *   #delimit cr
*  
*  *   #delimit;
*  *   replace RecallJob_GHTa = jbID1 if ((jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*  *     (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
*  *     & undur_en[_n+1]==`ii' & undur_en[_n+1+`ii']==0 
*  *     & (rwkesr2==1 | rwkesr2==2)
*  *     & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2) &
*  *     RecallJob_GHT~=0;
*  *   #delimit cr
*  
*    #delimit;
*    replace stillPaid = 1 if ((tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*      (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
*  
*    #delimit;
*    replace stillPaid_any = 1 if ((tpmsum1[_n+`ii']>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum1[_n+`ii']>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum2[_n+`ii']>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*      (tpmsum2[_n+`ii']>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
*  
*    #delimit;
*    replace stillPaidAll = 1 if ((tpmsum1[_n+`ii']>0 & tpmsum1[_n+1]>0 & jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum1[_n+1]>0 & jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*      (tpmsum2[_n+1]>0 & jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*      (tpmsum2[_n+1]>0 & jbID2==jbID2[_n+1+`ii'] & jbID2~=0))
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
*  
*    #delimit;
*    replace recall_GHT = 1 if ((jbID1==jbID1[_n+1+`ii'] & jbID1~=0) |
*      (jbID1==jbID2[_n+1+`ii'] & jbID1~=0) |
*      (jbID2==jbID1[_n+1+`ii'] & jbID2~=0) |
*      (jbID2==jbID2[_n+1+`ii'] & jbID2~=0)) 
*      & undur_en[_n+1]==1 & undur_en[_n+`ii']==`ii' & undur_en[_n+`ii'+1]==0
*      & (rwkesr2==1 | rwkesr2==2)
*      & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2);
*    #delimit cr
*  
*    capture drop jID
*    capture drop jID_before
*    capture drop jID_after
*    
*    gen jID = jbID1 + jbID2 if (jbID1>0 & jbID2==0 | jbID1==0 & jbID2>0)
*    
*    by ID: gen jID_before = jID if spell_length[_n+1]==1
*    by ID: gen jID_after = jID[_n+1+`ii'] if spell_length[_n+1]==`ii' & (rwkesr2[_n+1+`ii']==1 | rwkesr2[_n+1+`ii']==2)
*    
*    replace recall = 1 if (jID_before==jID_after & jID_before~=. & jID_before~=-1 & jID_before~=0)
*    
*    capture drop jID
*    capture drop jID_before
*    capture drop jID_after
*  
*  }
  
  sort ssuid eentaid epppnum swave srefmon
  merge 1:1 ssuid eentaid epppnum swave srefmon using FMrecalls.dta
  
  frlink m:1 ID job, frame(jobs)
  frget end_date = end_date, from(jobs)
  frget last_tt = last_tt, from(jobs)
  frget start_date = start_date, from(jobs)
  frget first_tt = first_tt, from(jobs)
  
  by ID (tt), sort: gen F1spell_length = spell_length[_n+1]
  
  forvalues i=1/10 {
    capture drop F`i'rwkesr2
    
    bys ID (tt): gen F`i'rwkesr2 = rwkesr2[_n+`i']
    bys ID (tt): gen F`i'emp = (F`i'rwkesr2==1 | F`i'rwkesr2==2)
  }
  
  
  tab recall_GHT F1rwkesr2 if F1spell_length<=3 & (rwkesr2==1 | rwkesr2==2), col
  
  keep recall_GHT recallFM recall rwkesr2 F1rwkesr2 F1spell_length F*rwkesr2 srot stillPaid* swave rwkesr* F*emp srefmon
  keep if (rwkesr2==1 | rwkesr2==2) & F1spell_length~=0 & F1spell_length~=.
  
  gen TL = (F1rwkesr2==3)
  gen PS = (F1rwkesr2==4)

  gen TL_m1 = (F1rwkesr2==3 & srefmon==1)
  gen PS_m1 = (F1rwkesr2==4 & srefmon==1)

  *save this.dta, replace ("ne" durations)
  save that.dta, replace
  
  
  * checking for seam effect!
  forvalues i=1/2 {
    di "`i'"
    reg recall_GHT PS TL if srefmon<4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  }
  forvalues i=1/2 {
    di "`i'"
    reg recall_GHT PS TL if srefmon>4-`i' & F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  }

  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  * all of them
  forvalues i=1/4 {
    di "`i'"
    reg recall_GHT PS TL if F1spell_length==`i' & (rwkesr2==1 | rwkesr2==2), hascons
  }
  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  reg stillPaid_any PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  reg recall_GHT PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length>1 & F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
*  reg recallFM PS TL if F1spell_length<=4 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length<=4 & stillPaid_any==1 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  reg recall_GHT PS TL if F1spell_length<=4 & stillPaid_any==0 & (rwkesr2==1 | rwkesr2==2) & swave<=6, hascons
  
  
  
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
