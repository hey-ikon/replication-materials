version 16.1

  quietly log
  local logon = r(status)
  if "`logon'" == "on" {
	log close 
	}
log using codes/01-mkdata-ANES01.log, text replace


/*	******************************************************************************	*/
/* 		Author:			Hyein Ko													*/
/*		Date:			April 8, 2024												*/
/*  	File:			01-mkdata-ANES01.do		       								*/
/*		Purpose:		Prepare data for analysis									*/
/*  	Input File: 	data/anes_timeseries_cdf_stata_20220916.dta					*/
/*						data/1976-2020-president.csv								*/
/* 						data/U.S. VEP Turnout 1789-Present - Statistics.csv			*/
/*  	Output File: 	data/01-mkdata-ANES01.log,									*/
/* 						data/anes_replicate_campbell_table1_noweight.dta			*/
/* 						data/anes_replicate_campbell_table1_weight.dta				*/
/*		Requires:		N/A															*/
/* 		Notes: 			Need to get input data from original data sources			*/
/* 						(1) ANES Time Series Cumulative Data, 1948–2020 			*/
/* 							Released  on September 16, 2022							*/
/*						(2)	MIT Election Data and Science Lab, 						*/
/*							"U.S. President 1976–2020" 								*/
/* 						(3) US Elections Project, Voter Turnout Data				*/
/* 						(4) Values of Campbell (2010) Table 1 						*/
/*	******************************************************************************	*/



			/***********************************/
			/* ANES data prep - Without weight */
			/***********************************/

	/* Import data */

use "data/anes_timeseries_cdf_stata_20220916.dta", clear

tab VCF0704a 
tab VCF0713 

	/* Rename relevant variables */

rename VCF0004	year
rename VCF0006	id 
rename VCF0006a	id2
rename VCF0704a	vote_major
rename VCF0702	vote_election
rename VCF0713	intend_vote

	/* Generate variables for collapsing */

gen vote_dem = .
replace vote_dem = 1 if vote_major == 1

gen vote_rep = . 
replace vote_rep = 1 if vote_major == 2

gen intend_vote_dem = .
replace intend_vote_dem = 1 if intend_vote == 1

gen intend_vote_rep = .
replace intend_vote_rep = 1 if intend_vote == 2

gen vote_election_yes = .
replace vote_election_yes = 1 if vote_election == 2
replace vote_election_yes = 0 if vote_election_yes == .

gen vote_election_respondent = .
replace vote_election_respondent = 1 if vote_election >= 0


	/* Collapse and keep relevante years */
	
collapse (sum) vote_dem vote_rep intend_vote_dem intend_vote_rep vote_election_yes vote_election_respondent, by(year)
	
drop if year == 1954 | year == 1958 | year == 1962 | year == 1966 | year == 1970 | ///
	    year == 1974 | year == 1978 | year == 1982 | year == 1986 | year == 1990 | ///
		year == 1994 | year == 1998 | year == 2002

	/* Generate reported and intended two-party for presidential candidate */

gen reported = vote_dem/(vote_dem + vote_rep)
gen intended = intend_vote_dem/(intend_vote_dem + intend_vote_rep)
	
label variable reported "reported two-party vote for president candidates"	
label variable intended "intended two-party vote for president candidates"
	
	/* Generate reported turnout variable for Presidential election */
	
gen reported_turnout = vote_election_yes/vote_election_respondent	
gen reported_turnout_pct = reported_turnout*100

label variable reported_turnout "reported turnout"
label variable reported_turnout "reported turnout in %"
	
	/* Save data */
	
save "data/anes_replicate_campbell_table1_noweight.dta", replace	
	

				/*******************************/
				/* Add actual election results */
				/*******************************/
	
	/* Import data */ 
	
import delimited "data/1976-2020-president.csv", clear 
 
	/* Keep relevent variable */
	
keep if party_simplified == "DEMOCRAT" | party_simplified == "REPUBLICAN"
keep year state state_po state_fips candidatevotes party_simplified
	
	/* Collapse actual vote*/
	
gen vote_dem = candidatevotes if party_simplified == "DEMOCRAT"
gen vote_rep = candidatevotes if party_simplified == "REPUBLICAN"

format vote_dem vote_rep %9.0f /* to keep large numbers */

collapse (sum) vote_dem vote_rep, by(year)	

	/* Generate actual two-party vote for president candidates (1976-2020) */
	
gen actual = vote_dem/(vote_dem + vote_rep)
rename vote_dem vote_dem_actual
rename vote_rep vote_rep_actual 

label variable actual "actual two-party vote for president candidates"	

	
	/* Add percentage info from Campbell (2010) Table 1 */
	
expand 7 if year == 2020 

replace year = 1952 in 13	
replace year = 1956 in 14 
replace year = 1960 in 15
replace year = 1964 in 16
replace year = 1968 in 17
replace year = 1972 in 18 

replace actual = .4460 in 13 
replace actual = .4225 in 14	
replace actual = .5008 in 15 
replace actual = .6134 in 16
replace actual = .4960 in 17
replace actual = .3821 in 18

replace vote_dem_actual = . ///
	if year == 1952 | year == 1956 | year == 1960 | year == 1964 | year == 1968 | ///
	   year == 1972
	   
replace vote_rep_actual = . ///
	if year == 1952 | year == 1956 | year == 1960 | year == 1964 | year == 1968 | ///
	   year == 1972

	/* Merge data with ANES one */
	
merge 1:1 year using data/anes_replicate_campbell_table1_noweight.dta, keep(match master using)
	   
sort year

				/********************************/
				/* Generate difference variable */
				/********************************/

	/* Generate difference variable */
	
gen difference = reported - actual 
gen difference2 = intended - actual 
label variable difference "difference b/w reported and actual"
label variable difference2 "difference b/w intended and actual"

	/* Make relevant variables in % format */
	
gen reported_pct = reported * 100
gen actual_pct = actual * 100
gen diff_pct = difference * 100 
gen diff_pct2 = difference2 * 100 
gen intended_pct = intended * 100

order year reported_pct actual_pct diff_pct intended_pct 	
drop _merge
save "data/anes_replicate_campbell_table1_noweight.dta", replace	


				/********************/
				/* Add turnout data */
				/********************/
	
	/* Import data */ 
	
import delimited "data/U.S. VEP Turnout 1789-Present - Statistics.csv", clear 
 	
	/* Keep relevent variable */	
	
keep if year >= 1948 & year <= 2020
keep year unitedstatespresidentialvepturno

rename unitedstatespresidentialvepturno actual_turnout
label variable actual_turnout "voting-eligible population turnout for presdiential elections"

gen actual_turnout_pct = actual_turnout
label variable actual_turnout_pct "voting-eligible population turnout for presdiential elections in %"

replace actual_turnout = actual_turnout/100
	
merge 1:1 year using data/anes_replicate_campbell_table1_noweight.dta, keep(match master using)
drop _merge
sort year		
	
	
				/***************/
				/* Export data */
				/***************/	
				
	/* Save data */
	
save "data/anes_replicate_campbell_table1_noweight.dta", replace	


********************************************************************************


			/********************************/
			/* ANES data prep - With weight */
			/********************************/

	/* Import data */

use "data/anes_timeseries_cdf_stata_20220916.dta", clear

svyset [pweight= VCF0009z]
svy: tab VCF0004 VCF0704, per row

tab VCF0704a 
tab VCF0713 

	/* Rename relevant variables */

rename VCF0004	year
rename VCF0006	id 
rename VCF0006a	id2
rename VCF0704a	vote_major
rename VCF0702	vote_election
rename VCF0713	intend_vote

	/* Generate variables for collapsing */

gen vote_dem = .
replace vote_dem = 1 if vote_major == 1

gen vote_rep = . 
replace vote_rep = 1 if vote_major == 2

gen intend_vote_dem = .
replace intend_vote_dem = 1 if intend_vote == 1

gen intend_vote_rep = .
replace intend_vote_rep = 1 if intend_vote == 2

gen vote_election_yes = .
replace vote_election_yes = 1 if vote_election == 2
replace vote_election_yes = 0 if vote_election_yes == .

gen vote_election_respondent = .
replace vote_election_respondent = 1 if vote_election >= 0

	/* Collapse and keep relevante years */
	
collapse (sum) vote_dem vote_rep intend_vote_dem intend_vote_rep vote_election_yes vote_election_respondent ///
	[pweight= VCF0009z], by(year)
	
drop if year == 1954 | year == 1958 | year == 1962 | year == 1966 | year == 1970 | ///
	    year == 1974 | year == 1978 | year == 1982 | year == 1986 | year == 1990 | ///
		year == 1994 | year == 1998 | year == 2002

	/* Generate reported and intended two-party for presidential candidate */

gen reported = vote_dem/(vote_dem + vote_rep)
gen intended = intend_vote_dem/(intend_vote_dem + intend_vote_rep)
	
label variable reported "reported two-party vote for president candidates"	
label variable intended "intended two-party vote for president candidates"

	/* Generate reported turnout variable for Presidential election */
	
gen reported_turnout = vote_election_yes/vote_election_respondent	
gen reported_turnout_pct = reported_turnout*100

label variable reported_turnout "reported turnout"
label variable reported_turnout "reported turnout in %"
		
	/* Save data */
	
save "data/anes_replicate_campbell_table1_weight.dta", replace	
	

				/*******************************/
				/* Add actual election results */
				/*******************************/
	
	/* Import data */ 
	
import delimited "data/1976-2020-president.csv", clear 
 
	/* Keep relevent variable */
	
keep if party_simplified == "DEMOCRAT" | party_simplified == "REPUBLICAN"
keep year state state_po state_fips candidatevotes party_simplified
	
	/* Collapse actual vote*/
	
gen vote_dem = candidatevotes if party_simplified == "DEMOCRAT"
gen vote_rep = candidatevotes if party_simplified == "REPUBLICAN"

format vote_dem vote_rep %9.0f /* to keep large numbers */

collapse (sum) vote_dem vote_rep, by(year)	

	/* Generate actual two-party vote for president candidates (1976-2020) */
	
gen actual = vote_dem/(vote_dem + vote_rep)
rename vote_dem vote_dem_actual
rename vote_rep vote_rep_actual 

label variable actual "actual two-party vote for president candidates"	

	
	/* Add percentage info from Campbell (2010) Table 1 */
	
expand 7 if year == 2020 

replace year = 1952 in 13	
replace year = 1956 in 14 
replace year = 1960 in 15
replace year = 1964 in 16
replace year = 1968 in 17
replace year = 1972 in 18 

replace actual = .4460 in 13 
replace actual = .4225 in 14	
replace actual = .5008 in 15 
replace actual = .6134 in 16
replace actual = .4960 in 17
replace actual = .3821 in 18

replace vote_dem_actual = . ///
	if year == 1952 | year == 1956 | year == 1960 | year == 1964 | year == 1968 | ///
	   year == 1972
	   
replace vote_rep_actual = . ///
	if year == 1952 | year == 1956 | year == 1960 | year == 1964 | year == 1968 | ///
	   year == 1972

	/* Merge data with ANES one */
	
merge 1:1 year using data/anes_replicate_campbell_table1_weight.dta, keep(match master using)
	   
sort year

				/***********************************************/
				/* Generate difference variable and Export dta */
				/***********************************************/

	/* Generate difference variable */
	
gen difference = reported - actual 
gen difference2 = intended - actual 
label variable difference "difference b/w reported and actual"
label variable difference2 "difference b/w intended and actual"

	/* Make relevant variables in % format */
	
gen reported_pct = reported * 100
gen actual_pct = actual * 100
gen diff_pct = difference * 100 
gen diff_pct2 = difference2 * 100 
gen intended_pct = intended * 100

order year reported_pct actual_pct diff_pct intended_pct 	
drop _merge 
save "data/anes_replicate_campbell_table1_weight.dta", replace	
	
	
				/********************/
				/* Add turnout data */
				/********************/
				
	
	/* Import data */ 
	
import delimited "data/U.S. VEP Turnout 1789-Present - Statistics.csv", clear 
 	
	/* Keep relevent variable */	
	
keep if year >= 1948 & year <= 2020
keep year unitedstatespresidentialvepturno

rename unitedstatespresidentialvepturno actual_turnout
label variable actual_turnout "voting-eligible population turnout for presdiential elections"

gen actual_turnout_pct = actual_turnout
label variable actual_turnout_pct "voting-eligible population turnout for presdiential elections in %"

replace actual_turnout = actual_turnout/100

	
merge 1:1 year using data/anes_replicate_campbell_table1_weight.dta, keep(match master using)
drop _merge 
sort year		
	
	
				/***************/
				/* Export data */
				/***************/	
	
	/* Save data */
	
save "data/anes_replicate_campbell_table1_weight.dta", replace	
	

***
log close
clear
*exit, STATA
