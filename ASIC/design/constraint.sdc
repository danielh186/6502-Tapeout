current_design CPU

set_units -time ns -resistance kOhm -capacitance pF -voltage V -current uA
set_max_fanout 20 [current_design]
set_max_transition 3 [current_design]
set_max_area 0

# set clk_name clk
set clk_port_name clk
# TODO
set clk_period 10.0
set clk_io_pct 0.2

set clk_port [get_ports $clk_port_name]

set non_clock_inputs [get_ports {\
    reset_n \
}]

set non_clock_outputs [get_ports {\
    addr_0 \
    addr_1 \
    addr_2 \
    addr_3 \
    addr_4 \
    addr_5 \
    addr_6 \
    addr_7 \
    addr_8 \
    addr_9 \
    addr_10 \
    addr_11 \
    addr_12 \
    addr_13 \
    addr_14 \
    addr_15 \
    RW \
}]


set non_clock_inouts [get_ports {\
	data_0 \
	data_1 \
	data_2 \
	data_3 \
	data_4 \
	data_5 \
	data_6 \
	data_7 \
}]

set_driving_cell -lib_cell sg13g2_IOPadIn -pin pad $clk_port
set_driving_cell -lib_cell sg13g2_IOPadIn -pin pad $non_clock_inputs
set_driving_cell -lib_cell sg13g2_IOPadOut4mA -pin pad $non_clock_outputs
set_driving_cell -lib_cell sg13g2_IOPadInOut4mA -pin pad $non_clock_inouts


set_ideal_network [get_pins u_pad_clk/p2c]
create_clock [get_pins u_pad_clk/p2c] -name $clk_port_name -period 20.8333333
set_clock_uncertainty 0.15 [get_clocks $clk_port_name]
set_clock_transition 0.25 [get_clocks $clk_port_name]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_port_name $clk_port
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_port_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_port_name $non_clock_outputs
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_port_name $non_clock_inouts
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_port_name $non_clock_inouts

set_load -pin_load 5 [all_inputs]
set_load -pin_load 5 [all_outputs]
