clear all
set more off
capture log close

log using "logfiles/runAnalysis.log", replace

use tmpdata/cw96.dta, clear

egen ID = group(ssuseq ssuid epppnum )

* -------------------------
* main table
* -------------------------

sort ID swave srefmon

gen SM_any3=0
gen SM_any4=0
forvalues imn=1/4 { // loop over reference month
  by ID swave srefmon: replace SM_any3 = 1 if (rwkesr2==3 & srefmon==`imn')
  by ID swave srefmon: replace SM_any4 = 1 if (rwkesr2==4 & srefmon==`imn')
}

gen sub_esr = 3 if rwkesr2==3
replace sub_esr = 4 if rwkesr2==4

tab elayoff sub_esr if elayoff~=-1, row col

* -------------------------
* within wave comparison
* -------------------------

sort ID swave srefmon

gen any3 = 0  // varies over the wave
gen any4 = 0  // varies over the wave
forvalues imn=1/4 { // loop over reference month
  forvalues iwk=1/5 { // loop over weeks in a month
    by ID swave: replace any3 = 1 if (rwkesr`iwk'==3 & `iwk'<=rwksperm & srefmon==`imn')
    by ID swave: replace any4 = 1 if (rwkesr`iwk'==4 & `iwk'<=rwksperm & srefmon==`imn')
  }
}

sort ID swave srefmon
by ID swave: gen comb34 = (any3 == 1 & any4 == 1)  // rwkesr = 3 or 4 during wave
by ID swave: gen only3  = (any3 == 1 & any4 == 0)  // rwkesr = 3 and not 4 during wave
by ID swave: gen only4  = (any3 == 0 & any4 == 1)  // rwkesr = 4 and not 3 during wave

keep if any3==1 | any4==1
collapse (mean) any3 any4 only3 only4 comb34, by(swave)

list
* comb34 always less than one percent

capture log close
