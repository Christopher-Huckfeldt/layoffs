local jobMethod="alt"
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
keep if _merge==3

save tmpdata/alldata`jobMethod', replace

forvalues i=1/2 {
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
  
  if `i'==2 {
    keep if swave<=6
  *  keep if spell_length<=4
  }
  
  collapse (count) num=recall (mean) unrate recall* UE E_U E_TL E_JL JL_E TL_E, by(ym)

  pwcorr unrate recall_prob2 recall_prop recall_prob3 unrate, sig
}

  
use tmpdata/alldata`jobMethod', clear

drop if typeZ==1 | no_pw==1
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
      quietly reg tmp if /*unemp_type==`j' &*/ rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`panel' [pw=lgtwgt]
      local recallP = _b[_cons]
      drop tmp
      *
      gen tmp = (recall==0 & spell_length==`i')
      quietly reg tmp if /*unemp_type==`j' &*/ rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 & spanel==`panel' [pw=lgtwgt ]
      local hireP = _b[_cons]
      drop tmp
      *
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }
}


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
      quietly reg tmp if /*unemp_type==`j' &*/ rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt]
      local recallP = _b[_cons]
      drop tmp
      *
      gen tmp = (recall==0 & spell_length==`i')
      quietly reg tmp if /*unemp_type==`j' &*/ rwkesr2==`j' & spell_end==tt & spell_length>=`i' & swave<=6 [pw=lgtwgt ]
      local hireP = _b[_cons]
      drop tmp
      *
      di "year is `panel', t=`i', `recallP', `hireP'" 
    }
  }


forvalues j=3/4 {
  reg recall if rwkesr2==`j' & unemp_type==`j' & spell_end==tt & spell_length<=4 & swave<=6
*  forvalues i=1/4 {
*    reg recall if rwkesr2==`j' & unemp_type==`j' & spell_end==tt & spell_length==`i' & swave<=6
*  }
}

reg recall if rwkesr2==4 & unemp_type==4 & spell_end==tt & spell_length<=4 & swave<=6
reg recall if rwkesr2==4 & unemp_type==4 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6 & srefmonZ<4

reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=3 & swave<=6
reg recall if rwkesr2==3 & unemp_type==3 & spell_end==tt & spell_length<=12 & swave<=6




frame hazard: outsheet using hazards.csv, comma replace

* compute recall probability without loss of recall.
