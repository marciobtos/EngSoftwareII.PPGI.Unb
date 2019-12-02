;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;                                              ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;                  VARIABLES                   ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

patches-own [ Dhin Bwin DW Dain hist_shor_retreat reservoir reservoira response damage_hist exp-response e-rep-decision rep-decision n-bdecision des-reservoir heelx bermx bermy heely rtpx rtpy croy crox crbx crby shorex shorey toex toey DWb DWf DWc BermW in-area-before-rep exp-response-in rep_width value_on erosion deltacrest]
globals [storm-erosion inc-storm toe SWFL SWFL-5 SWFL-10 SWFL-25 SWFL-50 SWFL-100 SWFL-d SWFL-de R depthclosure lengthclosure Berm Area-nourish predicted-eros-design price_sand_nourishment price_sand_replenishment cons_cost dnoup n_cost total_price init_com_density tot_house occ residential gov occupancy
  value1 check value2 total_nprice return total_damage com_att last_storm storm_rec st_name exp_att attractiveness narrow hapbeach return_list time_since_nourish SLR total_debt  damage_abon numb_buyers MSL Hs H-5 H-10 H-25 H-50 H-100 var_cost_nourish fixed_cost_nourish prebeachwidth minplanlen nourish_dec_2
  rep_fixed_cost rep_sand_cost designemstorm ednoup BWe st_5 st_10 st_25 st_50 st_10s st_25s st_50s st_5s setup10 setup25 setup50 feas_dune income_avg design_h_diff minbeachwidth ave-DH ave-BW coef numberstorm filename]
breed [households house]
households-own [purpose mort landval propertval structure-year year row distance-shore elevation-structure tax damage tax_damage tax_tot house_pt purp_pt objid ag_type]
breed [dreplenishments replenish]
dreplenishments-own [connected-nodes]
breed [bnourishments bnourish]
bnourishments-own [connected-bnodes]
breed [emptyp empty]
emptyp-own [purpose landval propertval structure-year row distance-shore elevation-structure tax damage]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;                                           ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;      INITIALIZATION AND OVERVIEW          ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extensions [r pathdir]

;;; Initialization
to setup_discenv
  clear-all
end

to setup
  clear-all
  install_packages
  load_profile_data
  create-houses
  set-parameters
  reset-ticks
end


;;; Model Structure

to go
  update_parameters
  sea-level-rise_erosion
  storm-impact
  calculate-damage
  set damage_abon damage_abon * 0.9
    ifelse time_since_nourish >= 4 [
  beach-nourishment
   dune-replenishment
    ][
    em-dune-replenishment
    price-nourishment
   ]
    price-nourishment
    tax_adjust
  buy
;
  tick
  if ticks >= 51 [stop]
  r:stop
end


to load_packages

;;;;;;;;;;;;;;set library Path to R library folder
  r:eval ".libPaths(c(\"/usr/local/lib/R/site-library\",.libPaths()))"
  r:eval "install.packages(\"bnlearn\")"
  r:eval "install.packages(\"readr\")"
end

to install_packages
  r:eval ".libPaths(c(\"/usr/local/lib/R/site-library\",.libPaths()))"
  r:eval "library(bnlearn)"
  r:eval "library(readr)"
  output-print "finished loading libraries"
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;                                           ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;                 INPUTS                    ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; set initial parameters, only used while setting up the model ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;         set-parameters          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-parameters
;;Morphology and water level parameters
set SLR 4.57 / 1000      ;m
set MSL -0.13      ;m
set SWFL-5 1.2 ;m
set SWFL-10 1.535 + 0.2466      ;m
set SWFL-25 1.780 + 0.3172      ;m
set SWFL-50 1.8213 + 0.3517      ;m
set SWFL-100 2.135 + 0.554     ;m
set SWFL-d 0.2481 * ln DesignStorm + 0.7848  ;m
set H-5 2 ;m
set H-10 3.161      ;m
set H-25 4.067      ;m
set H-50 4.752      ;m
set H-100 7.11      ;m
set toe 1.8      ;m
set lengthclosure 456      ;m
set Berm 1.58      ;m
set depthclosure 7.3      ;m


;; Household parameters
set occupancy 45800000         ;$
set tot_house 0
set occ 0
set com_att 1
set residential 0
let n 0
     while [n < 1650] [ ask one-of households with[purpose < 5] [set purpose 5 set n n + 1]]
ask households [ set year 1998 - structure-year
  if purpose < 5 [ set tot_house tot_house + 1 ]
  set init_com_density tot_house / count households
  if purpose = 4[set occ occ + 1]
  if purpose = 3[set occ occ + 1]
  if purpose = 1[set residential residential + 1]
  set ag_type 1]
set income_avg 0.5 * 50000
let j 0
;while [j < tot_house * 0.05] [ask one-of households with [ag_type = 1] [set ag_type 2 set j j + 1]]
set gov tot_house - residential - occ
set time_since_nourish 0
set last_storm 2

;;; Design parameters
set minbeachwidth 20
set minplanlen 17
set DesignEmStorm 15
set design_h_diff 0.6894 * ln DesignStorm - 0.0111


;;; set costs
set price_sand_nourishment 8.5                            ;$
set var_cost_nourish 4                                    ;$
set fixed_cost_nourish 1200000                            ;$
set cons_cost 1500000 + (random-float 1) * 500000         ;$
set rep_fixed_cost 40000                                  ;$
set rep_sand_cost 31                                      ;$

;;; Set incoming storms if not set to random
if Storm_Auto = false [
  set st_name replace-item 7 "storms_1.txt" numberstorm
 set return_list [0 0 0 0 6 50 75 6 75 75 6 50 75 75 75 75 75 50 75 50 75 75 75 50 6 75 75 50 50 75 75 75 75 75 75 75 75 75 75 50 75 6 75 75 75 6 50
   75 75 75 6 0 50 50 75 75 75 75 75 50 75 75 6 50 75 75 50 50 75 6 75 0 75 3 75 75 50 50 75 75 50 75 75 6 75 75 6 75 50 50 50 75 75 75 75 75 75 75 6 75 50]
 let i 0
 file-open st_name
  while [not file-at-end?]
[
  let next-purp file-read
  set return_list replace-item i return_list next-purp
  set i i + 1
]  file-close]

set st_5 [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0 0 0 ]

set st_10 [1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0 0 0 ]

set st_25 [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0 0 0 ]

set st_50 [0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
   0 0 0 0 0 0 0 0 0 0 ]

end

;;; Load physical profile data from external text files ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;   load_profile_data     ;;;;;;;;;;;;;;;;;;;;;;;;;;;

to load_profile_data
  ;; open file and load attributes
  ;; load dune heights
  file-open "DH_sm_grid.txt"
  let i 0
  while [not file-at-end?]
  [let next-DH file-read
    ask patch i 0 [set Dhin next-DH]
    set i i + 1
  ]
  file-close

  ;; load dune widths
   file-open "DW_sm_grid.txt"
  let j 0
  while [not file-at-end?]
  [let next-DW file-read
    ask patch j 0 [set DW next-DW]
    set j j + 1
  ]
  file-close

    ;; load beach widths
  file-open "BW_sm_grid.txt"
  let k 0
  while [not file-at-end?]
  [let next-BW file-read
    ask patch k 0 [set Bwin next-BW]
    set k k + 1
  ]
  file-close

  ;; load erosion rates
    file-open "erosion_rates_sm_grid.txt"
  let g 0
  while [not file-at-end?]
  [let next-erosion file-read
    ask patch g 0 [set hist_shor_retreat next-erosion * 0.3048]
    set g g + 1
  ]
  file-close

 ;; create representative profiles in patches
 ask patches
  [set heelx 55 + random 20
    set heely 2.5
    if Dhin < 2.5 [ set Dhin 2.5]
    set crbx (Dhin - 2.5) * 3 + heelx
    ifelse Dhin > 2.5 [set crby Dhin][set crby 2.6]
    set crox crbx
    set croy crby
    set rtpx crbx + DW
    set rtpy 1.8
    set toex rtpx
    set toey rtpy
    set shorex toex + Bwin
    set shorey -0.13
    ifelse Bwin > 28[set bermx toex + Bwin - 22]
    [ifelse Bwin > 23 [set bermx shorex - 22]
      [ifelse DW + Bwin > 28 [set bermx shorex - 22
          set toex bermx - 1
      ][set bermx toex + 1]]]
    set bermy 1.526
    set rtpx toex
    set Dain (Dhin - 1.8) * DW / 2
    set value_on 0
]
 end

;;; Create the houses and load data from external text files ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;     create_houses     ;;;;;;;;;;;;;;;;;;;;;;;;;;;

to create-houses
  file-open "houses_sm_grid.txt"
  while [not file-at-end?]
  [let next-purp file-read
    let next-group file-read
    let next-lvalue file-read
    let next-pvalue file-read
    let next-styear file-read
    let next-row file-read
    let next-dist file-read
    let next-id file-read
    create-households 1
     [
      set purpose next-purp
      set landval 0.22 * next-lvalue
      set propertval 0.57 * next-pvalue
      set structure-year next-styear
      set row next-row
      set distance-shore next-dist
      set objid next-id
      set size 0.5
      set color white
      set shape "house"
      set elevation-structure 1.5 + random-normal 2.5 0.3
      move-to patch next-group 0
     ]
  ]
     file-close

end

;;; Updates parameters at the start of each year ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;     update parameters      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update_parameters
;;Morphology and water level parameters

   set SLR SLR + SLRAccRate / 100

;; Household parameters
   set tot_house 0
   set occ 0
   set residential 0
   set value1 0
   set value2 0
   let DH_tot 0
   let BW_tot 0
   ask patches[set DH_tot DH_tot + reservoira
     set BW_tot BW_tot + Bwin]
   set ave-DH DH_tot / count patches
   set ave-BW BW_tot / count patches

   ask patches [set value_on 0
     ask households [if purpose < 5 [set value_on value_on + propertval]]]
   ask households [ let n 1

  if row = 1 and purpose < 5 [ set value1 value1 + propertval]
  if row = 2 and purpose < 5 [ set value2 value2 + propertval]
  if purpose < 5 [ set tot_house tot_house + 1 ]
  if purpose = 4[set occ occ + 1]
  if purpose = 3[set occ occ + 1]
  if purpose = 1[set residential residential + 1]
  if year < 30 [set mort (propertval / 60) ]
    set year year + 1]
  set gov tot_house - residential - occ
  set occupancy occupancy + 3.6
  ;; Replenishment and nourishment parameters
  ask patches [set rep-decision 0
    set e-rep-decision 0
   set n-bdecision 0
   set response "retreat"
   ifelse damage_hist > 1 [set damage_hist damage_hist - 1][set damage_hist 0]]
  set time_since_nourish time_since_nourish + 1
  set dnoup 0
  set n_cost 0
  set ednoup 0
  ;; Monetary parameters
  ask households [set damage damage - tax_damage if damage <= 0 [ set tax_damage 0 set damage damage - tax_damage]]

  ask households[ifelse tax_damage + tax <= income_avg [set tax_tot tax_damage + tax set tax_damage 0
      ] [set tax_tot income_avg if tax < income_avg [ set tax_damage tax_damage - (income_avg - tax)]]
      ]

  ask households[if purpose < 5 [set total_debt total_debt - tax_tot]]
  ask households[ifelse purpose < 5 [set purp_pt -1000][set purp_pt 0]]
  ask households[ set house_pt 1 / row * 2 + damage_hist / 5 + (distance-shore - 100) / 100 - (exp-response + heelx - shorex - 60 / 100) + purp_pt + ag_type * 25 - 25 if purpose > 4 [set house_pt 0]
]

  set total_damage 0
  if last_storm = 0 [ask households [ if purpose < 5 [ set total_damage total_damage + damage]]]
  set total_debt total_debt + total_price  + total_damage
  if total_debt > 100000[
  set total_debt total_debt - occupancy * 0.02 *  (tot_house / count households) / init_com_density]
  if total_debt < 0 [set total_debt 0 ask households [set tax 0]]
  set total_price 0
;  set damage_abon 0
  set last_storm last_storm + 1
end


;;;;; Optional functions to view vulnerabilities/ profile properties ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;                                                           ;;;;;;;;;;;
;;;;;;;;;;;                    PHYSICAL PROCESSES                     ;;;;;;;;;;;
;;;;;;;;;;;                                                           ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;                       SEA LEVEL RISE   AND EROSION

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; sea level rise impact calculated by Brunn Rule


;;; Modifies profile according to SLR and erosion ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;     sea-level-rise_erosion      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to sea-level-rise_erosion
let recession (SLR) * lengthclosure / (depthclosure + Berm)

;;; modify water levels
  set MSL MSL + SLR
  set SWFL-10 SWFL-10 + SLR
  set SWFL-25 SWFL-25 + SLR
  set SWFL-50 SWFL-50 + SLR
  set SWFL-100 SWFL-100 + SLR
  set SWFL-d SWFL-d + SLR

;;;modify morphology
  ask patches
  [ set bermx bermx - recession - hist_shor_retreat
  ;;; Scarping
    if bermx - 1 < toex [ set toex toex - recession - hist_shor_retreat
      let a (recession + hist_shor_retreat) * ( croy - toey)/ 2
      let xsl a /(bermy + depthclosure)
      set shorex shorex + xsl
      set bermx bermx + xsl]
;;; Modify horizontal
  set shorex shorex - recession - hist_shor_retreat
    set bermy bermy + SLR
    set shorey MSL
    set Dhin croy
    set DWc crox - crbx
    set DWb crbx - heelx
    set DWf toex - crox
;;; Duneface slope too steep
    if DWf < Dhin - toe
    [ let y Dhin - toe - DWf
      set Dhin DWf
      ]
    if DWf < 0.7 [set Dhin 2.5
      set DWf 2.5
      set croy Dhin
      set crby Dhin
      set crox toex + 1
      set crbx toex + 1 + DWc
       ]

    set Bwin shorex - toex
    set BermW bermx - toex
    if rtpx > toex [set rtpx toex]
    set Dain ((DHin - 1.8) * DWc) + ((DHin - 1.8) * DWc / 2)
   ]

  ;;; modify structure distances
  ask households
  [set distance-shore distance-shore - recession - hist_shor_retreat
    set elevation-structure elevation-structure - SLR
    if elevation-structure < 0.1 [set purpose 5]
  ]
  end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;                               STORM IMPACT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;; Storm impact
;;;; Erosion due to Storms are calculated using bayesian Network constructed from XBeach runs
;;;; and dune profile is modified accordingly

;;; Determines incoming storm and sets its properties  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    determine-storm         ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to determine-storm
  ;;; Decides what is the return period of the storm
  ifelse Storm_Auto = true [set return random 100]

  [set return item (ticks) return_list ]

if time = ticks[set return 25]
;; set parameters for the storm
  if  return < 0
  [set inc-storm 100
    set SWFL SWFL-100
    set Hs H-100
    set coef 1.5
    set last_storm 0]
    if  return >= 1 and return < 2
  [set inc-storm 50
    set SWFL SWFL-50
    set Hs H-50
    set coef 1.2
     set last_storm 0]
    if  return >= 2 and return < 4
  [set inc-storm 25
    set SWFL SWFL-25
    set Hs H-25
    set st_25 replace-item (ticks + 1) st_25 1
    set st_25 replace-item (ticks + 2) st_25 1
    set st_25 replace-item (ticks + 3) st_25 1
    set st_25 replace-item (ticks + 4) st_25 1
    set st_25 replace-item (ticks + 5) st_25 1
        set coef 1
     set last_storm 0]
    if  return >= 4 and return <= 6
  [set inc-storm 10
    set SWFL SWFL-10
    set Hs H-10
    set coef 0.85
   ifelse last_storm < 5[set st_10 replace-item (ticks + 1) st_10 2
   set st_10 replace-item (ticks + 2) st_10 2
   set st_10 replace-item (ticks + 3) st_10 2
   set st_10 replace-item (ticks + 4) st_10 2
  set st_10  replace-item (ticks + 5) st_10 2]
     [set st_10 replace-item (ticks + 1) st_10 1
   set st_10 replace-item (ticks + 2) st_10 1
   set st_10 replace-item (ticks + 3) st_10 1
   set st_10 replace-item (ticks + 4) st_10 1
   set st_10 replace-item (ticks + 5) st_10 1]
     set last_storm 0]
      if  return >= 7 and return <= 10
  [set inc-storm 5
    set SWFL SWFL-5
    set Hs H-5
   ifelse last_storm < 5[set st_5 replace-item (ticks + 1) st_5 2
   set st_5 replace-item (ticks + 2) st_5 2
   set st_5 replace-item (ticks + 3) st_5 2
   set st_5 replace-item (ticks + 4) st_5 2
  set st_5  replace-item (ticks + 5) st_5 2]
     [set st_5 replace-item (ticks + 1) st_5 1
   set st_5 replace-item (ticks + 2) st_5 1
   set st_5 replace-item (ticks + 3) st_5 1
   set st_5 replace-item (ticks + 4) st_5 1
   set st_5 replace-item (ticks + 5) st_5 1]
     set last_storm 0]
    if  return <= 100 and return > 10
  [set inc-storm 0
    set SWFL 0]
  set storm-erosion 8 * inc-storm ^ 0.4
end


;;; Modifies profile according to incoming storm  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      storm-impact        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to storm-impact
  determine-storm
  if inc-storm > 5
  [
;;;;;;;;;;;;;give results from the XBeach runs (results.txt) as input
      r:clearLocal
      let dir pathdir:get-model
      set filename (word dir "/" "results.txt")
      r:put "fn" filename
      r:eval "data <- read.table(file = fn)"
    r:eval "net <- model2network(\"[Dhin][Bwin][Dain|Dhin][deltacrest|Dhin:Bwin:Dain][Erosion|Dhin:Dain:Bwin]\")"
    r:eval "fitted <- bn.fit(net,data)"
    (r:putagentdf "dfpatches" patches "pxcor" "pycor" "Dhin" "Dain" "Bwin")
    r:eval "df <- dfpatches[,3:5]"
    r:eval "erosion <- predict(fitted,\"Erosion\",df)"
    r:eval "deltacrest <- predict(fitted,\"deltacrest\",df)"
    let xlist r:get "dfpatches$pxcor"
    let ylist r:get "dfpatches$pycor"
    let xylist (map [list ?1 ?2] xlist ylist)

    let counter 1
    foreach xylist
    [
    ask patch (item 0 ?) (item 1 ?)
    [
      set erosion (r:get (word "erosion[" counter "]"))
      set deltacrest (r:get (word "deltacrest[" counter "]"))
      if erosion > 0 [set Dain Dain - coef * erosion]
      if deltacrest > 0 [set Dhin Dhin - coef * deltacrest]
      ifelse Dhin < 2.8 [ set response "removal" set Dhin 2.5][set response "retreat"]
      set crby Dhin
      set croy Dhin
      set crbx heelx + (Dhin - 2.5) * 3
      if crbx > crox [ set crox crbx]
      set DWc crox - crbx
      set DWf Dain - (((Dhin - 1.8) * DWc) / (( Dhin - 1.8) / 2 ))
      set toex crox + DWf

    ]
    set counter counter + 1
  ]]
  r:clear
end


;;; Calculates damage to the houses  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      calculate-damage        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to calculate-damage
  let i 0
  let j 0
  set R SWFL + Hs / 2
  ask households [ if response = "removal" and row = 1 and purpose < 5 [ let dam-percent (0.2056 * ( SWFL + R - elevation-structure) * ( SWFL + R - elevation-structure) + 13.01 * ( SWFL + R - elevation-structure) + 34.83) / 100
      set damage  damage + ((0.001 + propertval - landval) * dam-percent)
      if random 100 * storm_rec < 30 [set damage 0]
      set tax_damage damage / 5
      if damage / (0.001 + propertval - landval) > 0.85 [
        set purpose 5
        set ag_type 2
        set i i + 1
       set damage_abon damage_abon + damage
           set total_damage total_damage + damage]
]
  if response = "removal" and row = 2 and purpose < 5 [ let dam-percent (0.581 * ( SWFL + R - elevation-structure) * ( SWFL + R - elevation-structure) + 13.01 * ( SWFL + R - elevation-structure) + 34.83) / 100 * 0.6
      set damage  damage + (0.001 + propertval - landval) * dam-percent
       if random 100 * storm_rec < 30 [set damage 0]
      set tax_damage damage / 5
      if damage / (0.001 + propertval - landval) > 0.85 [
       set purpose 5 set ag_type 2
       set j j + 1
   set total_damage total_damage + damage
    set damage_abon damage_abon + damage]
    ]]
  set total_damage total_damage - damage_abon
  set tot_house 0
  ask households [
  if purpose < 5 [ set tot_house tot_house + 1 ]]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;                                                           ;;;;;;;;;;;
;;;;;;;;;;;                    HUMAN DECISIONS                        ;;;;;;;;;;;
;;;;;;;;;;;                                                           ;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;                             DUNE REPLENISHMENT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;emergency dune replenishment module overview;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      emergency dune-replenishment   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to em-dune-replenishment
  assess-vulnerability-em
  locate-vulnerable-dunes
  populate
  ask dreplenishments [set e-rep-decision 1]
  construct_dune_replenishment_em
  dune-replenish-price-em
  ask links [die]
  ask dreplenishments [die]
end

;;; calculate the predicted erosion area for design storm using Hallermeier approach and compare with existing dune reservoir;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        assess-vulnerability   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to assess-vulnerability-em
  set predicted-eros-design 8 * DesignEmStorm ^ 0.4
  set SWFL-de 0.2724 * ln( DesignEmStorm) + 0.7829
  ask patches
    [let res DWc * ( croy - SWFL-de) + 0.5 * (croy - SWFL-de) * (rtpx - crox)
      ifelse res < predicted-eros-design [set exp-response 1][set exp-response 0]]
end

;;; locate the dunes which has less sand in their reservoir compared to expected erosion ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        locate-vulnerable-dunes    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to locate-vulnerable-dunes
  ask patches with [exp-response = 1] [sprout-dreplenishments 1
    [set shape "x"
      set size 0.7
      set color red ]]
  ask dreplenishments[connect_e]
  ask dreplenishments with [ not any? my-links ] [ die ]
end

;;; find the vulnerable dunes and connect them  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;         connect     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to connect_e
    set connected-nodes other dreplenishments in-radius 2
  if any? connected-nodes[
    create-links-with connected-nodes]
  ask links [ set color black
    set  thickness 0.2
   ]
end

;;; Mark the parcels links are going through  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;       populate      ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

To populate
ask links [
    let s 0
    let e2 end2
    ask end1[
        let dist distance e2
        hatch dist[
           set s s + 1
           set heading towards e2
           Fd s ]]]
end

;;;; Construct the replenished dunes    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        construct_dune_replenishment    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  to construct_dune_replenishment_em
     ask patches with [e-rep-decision = 1][
       set in-area-before-rep  ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2
       ifelse (33 - in-area-before-rep ) * rep_sand_cost * 1.30795 * 300 / 2 < value_on * 0.3  [

       if Dhin < 4 [
       set Dhin 4
       set DWf (Dhin - 1.8 ) * 5
       set DWb (Dhin - heely) * 3
       set DWc 8
       set crbx heelx + DWb
       set crby Dhin
       set croy Dhin
       set crox crbx + DWc
       set toex heelx + DWc + DWf + DWb
       set rtpx toex
       set rtpy 1.8
       ]][set e-rep-decision 0]]


     end
;;; Calculate variable replenishment costs    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;       dune-nourish-price    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  to dune-replenish-price-em
    set ednoup rep_fixed_cost
    if total_debt / (tot_house + 1) < income_avg [
     ask patches with[e-rep-decision = 1]
    [ if (((toey - bermy) * (((bermx - toex) / 2 ) + DWf + DWc + DWb) + ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2) - in-area-before-rep) > 0
      [set ednoup ednoup + (((toey - bermy) * (((bermx - toex) / 2 ) + DWf + DWc + DWb) + ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2) - in-area-before-rep ) * rep_sand_cost * 1.30795 * 300]]
    set ednoup ednoup / 2]
  end

;;;dune replenishment module overview;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      dune-replenishment   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to dune-replenishment
  assess-vulnerability
  locate-vulnerable-dunes
  populate
  ask dreplenishments [set rep-decision 1]
  ask patches with [rep-decision = 1] [ask neighbors [ set rep-decision  1 ]]
  construct_dune_replenishment
  dune-replenish-price
  ask links [die]
  ask dreplenishments [die]
end

;;; calculate the predicted erosion area for design storm using Hallermeier approach and compare with existing dune reservoir;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        assess-vulnerability   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to assess-vulnerability
  set predicted-eros-design 8 * DesignStorm ^ 0.4
    ask patches
    [let res DWc * ( croy - SWFL-d) + 0.5 * (croy - SWFL-d) * (rtpx - crox)
      ifelse res < predicted-eros-design [set exp-response 1][set exp-response 0]]
end

;;; find the vulnerable dunes and connect them  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;         connect     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to connect
    set connected-nodes other dreplenishments in-radius 12
  if any? connected-nodes[
    create-links-with connected-nodes]
  ask links [ set color black
    set  thickness 0.2
   ]
end


;;;; Construct the replenished dunes    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        construct_dune_replenishment    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  to construct_dune_replenishment
    feasible_replenish
    if feas_dune = 1 [
     ask patches with [rep-decision = 1][
       set in-area-before-rep (toey - bermy) * (((bermx - toex) / 2 ) + DWf + DWc + DWb) + ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2
       if Dhin < SWFL-d + design_h_diff [
         ifelse bermx - heelx  > 8 + (SWFL-d + design_h_diff - 1.8) * 5 + (SWFL-d + design_h_diff - 2.5) * 3  [
           set Dhin SWFL-d + design_h_diff  set rep_width 1]
       [
           ifelse ((toex - heelx + 8.5) / 8) >  SWFL-d + design_h_diff
           [set Dhin (toex - heelx + 8.5) / 8
             set rep_width 1][
             set rep_width 0]]]
       if rep_width = 1[
       set DWc 8
       set DWf (Dhin - 1.8 ) * 5
       set DWb (Dhin - heely) * 3
       set crbx heelx + DWb
       set crby Dhin
       set croy Dhin
       set crox crbx + DWc
       set toex heelx + DWc + DWf + DWb
       set rtpx toex
       set rtpy 1.8
       ]
      ]
    ]
     end
;;; Calculate variable replenishment costs    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;       dune-nourish-price    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

 to feasible_replenish
    let cost 0
    ask patches [ set in-area-before-rep (toey - bermy) * (((bermx - toex) / 2 ) + DWf + DWc + DWb) + ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2
      set cost cost + (48 - in-area-before-rep) * price_sand_replenishment * 1.30795 * 300]
   ifelse cost < (tot_house * 15000 * 5 - n_cost - total_debt) [ set feas_dune 1][set feas_dune 0]
end
  to dune-replenish-price
    set dnoup 0
    if total_debt + n_cost / (tot_house + 1) < income_avg [
     ask patches with[rep-decision = 1]
    [ set dnoup dnoup + (((toey - bermy) * (((bermx - toex) / 2 ) + DWf + DWc + DWb) + ( croy - toey) * ( DWc + (DWb + DWf) / 2) - 1.5 * ( heely - toey) ^ 2) - in-area-before-rep ) * price_sand_replenishment * 1.30795 * 300] ]
  end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;                             BEACH NOURISHMENT                                           ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;beach nourishment module overview;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;      beach-nourishment   ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to beach-nourishment
  locate-beach-nourish
  beach-populate
  ask bnourishments [set n-bdecision 1]
  ask patches with [n-bdecision = 1] [ask neighbors [ set n-bdecision  1 ]]
  assess-vulnerability
  locate-vulnerable-dunes
  populate
  ask dreplenishments [set rep-decision 1]
  ask patches with [rep-decision = 1] [ask neighbors [ set rep-decision  1 ]]

  feas-nourish
  construct_dune_replenishment
  dune-replenish-price
   ask links [die]
  ask dreplenishments [die]
  ask bnourishments [die]
  end

;;; locate the patches with less width then required  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        locate-beach-nourish    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to locate-beach-nourish
  ask patches with [Bwin < minbeachwidth + hist_shor_retreat * 5] [sprout-bnourishments 1
    [set shape "x"
      set size 0.7
      set color blue ]]
  ask bnourishments[bconnect]
  ask bnourishments with [ not any? my-links ] [ die ]
  construct_bnourish
end

to find-other-bremovals
  set connected-bnodes other bnourishments in-radius minplanlen
end

to bconnect
  find-other-bremovals
  if any? connected-bnodes[
    create-links-with connected-bnodes]
  ask links [ set color black
    set  thickness 0.2
    if link-length < 3 [die]]
end


To beach-populate
ask links [
                Let s 0
                Let e2 end2
                Ask end1[
                                Let dist distance e2
                                Hatch dist
                                  [
                                  Set s s + 1
                                  Set heading towards e2
                                  Fd s
                                  ]
                              ]
      ]

end

  to construct_bnourish

     ask patches with [n-bdecision = 1][
       if Bwin < minbeachwidth + hist_shor_retreat * 5
       [ set Bwin desbeachwidth
         if rep-decision = 1 [ if heelx - toex < 31.5 [
             set n_cost n_cost + 31.5 - (heelx - toex) * (depthclosure + 1.8 )
             set toex heelx + 31.5]
       set shorex toex + Bwin
       set bermx toex + 15

       ]]
       set time_since_nourish 0

      ]
     end


  to feas-nourish
    set n_cost 0
    let benefit 0
    ask patches with[n-bdecision = 1]
    [ let area_beach_fill (desbeachwidth - Bwin ) * (depthclosure + bermy)
      set n_cost n_cost + area_beach_fill * price_sand_nourishment * 1.30795 * 300
      ifelse n_cost > 1200000[ set nourish_dec_2 1][set nourish_dec_2 0]]
    ask patches with[n-bdecision = 1][ifelse Bwin < 0 [set BWe 0][set BWe Bwin]
      set benefit benefit + 2370 * (((desbeachwidth) ^ 1.5) - ( BWe ^ 1.5)) * tot_house / 50
    ]

    ifelse total_debt / (1 + tot_house) < income_avg [
      ifelse benefit - (n_cost / (price_sand_nourishment) * (price_sand_nourishment + var_cost_nourish) + fixed_cost_nourish ) > 0 [  ifelse (n_cost / (price_sand_nourishment) * (price_sand_nourishment + var_cost_nourish) + fixed_cost_nourish) / (5 * tot_house) < 3000[construct_bnourish][set n_cost 0]][set n_cost 0]
      ][set n_cost 0]
  end

;;; Cost of nourishment is calculated

 to price-nourishment
 set total_nprice 0
 set total_nprice ( (n_cost / (price_sand_nourishment) * (price_sand_nourishment + var_cost_nourish) + fixed_cost_nourish )+ dnoup + ednoup)
 set total_price total_price + total_nprice

 end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;                                    TAX

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to tax_adjust
  if total_price > 0[
  if ((total_price / 5) - occupancy * 0.02 *  tot_house / count households / init_com_density) > 0 [
  let tax_house (total_price / 5) - occupancy * 0.02 *  tot_house / count households / init_com_density
  let tax_row1 tax_house * 0.55 / (value1 + 1)
  let tax_row2 tax_house * 0.45 / (value2 + 1)
   ask households[ if purpose < 5 [if row = 1 [set tax tax + propertval * tax_row1 ]
      if row = 2 [set tax tax + propertval * tax_row2 ]
  ]]]]
  ask households [if purpose < 5 [if damage > 0 [ifelse 1500 + damage + mort + tax < income_avg [set tax_damage damage][if last_storm = 1 [set tax_damage damage / 5]]]]]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;                                 BUY/SELL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to dense

  let density tot_house / count households
  set com_att init_com_density / (tot_house / count households)
  if com_att > 1 [set com_att 1]
 end

to storm_recall
  set st_5s item (ticks) st_5
  set st_10s item (ticks) st_10
  set st_25s item (ticks) st_25
  set st_50s item (ticks) st_50
  set storm_rec 1 - (st_5s * 0.05 + st_10s * 0.1 + st_25s * 0.25 )

end

to expense
  let total_expense_com damage_abon
  ask households [ if purpose < 5 [set total_expense_com total_expense_com + tax + tax_damage + mort]]
  set exp_att 1 - (total_debt + damage_abon / 10) / (income_avg * tot_house)
  if exp_att < 0 [set exp_att 0.001]

   end


to attract
  dense
  storm_recall
  expense
  beach-width
  set attractiveness  exp_att * com_att * storm_rec

  end

to beach-width
  set narrow 0
  ask patches[set narrow narrow + Bwin]
  if narrow / 161 > 10 [set hapbeach 0.8]
    if narrow / 161 > 15 [set hapbeach 0.9]
      if narrow / 161 > 20 [set hapbeach 0.95]
        if narrow / 161 > 30 [set hapbeach 1]
end

to buy
  let z 0
  let y 0
  ask households[if tax  + tax_damage  + mort + 1500  > 22000 + (random 16 * 500)  [set purpose 5 set z z + 1 set damage_abon damage_abon + damage  set tax_damage 0]
  if distance-shore + Bwin - 20 < 0 [set purpose 5 set total_debt total_debt + 5000 ]
   ]
  attract
  set numb_buyers 30 * attractiveness * 1.2
  if count households - tot_house < numb_buyers [set numb_buyers count households - tot_house]

  let i 0
  while [ i < numb_buyers][ask one-of households with-max [house_pt] [
  set purpose 1
  set ag_type 1
  set elevation-structure 1.5 + random-normal 2.5 0.3
  set propertval 100000 * random-float 1 + 50000
  set year 0
  set damage_abon damage_abon - damage
  set i i + 1
]]


end
@#$#@#$#@
GRAPHICS-WINDOW
31
15
1571
76
-1
0
30.0
1
10
1
1
1
0
1
1
1
0
50
0
0
0
0
1
ticks
30.0

BUTTON
31
86
98
119
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
113
87
176
120
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
194
87
257
120
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
726
260
1354
425
incoming storm history
year
Recurrence Interval
0.0
60.0
0.0
50.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot inc-storm"

SLIDER
287
87
459
120
SLRAccRate
SLRAccRate
-0.1
0.1
0.005
0.001
1
NIL
HORIZONTAL

PLOT
727
461
1358
633
Tot_house
NIL
NIL
0.0
60.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot tot_house"

SLIDER
228
145
400
178
nourish_int1
nourish_int1
0
100
1
1
1
NIL
HORIZONTAL

SWITCH
472
133
607
166
Storm_Auto
Storm_Auto
0
1
-1000

PLOT
30
451
661
627
expense
NIL
NIL
0.0
60.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot exp_att"

SLIDER
469
87
641
120
time
time
0
100
25
1
1
NIL
HORIZONTAL

PLOT
30
259
662
424
total_debt
NIL
NIL
0.0
60.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot total_debt / tot_house"

SLIDER
29
192
201
225
desbeachwidth
desbeachwidth
0
100
30
1
1
NIL
HORIZONTAL

SLIDER
29
145
201
178
DesignStorm
DesignStorm
0
100
30
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

It is a barrier island model which

## HOW IT WORK

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Nags_bayes" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>tot_house</metric>
    <metric>attractiveness</metric>
    <metric>ave-BW</metric>
    <metric>ave-DH</metric>
    <enumeratedValueSet variable="Storm_Auto">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nourish_int1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="desbeachwidth">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DesignStorm">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SLRAccRate">
      <value value="0.005"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="loadpack" repetitions="1" runMetricsEveryStep="false">
    <setup>setup_discenv</setup>
    <go>load_packages</go>
    <timeLimit steps="1"/>
    <enumeratedValueSet variable="Storm_Auto">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SLRAccRate">
      <value value="0.005"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="desbeachwidth">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DesignStorm">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nourish_int1">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
