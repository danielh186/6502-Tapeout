set IO_LENGTH 180
set BONDPAD_SIZE 70
set SEALRING_OFFSET 70
# sg13g2_io.lef defines sg13g2_ioSite for the sides, but no corner site
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
place_pads -row IO_NORTH \
    u_pad_vddcore_1 \
    u_pad_addr_1 \
    u_pad_addr_2 \
    u_pad_addr_3 \
    u_pad_addr_4 \
    u_pad_addr_5 \
    u_pad_addr_6 \
    u_pad_addr_7 \
    u_pad_addr_8 \
    u_pad_addr_9 \
    u_pad_addr_10 \
    u_pad_addr_11 \
    u_pad_addr_12 \
    u_pad_addr_13 \
    u_pad_addr_14 \
    u_pad_gndcore_1 \

place_pads -row IO_EAST \
    u_pad_gndpad_0 \
    u_pad_gndpad_1 \

place_pads -row IO_SOUTH \
    u_pad_gndcore_0 \
    u_pad_addr_15 \
    u_pad_addr_0 \
    u_pad_data_0 \
    u_pad_data_1 \
    u_pad_data_2 \
    u_pad_data_3 \
    u_pad_data_4 \
    u_pad_data_5 \
    u_pad_data_6 \
    u_pad_data_7 \
    u_pad_reset_n \
    u_pad_clk \
    u_pad_rw \
    u_pad_vddcore_0 \


place_pads -row IO_WEST \
    u_pad_vddpad_0 \
    u_pad_vddpad_1 \


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