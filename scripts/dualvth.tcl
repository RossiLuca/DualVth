proc dualVth {args} {
	parse_proc_arguments -args $args results
	set lvt $results(-lvt)
	set constraint $results(-constraint)

	#################################
	### INSERT YOUR COMMANDS HERE ###
	#################################

	suppress_message PWR-601
	suppress_message PWR-246
	suppress_message NED-045
	suppress_message LNK-041
	suppress_message PTE-018
	
	global timing_save_pin_arrival_and_slack
	
	set original_leakage [get_attribute [current_design] leakage_power]
	set list_cell_to_swap [list]
	set lvt_cell [list]
	set post_soft_cell_to_swap_list [list]
	set post_soft_cell_list [list]
	set cell_swap_in_hard_list [list]

	set slack_met 0
	set num_lvt_cell 0
	set num_hvt_cell 0
	set achieved_lvt_percentage 0
	set num_cell_for_hard 0
	set slack 0
	set leakage_power $original_leakage
	set timing_save_pin_arrival_and_slack 1
	set percentage [expr $lvt * 100]
	set celltoswap_totcell [ tot_lvt_cell $lvt ]

	set splitted_values [split $celltoswap_totcell " "]
	set tot_lvt_cell [lindex $splitted_values 2]
	set tot_cell [lindex $splitted_values 1]
	set cell_to_swap [lindex $splitted_values 0]
	set precision [expr 100/double($tot_cell)]
	set lvt_cell [get_slack_from_pin]
	set list_cell_to_swap [generate_cost_list $lvt_cell]
	set cell_available [llength $list_cell_to_swap]

	while 1 {

		set start_index 0
		set stop_index [expr {$cell_available-1}]

		set depth [expr entier(ceil(log(100/$precision)/log(2)))]

		set list_cell_to_swap	[cells_swapping_to_hvt $list_cell_to_swap $start_index $stop_index]
		set slack_met [test_slack_met]

		set pUp 0
		set pDown $cell_available
		set pNow 0
		set pOld $pNow

		if {$slack_met == 0} {
			for {set index 0} {$index < $depth} {incr index} {
				if {$slack_met == 0} {
					set pOld $pNow
					set pNow [expr $pNow + entier(ceil(($pDown-$pNow)/2))]
					set pUp $pOld
					set list_cell_to_swap [cells_swapping_to_lvt $list_cell_to_swap $pUp [expr $pNow-$pUp]]
					set slack_met [test_slack_met]
				} else {
					set pOld $pNow
					set pNow [expr $pNow - entier(ceil(($pDown-$pNow)/2))]
					set pDown $pOld
					set list_cell_to_swap [cells_swapping_to_hvt $list_cell_to_swap $pNow $pDown]
					set slack_met [test_slack_met]
				}
			}
		}
		
		if {$slack_met == 0} {
			set list_cell_to_swap [cells_swapping_to_lvt $list_cell_to_swap $pNow [expr $pDown-$pNow]]
		}
		
		set lvt_cell [get_slack_from_pin]
		set list_cell_to_swap [generate_cost_list $lvt_cell]
		set cell_available_next [llength $list_cell_to_swap]
		if {$cell_available_next==$cell_available} {
			break
		}

		set cell_available $cell_available_next
		set slack_met 0

	}

	foreach row [get_attribute [get_cells] ref_name] {
		set name [split $row "_"]
		set type [lindex $name 2]
		set lib_type [lindex $name 0]
		
		if {[lindex $name 1] == "LH" || [lindex $name 1] == "LHS" } {
			incr num_hvt_cell
		}
		
		if {[lindex $name 1] == "LL" || [lindex $name 1] == "LLS" } {
			incr num_lvt_cell
		}
	}

	set achieved_lvt_percentage [expr (100*($num_lvt_cell)/double($tot_cell))]

	if {$constraint == "hard"} {
		set num_cell_for_hard [expr entier(ceil((( $achieved_lvt_percentage - $percentage)/100)*$tot_cell))]
		
		if {$num_cell_for_hard > 0} {
			set post_soft_cell_list $list_cell_to_swap
			set post_soft_cell_to_swap_list [get_slack_from_pin_list $post_soft_cell_list]
			set cell_swap_in_hard_list [cell_swap_to_hvt_cost_func_hard $post_soft_cell_to_swap_list $num_cell_for_hard]
			}
		}

	return 1

}


proc generate_cost_list {list_cell_to_swap} {
	set index 0
	set ret_list $list_cell_to_swap
	set lenght [llength $list_cell_to_swap]
	set cell_cost_list [list]
	set count 0
	
	while {$index < $lenght} {
		set element_swap_list [lindex $list_cell_to_swap $index]
		set line_swap [split $element_swap_list " "]
		set cell_name [lindex $line_swap 0]
		set cell_ref_name [lindex $line_swap 1]
		set slack_cell [lindex $line_swap 2]
		set leak_pow_cell [lindex $line_swap 3]
		set cost_fun_value [cost_fun $slack_cell $leak_pow_cell]
		set element_cost_cell_list "${cell_name} ${cell_ref_name} ${cost_fun_value} ${slack_cell} ${leak_pow_cell}"
		lappend cell_cost_list $element_cost_cell_list
		incr index
	}
	
	set cell_cost_list [lsort -index 2 $cell_cost_list]
	
	return $cell_cost_list
}

proc tot_lvt_cell {lvt} {
	set count 0
	set tot_cell 0
	set collection_of_cell [get_cells]
	
	foreach_in_collection cell $collection_of_cell {
		incr tot_cell
		set cell_ref_name [get_attribute $cell ref_name]
		set lines [split $cell_ref_name "_"]
		
		if { [lindex $lines 1] == "LL" || [lindex $lines 1] == "LLS" } {
			incr count
		}
	}
	
	set max_tot_lvt [ expr { $lvt * $tot_cell} ]
	set cell_to_swap [ expr {floor($count - $max_tot_lvt)}]
	
	if { $cell_to_swap <= 0 } {
		set ret_values "0 ${tot_cell} ${count}"
		return $ret_values
	} else {
		set ret_values "${cell_to_swap} ${tot_cell} ${count}"
		return $ret_values
	}
}

proc cost_fun {slack leak_power} {
	set slack_weigth 0.5
	set power_weigth 0.5
	set value_fun [expr double($slack*$slack_weigth + $leak_power*$power_weigth)]
	return $value_fun
}

proc cell_swap_to_hvt_cost_func_hard {list_cell_to_swap num_cell_to_swap_hard} {
	set index 0
	set ret_list $list_cell_to_swap
	set lenght [llength $list_cell_to_swap]
	set cell_cost_list [list]
	set count 0
	
	while {$index < $lenght} {
		set element_swap_list [lindex $list_cell_to_swap $index]
		set line_swap [split $element_swap_list " "]
		set cell_name [lindex $line_swap 0]
		set cell_ref_name [lindex $line_swap 1]
		set slack_cell [lindex $line_swap 2]
		set leak_pow_cell [lindex $line_swap 3]
		set cost_fun_value [cost_fun $slack_cell $leak_pow_cell]
		set element_cost_cell_list "${index} ${cell_name} ${cell_ref_name} ${cost_fun_value} ${slack_cell} ${leak_pow_cell}"
		lappend cell_cost_list $element_cost_cell_list
		incr index
	}
	
	set cell_cost_list [lsort -index 3 $cell_cost_list]
	set lenght_cost_list [llength $cell_cost_list]
	
	while {$count < $num_cell_to_swap_hard} {
		set element_cost_list [lindex $cell_cost_list [expr $lenght_cost_list-$count-1]]
		set line_cost [split $element_cost_list " "]
		set original_index [lindex $line_cost 0]
		set cell_name_cost [lindex $line_cost 1]
		set cell_ref_name_cost [lindex $line_cost 2]
		set name [split $cell_ref_name_cost "_"]
		set lib_type [lindex $name 0]
		set type [lindex $name 2]
		
		if {[lindex $name 1] == "LL"} {
			set new_cell_hvt "${lib_type}_LH_${type}"
			set newelement "${cell_name_cost} ${new_cell_hvt}"
			set ret_list [lreplace $ret_list $original_index $original_index $newelement]
			size_cell $cell_name_cost "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/${new_cell_hvt}"
		} else {
		
			if {[lindex $name 1] == "LLS"} {
				set new_cell_hvt "${lib_type}_LHS_${type}"
				set newelement "${cell_name_cost} ${new_cell_hvt}"
				set ret_list [lreplace $ret_list $original_index $original_index $newelement]
				size_cell $cell_name_cost "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/${new_cell_hvt}"
			}
		}
		
	incr count
	}
	
	return $ret_list
}

proc test_slack_met {} {
	
	foreach_in_collection path [get_timing_paths] {
		set slack [get_attribute $path slack]
		
		if  {$slack < 0.0 } {
			return 0
		} else {
			return 1
		}
	}
}

proc cells_swapping_to_lvt {cell_list start_index stop_index} {
	set index $start_index
	set count 0
	set ret_list $cell_list
	
	while {$count < $stop_index} {
		set element [lindex $cell_list $index]
		set line [split $element " "]
		set cell [lindex $line 0]
		set name [split [lindex $line 1] "_"]
		set type [lindex $name 2]
		set cell_name [lindex $name 0]
	
		if {[lindex $name 1] != "LL" || [lindex $name 1] != "LLS" } {
		
			if {[lindex $name 1] == "LH"} {
				set new_cell_lvt "${cell_name}_LL_${type}"
				set newelement "${cell} ${new_cell_lvt}"
			}
			
			if {[lindex $name 1] == "LHS"} {
				set new_cell_lvt "${cell_name}_LLS_${type}"
				set newelement "${cell} ${new_cell_lvt}"
			}

			set ret_list [lreplace $ret_list $index $index $newelement]
			size_cell $cell "CORE65LPLVT_nom_1.20V_25C.db:CORE65LPLVT/${new_cell_lvt}"
		}

		incr index
		incr count
	}

	return $ret_list
}

proc cells_swapping_to_hvt {cell_list start_index stop_index} {
	set index $start_index
	set ret_list $cell_list
	
	while {$index <= $stop_index} {
		set element [lindex $cell_list $index]
		set line [split $element " "]
		set cell [lindex $line 0]
		set name [split [lindex $line 1] "_"]
		set type [lindex $name 2]
		set cell_name [lindex $name 0]
		
		if {[lindex $name 1] == "LL"} {
			set new_cell_hvt "${cell_name}_LH_${type}"
			set newelement "${cell} ${new_cell_hvt}"
			set ret_list [lreplace $ret_list $index $index $newelement]
			size_cell $cell "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/${new_cell_hvt}"
		} else {

		if {[lindex $name 1] == "LLS"} {
			set new_cell_hvt "${cell_name}_LHS_${type}"
			set newelement "${cell} ${new_cell_hvt}"
			set ret_list [lreplace $ret_list $index $index $newelement]
			size_cell $cell "CORE65LPHVT_nom_1.20V_25C.db:CORE65LPHVT/${new_cell_hvt}"
		}
	}

	incr index
	}

	return $ret_list
	}


proc get_slack_from_pin {} {
	set ret_list [list]
	set cell_collection [get_cells]
	
	foreach_in_collection cell $cell_collection {
		set cell_name [get_attribute $cell full_name]
		set cell_ref_name [get_attribute $cell ref_name]
		set lines [split $cell_ref_name "_" ]
		
		if { [lindex $lines 1] == "LL" || [lindex $lines 1] == "LLS" } {
			set pin_collection [get_pins -of_object $cell]
		
			foreach_in_collection pin $pin_collection {
				set pin_name [get_attribute $pin full_name]
				
				if {$pin_name == "${cell_name}/Z"} {
					set cell_name_slack [get_attribute $pin max_slack]
				}
			}
			
			set cell_name_power [get_attribute $cell leakage_power]
			set cell_information "$cell_name $cell_ref_name $cell_name_slack $cell_name_power"
			lappend ret_list $cell_information
		}
	}
	
	set ret_list [lsort -index 2 $ret_list]
	return $ret_list
}

proc get_slack_from_pin_list {work_list} {
	set ret_list [list]
	set cell_work_list [list]
	
	foreach work_cell $work_list {
		set row [split $work_cell " "]
		lappend cell_work_list [list [lindex $row 0]]
	}
	
	set cell_collection [get_cells $cell_work_list]
	
	foreach_in_collection cell $cell_collection {
		set cell_name [get_attribute $cell full_name]
		set cell_ref_name [get_attribute $cell ref_name]
		set pin_collection [get_pins -of_object $cell]
		
		foreach_in_collection pin $pin_collection {
			set pin_name [get_attribute $pin full_name]
			
			if {$pin_name == "${cell_name}/Z"} {
				set cell_name_slack [get_attribute $pin max_slack]
			}
		}
		
		set cell_name_power [get_attribute $cell leakage_power]
		set cell_information "$cell_name $cell_ref_name $cell_name_slack $cell_name_power"
		lappend ret_list $cell_information
	}
	
	return $ret_list
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-lvt "maximum % of LVT cells in range [0, 1]" lvt float required}
	{-constraint "optimization effort: soft or hard" constraint one_of_string {required {values {soft hard}}}}
}
