set sdc_version 1.3

set clockName "clk"
set clockPeriod "1.25"

create_clock -name clk -period $clockPeriod
set_input_delay 0 -clock clk  [all_inputs]
set_output_delay 0 -clock clk  [all_outputs]


;# Set-up Clock
create_clock -period ${clockPeriod} clk
set_clock_uncertainty [format %.4f [expr $clockPeriod*0.05]]  $clockName
set_dont_touch_network $clockName
set_ideal_network $clockName
set_dont_touch_network $rstName
set_ideal_network $rstName

;# fix hold constraints
set_min_delay 0.05 -through [all_registers] -from [all_inputs] -to [all_outputs]

;# Set-up IOs
set STM_minStrength_buf_LVT "HS65_LL_BFX7"
set STM_minStrength_buf_SVT "HS65_LS_BFX7"
set STM_minStrength_buf_HVT "HS65_LH_BFX7"

set_driving_cell -library "CORE65LPLVT_nom_1.00V_25C.db:CORE65LPLVT" -lib_cell $STM_minStrength_buf_LVT [all_inputs]
set_driving_cell -library "CORE65LPSVT_nom_1.00V_25C.db:CORE65LPSVT" -lib_cell $STM_minStrength_buf_SVT [all_inputs]
set_driving_cell -library "CORE65LPHVT_nom_1.00V_25C.db:CORE65LPHVT" -lib_cell $STM_minStrength_buf_HVT [all_inputs]

set_input_delay  [format %.4f [expr $clockPeriod*0.10]] -clock $clockName [all_inputs]
set_output_delay [format %.4f [expr $clockPeriod*0.10]] -clock $clockName [all_outputs]
set_input_delay 0 -clock clk clk

set max_transition_time 0.1
set_max_transition $max_transition_time [all_outputs]

;# Set area constraint
set_max_area 0
