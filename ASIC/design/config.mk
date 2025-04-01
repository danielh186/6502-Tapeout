export DESIGN_NICKNAME = 6502_cpu
export DESIGN_NAME = cpu_top
export PLATFORM    = ihp-sg13g2


export VERILOG_FILES = $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/6502_top.v \
                       $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/include.v \
                       $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/cpu.v

export SDC_FILE = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc
export FOOTPRINT_TCL = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/footprint.tcl
export SEAL_GDS = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/sealring.gds

export DIE_AREA  =   0   0 1780 690
export CORE_AREA = 270 270 1510 420


# I/O pads: 180um
# Bondpads: 70um
# Margin for core power ring: 20um
# Total margin to core area: 270um
# Sealring: roughly 60um
# Die Area = Core Area + Power Ring
    # -> DIE_AREA = CORE_AREA + 270 (in both directions)
    # -> Sealring = DIRE_ARE + 120 (in both directions)


########## INSTRUCTIONS TO BUILD DESIGN AND RUN DRC CHECKS ##########

# Install IHP Open PDK (https://ihp-open-pdk-docs.readthedocs.io/en/latest/install.html)
    # Checkout the dev branch on the IHP-Open-PDK repo!

# Generate sealring:
    # The sealring has to be roughly 120um larger than the DIE_AREA in both directions.
    # klayout -n sg13g2 -zz -r ~/IHP-Open-PDK/ihp-sg13g2/libs.tech/klayout/tech/scripts/sealring.py -rd width=810 -rd height=1900 -rd output=sealring.gds

# Move sealring:
    # The sealring has to be moved to postition -60, -60 in klayout for it to be centered in the final design.
    # Open the sealring in klayout edit mode, double click it and move it to -60, -60
    # klayout -e sealring.gds

# Run OpenROAD build (make)

# Run Metal fill:
    # Open the final design in klayout:
    # klayout -e flow/results/ihp-sg13g2/6502_cpu/base/6_final.gds
    # Select the sg13g2 technology
    # In the menu bar under "SG13G2 PDK" run: "Fill Activ/GatPoly", "Fill Metal", "Fill Top Metal"
    # Save the gds (File -> Save)

# Run DRCs with klayout
    # This will take a while, you might want to pipe the output into a file
    # klayout -n sg13g2 -zz -r $PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/drc/sg13g2_maximal.lydrc -rd in_gds=6_final.gds -rd cell=cpu_top -rd report_file=~/maximal_db_drc.lyrdb

    # Double check that there are no critical DRCs.
        # You can get more detail on the DRCs by opening the `6_final.gds` in klayout.
        # Under "Tools -> Marker Browser" open the maximal_db_drc.lyrdb file.
