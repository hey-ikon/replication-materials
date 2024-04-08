version 16.1

  quietly log
  local logon = r(status)
  if "`logon'" == "on" {
	log close 
	}
log using codes/02-analysis-ANES01.log, text replace


/*	********************************************************************	*/
/* 		Author:			Hyein Ko											*/
/*		Date:			April 8, 2024										*/
/*  	File:			02-analysis-ANES01.do		       					*/
/*		Purpose:		Replication codes 									*/
/*  	Input File: 	anes_replicate_campbell_table1_weight.dta			*/
/*  	Output File: 	data/02-analysis-ANES01.log,						*/
/*						figures/analysis-figure01.gph						*/
/*						figures/analysis-figure01.png						*/
/*						figures/analysis-figure02.gph						*/
/*						figures/analysis-figure02.png						*/
/*						tables/analysis-table06.rtf							*/
/* 						tables/analysis-table08.rtf							*/
/*		Requires:		esttab												*/
/*	*******************************************************************		*/



				/**************************/
				/* Data prep for analysis */
				/**************************/
				
	
		/* Import data */

use "data/anes_replicate_campbell_table1_weight.dta", clear


		/* Create variables */
	
	* weight (0: not affected, 1: affected) * 
gen weight = 0
replace weight = 1 if year == 1952 | year == 1956 | ///
					  year == 1964 | year == 1968 | ///
					  year == 1972 | year == 1980 | ///
					  year == 1984 | year == 1988

label variable weight "impact of survey weight (0,1)"


	* incumbent party (0: Rep, 1: Dem) * 
	
gen incum_party = 1
replace incum_party = 0 if year == 1956 | year == 1960 | ///
						   year == 1972 | year == 1976 | ///
						   year == 1984 | year == 1988 | ///
						   year == 1992 | year == 2004 | ///
						   year == 2008 | year == 2020

label variable incum_party "incumbent president's party (0: Rep, 1: Dem)"

	* all face-to-face (0: No, 1: Yes) *  

gen face_to_face = 1
replace face_to_face = 0 if year == 2012 | year == 2016 | year == 2020

label variable face_to_face "all face to face interview (0: No, 1: Yes)"


				/*********************/
				/* Explore variables */
				/*********************/

drop if year == 1948 

describe 
sum 

sum year actual intended reported weight face_to_face incum_party	


				/**************************************************/
				/* Line Plot between Estimated and Actual turnout */
				/**************************************************/	

twoway (line (actual_turnout_pct reported_turnout_pct) year, lpattern(solid longdash)), ///
	scheme(s1mono) ///
	ylabel(50(5)80) ///
	ytitle("Turnout (%)") ///
	legend(pos(7) col(1) ring(0) label(1 "Actual") label(2 "Reported (ANES)")) ///
	saving(figures/analysis-figure01.gph, replace)	
	   
graph export figures/analysis-figure01.png, replace width(3000)

		
		
				/**************************/
				/* Bivariate Scatter Plot */
				/**************************/	
	
graph twoway (lfit actual intended) (scatter actual intended, mlabel(year) mlabsize(vsmall)), scheme(s1mono) ///
	xtitle("Intended Two-Party Vote for Presidential Candidates") ///
	ytitle("Actual Two-Party Vote for Presidential Candidates") ///
	saving(figures/analysis-figure02.gph, replace)	
	
graph export figures/analysis-figure02.png, replace width(3000)
						  
											 
						  
				/************/
				/* Analysis */
				/************/	
				
				
*DV: Two-Party Vote Percentage Difference (Reported Party Vote - Actual Party Vote)
*IV: Voter Turnout Difference (Reported Turned Out - Actual Turnout)

gen diff_turnout = reported_turnout_pct - actual_turnout_pct

reg diff_pct2 diff_turnout
	estimate store m1
	
esttab m1 ///
	using "tables/analysis-table05.rtf", replace b(%9.3f) ///
	mlabel("Model 1") ///
	se stats(N r2 r2_a rmse) ///
	star(* .05 ** .01 *** .001) ///
	varlabels(diff_turnout		"Voter Turnout Difference" ///	  
			  _cons "Constant") ///
	title("Table 5: Impact of Voter Turnout Differences") ///
	eqlabel("") nonumbers nomtitles	
	
	
				
	/* OLS analysis */
	
reg actual intended	
  estimate store m2 
  
reg actual reported 
  estimate store m3 
  
reg actual year
  estimate store m4 
  
reg actual weight 	
  estimate store m5 
  
reg actual face_to_face
  estimate store m6 
  
reg actual incum_party
  estimate store m7
  
reg actual intended weight	
  estimate store m8 
	
reg actual intended year weight face_to_face incum_party 	
  estimate store m9 
	
	/* export results */
	
esttab m2 m3 m4 m5 m6 m7 m8 m9 ///
	using "tables/analysis-table06.rtf", replace b(%9.3f) ///
	mlabel("Model 1" "Model 2" " Model 3" "Model 4" "Model 5" ///
		   "Model 6" "Model 7" "Model 8") ///
	se stats(N r2 r2_a rmse) ///
	star(* .05 ** .01 *** .001) ///
	varlabels(intended		"Intended Vote" ///
			  reported		"Reported Vote " ///
			  year			"Year" ///
			  weight		"Weight Impact" ///
			  face_to_face	"Face-to-Face Survey" ///
			  incum_party	"Incumbent President's Party" ///		  
			  _cons 		"Constant") ///
	title("Table 6: Determinants of Actual Vote") ///
	eqlabel("") nonumbers nomtitles	
	
	
	
	/* Shapiro-Wilk test for normality on m1 (reg actual intended) */	
	
swilk actual

estimate restore m2
predict r, resid
swilk r  /* Result reported in Table 7 */
drop r	
	
	
	
	/* Mean shift test */

reg actual intended	
	predict r, rstudent
	list r year if abs(r) >= 2 /* outliers: 1960, 1980 */
	
gen outliers11 = 0
replace outliers11 = 1 if abs(r) >=2

reg actual outliers11 intended  
	estimate store m21
	
	/* export results */
	
esttab m21 ///
	using "tables/analysis-table08.rtf", replace b(%9.3f) ///
	mlabel("Weighted") ///
	se stats(N r2 r2_a rmse) ///
	star(* .05 ** .01 *** .001) ///
	varlabels(outliers11	"Outlier(s)" ///
			  intended		"Intended Vote" ///	  
			  _cons			"Constant") ///
	title("Table 8: Mean shift test") ///
	eqlabel("") nonumbers nomtitles	
		
		
	
	/* Cook's D test */

estimate restore m21
	predict d, cooksd
	list year d if d > 4/18	/* 1960, 1980 */	
		

	/* Leverage test */ 
	
* Look for leverage greater than (2k+2)/n where k is the number of predictors
* and n is the number of of observations
display (2*1+2)/18
	
reg actual intended	
	predict lev, leverage
	list year  lev 	/* Result reported in Table 9 */
	list year  lev if lev > 0.22222222	 /* Result reported in Table 9 */
		
		
		
	/* Cook's D */ 
	
reg actual intended	
	drop d
	predict d, cooksd
	list year d		/* Result reported in Table 9 */
	list year d if d > 4/18		/* Result reported in Table 9 */		
	
	
***
log close
clear
exit, STATA	
	
