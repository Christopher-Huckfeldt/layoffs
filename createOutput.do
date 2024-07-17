use tmpdata/recall96.dta, clear
gen spanel = 1996
foreach panel in 01 04 08 {
  append using tmpdata/recall`panel'.dta
  replace spanel = 2000+`panel' if spanel==.
}
gen ym = ym(rhcalyr, rhcalmn)
format %tm ym

drop if EUE==. & EUN==. 

capture drop job_info_lost
gen job_info_lost = 0
replace job_info_lost = 1 if rwkesr2==4 & srefmonA==1 & spell_length>=4
replace job_info_lost = 1 if rwkesr2==4 & srefmonA==2 & spell_length>=5
replace job_info_lost = 1 if rwkesr2==4 & srefmonA==3 & spell_length>=6
replace job_info_lost = 1 if rwkesr2==4 & srefmonA==4 & spell_length>=7

save tmpdata/alldata, replace

use tmpdata/alldata, clear
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

*frame hazard_panel: replace pR=. if rwkesr2==4 & duration>4
*frame hazard_panel: replace pN=. if rwkesr2==4 & duration>4
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

*frame hazard_srefmonA: replace pR=. if rwkesr2==4 & duration>4
*frame hazard_srefmonA: replace pN=. if rwkesr2==4 & duration>4
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
use tmpdata/alldata, clear


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

frame hazard: sort rwkesr2 duration
frame hazard: outsheet using hazard.csv, comma replace



clear all
use tmpdata/alldata, clear


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

foreach panel in 1996 2001 2004 2008 {
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


* HOW MANY SEAM CROSSERS?

tab multiple_Ucodes if spell_end==tt & swave<=6
tab multiple_Ucodes if rwkesr2==3 & spell_end==tt
tab multiple_Ucodes if rwkesr2==4 & spell_end==tt

gen seam_cross = 0
#delimit;
replace seam_cross = 1 if (rwkesr2==3 | rwkesr2==4)
  & (srefmonA==2 & srefmonZ==2 & spell_length==1
    | srefmonA==2 & srefmonZ==3 & spell_length==2
    | srefmonA==3 & srefmonZ==3 & spell_length==1);
#delimit cr

tab seam_cross if rwkesr2==4 & spell_end==tt & spell_length<=4
tab seam_cross if rwkesr2==4 & spell_end==tt & spell_length<=6


capture file close tmpfile
file open tmpfile using "tables/stats.txt", write replace

forvalues j=3/4 {

file write tmpfile _n "# Recall shares" _n

  if `j'==3 {
    local state = "TL"
  }
  else {
    local state = "PS"
  }

  reg recall if rwkesr2==`j' & EUE==1 & job_info_lost==0 & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
  file write tmpfile "s/\<recall_`state'\>/" %5.3f (_b[_cons]) "/g"  _n
  foreach ispanel in 1996 2001 2004 2008 {
    reg recall if rwkesr2==`j' & EUE==1 & job_info_lost==0 & spell_end==tt & spell_length<=4 & swave<=6 & spanel==`ispanel' [pw=lgtwgt]
    file write tmpfile "s/\<recall_`state'_`ispanel'\>/" %5.3f (_b[_cons]) "/g"  _n
  }
}


forvalues ilength = 2/8 {

file write tmpfile _n "# Recall shares by duration & controlling for missing data, spell duration lte `ilength'" _n

  forvalues j=3/4 {
  
    if `j'==3 {
      local state = "TL"
    }
    else {
      local state = "PS"
    }
  
    reg recall if rwkesr2==`j' & EUE==1 & spell_end==tt & spell_length<=`ilength' & swave<=6 [pw=lgtwgt]
    file write tmpfile "s/\<rShare_`state'_`ilength'\>/" %5.3f (_b[_cons]) "/g"  _n
    foreach ispanel in 1996 2001 2004 2008 {
      reg recall if rwkesr2==`j' & EUE==1 & spell_end==tt & spell_length<=`ilength' & swave<=6 & spanel==`ispanel' [pw=lgtwgt]
      file write tmpfile "s/\<rShare_`state'_`ilength'_`ispanel'\>/" %5.3f (_b[_cons]) "/g"  _n
    }
  
    if (`j'==4 & `ilength'<8) {
      reg recall if rwkesr2==`j' & EUE==1 & spell_end==tt & spell_length<=`ilength' & job_info_lost==0 & swave<=6 [pw=lgtwgt]
      file write tmpfile "s/\<rShare_`state'_jinfo_`ilength'\>/" %5.3f (_b[_cons]) "/g"  _n
      foreach ispanel in 1996 2001 2004 2008 {
        reg recall if rwkesr2==`j' & EUE==1 & spell_end==tt & spell_length<=`ilength' & swave<=6 & spanel==`ispanel' [pw=lgtwgt]
        file write tmpfile "s/\<rShare_`state'_jinfo_`ilength'_`ispanel'\>/" %5.3f (_b[_cons]) "/g"  _n
      }
    }
  }
}



file write tmpfile _n _n "# Distribution of first month" _n

forvalues i=1/4 {
  capture drop tmp
  gen tmp = (srefmonA==`i')
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==3 & EUE==1
  file write tmpfile "s/\<srefmonA`i'_TL\>/" %5.3f (_b[_cons]) "/g"  _n
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==4 & EUE==1
  file write tmpfile "s/\<srefmonA`i'_PS\>/" %5.3f (_b[_cons]) "/g"  _n
}

file write tmpfile _n _n "# Distribution of last month" _n

forvalues i=1/4 {
  capture drop tmp
  gen tmp = (srefmonZ==`i')
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==3 & EUE==1
  file write tmpfile "s/\<srefmonZ`i'_TL\>/" %5.3f (_b[_cons]) "/g"  _n
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==4 & EUE==1
  file write tmpfile "s/\<srefmonZ`i'_PS\>/" %5.3f (_b[_cons]) "/g"  _n
}

file close tmpfile
