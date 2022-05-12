set more off
clear all
capture log close

log using "logfiles/genExtract.log", replace

set seed 19840317

/*-----------Extract 1996 Core Waves--------------*/

*read
forvalues i=1/12 {
  sh rm rawdata/l96puw`i'.dat // delete if already there
  sh gunzip -c rawdata/l96puw`i'.dat.gz > rawdata/l96puw`i'.dat
  sh chmod 644 rawdata/l96puw`i'.dat
  quietly infile using ght2.dct, using(rawdata/l96puw`i'.dat) clear
  sh rm rawdata/l96puw`i'.dat
  save "tmpdata/p96w`i'.dta", replace 
}

*append
use tmpdata/p96w1.dta, clear
sh rm tmpdata/p96w1.dta
forvalues i=2/12 {
  append using tmpdata/p96w`i'.dta
  sh rm tmpdata/p96w`i'.dta
}

*sort and save
sort ssuid epppnum swave
save tmpdata/cw96.dta, replace


