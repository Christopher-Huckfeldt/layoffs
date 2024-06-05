* local jobMethod="alt"
local jobMethod=""

clear all
set fredkey 74348ccf8d0c8e4873861aa692a29323
import fred unrate
drop daten
sort datestr

gen date = substr(datestr,1,4)+substr(datestr,6,2)
gen year = substr(datestr,1,4)
gen month = substr(datestr,6,2)

destring date, replace
destring year, replace
destring month, replace
gen ym = ym(year,month)
format %tm ym
sort ym
rename UNRATE unrate
save tmpdata/unrate, replace


use tmpdata/recall96`jobMethod'.dta, clear
gen spanel = 1996
foreach panel in 01 04 08 {
  append using tmpdata/recall`panel'`jobMethod'.dta
  replace spanel = 2000+`panel' if spanel==.
}
gen ym = ym(rhcalyr, rhcalmn)
format %tm ym

sort ym
merge m:1 ym using tmpdata/unrate
assert (_merge==1 & no_pw~=1) | _merge==2 | _merge==3
keep if _merge==3

save tmpdata/alldata`jobMethod', replace

* ------

  use tmpdata/alldata`jobMethod', clear
  
  
  drop TL_E
  gen TL_E = .
  replace TL_E = 0 if unemp_type==3 & UE==0
  replace TL_E = 1 if unemp_type==3 & UE==1
  
  drop JL_E
  gen JL_E = .
  replace JL_E = 0 if unemp_type==4 & UE==0
  replace JL_E = 1 if unemp_type==4 & UE==1
  
  
  gen recall_prop  = recall
  
  gen recall_prob2 = .
  replace recall_prob2 = 0 if TL_E==0
  replace recall_prob2 = 1 if recall==1 & TL_E==1
  
  gen recall_prob3 = .
  replace recall_prob3 = 0 if JL_E==0
  replace recall_prob3 = 1 if recall==1 & JL_E==1
  
  gen recall_prob4 = .
  replace recall_prob4 = 0 if UE==0
  replace recall_prob4 = 1 if recall==1 & UE==1
  
  replace recall   = recall * UE
  
*  if `i'==2 {
*    keep if swave<=6
* drop if (rwkesr2==3 | rwkesr==4) & spell_length>4
*  }
  
  collapse (count) num=recall (mean) unrate recall* UE E_U E_TL E_JL JL_E TL_E, by(ym)

  sum unrate recall_prob2 TL_E JL_E E_TL E_JL
  pwcorr unrate recall_prob2 TL_E JL_E E_TL E_JL, sig

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

frame hazard: replace pR=. if rwkesr2==4 & duration>4
frame hazard: replace pN=. if rwkesr2==4 & duration>4

gen seam_cross = 1 if (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 0 if srefmonA==3 & srefmonZ==3 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 0 if srefmonA==3 & srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
replace seam_cross = 0 if srefmonA==4 & srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4

*x gen seam_cross = 0 if (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*x replace seam_cross = 1 if srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*x replace seam_cross = 1 if srefmonZ==1 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*x replace seam_cross = 1 if srefmonA>2 & srefmonZ==2 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*x replace seam_cross = 1 if srefmonA>3 & srefmonZ==3 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4

tab seam_cross rwkesr2 if spell_length<=2, col
tab seam_cross rwkesr2 if spell_length<=4, col


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



capture file close tmpfile
file open tmpfile using "tables/stats.txt", write replace

file write tmpfile _n "# Recall rates" _n

forvalues j=3/4 {

  if `j'==3 {
    local state = "TL"
  }
  else {
    local state = "PS"
  }

  reg recall if rwkesr2==`j' & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
  file write tmpfile "s/\<recall_`state'\>/" %5.3f (_b[_cons]) "/g"  _n
  count if rwkesr2==`j' & spell_end==tt & spell_length<=4 & swave<=6 & spanel ==1996
  foreach ispanel in 1996 2001 2004 2008 {
    reg recall if rwkesr2==`j' & spell_end==tt & spell_length<=4 & swave<=6 & spanel==`ispanel' [pw=lgtwgt]
    file write tmpfile "s/\<recall_`state'_`ispanel'\>/" %5.3f (_b[_cons]) "/g"  _n
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

*rm  file write tmpfile _n _n "# Distribution of first and last month" _n
*rm  
*rm  forvalues i=1/4 {
*rm    capture drop tmp
*rm    gen tmp = (srefmonA==`i')
*rm    reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==3 & EUE==1
*rm    file write tmpfile "s/\<srefmonA`i'_TL\>/" %5.3f (_b[_cons]) "/g"  _n
*rm    reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==4 & EUE==1
*rm    file write tmpfile "s/\<srefmonA`i'_PS\>/" %5.3f (_b[_cons]) "/g"  _n
*rm  }

file write tmpfile _n _n "# Distribution of last month" _n

forvalues i=1/4 {
  capture drop tmp
  gen tmp = (srefmonZ==`i')
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==3 & EUE==1
  file write tmpfile "s/\<srefmonZ`i'_TL\>/" %5.3f (_b[_cons]) "/g"  _n
  reg tmp [pw=lgtwgt] if spell_length<=4 & spell_begin==tt & rwkesr2==4 & EUE==1
  file write tmpfile "s/\<srefmonZ`i'_PS\>/" %5.3f (_b[_cons]) "/g"  _n
  * similar to "tab rwkesr2 srefmonZ if spell_length<=4 & 
  * spell_begin==tt & EUE==1, row", but with panel weights
}

file close tmpfile

*rm forvalues i=1/4 {
*rm   forvalues j=3/4 {
*rm   di "srefmonA is `i'"
*rm     reg recall if rwkesr2==`j' & srefmonA==`i' & spell_end==tt & spell_length<=4 & swave<=6 [pw=lgtwgt]
*rm   }
*rm }
*rm 
*rm gen seam_cross = 1 if (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*rm replace seam_cross = 0 if srefmonA==3 & srefmonZ==3 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*rm replace seam_cross = 0 if srefmonA==3 & srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*rm replace seam_cross = 0 if srefmonA==4 & srefmonZ==4 & (rwkesr2==3 | rwkesr2==4) & spell_length<=4
*rm 
*rm 
*rm * "short spells" w/ seam cross
*rm reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==1 & spell_length<=2 & spell_length>0 & swave<=6 [pw=lgtwgt]
*rm reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==0 & spell_length<=2 & spell_length>0 & swave<=6 [pw=lgtwgt]
*rm 
*rm * "longer spells" w/ seam cross
*rm reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==1 & spell_length<=4 & spell_length>0 & swave<=6 [pw=lgtwgt]
*rm reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & seam_cross==0 & spell_length<=4 & spell_length>0 & swave<=6 [pw=lgtwgt]
*rm 
*rm * "long spells"
*rm reg recall if (rwkesr2==3 | rwkesr2==4) & spell_end==tt & spell_length<=6 & spell_length>2 & swave<=6 [pw=lgtwgt]
*rm 
*rm 
*rm 
*rm reg recall if rwkesr2==3 & spell_end==tt & spell_length<=6 & swave<=6 [pw=lgtwgt]
*rm 
*rm reg recall if rwkesr2==4 & unemp_type==4 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4
*rm reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
*rm reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4
*rm 
*rm reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
*rm reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=12 & swave<=6
*rm 
*rm 
*rm 
*rm 
*rm frame hazard: outsheet using hazards.csv, comma replace
*rm 
*rm * compute recall probability without loss of recall.
