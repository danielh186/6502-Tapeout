set IO_LENGTH 180
set IO_WIDTH 80
set BONDPAD_SIZE 70
set SEALRING_OFFSET 70
# PAD_OFFSET = 180 + 70 + 70 = 320
# HORIZONTAL_PAD_DISTANCE: ~10
# PAD_AREA_WIDTH = n * IO_WIDTH + (n + 1) * HORIZONTAL_PAD_DISTANCE (1450, 190)
# DIE_AREA = 2 * PAD_OFFSET + PAD_AREA_WIDTH (2090, 830)

proc calc_horizontal_pad_location {index total} {
    global IO_LENGTH
    global IO_WIDTH
    global BONDPAD_SIZE
    global SEALRING_OFFSET

    set DIE_WIDTH [expr {[lindex $::env(DIE_AREA) 2] - [lindex $::env(DIE_AREA) 0]}]
    set PAD_OFFSET [expr {$IO_LENGTH + $BONDPAD_SIZE + $SEALRING_OFFSET}]
    set PAD_AREA_WIDTH [expr {$DIE_WIDTH - ($PAD_OFFSET * 2)}]
    set HORIZONTAL_PAD_DISTANCE [expr {($PAD_AREA_WIDTH / $total) - $IO_WIDTH}]

    return [expr {$PAD_OFFSET + (($IO_WIDTH + $HORIZONTAL_PAD_DISTANCE) * $index) + ($HORIZONTAL_PAD_DISTANCE / 2)}]
}

proc calc_vertical_pad_location {index total} {
    global IO_LENGTH
    global IO_WIDTH
    global BONDPAD_SIZE
    global SEALRING_OFFSET

    set DIE_HEIGHT [expr {[lindex $::env(DIE_AREA) 3] - [lindex $::env(DIE_AREA) 1]}]
    set PAD_OFFSET [expr {$IO_LENGTH + $BONDPAD_SIZE + $SEALRING_OFFSET}]
    set PAD_AREA_HEIGHT [expr {$DIE_HEIGHT - ($PAD_OFFSET * 2)}]
    set VERTICAL_PAD_DISTANCE [expr {($PAD_AREA_HEIGHT / $total) - $IO_WIDTH}]

    return [expr {$PAD_OFFSET + (($IO_WIDTH + $VERTICAL_PAD_DISTANCE) * $index) + ($VERTICAL_PAD_DISTANCE / 2)}]
}

make_fake_io_site -name IOLibSite -width 1 -height $IO_LENGTH
make_fake_io_site -name IOLibCSite -width $IO_LENGTH -height $IO_LENGTH

set IO_OFFSET [expr {$BONDPAD_SIZE + $SEALRING_OFFSET}]
# Create IO Rows
make_io_sites \
    -horizontal_site IOLibSite \
    -vertical_site IOLibSite \
    -corner_site IOLibCSite \
    -offset $IO_OFFSET

######## Place Pads ########
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 0 16] {u_pad_vddcore_1} -master sg13g2_IOPadVdd
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 1 16] {u_pad_addr_1} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 2 16] {u_pad_addr_2} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 3 16] {u_pad_addr_3} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 4 16] {u_pad_addr_4} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 5 16] {u_pad_addr_5} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 6 16] {u_pad_addr_6} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 7 16] {u_pad_addr_7} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 8 16] {u_pad_addr_8} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 9 16] {u_pad_addr_9} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 10 16] {u_pad_addr_10} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 11 16] {u_pad_addr_11} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 12 16] {u_pad_addr_12} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 13 16] {u_pad_addr_13} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 14 16] {u_pad_addr_14} -master sg13g2_IOPadOut4mA
place_pad -row IO_NORTH -location [calc_horizontal_pad_location 15 16] {u_pad_gndcore_1} -master sg13g2_IOPadVss

place_pad -row IO_EAST -location [calc_vertical_pad_location 0 2] {u_pad_gndpad_0} -master sg13g2_IOPadIOVss
place_pad -row IO_EAST -location [calc_vertical_pad_location 1 2] {u_pad_gndpad_1} -master sg13g2_IOPadIOVss

place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 0 15] {u_pad_gndcore_0} -master sg13g2_IOPadVss
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 1 15] {u_pad_addr_15} -master sg13g2_IOPadOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 2 15] {u_pad_addr_0} -master sg13g2_IOPadOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 3 15] {u_pad_data_0} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 4 15] {u_pad_data_1} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 5 15] {u_pad_data_2} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 6 15] {u_pad_data_3} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 7 15] {u_pad_data_4} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 8 15] {u_pad_data_5} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 9 15] {u_pad_data_6} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 10 15] {u_pad_data_7} -master sg13g2_IOPadInOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 11 15] {u_pad_reset_n} -master sg13g2_IOPadIn
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 12 15] {u_pad_clk} -master sg13g2_IOPadIn
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 13 15] {u_pad_rw} -master sg13g2_IOPadOut4mA
place_pad -row IO_SOUTH -location [calc_horizontal_pad_location 14 15] {u_pad_vddcore_0} -master sg13g2_IOPadVdd

place_pad -row IO_WEST -location [calc_vertical_pad_location 0 2] {u_pad_vddpad_0} -master sg13g2_IOPadIOVdd
place_pad -row IO_WEST -location [calc_vertical_pad_location 1 2] {u_pad_vddpad_1} -master sg13g2_IOPadIOVdd

# Place corners
place_corners sg13g2_Corner

# Place IO fill
set iofill {sg13g2_Filler10000
            sg13g2_Filler4000
            sg13g2_Filler2000
            sg13g2_Filler1000
            sg13g2_Filler400
            sg13g2_Filler200} ;

place_io_fill -row IO_NORTH {*}$iofill
place_io_fill -row IO_SOUTH {*}$iofill
place_io_fill -row IO_WEST {*}$iofill
place_io_fill -row IO_EAST {*}$iofill

# Place the bondpads
place_bondpad -bond bondpad_70x70 u_pad_* -offset "5.0 -$BONDPAD_SIZE.0"

# Connect ring signals
connect_by_abutment

remove_io_rows