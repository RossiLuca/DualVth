# DualVth

## Algorithm

The procedure, given a combinational circuit implemented with `LVT` cells, tries to reduce the leakage power by swapping part of the cells to `HVT`.  
The first part of the algorithm extracts the timing and power information from each `LVT` cell and then computes a value through a cost function that represent the suitability of the cell to be swapped into an `HVT` one. The cost function is based on a very simple formula

`value = slack * 0.5 + leakage_power * 0.5`

In this way we take into account both the timing and power influence of the cell in the circuit.
After that we collect all these information in a list sorted by the cost function value. The cells with a lower index have lower values and so they are less suitable to be changed because they have a lower slack and lower leakage power.

As first try the algorithm swaps all the ports of the design to `HVT` and then it checks if the slack of the circuit is still met. If it is lower than zero the procedure, through a Dichotomous search applied to the list, starts to re-size part of the design and after each attempt the program controls if the slack is positive or not.

At the end of the search the algorithm uploads the list with the changed cells and compute again the value of the cost function for each `LVT` cell in the circuit. The procedure iterates the search and upload phase until two consecutive lists with the same length are found.  When this condition is reached the algorithm is no more able to perform other re-size operations without violating the slack or without a heavy overhead on computing time.

This is the `soft` part of the procedure because at the end the circuit has the lower possible percentage of LVT with still a positive slack condition. After that if the constraint specified is `hard` and the required percentage is lower than the one achieved until now, the procedure extracts again the timing and power information of the remaining `LVT` cells. In the end it executes the last re-size operations based on a sorted list obtained through the cost function to achieved the required percentage.

### Additional procedure definition

* `generate_cost_list`:  given a list it returns another one based on the input one but sorted with respect to the value calculated with the cost function. The structure of an element is the following   
 “fullname ref_name value slack leakage_power”

* `tot_lvt_cell`: given the required percentage it returns the cell to swap to achieved the percentage,  the total number of cells in the design, and the total amount of LVT cell in the following form
 “cell_to_swap tot_cell_in_design tot_lvt_cell_in_design”

* `cost_func`: given slack and leakage power value of a cell it returns the cost function value for that element.

* `cell_swap_to_hvt_cost_func_hard`: given an input list and an input value x it computes the cost function value for each cell of the list and re-size to HVT the last x elements of the generated cost_list. It returns a modified version of the input list that reports all the modified cells in the following form
 “fullname ref_name”

* `test_slack_met`: it returns 1 if the slack is met 0 otherwise.
 
* `cell_swapping_to_lvt`: given an input list, a start and a stop index it swaps from HVT to LVT all the cells within the specified range.

* `cell_swapping_to_hvt`: given an input list, a start and a stop index it swaps from LVT to HVT all the cells within that range.

* `get_slack_form_pin`: it returns a list containing the timing and power information of all the LVT cells in the design in the following form
 “fullname ref_name slack leakage_power”

* `get_slack_from_pin_list`: it returns a list containing the timing and power information of all the LVT cells specified in the input list in the following form
 “fullname ref_name slack leakage_power”


 ## Usage example

 The design must be synthesized by `DesignCompiler` and analyzed by `PrimeTime`.
 The `synthesis.tcl` and `pt_analysis.tcl` scripts are provided to partially reproduce the synthesis flow.
 The DualVth script requires two arguments:

 * `lvt`: the maximum percentage of LVT (Low Voltage Threshold) cells that can be left in the circuit at the end of the elaboration.

 * `constraint`: `hard` or `soft`. In the first case the `lvt` argument must be respected even if it produces a negative slack. In the second one instead the slack must not go under 0, even if it means not fulfilling the lvt agrument.

Examples:

 ```
 > The percentage of LVT cells in the design must be lower than 20% even if it means negative slack condition
dualVth -lvt 0.2 -constraint hard

>We would like to have only 80% of LVT cells in the design or get as close as possible with still positive slack
dualVth -lvt 0.8 -constraint soft

>We want to swap as many cells as possible, while keeping a positive slack
dualVth -lvt 0 -constraint soft
 ```
