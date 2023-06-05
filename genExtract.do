set more off
clear all
capture log close

log using "logfiles/genExtract.log", replace

set seed 19840317



/*-----------Extract 1996 Core Waves--------------*/

*read
foreach iyr in 96 01 04 08 {

  if `iyr'==08 {
    local max_wave = 16
  }
  else if `iyr'==01 {
    local max_wave = 9
  }
  else {
    local max_wave = 12
  }
  
    forvalues i=1/`max_wave' {
      sh rm rawdata/l`iyr'puw`i'.dat // delete if already there
      sh gunzip -c rawdata/l`iyr'puw`i'.dat.gz > rawdata/l`iyr'puw`i'.dat
      sh chmod 644 rawdata/l`iyr'puw`i'.dat
      di "`iyr'  `i'"
      quietly infile using ./dictionaries/ght`iyr'w`i'.dct, using(rawdata/l`iyr'puw`i'.dat) clear
      sh rm rawdata/l`iyr'puw`i'.dat
      save "tmpdata/p`iyr'w`i'.dta", replace 
    }
  
  *append
  use tmpdata/p`iyr'w1.dta, clear
  sh rm tmpdata/p`iyr'w1.dta
  forvalues i=2/`max_wave' {
    append using tmpdata/p`iyr'w`i'.dta
    sh rm tmpdata/p`iyr'w`i'.dta
  }
  
  *sort and save
  sort ssuid epppnum swave
  save tmpdata/cw`iyr'.dta, replace
}




