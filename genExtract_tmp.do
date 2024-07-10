set more off
clear all
capture log close

log using "logfiles/genExtract.log", replace

set seed 19840317



/*-----------Extract Core Waves--------------*/

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

    sh rm rawdata/l`iyr'wgt.dat // delete if already there
    sh gunzip -c rawdata/l`iyr'wgt.dat.gz > rawdata/l`iyr'wgt.dat
    sh chmod 644 rawdata/l`iyr'wgt.dat
    di "`iyr'  `i'"
    quietly infile using ./source_dictionaries/sip`iyr'lw.dct, using(rawdata/l`iyr'wgt.dat) clear
    sh rm rawdata/l`iyr'wgt.dat
    sort spanel ssuid epppnum
    save "tmpdata/l`iyr'wgt.dta", replace 

  
  *append
  use tmpdata/p`iyr'w1.dta, clear
  sh rm tmpdata/p`iyr'w1.dta
  forvalues i=2/`max_wave' {
    append using tmpdata/p`iyr'w`i'.dta
    sh rm tmpdata/p`iyr'w`i'.dta
  }
  
  *sort and save
  sort spanel ssuid epppnum swave
  merge m:1 spanel ssuid epppnum using tmpdata/l`iyr'wgt.dta
  sh rm tmpdata/l`iyr'wgt.dta
  rename _merge wgt_merge
  gen typeZ = (eppintvw==3 | eppintvw==4)
  sort spanel ssuid epppnum swave
  if "`iyr'"=="08" {
    gen lgtwgt = .
    by spanel ssuid epppnum: replace lgtwgt = lgtpn1wt if rhcalyr==2008 | rhcalyr==2009
    by spanel ssuid epppnum: replace lgtwgt = lgtpn2wt if rhcalyr==2010
    by spanel ssuid epppnum: replace lgtwgt = lgtpn3wt if rhcalyr==2011
    by spanel ssuid epppnum: replace lgtwgt = lgtpn4wt if rhcalyr==2012
    by spanel ssuid epppnum: replace lgtwgt = lgtpn5wt if rhcalyr==2013
    gen no_pw = (lgtpn1wt==0 | lgtpn1wt==.)
  }
  *
  else if "`iyr'"=="04" {
    gen lgtwgt = .
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt1 if rhcalyr==2004
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt2 if rhcalyr==2005
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt3 if rhcalyr==2006
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt4 if rhcalyr==2007
    gen no_pw = (lgtpnwt1==0 | lgtpnwt1==.)
  }
  *
  else if "`iyr'"=="01" {
    gen lgtwgt = .
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt1 if rhcalyr==2001
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt2 if rhcalyr==2002
    by spanel ssuid epppnum: replace lgtwgt = lgtpnwt3 if rhcalyr==2003
    gen no_pw = (lgtpnwt1==0 | lgtpnwt1==.)
  }
  else {
    gen lgtwgt = lgtpnlwt
    gen no_pw = (lgtpnlwt==0 | lgtpnlwt==.)
  }
  sort spanel ssuid epppnum swave
  save tmpdata/cw`iyr'.dta, replace
}




