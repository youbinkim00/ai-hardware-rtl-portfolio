# =============================================================================
# Vivado post-route timing audit report generator
# Vivado 2023.1 / configurable implementation run
#
# Output directory:
#   <implementation-run DIRECTORY>/timing_debug
#
# Generates:
#   00_route_status.rpt
#   01_methodology.rpt
#   02_check_timing_verbose.rpt
#   03_timing_summary.rpt
#   04_setup_violations_unique.rpt
#   05_hold_violations_unique.rpt
#   06_high_fanout_timing.rpt
#   07_high_fanout_regions.rpt
#   08_congestion.rpt
#   09_utilization_hier.rpt
#   10_qor_assessment.rpt
#   11_clock_interaction.rpt
#   12_cdc.rpt
#   13_design_analysis_timing.rpt
#   97_UPLOAD_MANIFEST.txt
#   98_TIMING_ANALYSIS_BUNDLE.rpt
#   99_report_generation_status.log
#
# Run from Vivado Tcl Console:
#   source vivado_postroute_timing_audit.tcl
#
# NOTE:
#   - Any currently open design is closed.
#   - The script opens the latest available checkpoint in IMPL_RUN_NAME.
#   - A failed individual report does not stop the remaining reports.
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
set out_dir [file join $impl_dir timing_debug]
set qor_csv_dir [file join $out_dir qor_csv]

file mkdir $out_dir
file mkdir $qor_csv_dir

set timing_status_path [file join $out_dir 99_report_generation_status.log]
set timing_status_fp [open $timing_status_path w]

set timing_pass_count 0
set timing_fail_count 0

proc run_timing_report {report_id report_name command_list} {
    global timing_status_fp
    global timing_pass_count
    global timing_fail_count

    set title [format "%s  %s" $report_id $report_name]

    puts ""
    puts "============================================================================="
    puts "START: $title"
    puts "============================================================================="

    puts $timing_status_fp "START: $title"
    flush $timing_status_fp

    set report_failed [catch {uplevel #0 $command_list} report_result]

    if {$report_failed} {
        puts "FAILED: $title"
        puts "REASON: $report_result"

        puts $timing_status_fp "FAILED: $title"
        puts $timing_status_fp "REASON: $report_result"
        puts $timing_status_fp ""
        flush $timing_status_fp

        incr timing_fail_count
        return 0
    }

    puts "DONE: $title"

    puts $timing_status_fp "DONE: $title"
    puts $timing_status_fp ""
    flush $timing_status_fp

    incr timing_pass_count
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
puts "  $out_dir"
puts "============================================================================="

puts $timing_status_fp "============================================================================="
puts $timing_status_fp "IMPLEMENTATION RUN INFORMATION"
puts $timing_status_fp "STATUS:"
puts $timing_status_fp "  $impl_status"
puts $timing_status_fp "DIRECTORY:"
puts $timing_status_fp "  $impl_dir"
puts $timing_status_fp "REPORT DIRECTORY:"
puts $timing_status_fp "  $out_dir"
puts $timing_status_fp "============================================================================="
puts $timing_status_fp ""
flush $timing_status_fp

# Warn when the selected implementation run does not appear to have completed route_design.
# Continue because open_run can still open the latest available implementation
# checkpoint and the status reports will show the exact design state.
set route_complete_string_found 0

if {[string first "route_design Complete" $impl_status] >= 0} {
    set route_complete_string_found 1
}

if {[string first "write_bitstream Complete" $impl_status] >= 0} {
    set route_complete_string_found 1
}

if {!$route_complete_string_found} {
    puts ""
    puts "WARNING:"
    puts "  implementation-run STATUS does not explicitly show route_design Complete."
    puts "  Timing reports may contain estimated rather than fully routed delays."
    puts ""

    puts $timing_status_fp "WARNING:"
    puts $timing_status_fp "  implementation-run STATUS does not explicitly show route_design Complete."
    puts $timing_status_fp "  Timing reports may contain estimated rather than fully routed delays."
    puts $timing_status_fp ""
    flush $timing_status_fp
}

# Close any currently open synthesized, placed, routed, or old checkpoint design.
if {[llength [get_designs -quiet]] != 0} {
    puts "Closing currently open design:"
    puts "  [current_design]"

    puts $timing_status_fp "Closing currently open design:"
    puts $timing_status_fp "  [current_design]"
    flush $timing_status_fp

    set close_failed [catch {close_design} close_result]

    if {$close_failed} {
        puts "FATAL ERROR: Failed to close current design."
        puts "REASON: $close_result"

        puts $timing_status_fp "FATAL ERROR: Failed to close current design."
        puts $timing_status_fp "REASON: $close_result"
        close $timing_status_fp

        error "Failed to close current design: $close_result"
    }
}

puts ""
puts "Opening implementation run: $IMPL_RUN_NAME..."
puts $timing_status_fp "Opening implementation run: $IMPL_RUN_NAME..."
flush $timing_status_fp

set open_failed [catch {open_run $IMPL_RUN_NAME} open_result]

if {$open_failed} {
    puts "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts "REASON: $open_result"

    puts $timing_status_fp "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts $timing_status_fp "REASON: $open_result"
    close $timing_status_fp

    error "Failed to open implementation run $IMPL_RUN_NAME: $open_result"
}

puts "Opened design:"
puts "  [current_design]"

puts $timing_status_fp "Opened design:"
puts $timing_status_fp "  [current_design]"
puts $timing_status_fp ""
flush $timing_status_fp

# =============================================================================
# 1. Generate reports
# =============================================================================

run_timing_report "00" "route status" \
    [list report_route_status \
        -ignore_cache \
        -show_all \
        -file [file join $out_dir 00_route_status.rpt]]

run_timing_report "01" "methodology" \
    [list report_methodology \
        -verbose \
        -file [file join $out_dir 01_methodology.rpt]]

# Run before CDC. This exposes no-clock, multiple-clock, unconstrained internal
# endpoint, incomplete input/output delay, and generated-clock problems.
run_timing_report "02" "check timing verbose" \
    [list check_timing \
        -verbose \
        -file [file join $out_dir 02_check_timing_verbose.rpt]]

run_timing_report "03" "timing summary" \
    [list report_timing_summary \
        -delay_type min_max \
        -check_timing_verbose \
        -report_unconstrained \
        -max_paths 50 \
        -nworst 1 \
        -unique_pins \
        -path_type full_clock_expanded \
        -input_pins \
        -file [file join $out_dir 03_timing_summary.rpt]]

run_timing_report "04" "setup violations" \
    [list report_timing \
        -setup \
        -slack_lesser_than 0 \
        -max_paths 2000 \
        -nworst 1 \
        -unique_pins \
        -sort_by slack \
        -path_type full_clock_expanded \
        -input_pins \
        -file [file join $out_dir 04_setup_violations_unique.rpt]]

run_timing_report "05" "hold violations" \
    [list report_timing \
        -hold \
        -slack_lesser_than 0 \
        -max_paths 1000 \
        -nworst 1 \
        -unique_pins \
        -sort_by slack \
        -path_type full_clock_expanded \
        -input_pins \
        -file [file join $out_dir 05_hold_violations_unique.rpt]]

run_timing_report "06" "high-fanout timing" \
    [list report_high_fanout_nets \
        -timing \
        -load_types \
        -max_nets 200 \
        -fanout_greater_than 64 \
        -file [file join $out_dir 06_high_fanout_timing.rpt]]

# load_types and clock_regions are intentionally separate because Vivado does
# not allow these two report_high_fanout_nets options in one command.
run_timing_report "07" "high-fanout clock regions" \
    [list report_high_fanout_nets \
        -clock_regions \
        -max_nets 200 \
        -fanout_greater_than 64 \
        -file [file join $out_dir 07_high_fanout_regions.rpt]]

run_timing_report "08" "congestion" \
    [list report_design_analysis \
        -congestion \
        -min_congestion_level 3 \
        -file [file join $out_dir 08_congestion.rpt]]

run_timing_report "09" "hierarchical utilization" \
    [list report_utilization \
        -hierarchical \
        -hierarchical_depth 8 \
        -file [file join $out_dir 09_utilization_hier.rpt]]

run_timing_report "10" "QoR assessment" \
    [list report_qor_assessment \
        -full_assessment_details \
        -max_paths 1000 \
        -file [file join $out_dir 10_qor_assessment.rpt] \
        -csv_output_dir $qor_csv_dir]

run_timing_report "11" "clock interaction" \
    [list report_clock_interaction \
        -file [file join $out_dir 11_clock_interaction.rpt]]

run_timing_report "12" "CDC" \
    [list report_cdc \
        -details \
        -file [file join $out_dir 12_cdc.rpt]]

# This complements report_timing by listing timing-path characteristics such as
# logic, physical, routing, and constraint-related properties.
run_timing_report "13" "design analysis timing" \
    [list report_design_analysis \
        -timing \
        -setup \
        -hold \
        -max_paths 100 \
        -show_all \
        -file [file join $out_dir 13_design_analysis_timing.rpt]]


# =============================================================================
# 2. Create upload manifest and combined timing-analysis bundle
# =============================================================================

set upload_manifest_path [file join $out_dir 97_UPLOAD_MANIFEST.txt]
set upload_manifest_fp [open $upload_manifest_path w]

puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp "TIMING DEBUG UPLOAD MANIFEST"
puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEST OPTION:"
puts $upload_manifest_fp "  Upload the entire timing_debug directory as one ZIP file."
puts $upload_manifest_fp ""
puts $upload_manifest_fp "MINIMUM FILES:"
puts $upload_manifest_fp "  1. 98_TIMING_ANALYSIS_BUNDLE.rpt"
puts $upload_manifest_fp "  2. 99_report_generation_status.log"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "WHEN THE WORST PATH NEEDS DEEPER REVIEW:"
puts $upload_manifest_fp "  3. 04_setup_violations_unique.rpt"
puts $upload_manifest_fp "  4. 05_hold_violations_unique.rpt"
puts $upload_manifest_fp "  5. 10_qor_assessment.rpt"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "PRIMARY INTERPRETATION ORDER:"
puts $upload_manifest_fp "  A. Route completion / methodology / check_timing"
puts $upload_manifest_fp "  B. WNS/TNS and setup/hold violations"
puts $upload_manifest_fp "  C. High-fanout and clock-region spread"
puts $upload_manifest_fp "  D. Congestion and hierarchical utilization"
puts $upload_manifest_fp "  E. QoR assessment, clock interaction, CDC, design analysis"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEFORE/AFTER COMPARISON RULE:"
puts $upload_manifest_fp "  Compare only reports generated from the same device, clock constraints,"
puts $upload_manifest_fp "  implementation stage, and analysis settings."
puts $upload_manifest_fp "============================================================================="
close $upload_manifest_fp

set bundle_path [file join $out_dir 98_TIMING_ANALYSIS_BUNDLE.rpt]
set bundle_fp [open $bundle_path w]

puts $bundle_fp "============================================================================="
puts $bundle_fp "VIVADO POST-ROUTE TIMING ANALYSIS BUNDLE"
puts $bundle_fp "Generated by vivado_postroute_timing_audit.tcl"
puts $bundle_fp "Generated time: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $bundle_fp "IMPLEMENTATION RUN: $IMPL_RUN_NAME"
puts $bundle_fp "============================================================================="

foreach {title filename} {
    "00 ROUTE STATUS"                  "00_route_status.rpt"
    "01 METHODOLOGY"                   "01_methodology.rpt"
    "02 CHECK TIMING VERBOSE"          "02_check_timing_verbose.rpt"
    "03 TIMING SUMMARY"                "03_timing_summary.rpt"
    "04 SETUP VIOLATIONS"              "04_setup_violations_unique.rpt"
    "05 HOLD VIOLATIONS"               "05_hold_violations_unique.rpt"
    "06 HIGH-FANOUT TIMING"            "06_high_fanout_timing.rpt"
    "07 HIGH-FANOUT CLOCK REGIONS"     "07_high_fanout_regions.rpt"
    "08 CONGESTION"                    "08_congestion.rpt"
    "09 HIERARCHICAL UTILIZATION"      "09_utilization_hier.rpt"
    "10 QOR ASSESSMENT"                "10_qor_assessment.rpt"
    "11 CLOCK INTERACTION"              "11_clock_interaction.rpt"
    "12 CDC"                            "12_cdc.rpt"
    "13 DESIGN ANALYSIS TIMING"         "13_design_analysis_timing.rpt"
    "97 UPLOAD MANIFEST"                "97_UPLOAD_MANIFEST.txt"
} {
    append_text_file $bundle_fp $title [file join $out_dir $filename]
}

close $bundle_fp

puts $timing_status_fp "DONE: 97 upload manifest"
puts $timing_status_fp "OUTPUT: $upload_manifest_path"
puts $timing_status_fp ""
puts $timing_status_fp "DONE: 98 combined timing analysis bundle"
puts $timing_status_fp "OUTPUT: $bundle_path"
puts $timing_status_fp ""
flush $timing_status_fp

incr timing_pass_count 2

# =============================================================================
# 3. Final status
# =============================================================================

puts $timing_status_fp "============================================================================="
puts $timing_status_fp "REPORT GENERATION COMPLETE"
puts $timing_status_fp "PASS: $timing_pass_count"
puts $timing_status_fp "FAIL: $timing_fail_count"
puts $timing_status_fp "OPENED DESIGN: [current_design]"
puts $timing_status_fp "IMPLEMENTATION STATUS: $impl_status"
puts $timing_status_fp "OUTPUT: $out_dir"
puts $timing_status_fp "============================================================================="

close $timing_status_fp

puts ""
puts "============================================================================="
puts "REPORT GENERATION COMPLETE"
puts "PASS: $timing_pass_count"
puts "FAIL: $timing_fail_count"
puts "OPENED DESIGN: [current_design]"
puts "IMPLEMENTATION STATUS: $impl_status"
puts "REPORT DIRECTORY:"
puts "  $out_dir"
puts "MAIN FILE TO UPLOAD:"
puts "  $bundle_path"
puts "STATUS LOG:"
puts "  $timing_status_path"
puts "============================================================================="
