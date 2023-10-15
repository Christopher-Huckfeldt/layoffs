*tmp local jobMethod="alt"
*tmp local jobMethod=""
*tmp 
*tmp clear all
*tmp set fredkey 74348ccf8d0c8e4873861aa692a29323
*tmp import fred unrate
*tmp drop daten
*tmp sort datestr
*tmp 
*tmp gen date = substr(datestr,1,4)+substr(datestr,6,2)
*tmp gen year = substr(datestr,1,4)
*tmp gen month = substr(datestr,6,2)
*tmp 
*tmp destring date, replace
*tmp destring year, replace
*tmp destring month, replace
*tmp gen ym = ym(year,month)
*tmp format %tm ym
*tmp sort ym
*tmp rename UNRATE unrate
*tmp save tmpdata/unrate, replace
*tmp 
*tmp 
*tmp use tmpdata/recall96`jobMethod'.dta, clear
*tmp gen spanel = 1996
*tmp foreach panel in 01 04 08 {
*tmp   append using tmpdata/recall`panel'`jobMethod'.dta
*tmp   replace spanel = 2000+`panel' if spanel==.
*tmp }
*tmp gen ym = ym(rhcalyr, rhcalmn)
*tmp format %tm ym
*tmp 
*tmp sort ym
*tmp merge m:1 ym using tmpdata/unrate
*tmp keep if _merge==3
*tmp 
*tmp save tmpdata/alldata`jobMethod', replace
*tmp 
*tmp forvalues i=1/2 {
*tmp   use tmpdata/alldata`jobMethod', clear
*tmp   
*tmp   
*tmp   drop TL_E
*tmp   gen TL_E = .
*tmp   replace TL_E = 0 if unemp_type==3 & UE==0
*tmp   replace TL_E = 1 if unemp_type==3 & UE==1
*tmp   
*tmp   drop JL_E
*tmp   gen JL_E = .
*tmp   replace JL_E = 0 if unemp_type==4 & UE==0
*tmp   replace JL_E = 1 if unemp_type==4 & UE==1
*tmp   
*tmp   
*tmp   gen recall_prop  = recall
*tmp   
*tmp   gen recall_prob2 = .
*tmp   replace recall_prob2 = 0 if TL_E==0
*tmp   replace recall_prob2 = 1 if recall==1 & TL_E==1
*tmp   
*tmp   gen recall_prob3 = .
*tmp   replace recall_prob3 = 0 if JL_E==0
*tmp   replace recall_prob3 = 1 if recall==1 & JL_E==1
*tmp   
*tmp   gen recall_prob4 = .
*tmp   replace recall_prob4 = 0 if UE==0
*tmp   replace recall_prob4 = 1 if recall==1 & UE==1
*tmp   
*tmp   replace recall   = recall * UE
*tmp   
*tmp   if `i'==2 {
*tmp     keep if swave<=6
*tmp   *  keep if spell_length<=4
*tmp   }
*tmp   
*tmp   collapse (count) num=recall (mean) unrate recall* UE E_U E_TL E_JL JL_E TL_E, by(ym)
*tmp 
*tmp   pwcorr unrate recall_prob2 recall_prop recall_prob3 unrate, sig
*tmp }
*tmp 
*tmp   
use tmpdata/alldata`jobMethod', clear
capture frame change default

* -----------------
* hazards, by panel
* -----------------

capture frame drop hazard_panel
frame create hazard_panel
frame hazard_panel: insobs 64 // 8 * 4 * 2
frame hazard_panel: gen duration = .
frame hazard_panel: gen pE = .
frame hazard_panel: gen pN = .
frame hazard_panel: gen pR = .
frame hazard_panel: gen rwkesr2 = .
frame hazard_panel: gen spanel = .
*
frame change hazard_panel
local iter=1
foreach ipanel in 1996 2001 2004 2008 {
  forvalues iesr = 3/4 {
    forvalues idur = 1/8 {
      replace duration=`idur' if _n==`iter'
      replace rwkesr2=`iesr' if _n==`iter'
      replace spanel=`ipanel' if _n==`iter'
      local iter=`iter'+1
    }
  }
}

frame change default

foreach ipanel in 1996 2001 2004 2008 {
  forvalues j=3/4 {
    if (`j'==3) {
      di "TL"
    }
    else {
      di "PS"
    }
    forvalues i=1/8 {
      capture drop tmp
      gen tmp = (recall==1 & spell_length==`i')
      quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`ipanel' [pw=lgtwgt]
      local recallP = _b[_cons]
      frame hazard_panel: quietly replace pR = `recallP' if duration==`i' & spanel==`ipanel' & rwkesr2==`j'
      drop tmp
      *
      gen tmp = (recall==0 & spell_length==`i')
      quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`ipanel' [pw=lgtwgt ]
      local hireP = _b[_cons]
      frame hazard_panel: quietly replace pN = `hireP' if duration==`i' & spanel==`ipanel' & rwkesr2==`j'
      drop tmp
      *
      di "year is `ipanel', t=`i', `recallP', `hireP'" 
      *
      frame hazard_panel: quietly replace pE = `recallP' + `hireP' if duration==`i' & spanel==`ipanel' & rwkesr2==`j'
    }
  }
}

frame hazard_panel: replace pR=. if rwkesr2==4 & duration>4
frame hazard_panel: replace pN=. if rwkesr2==4 & duration>4
frame hazard_panel: sort rwkesr2 duration spanel
frame hazard_panel: outsheet using hazard_panel.csv, comma replace

* -----------------
* hazards, by panel & refmth
* -----------------

capture frame drop hazard_srefmonA
frame create hazard_srefmonA
frame hazard_srefmonA: insobs 256 // 8 * 4 * 2 * 4
frame hazard_srefmonA: gen duration = .
frame hazard_srefmonA: gen pE = .
frame hazard_srefmonA: gen pN = .
frame hazard_srefmonA: gen pR = .
frame hazard_srefmonA: gen rwkesr2 = .
frame hazard_srefmonA: gen srefmonA = .
*
frame change hazard_srefmonA
local iter=1
forvalues iesr = 3/4 {
  forvalues isrefmonA = 1/4 {
    forvalues idur = 1/8 {
      replace duration=`idur' if _n==`iter'
      replace rwkesr2=`iesr' if _n==`iter'
      replace srefmonA=`isrefmonA' if _n==`iter'
      local iter=`iter'+1
    }
  }
}

frame change default

forvalues j=3/4 {
  forvalues isrefmonA = 1/4 {
    if (`j'==3) {
      di "TL, `isrefmonA'"
    }
    else {
      di "PS, `isrefmonA'"
    }
    forvalues i=1/8 {
      capture drop tmp
      gen tmp = (recall==1 & spell_length==`i')
      quietly capture reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & srefmonA==`isrefmonA' [pw=lgtwgt]
      local recallP = _b[_cons]
      frame hazard_srefmonA: quietly replace pR = `recallP' if duration==`i' & rwkesr2==`j' & srefmonA==`isrefmonA'
      drop tmp
      *
      gen tmp = (recall==0 & spell_length==`i')
      quietly capture reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & srefmonA==`isrefmonA' [pw=lgtwgt ]
      local hireP = _b[_cons]
      frame hazard_srefmonA: quietly replace pN = `hireP' if duration==`i' & rwkesr2==`j' & srefmonA==`isrefmonA'
      drop tmp
      *
      di "year is `ipanel', t=`i', `recallP', `hireP'" 
      *
      frame hazard_srefmonA: quietly replace pE = `recallP' + `hireP' if duration==`i' & rwkesr2==`j' & srefmonA==`isrefmonA'
    }
  }
}

frame hazard_srefmonA: replace pR=. if rwkesr2==4 & duration>4
frame hazard_srefmonA: replace pN=. if rwkesr2==4 & duration>4
frame hazard_srefmonA: sort rwkesr2 srefmonA duration
frame hazard_srefmonA: outsheet using hazard_srefmonA.csv, comma replace

* ------------------
* hazards, aggregate
* ------------------

capture frame drop hazard
frame create hazard
frame hazard: insobs 16 // 8 * 2
frame hazard: gen duration = .
frame hazard: gen pE = .
frame hazard: gen pN = .
frame hazard: gen pR = .
frame hazard: gen rwkesr2 = .
*
frame change hazard
local iter=1
forvalues iesr = 3/4 {
  forvalues idur = 1/8 {
    replace duration=`idur' if _n==`iter'
    replace rwkesr2=`iesr' if _n==`iter'
    local iter=`iter'+1
  }
}

frame change default

forvalues j=3/4 {
  if (`j'==3) {
    di "TL"
  }
  else {
    di "PS"
  }
  forvalues i=1/8 {
    capture drop tmp
    gen tmp = (recall==1 & spell_length==`i')
    quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt]
    local recallP = _b[_cons]
    frame hazard: quietly replace pR = `recallP' if duration==`i' & rwkesr2==`j'
    drop tmp
    *
    gen tmp = (recall==0 & spell_length==`i')
    quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt ]
    local hireP = _b[_cons]
    frame hazard: quietly replace pN = `hireP' if duration==`i' & rwkesr2==`j'
    drop tmp
    *
    di "year is `ipanel', t=`i', `recallP', `hireP'" 
    *
    frame hazard: quietly replace pE = `recallP' + `hireP' if duration==`i' & rwkesr2==`j'
  }
}

frame hazard: replace pR=. if rwkesr2==4 & duration>4
frame hazard: replace pN=. if rwkesr2==4 & duration>4
frame hazard: sort rwkesr2 duration
frame hazard: outsheet using hazard.csv, comma replace
dflkj

frame hazard: replace pR=. if rwkesr2==4 & duration>4
frame hazard: replace pN=. if rwkesr2==4 & duration>4
dflkj

gen seam_cross = 0 if (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 1 if srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 1 if srefmonZ==1 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 1 if srefmonA>2 & srefmonZ==2 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 1 if srefmonA>3 & srefmonZ==3 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4

tab seam_cross rwkesr2 if spell_length<=2, col
tab seam_cross rwkesr2 if spell_length<=4, col
dflkj


clear all
use tmpdata/alldata`jobMethod', clear


capture frame drop hazard
frame create hazard
frame hazard: insobs 16
frame hazard: gen duration = .
frame hazard: gen pE = .
frame hazard: gen pN = .
frame hazard: gen pR = .
frame hazard: gen TL = .

forvalues j=3/4 {
  if (`j'==3) {
    di "TL"
  }
  else {
    di "PS"
  }
  forvalues i=1/8 {
    gen tmp = (recall==1 & spell_length==`i')
    quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt]
    local recallP = _b[_cons]
    drop tmp
    *
    gen tmp = (recall==0 & spell_length==`i')
    quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt ]
    local hireP = _b[_cons]
    drop tmp
    *
    di "year is `panel', t=`i', `recallP', `hireP'" 
  }
}



capture frame drop hazard
frame create hazard
frame hazard: insobs 64
frame hazard: gen duration = .
frame hazard: gen pE = .
frame hazard: gen pN = .
frame hazard: gen pR = .
frame hazard: gen TL = .
frame hazard: gen panel = .

foreach panel in 1996 2001 2004 {
  forvalues j=3/4 {
    if (`j'==3) {
      di "TL"
    }
    else {
      di "PS"
    }
    forvalues i=1/8 {
      gen tmp = (recall==1 & spell_length==`i')
      quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`panel' [pw=lgtwgt]
      local recallP = _b[_cons]
      drop tmp
      *
      gen tmp = (recall==0 & spell_length==`i')
      quietly reg tmp if rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`panel' [pw=lgtwgt ]
      local hireP = _b[_cons]
      drop tmp
      *
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }
}



forvalues j=3/4 {
  reg recall if rwkesr2==`j' & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
}

forvalues i=1/4 {
  forvalues j=3/4 {
  di "srefmonA is `i'"
    reg recall if rwkesr2==`j' & srefmonA==`i' & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
  }
}

reg recall if rwkesr2==3 & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
reg recall if rwkesr2==4 & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]

* "short spells" w/ seam cross
reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==1 & spell_length<=2 & spell_length>0 & swave<=6 [pw=lgtwgt]
reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==0 & spell_length<=2 & spell_length>0 & swave<=6 [pw=lgtwgt]

* "longer spells" w/ seam cross
reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==1 & spell_length<=4 & spell_length>0 & swave<=6 [pw=lgtwgt]
reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==0 & spell_length<=4 & spell_length>0 & swave<=6 [pw=lgtwgt]

* "long spells"
reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & spell_length<=6 & spell_length>2 & swave<=6 [pw=lgtwgt]



reg recall if rwkesr2==3 & spell_end==tt & spell_length<=6 & swave<=6 [pw=lgtwgt]

reg recall if rwkesr2==4 & unemp_type==4 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4

reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=12 & swave<=6




frame hazard: outsheet using hazards.csv, comma replace

* compute recall probability without loss of recall.
