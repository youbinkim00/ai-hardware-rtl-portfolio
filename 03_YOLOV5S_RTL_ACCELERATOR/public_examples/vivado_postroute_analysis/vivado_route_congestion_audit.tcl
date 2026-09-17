# =============================================================================
# Vivado route / congestion audit report generator
# Vivado 2023.1 / configurable implementation run
#
# Output directory:
#   <implementation-run DIRECTORY>/route_congestion_check
#
# Main file to upload for analysis:
#   98_ROUTE_ANALYSIS_BUNDLE.rpt
#
# Status log:
#   99_report_generation_status.log
#
# Run from Vivado Tcl Console:
#   source vivado_route_congestion_audit.tcl
#
# NOTE:
#   - Any currently open design is closed.
#   - The script opens the latest available checkpoint in IMPL_RUN_NAME.
#   - A failed individual report does not stop the remaining reports.
#   - Unsupported route_type / boolean_check values are recorded in reports.
# =============================================================================

# =============================================================================
# USER CONFIGURATION
# =============================================================================

# Name of the completed or in-progress Vivado implementation run to inspect.
# The script does not launch implementation; it opens the latest checkpoint
# available inside this run and records the exact run status in the reports.
set IMPL_RUN_NAME "impl_1"

# =============================================================================
# 0. Resolve implementation run and create the report directory inside the selected run
# =============================================================================

set impl_runs [get_runs -quiet $IMPL_RUN_NAME]

if {[llength $impl_runs] == 0} {
    error "Implementation run does not exist: $IMPL_RUN_NAME"
}

set impl_run [lindex $impl_runs 0]
set impl_status [get_property STATUS $impl_run]
set impl_dir [file normalize [get_property DIRECTORY $impl_run]]
set rpt_dir [file join $impl_dir route_congestion_check]

file mkdir $rpt_dir

set route_status_path [file join $rpt_dir 99_report_generation_status.log]
set route_status_fp [open $route_status_path w]

set route_pass_count 0
set route_fail_count 0

proc run_route_report {report_id report_name command_list} {
    global route_status_fp
    global route_pass_count
    global route_fail_count

    set title [format "%s  %s" $report_id $report_name]

    puts ""
    puts "============================================================================="
    puts "START: $title"
    puts "============================================================================="

    puts $route_status_fp "START: $title"
    flush $route_status_fp

    set report_failed [catch {uplevel #0 $command_list} report_result]

    if {$report_failed} {
        puts "FAILED: $title"
        puts "REASON: $report_result"

        puts $route_status_fp "FAILED: $title"
        puts $route_status_fp "REASON: $report_result"
        puts $route_status_fp ""
        flush $route_status_fp

        incr route_fail_count
        return 0
    }

    puts "DONE: $title"

    puts $route_status_fp "DONE: $title"
    puts $route_status_fp ""
    flush $route_status_fp

    incr route_pass_count
    return 1
}


proc append_text_file {bundle_fp title path} {
    puts $bundle_fp ""
    puts $bundle_fp ""
    puts $bundle_fp "#############################################################################"
    puts $bundle_fp "# $title"
    puts $bundle_fp "# SOURCE FILE: $path"
    puts $bundle_fp "#############################################################################"

    if {![file exists $path]} {
        puts $bundle_fp "FILE NOT GENERATED OR NOT FOUND"
        return
    }

    set src_fp [open $path r]
    fcopy $src_fp $bundle_fp
    close $src_fp
}

puts "============================================================================="
puts "IMPLEMENTATION RUN INFORMATION"
puts "STATUS:"
puts "  $impl_status"
puts "DIRECTORY:"
puts "  $impl_dir"
puts "REPORT DIRECTORY:"
puts "  $rpt_dir"
puts "============================================================================="

puts $route_status_fp "============================================================================="
puts $route_status_fp "IMPLEMENTATION RUN INFORMATION"
puts $route_status_fp "STATUS:"
puts $route_status_fp "  $impl_status"
puts $route_status_fp "DIRECTORY:"
puts $route_status_fp "  $impl_dir"
puts $route_status_fp "REPORT DIRECTORY:"
puts $route_status_fp "  $rpt_dir"
puts $route_status_fp "============================================================================="
puts $route_status_fp ""
flush $route_status_fp

# Close any currently open synthesized, placed, routed, or old checkpoint design.
if {[llength [get_designs -quiet]] != 0} {
    puts "Closing currently open design:"
    puts "  [current_design]"

    puts $route_status_fp "Closing currently open design:"
    puts $route_status_fp "  [current_design]"
    flush $route_status_fp

    set close_failed [catch {close_design} close_result]

    if {$close_failed} {
        puts "FATAL ERROR: Failed to close current design."
        puts "REASON: $close_result"

        puts $route_status_fp "FATAL ERROR: Failed to close current design."
        puts $route_status_fp "REASON: $close_result"
        close $route_status_fp

        error "Failed to close current design: $close_result"
    }
}

puts ""
puts "Opening implementation run: $IMPL_RUN_NAME..."
puts $route_status_fp "Opening implementation run: $IMPL_RUN_NAME..."
flush $route_status_fp

set open_failed [catch {open_run $IMPL_RUN_NAME} open_result]

if {$open_failed} {
    puts "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts "REASON: $open_result"

    puts $route_status_fp "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts $route_status_fp "REASON: $open_result"
    close $route_status_fp

    error "Failed to open implementation run $IMPL_RUN_NAME: $open_result"
}

puts "Opened design:"
puts "  [current_design]"

puts $route_status_fp "Opened design:"
puts $route_status_fp "  [current_design]"
puts $route_status_fp ""
flush $route_status_fp

# =============================================================================
# 1. Main route / congestion reports
# =============================================================================

run_route_report "01" "full route status" \
    [list report_route_status \
        -ignore_cache \
        -show_all \
        -file [file join $rpt_dir 01_route_status_full.rpt]]

run_route_report "02" "congestion level 3 or higher" \
    [list report_design_analysis \
        -congestion \
        -min_congestion_level 3 \
        -file [file join $rpt_dir 02_congestion_level3_plus.rpt]]

run_route_report "03" "congestion level 5 or higher" \
    [list report_design_analysis \
        -congestion \
        -min_congestion_level 5 \
        -file [file join $rpt_dir 03_congestion_level5_plus.rpt]]

run_route_report "04" "hierarchical utilization" \
    [list report_utilization \
        -hierarchical \
        -hierarchical_depth 8 \
        -file [file join $rpt_dir 04_utilization_hierarchical.rpt]]

run_route_report "05" "post-route DRC" \
    [list report_drc \
        -file [file join $rpt_dir 05_postroute_drc.rpt]]

run_route_report "06" "methodology" \
    [list report_methodology \
        -verbose \
        -file [file join $rpt_dir 06_methodology.rpt]]

# Rent exponent and average fanout help distinguish a local routing hot spot
# from structurally high interconnect complexity.
run_route_report "07" "hierarchical design complexity" \
    [list report_design_analysis \
        -complexity \
        -hierarchical_depth 8 \
        -file [file join $rpt_dir 07_design_complexity_hierarchical.rpt]]

# Timing and load-type information is useful when a congestion window is caused
# by a high-fanout control signal rather than only by LUTRAM/DSP placement.
run_route_report "08" "high-fanout nets" \
    [list report_high_fanout_nets \
        -timing \
        -load_types \
        -max_nets 200 \
        -fanout_greater_than 64 \
        -file [file join $rpt_dir 08_high_fanout_nets.rpt]]

# =============================================================================
# 2. Route problem net extraction
# =============================================================================

set route_types {
    UNROUTED
    PARTIAL
    GAPS
    CONFLICTS
    ANTENNAS
    NODRIVER
    MULTI_DRIVER
    LOCKED_NODES
}

set summary_file [file join $rpt_dir 09_problem_net_summary.rpt]
set summary_fp [open $summary_file w]

puts $summary_fp "=============================================="
puts $summary_fp "ROUTE PROBLEM NET SUMMARY"
puts $summary_fp "=============================================="

foreach route_type $route_types {
    puts ""
    puts "Checking route type: $route_type"

    set route_type_lower [string tolower $route_type]
    set list_file [file join $rpt_dir \
        "10_${route_type_lower}_net_list.rpt"]
    set list_fp [open $list_file w]

    puts $list_fp "ROUTE TYPE : $route_type"
    puts $list_fp "=============================================="

    set query_failed [catch {
        report_route_status \
            -return_nets \
            -route_type $route_type
    } problem_nets]

    if {$query_failed} {
        puts $summary_fp [format "%-20s : NOT SUPPORTED OR ERROR" $route_type]

        puts $list_fp "RESULT     : NOT SUPPORTED OR ERROR"
        puts $list_fp "REASON     : $problem_nets"
        close $list_fp

        puts $route_status_fp "FAILED: route_type $route_type"
        puts $route_status_fp "REASON: $problem_nets"
        puts $route_status_fp ""
        flush $route_status_fp

        incr route_fail_count
        continue
    }

    set problem_count [llength $problem_nets]

    puts $summary_fp [format "%-20s : %d" $route_type $problem_count]

    puts $list_fp "NET COUNT  : $problem_count"
    puts $list_fp "=============================================="

    foreach problem_net $problem_nets {
        puts $list_fp [get_property NAME $problem_net]
    }

    close $list_fp

    puts $route_status_fp "DONE: route_type $route_type"
    puts $route_status_fp "NET COUNT: $problem_count"
    puts $route_status_fp ""
    flush $route_status_fp

    incr route_pass_count

    # Prevent excessively large reports. Record detailed routing information
    # for at most the first 200 nets of each problem type.
    if {$problem_count > 0} {
        set detail_nets [lrange $problem_nets 0 199]

        run_route_report \
            "11_${route_type_lower}" \
            "$route_type route detail, first 200 nets" \
            [list report_route_status \
                -of_objects $detail_nets \
                -file [file join $rpt_dir \
                    "11_${route_type_lower}_route_detail.rpt"]]
    }
}

close $summary_fp

# =============================================================================
# 3. Route completion Boolean checks
# =============================================================================

set boolean_file [file join $rpt_dir 12_route_boolean_check.rpt]
set boolean_fp [open $boolean_file w]

puts $boolean_fp "=============================================="
puts $boolean_fp "ROUTE BOOLEAN CHECK"
puts $boolean_fp "=============================================="

foreach route_check {
    PLACED_FULLY
    PARTIALLY_ROUTED
    ROUTED_FULLY
    ERRORS_IN_ROUTES
} {
    set boolean_failed [catch {
        report_route_status -boolean_check $route_check
    } route_result]

    if {$boolean_failed} {
        puts $boolean_fp "$route_check : NOT SUPPORTED OR ERROR"
        puts $boolean_fp "REASON: $route_result"

        puts $route_status_fp "FAILED: boolean_check $route_check"
        puts $route_status_fp "REASON: $route_result"
        puts $route_status_fp ""
        flush $route_status_fp

        incr route_fail_count
    }

    if {!$boolean_failed} {
        puts $boolean_fp "$route_check : $route_result"

        puts $route_status_fp "DONE: boolean_check $route_check"
        puts $route_status_fp "RESULT: $route_result"
        puts $route_status_fp ""
        flush $route_status_fp

        incr route_pass_count
    }
}

close $boolean_fp


# =============================================================================
# 4. Create upload manifest and combined route-analysis bundle
# =============================================================================

set upload_manifest_path [file join $rpt_dir 97_UPLOAD_MANIFEST.txt]
set upload_manifest_fp [open $upload_manifest_path w]

puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp "ROUTE / CONGESTION DEBUG UPLOAD MANIFEST"
puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEST OPTION:"
puts $upload_manifest_fp "  Upload the entire route_congestion_check directory as one ZIP file."
puts $upload_manifest_fp ""
puts $upload_manifest_fp "MINIMUM FILES:"
puts $upload_manifest_fp "  1. 98_ROUTE_ANALYSIS_BUNDLE.rpt"
puts $upload_manifest_fp "  2. 99_report_generation_status.log"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "WHEN PROBLEM NETS EXIST:"
puts $upload_manifest_fp "  Also inspect 10_*_net_list.rpt and 11_*_route_detail.rpt."
puts $upload_manifest_fp ""
puts $upload_manifest_fp "PRIMARY INTERPRETATION ORDER:"
puts $upload_manifest_fp "  A. Full route status and route Boolean checks"
puts $upload_manifest_fp "  B. Congestion level >=3 and >=5"
puts $upload_manifest_fp "  C. Hierarchical utilization and complexity"
puts $upload_manifest_fp "  D. DRC / methodology"
puts $upload_manifest_fp "  E. High-fanout nets and explicit problem-net classes"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEFORE/AFTER COMPARISON RULE:"
puts $upload_manifest_fp "  Compare the same device, clock constraints, implementation stage, and"
puts $upload_manifest_fp "  routing-analysis settings."
puts $upload_manifest_fp "============================================================================="
close $upload_manifest_fp

set bundle_path [file join $rpt_dir 98_ROUTE_ANALYSIS_BUNDLE.rpt]
set bundle_fp [open $bundle_path w]

puts $bundle_fp "============================================================================="
puts $bundle_fp "VIVADO ROUTE / CONGESTION ANALYSIS BUNDLE"
puts $bundle_fp "Generated by vivado_route_congestion_audit.tcl"
puts $bundle_fp "Generated time: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $bundle_fp "IMPLEMENTATION RUN: $IMPL_RUN_NAME"
puts $bundle_fp "============================================================================="

foreach {title filename} {
    "01 FULL ROUTE STATUS"              "01_route_status_full.rpt"
    "02 CONGESTION LEVEL 3+"            "02_congestion_level3_plus.rpt"
    "03 CONGESTION LEVEL 5+"            "03_congestion_level5_plus.rpt"
    "04 HIERARCHICAL UTILIZATION"       "04_utilization_hierarchical.rpt"
    "05 POST-ROUTE DRC"                 "05_postroute_drc.rpt"
    "06 METHODOLOGY"                    "06_methodology.rpt"
    "07 DESIGN COMPLEXITY"              "07_design_complexity_hierarchical.rpt"
    "08 HIGH-FANOUT NETS"               "08_high_fanout_nets.rpt"
    "09 PROBLEM NET SUMMARY"            "09_problem_net_summary.rpt"
    "12 ROUTE BOOLEAN CHECK"            "12_route_boolean_check.rpt"
    "97 UPLOAD MANIFEST"                "97_UPLOAD_MANIFEST.txt"
} {
    append_text_file $bundle_fp $title [file join $rpt_dir $filename]
}

close $bundle_fp

puts $route_status_fp "DONE: 97 upload manifest"
puts $route_status_fp "OUTPUT: $upload_manifest_path"
puts $route_status_fp ""
puts $route_status_fp "DONE: 98 combined route analysis bundle"
puts $route_status_fp "OUTPUT: $bundle_path"
puts $route_status_fp ""
flush $route_status_fp

incr route_pass_count 2

# =============================================================================
# 5. Final status
# =============================================================================

puts $route_status_fp "============================================================================="
puts $route_status_fp "REPORT GENERATION COMPLETE"
puts $route_status_fp "PASS: $route_pass_count"
puts $route_status_fp "FAIL: $route_fail_count"
puts $route_status_fp "OPENED DESIGN: [current_design]"
puts $route_status_fp "IMPLEMENTATION STATUS: $impl_status"
puts $route_status_fp "OUTPUT: $rpt_dir"
puts $route_status_fp "============================================================================="

close $route_status_fp

puts ""
puts "============================================================================="
puts "REPORT GENERATION COMPLETE"
puts "PASS: $route_pass_count"
puts "FAIL: $route_fail_count"
puts "OPENED DESIGN: [current_design]"
puts "IMPLEMENTATION STATUS: $impl_status"
puts "REPORT DIRECTORY:"
puts "  $rpt_dir"
puts "MAIN FILE TO UPLOAD:"
puts "  $bundle_path"
puts "STATUS LOG:"
puts "  $route_status_path"
puts "============================================================================="
