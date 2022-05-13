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

dflkj

/* Hypothesis 1): wkesr*==3 if and only if a worker reports being on temporary layoff. Check by cross-tabbing "ELAYOFF" with "any3". Under hypothesis, only3==0 => elayoff==1.  */

tab elayoff only3
tab elayoff only3 if elayoff~=-1

/* Reject hypothesis. We see many cases where layoff==1 but worker never reports wkesr==3. */

* -------------------------

/* Hypothesis 2): A worker reporting wkesr*=4 and never wkesr*=3 cannot be on temporary layoff. check by cross-tabing "ELAYOFF" with "only4" */

tab elayoff only4
tab elayoff only4 if elayoff~=-1

/* Reject hypothesis. We see many cases where worker is on Layoff but reports wkesr==4 (and not wkesr==3). */

* -------------------------

* folks can be on layoff and looking for work.

tab elayoff elkwrk
tab elayoff elkwrk if elayoff~=-1 & elkwrk~=-1

* If you report only3==1, you are definitely a worker on temporary 
* layoff, and you might be searching for work:
tab elayoff elkwrk if only3==1, row

* But, if you report only4==1, you could be a worker on temporary layoff. If you are, you are more likely to be searching for work.
tab elayoff elkwrk if only4==1, row
tab elayoff elkwrk if only4==1 & elayoff~=-1 & elkwrk~=-1, row

* -------------------------

gen weekly = .
replace weekly = 1 if only3==1
replace weekly = 2 if only4==1
replace weekly = 3 if comb34==1

tab elayoff weekly

* If you report only3==1, you are definitely a worker on temporary 
* layoff, and you might be searching for work:
tab elayoff elkwrk if only3==1, col
tab elayoff elkwrk if only3==1 & elayoff~=-1 & elkwrk~=-1, col

* But, if you report only4==1, you could be a worker on temporary 
* layoff. If you are, you are more likely to be searching for work.
tab elayoff elkwrk if only4==1, col
tab elayoff elkwrk if only4==1 & elayoff~=-1 & elkwrk~=-1, col

tab weekly if elayoff==1
tab weekly if elayoff==1 & elkwrk==1
tab weekly if elayoff==1 & elkwrk!=1

tab elayoff if only3==1 & elayoff~=-1
tab elayoff if only4==1 & elayoff~=-1
tab elayoff if comb34==1 & elayoff~=-1
