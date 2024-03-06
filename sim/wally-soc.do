# wally-batch.do 
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Modification by Oklahoma State University & Harvey Mudd College
# Use with Testbench 
# James Stine, 2008; David Harris 2021
# Go Cowboys!!!!!!
#
# Takes 1:10 to run RV64IC tests using gui

# Usage: do wally-batch.do <config> <testcases>
# Example: do wally-batch.do rv32imc imperas-32i

# Use this wally-batch.do file to run this example.
# Either bring up ModelSim and type the following at the "ModelSim>" prompt:
#     do wally-batch.do
# or, to run from a shell, type the following at the shell prompt:
#     vsim -do wally-batch.do -c
# (omit the "-c" to see the GUI while running from the shell)

onbreak {resume}

# create library
if [file exists wkdir/work_${1}_${2}] {
    vdel -lib wkdir/work_${1}_${2} -all
}
vlib wkdir/work_${1}_${2}
# Create directory for coverage data
mkdir -p cov

set coverage 0
set CoverageVoptArg ""
set CoverageVsimArg ""

# Need to be able to pass arguments to vopt.  Unforunately argv does not work because
# it takes on different values if vsim and the do file are called from the command line or
# if the do file isd called from questa sim directly.  This chunk of code uses the $4 through $n
# variables and compacts into a single list for passing to vopt.
set configOptions ""
set from 4
set step 1
set lst {}
for {set i 0} true {incr i} {
    set x [expr {$i*$step + $from}]
    if {$x > $argc} break
    set arg [expr "$$x"]
    lappend lst $arg
}

if {$argc >= 3} {
    if {$3 eq "-coverage" || ($argc >= 7 && $7 eq "-coverage")} {
        set coverage 1
        set CoverageVoptArg "+cover=sbecf"
        set CoverageVsimArg "-coverage"
    } elseif {$3 eq "configOptions"} {
        set configOptions $lst
        puts $configOptions
    }
}

# compile source files
# suppress spurious warnngs about 
# "Extra checking for conflicts with always_comb done at vopt time"
# because vsim will run vopt

# default to config/rv64ic, but allow this to be overridden at the command line.  For example:
# do wally-pipelined-batch.do ../config/rv32imc rv32imc

# Compile bsg files, then wally
set bsg_dir ../soc/src/basejump_stl
vlog -lint -work wkdir/work_${1}_${2} +define+den2048Mb +define+sg5 +define+x32 +incdir+$bsg_dir/bsg_clk_gen +incdir+$bsg_dir/bsg_dmc +incdir+$bsg_dir/bsg_noc +incdir+$bsg_dir/bsg_tag +incdir+$bsg_dir/testing/bsg_dmc/lpddr_verilog_model +incdir+$bsg_dir/bsg_misc +incdir+$bsg_dir/testing/bsg_dmc/lpddr_verilog_model $bsg_dir/bsg_misc/bsg_defines.sv $bsg_dir/bsg_tag/bsg_tag_pkg.sv $bsg_dir/bsg_dmc/bsg_dmc_pkg.sv $bsg_dir/bsg_noc/bsg_noc_pkg.sv $bsg_dir/bsg_noc/bsg_mesh_router_pkg.sv $bsg_dir/bsg_noc/bsg_wormhole_router_pkg.sv $bsg_dir/*/*.sv $bsg_dir/testing/bsg_dmc/lpddr_verilog_model/*.sv -suppress 2583,2596,2605,2902,7063,8885,13286,13314,13388
vlog -lint -work wkdir/work_${1}_${2} +incdir+../config/$1 +incdir+../config/deriv/$1 +incdir+../config/shared +incdir+$bsg_dir/bsg_clk_gen +incdir+$bsg_dir/bsg_dmc +incdir+$bsg_dir/dmc_misc +incdir+$bsg_dir/bsg_misc +incdir+$bsg_dir/bsg_tag +incdir+$bsg_dir/testing/bsg_dmc/lpddr_verilog_model ../src/cvw.sv ../testbench/testbench-soc.sv ../testbench/common/*.sv ../src/*/*.sv ../src/*/*/*.sv ../soc/src/fifo/*.sv ../soc/src/*.sv -suppress 2583,2596,2605,2902,7063,8885,13286,13314,13388

# start and run simulation
# remove +acc flag for faster sim during regressions if there is no need to access internal signals
vopt wkdir/work_${1}_${2}.testbench -work wkdir/work_${1}_${2} -G TEST=$2 ${configOptions} -o testbenchopt ${CoverageVoptArg}
vsim -lib wkdir/work_${1}_${2} testbenchopt  -fatal 7 -suppress 3009,3829,8885 ${CoverageVsimArg}

# power add generates the logging necessary for said generation.
# power add -r /dut/core/*
run -all
# power off -r /dut/core/*


if {$coverage} {
    echo "Saving coverage to ${1}_${2}.ucdb"
    do coverage-exclusions-rv64gc.do  # beware: this assumes testing the rv64gc configuration
    coverage save -instance /testbench/dut/core cov/${1}_${2}.ucdb
}

# These aren't doing anything helpful
#profile report -calltree -file wally-calltree.rpt -cutoff 2
#power report -all -bsaif power.saif
quit
