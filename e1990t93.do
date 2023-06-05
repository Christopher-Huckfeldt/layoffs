set more off
clear all
capture log close

log using "./logfiles/genExtract_pre.log", replace

set seed 19840317

/*Set number of waves per panel in vector "WaveNum"*/
matrix WaveNum = (8, 8, 10, 9) 
/*add note on documntation of wave numbers*/
matrix cWaveNum = (8,8,9,9)
/*Location of tenure variable*/
matrix TenureLoc = (2,2,1,1) 
/* add note on documentation of tenure variable in topical modules*/



/*******************************************************
*********** Load Full Panel ****************************
*******************************************************/

*local year = 93
*local z = 1
*forvalues year = 90(1)93 {
local z = 4
{
local year = 93

di " -----------19`year'---------------------"
local max = el(WaveNum, 1, `z') 

sh rm rawdata/sipp`year'fp.dat // delete if already there
sh unzip -c ./rawdata/sipp`year'fp.zip > ./rawdata/sipp`year'fp.dat
sh chmod 644 ./rawdata/sipp`year'fp.dat

quietly infile using ./dictionaries/ght`year'fp.dct, using(./rawdata/sipp`year'fp.dat) clear
drop if pp_id==""

// wave frequency: convert to long format
foreach var in pp_intv higrade grd_cmp in_af geo_ste att_sch { 
local WaveNum = `max'

// --- Unify format of stubs ---
*1. Wave frequency
forvalues i = 1(1)`WaveNum' {
// look at the variables again before this step.
capture rename `var'0`i' `var'`i'
capture rename `var'_0`i' `var'_`i'
capture rename `var'_`i' `var'`i'
rename `var'`i' p`var'`i'
}

forvalues i = 1(1)`WaveNum'{
forvalues j = 1(1)4 {
local m = 4*(`i'-1) + `j'
gen `var'`m' = p`var'`i'
}
}
drop p`var'* 
}

*2. Monthly frequency
foreach var in pp_mis age ms esr wksper  ///
	jobid1 jobid2 wksem1 wksem2 ernam1 ernam2 ///
	wshrs1 wshrs2 occ1 occ2 ind1 ind2 ///
  hrrat1 hrrat2 busid1 busid2 ws_i1 ws_i2 {
forvalues i=1(1)9{
capture rename `var'_0`i' `var'_`i'
capture rename `var'0`i' `var'`i'
}

local MonthNum = 4*`WaveNum'

forvalues i=1(1)`MonthNum'{
capture rename `var'_`i' `var'`i'
}

}

* ------ Convert dataset to long format ---------
gen X=_n

reshape long pp_intv higrade grd_cmp in_af geo_ste att_sch ///
	pp_mis age ms esr wksper ///
	jobid1 jobid2 wksem1 wksem2 ernam1 ernam2 ///
	occ1 occ2 ind1 ind2 ///
	wshrs1 wshrs2 hrrat1 hrrat2 busid1 busid2 ws_i1 ws_i2, i(X) j(tt)

*rename variables for merging with topical modules, jobid files, and core waves.
rename pp_id suid
rename pp_entry entry
rename pp_pnum pnum
sort suid pnum entry tt

*create wave variable
gen refmth=t-4*floor((tt-1)/4)
gen panel=1900+`year'
gen wave = ceil(t/4)
drop if wave>9
sort panel suid entry pnum wave
save ./tmpdata/fp`year'.dta, replace
sh rm rawdata/./rawdata/sipp`year'fp.dat
local z = `z' + 1
}


/*******************************************************
*********** Load Core Waves ****************************
*******************************************************/
*local z = 1
*forvalues year = 90(1)93 {
{
local z=4
local year = 93
di " -----------19`year'---------------------"
local max = el(cWaveNum, 1, `z')
forvalues i=1/`max' {

sh rm ./rawdata/sipp`year'w`i'.dat // delete if already there
sh unzip -c ./rawdata/sipp`year'w`i'.zip > ./rawdata/sipp`year'w`i'.dat
sh chmod 644 ./rawdata/sipp`year'w`i'.dat

quietly infile using ./dictionaries/ght`year'w`i'.dct, using(./rawdata/sipp`year'w`i'.dat) clear

sort suid pnum entry
save ./tmpdata/p`year'w`i'.dta, replace
}

*append Loop
use ./tmpdata/p`year'w1.dta, clear
forvalues i=2/`max' {
  append using ./tmpdata/p`year'w`i'.dta
}

replace panel = panel + 1900
egen tt=group(wave refmth)
sort wave refmth


* 1992 FP data has leading zeros.  Adding to other data for merge
replace pnum = "0"+pnum if `year'==92 
replace entry = "0"+entry if `year'==92
sort suid pnum entry tt
save ./tmpdata/p`year'.dta, replace


/*---------------- Survey size ---------------------*/
use ./tmpdata/p`year'.dta, replace
local panel = `year'+1900

egen hhcount_w = group(suid wave)
sum hhcount_w if wave==1, d
gen hhcount = r(max)
collapse (mean) p`panel'=hhcount (sd) check=hhcount, by(tt)
sum check
drop check
save ./tmpdata/count`panel'.dta, replace


forvalues i=1/`max' {
  sh rm ./tmpdata/p`year'w`i'.dta
  sh rm ./rawdata/sipp`year'w`i'.dat
}

local z = `z'+1
}

    
*x * ********************************************************
*x * ************ Topical Module ****************************
*x * ********************************************************
*x local z=1
*x forvalues year=90/93 {
*x local tl = el(TenureLoc, 1, `z')
*x 
*x local zip_name "`datadir'/p19`year'/sipp`year't`tl'.dat.gz"
*x local dat_name "`tbase'/sipp`year't`tl'.dat"
*x local dct_name "`base'/dictionaries/p19`year'/ght`year'tm.dct"
*x 
*x sh rm `dat_name'
*x sh gunzip -c `zip_name' > `dat_name'
*x sh chmod 644 `dat_name'
*x 
*x quietly infile using "`dct_name'", using("`dat_name'") clear
*x 
*x gen tmjobp=0
*x capture replace tmjobp = tm8206 if `year'==90 | `year'==91
*x replace tmjobp = 0 if `year'==92 | `year'==93
*x 
*x rename tm8214 tmjob
*x rename tm8218 TJmth
*x rename tm8220 TJyr
*x rename tmind3 TPJind
*x rename tmind4 occ
*x 
*x rename id suid
*x gen wave = `tl'
*x gen panel = 1900 + `year'
*x replace pnum = "0"+pnum if `year'==92
*x replace entry = "0"+entry if `year'==92
*x sort panel suid entry pnum wave
*x save "`tbase'/tm`year'.dta", replace
*x sh rm `dat_name'
*x local z=`z'+1
*x }
 

/*******************************************************
*********** Infile JobID data***************************
*******************************************************/

*forvalues year=90/93 {
{
local year=93

sh rm ./rawdata/sipp`year'jid.dat
sh unzip -c ./rawdata/sipp`year'jid.zip > ./rawdata/sipp`year'jid.dat
sh chmod 644 ./rawdata/sipp`year'jid.dat

quietly infile using ./dictionaries/ght`year'jid.dct, using(./rawdata/sipp`year'jid.dat) clear
replace pnum = "0"+pnum if `year'==92
replace entry = "0"+entry if `year'==92
sort panel suid entry pnum wave jobid
save ./tmpdata/jid`year'.dta, replace

sh rm ./rawdata/sipp`year'jid.dat

}


capture log close
