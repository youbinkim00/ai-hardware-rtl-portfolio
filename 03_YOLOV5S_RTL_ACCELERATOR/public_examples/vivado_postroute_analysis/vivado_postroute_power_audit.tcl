# =============================================================================
# Vivado post-route power audit report generator
# Vivado 2023.1 / configurable implementation run
#
# Purpose:
#   Generate a deterministic, assistant-friendly power-analysis package that
#   records not only Total/Dynamic/Static power, but also the exact design state,
#   clocks, operating conditions, switching-activity source, SAIF import result,
#   power-optimization result, utilization, and high-fanout context required to
#   explain why power changed after an RTL or implementation modification.
#
# Output directory:
#   <implementation-run DIRECTORY>/power_debug
#
# Main file to upload for analysis:
#   98_POWER_ANALYSIS_BUNDLE.rpt
#
# Also upload when available:
#   06_power_full_propagated.xml
#   09_saif_import.rpt                 (SAIF mode only)
#   99_report_generation_status.log
#
# Run from Vivado Tcl Console:
#   source vivado_postroute_power_audit.tcl
#
# NOTE:
#   - Any currently open design is closed.
#   - The script opens the latest available checkpoint in IMPL_RUN_NAME.
#   - A failed individual report does not stop the remaining reports.
#   - The script does not run power_opt_design or change the implemented netlist.
#   - Activity/operating-condition changes affect only the current open session.
# =============================================================================

# =============================================================================
# USER CONFIGURATION
# =============================================================================

# Name of the completed or in-progress Vivado implementation run to inspect.
# The script does not launch implementation; it opens the latest checkpoint
# available inside this run and records the exact run status in the reports.
set IMPL_RUN_NAME "impl_1"

# POWER_ACTIVITY_MODE:
#   IMPLEMENTED : Preserve activity contained in the opened implemented design.
#                 Undefined nodes are estimated by vectorless propagation.
#   SAIF        : Clear existing node activity, import SAIF_FILE, then propagate
#                 activity for unmatched/undefined nodes.
#   VECTORLESS  : Clear existing node activity and use clocks/defaults plus
#                 vectorless propagation only.
set POWER_ACTIVITY_MODE "IMPLEMENTED"

# Required only when POWER_ACTIVITY_MODE is SAIF.
# Example:
# set SAIF_FILE "C:/project/power/post_route.saif"
set SAIF_FILE ""

# Optional SAIF hierarchy prefix to remove while matching the implemented design.
# Do not begin with '/'. Leave empty when no strip path is needed.
# Example:
# set SAIF_STRIP_PATH "tb_top_Yolov5s/dut"
set SAIF_STRIP_PATH ""

# Optional operating-condition overrides.
# Empty string means preserve the operating condition stored in the design.
# POWER_PROCESS_OVERRIDE: "", "typical", or "maximum"
set POWER_PROCESS_OVERRIDE ""
set AMBIENT_TEMP_OVERRIDE ""
set AIRFLOW_OVERRIDE ""
set HEATSINK_OVERRIDE ""
set BOARD_OVERRIDE ""
set BOARD_LAYERS_OVERRIDE ""

# Text power-report depth/detail.
# Larger values improve hierarchy visibility but increase report size and time.
set POWER_HIER_DEPTH 12
set POWER_DETAIL_LINES 10000

# Hierarchical utilization depth used to correlate power with resource changes.
set UTIL_HIER_DEPTH 10

# High-fanout threshold and maximum number of reported nets.
set HIGH_FANOUT_THRESHOLD 64
set HIGH_FANOUT_MAX_NETS 300

# Generate a detailed switching-activity report for DSP/LUTRAM/BRAM control
# objects. This file can be large and is not included in the combined bundle.
set GENERATE_ACTIVITY_DETAIL 1

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
set out_dir [file join $impl_dir power_debug]

file mkdir $out_dir

set power_status_path [file join $out_dir 99_report_generation_status.log]
set power_status_fp [open $power_status_path w]

set power_pass_count 0
set power_fail_count 0
set generated_text_reports {}

# =============================================================================
# Helper procedures
# =============================================================================

proc run_power_report {report_id report_name command_list output_path} {
    global power_status_fp
    global power_pass_count
    global power_fail_count
    global generated_text_reports

    set title [format "%s  %s" $report_id $report_name]

    puts ""
    puts "============================================================================="
    puts "START: $title"
    puts "============================================================================="

    puts $power_status_fp "START: $title"
    flush $power_status_fp

    set report_failed [catch {uplevel #0 $command_list} report_result]

    if {$report_failed} {
        puts "FAILED: $title"
        puts "REASON: $report_result"

        puts $power_status_fp "FAILED: $title"
        puts $power_status_fp "REASON: $report_result"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_fail_count
        return 0
    }

    puts "DONE: $title"

    puts $power_status_fp "DONE: $title"
    if {$output_path ne ""} {
        puts $power_status_fp "OUTPUT: $output_path"
    }
    puts $power_status_fp ""
    flush $power_status_fp

    if {$output_path ne "" && [file exists $output_path]} {
        if {[string equal -nocase [file extension $output_path] ".rpt"] ||
            [string equal -nocase [file extension $output_path] ".txt"] ||
            [string equal -nocase [file extension $output_path] ".log"]} {
            lappend generated_text_reports $output_path
        }
    }

    incr power_pass_count
    return 1
}

proc safe_property {property object} {
    if {[llength $object] == 0} {
        return "<NO OBJECT>"
    }

    set failed [catch {get_property $property $object} value]
    if {$failed} {
        return "<UNAVAILABLE: $value>"
    }

    if {$value eq ""} {
        return "<EMPTY>"
    }

    return $value
}

proc safe_count {command_list} {
    set failed [catch {uplevel #0 $command_list} objects]

    if {$failed} {
        return "<UNAVAILABLE: $objects>"
    }

    return [llength $objects]
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

proc write_activity_section_header {fp title} {
    puts $fp ""
    puts $fp "============================================================================="
    puts $fp "$title"
    puts $fp "============================================================================="
}

# =============================================================================
# 1. Initial run information
# =============================================================================

puts "============================================================================="
puts "IMPLEMENTATION RUN INFORMATION"
puts "STATUS:"
puts "  $impl_status"
puts "DIRECTORY:"
puts "  $impl_dir"
puts "REPORT DIRECTORY:"
puts "  $out_dir"
puts "POWER ACTIVITY MODE:"
puts "  $POWER_ACTIVITY_MODE"
puts "============================================================================="

puts $power_status_fp "============================================================================="
puts $power_status_fp "IMPLEMENTATION RUN INFORMATION"
puts $power_status_fp "STATUS:"
puts $power_status_fp "  $impl_status"
puts $power_status_fp "DIRECTORY:"
puts $power_status_fp "  $impl_dir"
puts $power_status_fp "REPORT DIRECTORY:"
puts $power_status_fp "  $out_dir"
puts $power_status_fp "POWER ACTIVITY MODE:"
puts $power_status_fp "  $POWER_ACTIVITY_MODE"
puts $power_status_fp "============================================================================="
puts $power_status_fp ""
flush $power_status_fp

# Warn when the selected implementation run does not appear to have completed route_design.
# Continue because open_run can still open the latest available implementation
# checkpoint, and the route/timing reports will expose the exact design state.
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
    puts "  Power may be based on an incompletely routed or estimated design."
    puts ""

    puts $power_status_fp "WARNING:"
    puts $power_status_fp "  implementation-run STATUS does not explicitly show route_design Complete."
    puts $power_status_fp "  Power may be based on an incompletely routed or estimated design."
    puts $power_status_fp ""
    flush $power_status_fp
}

# Close any currently open synthesized, placed, routed, or old checkpoint design.
if {[llength [get_designs -quiet]] != 0} {
    puts "Closing currently open design:"
    puts "  [current_design]"

    puts $power_status_fp "Closing currently open design:"
    puts $power_status_fp "  [current_design]"
    flush $power_status_fp

    set close_failed [catch {close_design} close_result]

    if {$close_failed} {
        puts "FATAL ERROR: Failed to close current design."
        puts "REASON: $close_result"

        puts $power_status_fp "FATAL ERROR: Failed to close current design."
        puts $power_status_fp "REASON: $close_result"
        close $power_status_fp

        error "Failed to close current design: $close_result"
    }
}

puts ""
puts "Opening implementation run: $IMPL_RUN_NAME..."
puts $power_status_fp "Opening implementation run: $IMPL_RUN_NAME..."
flush $power_status_fp

set open_failed [catch {open_run $IMPL_RUN_NAME} open_result]

if {$open_failed} {
    puts "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts "REASON: $open_result"

    puts $power_status_fp "FATAL ERROR: Failed to open implementation run: $IMPL_RUN_NAME"
    puts $power_status_fp "REASON: $open_result"
    close $power_status_fp

    error "Failed to open implementation run $IMPL_RUN_NAME: $open_result"
}

puts "Opened design:"
puts "  [current_design]"

puts $power_status_fp "Opened design:"
puts $power_status_fp "  [current_design]"
puts $power_status_fp ""
flush $power_status_fp

# =============================================================================
# 2. Apply optional operating-condition overrides
# =============================================================================

set operating_cmd [list set_operating_conditions]
set operating_override_count 0

if {$POWER_PROCESS_OVERRIDE ne ""} {
    lappend operating_cmd -process $POWER_PROCESS_OVERRIDE
    incr operating_override_count
}

if {$AMBIENT_TEMP_OVERRIDE ne ""} {
    lappend operating_cmd -ambient_temp $AMBIENT_TEMP_OVERRIDE
    incr operating_override_count
}

if {$AIRFLOW_OVERRIDE ne ""} {
    lappend operating_cmd -airflow $AIRFLOW_OVERRIDE
    incr operating_override_count
}

if {$HEATSINK_OVERRIDE ne ""} {
    lappend operating_cmd -heatsink $HEATSINK_OVERRIDE
    incr operating_override_count
}

if {$BOARD_OVERRIDE ne ""} {
    lappend operating_cmd -board $BOARD_OVERRIDE
    incr operating_override_count
}

if {$BOARD_LAYERS_OVERRIDE ne ""} {
    lappend operating_cmd -board_layers $BOARD_LAYERS_OVERRIDE
    incr operating_override_count
}

if {$operating_override_count > 0} {
    set operating_failed [catch {uplevel #0 $operating_cmd} operating_result]

    if {$operating_failed} {
        puts "WARNING: Operating-condition override failed."
        puts "REASON: $operating_result"

        puts $power_status_fp "FAILED: operating-condition override"
        puts $power_status_fp "REASON: $operating_result"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_fail_count
    } else {
        puts $power_status_fp "DONE: operating-condition override"
        puts $power_status_fp "COMMAND: $operating_cmd"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_pass_count
    }
}

# =============================================================================
# 3. Configure switching activity
# =============================================================================

set activity_mode_upper [string toupper $POWER_ACTIVITY_MODE]
set saif_import_report [file join $out_dir 09_saif_import.rpt]
set activity_setup_note [file join $out_dir 09_activity_setup.rpt]
set activity_note_fp [open $activity_setup_note w]

puts $activity_note_fp "============================================================================="
puts $activity_note_fp "POWER ACTIVITY SETUP"
puts $activity_note_fp "============================================================================="
puts $activity_note_fp "MODE            : $activity_mode_upper"
puts $activity_note_fp "SAIF FILE       : $SAIF_FILE"
puts $activity_note_fp "SAIF STRIP PATH : $SAIF_STRIP_PATH"
puts $activity_note_fp ""

if {$activity_mode_upper eq "IMPLEMENTED"} {
    puts $activity_note_fp "ACTION:"
    puts $activity_note_fp "  Existing activity in the opened implemented design was preserved."
    puts $activity_note_fp "  Undefined activity will be estimated by report_power propagation."

    puts $power_status_fp "DONE: activity setup IMPLEMENTED"
    puts $power_status_fp ""
    flush $power_status_fp
    incr power_pass_count
} elseif {$activity_mode_upper eq "VECTORLESS"} {
    set reset_failed [catch {
        reset_switching_activity -all
        reset_switching_activity -default
    } reset_result]

    if {$reset_failed} {
        puts $activity_note_fp "RESULT: FAILED"
        puts $activity_note_fp "REASON: $reset_result"

        puts $power_status_fp "FAILED: activity setup VECTORLESS"
        puts $power_status_fp "REASON: $reset_result"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_fail_count
    } else {
        puts $activity_note_fp "ACTION:"
        puts $activity_note_fp "  Existing node/default switching activity was cleared."
        puts $activity_note_fp "  report_power will use clocks/defaults and vectorless propagation."

        puts $power_status_fp "DONE: activity setup VECTORLESS"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_pass_count
    }
} elseif {$activity_mode_upper eq "SAIF"} {
    if {$SAIF_FILE eq ""} {
        close $activity_note_fp
        close $power_status_fp
        error "POWER_ACTIVITY_MODE is SAIF, but SAIF_FILE is empty."
    }

    set saif_file_normalized [file normalize $SAIF_FILE]

    if {![file exists $saif_file_normalized]} {
        close $activity_note_fp
        close $power_status_fp
        error "SAIF file does not exist: $saif_file_normalized"
    }

    set reset_failed [catch {
        reset_switching_activity -all
        reset_switching_activity -default
    } reset_result]

    if {$reset_failed} {
        puts $activity_note_fp "RESET RESULT: FAILED"
        puts $activity_note_fp "RESET REASON: $reset_result"
    } else {
        puts $activity_note_fp "RESET RESULT: DONE"
    }

    set saif_cmd [list read_saif -out_file $saif_import_report]

    if {$SAIF_STRIP_PATH ne ""} {
        lappend saif_cmd -strip_path $SAIF_STRIP_PATH
    }

    lappend saif_cmd $saif_file_normalized

    set saif_failed [catch {uplevel #0 $saif_cmd} saif_result]

    if {$saif_failed} {
        puts $activity_note_fp "SAIF RESULT: FAILED"
        puts $activity_note_fp "SAIF REASON: $saif_result"
        puts $activity_note_fp "SAIF COMMAND: $saif_cmd"

        puts $power_status_fp "FAILED: SAIF import"
        puts $power_status_fp "REASON: $saif_result"
        puts $power_status_fp "COMMAND: $saif_cmd"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_fail_count
    } else {
        puts $activity_note_fp "SAIF RESULT: DONE"
        puts $activity_note_fp "SAIF COMMAND: $saif_cmd"
        puts $activity_note_fp "SAIF IMPORT REPORT: $saif_import_report"
        puts $activity_note_fp ""
        puts $activity_note_fp "IMPORTANT:"
        puts $activity_note_fp "  Review unmatched/matched hierarchy in 09_saif_import.rpt."
        puts $activity_note_fp "  Unmatched internal nodes are estimated by vectorless propagation."

        puts $power_status_fp "DONE: SAIF import"
        puts $power_status_fp "COMMAND: $saif_cmd"
        puts $power_status_fp "OUTPUT: $saif_import_report"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_pass_count
    }
} else {
    close $activity_note_fp
    close $power_status_fp
    error "Unsupported POWER_ACTIVITY_MODE: $POWER_ACTIVITY_MODE"
}

close $activity_note_fp
lappend generated_text_reports $activity_setup_note

# =============================================================================
# 4. Generate context report before power analysis
# =============================================================================

set context_path [file join $out_dir 00_power_analysis_context.rpt]
set context_fp [open $context_path w]

puts $context_fp "============================================================================="
puts $context_fp "VIVADO POWER ANALYSIS CONTEXT"
puts $context_fp "============================================================================="
puts $context_fp "GENERATED TIME               : [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $context_fp "VIVADO VERSION               : [version -short]"
puts $context_fp "CURRENT DESIGN               : [current_design]"
puts $context_fp "TOP                          : [safe_property TOP [current_design]]"
puts $context_fp "PART                         : [safe_property PART [current_design]]"
puts $context_fp "DESIGN MODE                  : [safe_property DESIGN_MODE [current_design]]"
puts $context_fp "IMPL RUN                     : [safe_property NAME $impl_run]"
puts $context_fp "IMPL STATUS                  : $impl_status"
puts $context_fp "IMPL STRATEGY                : [safe_property STRATEGY $impl_run]"
puts $context_fp "RUN NEEDS REFRESH            : [safe_property NEEDS_REFRESH $impl_run]"
puts $context_fp "POWER ACTIVITY MODE          : $activity_mode_upper"
puts $context_fp "SAIF FILE                    : $SAIF_FILE"
puts $context_fp "SAIF STRIP PATH              : $SAIF_STRIP_PATH"
puts $context_fp "PROCESS OVERRIDE             : $POWER_PROCESS_OVERRIDE"
puts $context_fp "AMBIENT TEMP OVERRIDE        : $AMBIENT_TEMP_OVERRIDE"
puts $context_fp "AIRFLOW OVERRIDE             : $AIRFLOW_OVERRIDE"
puts $context_fp "HEATSINK OVERRIDE            : $HEATSINK_OVERRIDE"
puts $context_fp "BOARD OVERRIDE               : $BOARD_OVERRIDE"
puts $context_fp "BOARD LAYERS OVERRIDE        : $BOARD_LAYERS_OVERRIDE"
puts $context_fp "POWER HIERARCHY DEPTH        : $POWER_HIER_DEPTH"
puts $context_fp "POWER DETAIL LINE LIMIT      : $POWER_DETAIL_LINES"
puts $context_fp "UTILIZATION HIERARCHY DEPTH  : $UTIL_HIER_DEPTH"
puts $context_fp "OUTPUT DIRECTORY             : $out_dir"
puts $context_fp ""
puts $context_fp "IMPLEMENTATION STEP SETTINGS"
puts $context_fp "----------------------------------------------"
puts $context_fp "POWER_OPT_DESIGN ENABLED     : [safe_property STEPS.POWER_OPT_DESIGN.IS_ENABLED $impl_run]"
puts $context_fp "PHYS_OPT_DESIGN ENABLED      : [safe_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED $impl_run]"
puts $context_fp "OPT_DESIGN DIRECTIVE         : [safe_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE $impl_run]"
puts $context_fp "PLACE_DESIGN DIRECTIVE       : [safe_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $impl_run]"
puts $context_fp "PHYS_OPT_DESIGN DIRECTIVE    : [safe_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE $impl_run]"
puts $context_fp "ROUTE_DESIGN DIRECTIVE       : [safe_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $impl_run]"
puts $context_fp ""
puts $context_fp "DESIGN OBJECT COUNTS"
puts $context_fp "----------------------------------------------"
puts $context_fp "CLOCKS                       : [safe_count [list get_clocks -quiet]]"
puts $context_fp "PORTS                        : [safe_count [list get_ports -quiet]]"
puts $context_fp "CELLS                        : [safe_count [list get_cells -hier -quiet]]"
puts $context_fp "NETS                         : [safe_count [list get_nets -hier -quiet]]"
puts $context_fp "DSP CELLS                    : [safe_count [list get_cells -hier -quiet -filter {PRIMITIVE_GROUP == DSP}]]"
puts $context_fp "BRAM CELLS                   : [safe_count [list get_cells -hier -quiet -filter {PRIMITIVE_GROUP == BRAM}]]"
puts $context_fp "LUTRAM CELLS                 : [safe_count [list get_cells -hier -quiet -filter {PRIMITIVE_SUBGROUP == LUTRAM}]]"
puts $context_fp "CLOCK-GATED CELLS            : [safe_count [list get_cells -hier -quiet -filter {IS_CLOCK_GATED == 1}]]"
puts $context_fp ""
puts $context_fp "CLOCK SUMMARY"
puts $context_fp "----------------------------------------------"
puts $context_fp [format "%-50s %-14s %-25s" "CLOCK" "PERIOD(ns)" "WAVEFORM(ns)"]

foreach clk [get_clocks -quiet] {
    set clk_name [safe_property NAME $clk]
    set clk_period [safe_property PERIOD $clk]
    set clk_waveform [safe_property WAVEFORM $clk]
    puts $context_fp [format "%-50s %-14s %-25s" $clk_name $clk_period $clk_waveform]
}

puts $context_fp ""
puts $context_fp "INTERPRETATION RULES"
puts $context_fp "----------------------------------------------"
puts $context_fp "1. Compare power only when part, implementation state, clocks, activity mode,"
puts $context_fp "   SAIF workload/window, operating conditions, and report settings are equal."
puts $context_fp "2. 06_power_full_propagated uses imported/user/clock activity and vectorless"
puts $context_fp "   propagation for undefined nodes."
puts $context_fp "3. 08_power_no_propagation disables vectorless propagation. A large difference"
puts $context_fp "   versus report 06 indicates that much of the estimate depends on unannotated"
puts $context_fp "   activity rather than direct SAIF/user activity."
puts $context_fp "4. Dynamic-power RTL optimization must be correlated with hierarchy power,"
puts $context_fp "   switching activity, clock power, high fanout, and utilization."
puts $context_fp "5. Static power changes can result from process/temperature/voltage and must not"
puts $context_fp "   be attributed to RTL without checking operating conditions."
puts $context_fp "============================================================================="

close $context_fp
lappend generated_text_reports $context_path
incr power_pass_count

puts $power_status_fp "DONE: 00 power analysis context"
puts $power_status_fp "OUTPUT: $context_path"
puts $power_status_fp ""
flush $power_status_fp

# =============================================================================
# 5. Generate reports
# =============================================================================

set environment_path [file join $out_dir 01_environment.rpt]
run_power_report "01" "Vivado environment" \
    [list report_environment \
        -file $environment_path] \
    $environment_path

set route_path [file join $out_dir 02_route_status.rpt]
run_power_report "02" "route status" \
    [list report_route_status \
        -ignore_cache \
        -show_all \
        -file $route_path] \
    $route_path

set timing_path [file join $out_dir 03_timing_summary.rpt]
run_power_report "03" "timing summary" \
    [list report_timing_summary \
        -delay_type min_max \
        -check_timing_verbose \
        -report_unconstrained \
        -max_paths 50 \
        -nworst 1 \
        -unique_pins \
        -path_type full_clock_expanded \
        -input_pins \
        -file $timing_path] \
    $timing_path

set clocks_path [file join $out_dir 04_clocks.rpt]
run_power_report "04" "clock definitions" \
    [list report_clocks \
        -file $clocks_path] \
    $clocks_path

set operating_path [file join $out_dir 05_operating_conditions.rpt]
run_power_report "05" "operating conditions" \
    [list report_operating_conditions \
        -file $operating_path] \
    $operating_path

# Main propagated power report. This is the primary human-readable report.
set power_full_path [file join $out_dir 06_power_full_propagated.rpt]
set power_full_rpx [file join $out_dir 06_power_full_propagated.rpx]
run_power_report "06" "full propagated power" \
    [list report_power \
        -hier all \
        -hierarchical_depth $POWER_HIER_DEPTH \
        -advisory \
        -l $POWER_DETAIL_LINES \
        -file $power_full_path \
        -rpx $power_full_rpx] \
    $power_full_path

# XML version is useful for exact machine parsing and before/after comparison.
set power_xml_path [file join $out_dir 06_power_full_propagated.xml]
run_power_report "06_XML" "full propagated power XML" \
    [list report_power \
        -hier all \
        -hierarchical_depth $POWER_HIER_DEPTH \
        -advisory \
        -l $POWER_DETAIL_LINES \
        -format xml \
        -file $power_xml_path] \
    $power_xml_path

# Logic-hierarchy presentation makes module-level RTL ownership easier to map.
set power_logic_path [file join $out_dir 07_power_logic_hierarchy.rpt]
run_power_report "07" "logic hierarchy power" \
    [list report_power \
        -hier logic \
        -hierarchical_depth $POWER_HIER_DEPTH \
        -l $POWER_DETAIL_LINES \
        -file $power_logic_path] \
    $power_logic_path

# No-propagation report shows the estimate supported directly by asserted/imported
# activity. Compare with report 06 to assess activity coverage and confidence.
set power_noprop_path [file join $out_dir 08_power_no_propagation.rpt]
run_power_report "08" "power without vectorless propagation" \
    [list report_power \
        -no_propagation \
        -hier all \
        -hierarchical_depth $POWER_HIER_DEPTH \
        -l $POWER_DETAIL_LINES \
        -file $power_noprop_path] \
    $power_noprop_path

# Primary-input activity is a critical vectorless/SAIF boundary condition.
set input_activity_path [file join $out_dir 10_switching_activity_inputs.rpt]
set input_ports [get_ports -quiet -filter {DIRECTION == IN}]

if {[llength $input_ports] > 0} {
    run_power_report "10" "primary-input switching activity" \
        [list report_switching_activity \
            -signal_rate \
            -toggle_rate \
            -static_probability \
            -default_toggle_rate \
            -default_static_probability \
            -file $input_activity_path \
            $input_ports] \
        $input_activity_path
} else {
    set input_fp [open $input_activity_path w]
    puts $input_fp "NO INPUT PORTS FOUND"
    close $input_fp
    lappend generated_text_reports $input_activity_path
}

# Average activity by logic type provides a compact activity-quality overview.
set activity_average_path [file join $out_dir 11_switching_activity_average_by_type.rpt]
set activity_average_fp [open $activity_average_path w]
puts $activity_average_fp "============================================================================="
puts $activity_average_fp "AVERAGE SWITCHING ACTIVITY BY TYPE"
puts $activity_average_fp "============================================================================="
close $activity_average_fp

set activity_types {
    io_output
    io_bidir_enable
    register
    lut
    lut_ram
    dsp
    bram_enable
    bram_wr_enable
}

foreach activity_type $activity_types {
    set section_fp [open $activity_average_path a]
    write_activity_section_header $section_fp "TYPE: $activity_type"
    close $section_fp

    set activity_cmd [list report_switching_activity \
        -signal_rate \
        -toggle_rate \
        -static_probability \
        -default_toggle_rate \
        -default_static_probability \
        -average \
        -type $activity_type \
        -all \
        -append \
        -file $activity_average_path]

    set activity_failed [catch {uplevel #0 $activity_cmd} activity_result]

    if {$activity_failed} {
        set section_fp [open $activity_average_path a]
        puts $section_fp "FAILED: $activity_result"
        close $section_fp

        puts $power_status_fp "FAILED: average activity type $activity_type"
        puts $power_status_fp "REASON: $activity_result"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_fail_count
    } else {
        puts $power_status_fp "DONE: average activity type $activity_type"
        puts $power_status_fp ""
        flush $power_status_fp

        incr power_pass_count
    }
}

lappend generated_text_reports $activity_average_path

# Detailed activity for power-dense resource/control types. Kept separate from
# the combined bundle because the file can be large.
set activity_detail_path [file join $out_dir 12_switching_activity_resource_detail.rpt]

if {$GENERATE_ACTIVITY_DETAIL} {
    set activity_detail_fp [open $activity_detail_path w]
    puts $activity_detail_fp "============================================================================="
    puts $activity_detail_fp "DETAILED SWITCHING ACTIVITY: DSP / LUTRAM / BRAM CONTROLS"
    puts $activity_detail_fp "============================================================================="
    close $activity_detail_fp

    foreach activity_type {dsp lut_ram bram_enable bram_wr_enable} {
        set detail_fp [open $activity_detail_path a]
        write_activity_section_header $detail_fp "TYPE: $activity_type"
        close $detail_fp

        set detail_cmd [list report_switching_activity \
            -signal_rate \
            -toggle_rate \
            -static_probability \
            -default_toggle_rate \
            -default_static_probability \
            -type $activity_type \
            -all \
            -append \
            -file $activity_detail_path]

        set detail_failed [catch {uplevel #0 $detail_cmd} detail_result]

        if {$detail_failed} {
            set detail_fp [open $activity_detail_path a]
            puts $detail_fp "FAILED: $detail_result"
            close $detail_fp

            puts $power_status_fp "FAILED: detailed activity type $activity_type"
            puts $power_status_fp "REASON: $detail_result"
            puts $power_status_fp ""
            flush $power_status_fp

            incr power_fail_count
        } else {
            puts $power_status_fp "DONE: detailed activity type $activity_type"
            puts $power_status_fp ""
            flush $power_status_fp

            incr power_pass_count
        }
    }
}

set power_opt_path [file join $out_dir 13_power_optimization.rpt]
run_power_report "13" "power optimization" \
    [list report_power_opt \
        -file $power_opt_path] \
    $power_opt_path

set power_opt_xml_path [file join $out_dir 13_power_optimization.xml]
run_power_report "13_XML" "power optimization XML" \
    [list report_power_opt \
        -format xml \
        -file $power_opt_xml_path] \
    $power_opt_xml_path

set utilization_path [file join $out_dir 14_utilization_hierarchical.rpt]
run_power_report "14" "hierarchical utilization" \
    [list report_utilization \
        -hierarchical \
        -hierarchical_depth $UTIL_HIER_DEPTH \
        -file $utilization_path] \
    $utilization_path

set clock_util_path [file join $out_dir 15_clock_utilization.rpt]
run_power_report "15" "clock utilization" \
    [list report_clock_utilization \
        -file $clock_util_path] \
    $clock_util_path

set high_fanout_path [file join $out_dir 16_high_fanout_power_context.rpt]
run_power_report "16" "high-fanout power context" \
    [list report_high_fanout_nets \
        -timing \
        -load_types \
        -max_nets $HIGH_FANOUT_MAX_NETS \
        -fanout_greater_than $HIGH_FANOUT_THRESHOLD \
        -file $high_fanout_path] \
    $high_fanout_path

set methodology_path [file join $out_dir 17_methodology.rpt]
run_power_report "17" "methodology" \
    [list report_methodology \
        -verbose \
        -file $methodology_path] \
    $methodology_path

set io_path [file join $out_dir 18_io_configuration.rpt]
run_power_report "18" "I/O configuration" \
    [list report_io \
        -file $io_path] \
    $io_path

set ram_path [file join $out_dir 19_ram_utilization.rpt]
run_power_report "19" "RAM utilization" \
    [list report_ram_utilization \
        -file $ram_path] \
    $ram_path

set control_sets_path [file join $out_dir 20_control_sets.rpt]
run_power_report "20" "control sets" \
    [list report_control_sets \
        -verbose \
        -file $control_sets_path] \
    $control_sets_path

# =============================================================================
# 6. Create upload manifest and one combined assistant-readable report
# =============================================================================

set upload_manifest_path [file join $out_dir 97_UPLOAD_MANIFEST.txt]
set upload_manifest_fp [open $upload_manifest_path w]

puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp "POWER DEBUG UPLOAD MANIFEST"
puts $upload_manifest_fp "============================================================================="
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEST OPTION:"
puts $upload_manifest_fp "  Upload the entire power_debug directory as one ZIP file."
puts $upload_manifest_fp ""
puts $upload_manifest_fp "MINIMUM FILES:"
puts $upload_manifest_fp "  1. 98_POWER_ANALYSIS_BUNDLE.rpt"
puts $upload_manifest_fp "  2. 06_power_full_propagated.xml"
puts $upload_manifest_fp "  3. 99_report_generation_status.log"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "SAIF MODE ADDITION:"
puts $upload_manifest_fp "  4. 09_saif_import.rpt"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "WHEN ACTIVITY QUALITY IS QUESTIONED:"
puts $upload_manifest_fp "  5. 12_switching_activity_resource_detail.rpt"
puts $upload_manifest_fp ""
puts $upload_manifest_fp "BEFORE/AFTER COMPARISON RULE:"
puts $upload_manifest_fp "  Keep each power_debug directory unchanged and label them BASELINE and NEW."
puts $upload_manifest_fp "  Do not compare reports generated with different SAIF workloads, clocks,"
puts $upload_manifest_fp "  process/temperature settings, device parts, or implementation states."
puts $upload_manifest_fp ""
puts $upload_manifest_fp "PRIMARY INTERPRETATION ORDER:"
puts $upload_manifest_fp "  A. Context / design state / clocks / operating conditions"
puts $upload_manifest_fp "  B. SAIF import and switching-activity quality"
puts $upload_manifest_fp "  C. Total, dynamic, and device-static power"
puts $upload_manifest_fp "  D. Power by block type and hierarchy"
puts $upload_manifest_fp "  E. Full-propagation versus no-propagation difference"
puts $upload_manifest_fp "  F. Power optimization, utilization, clocks, and high-fanout correlation"
puts $upload_manifest_fp "============================================================================="

close $upload_manifest_fp
lappend generated_text_reports $upload_manifest_path

set bundle_path [file join $out_dir 98_POWER_ANALYSIS_BUNDLE.rpt]
set bundle_fp [open $bundle_path w]

puts $bundle_fp "============================================================================="
puts $bundle_fp "VIVADO POWER ANALYSIS BUNDLE"
puts $bundle_fp "Generated by vivado_postroute_power_audit.tcl"
puts $bundle_fp "Generated time: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S %Z}]"
puts $bundle_fp "============================================================================="
puts $bundle_fp ""
puts $bundle_fp "This bundle is ordered so that power values are interpreted only after the"
puts $bundle_fp "design state, clocks, operating conditions, and switching-activity source are"
puts $bundle_fp "known. For exact XML parsing, also provide 06_power_full_propagated.xml."

append_text_file $bundle_fp "00 POWER ANALYSIS CONTEXT" $context_path
append_text_file $bundle_fp "02 ROUTE STATUS" $route_path
append_text_file $bundle_fp "03 TIMING SUMMARY" $timing_path
append_text_file $bundle_fp "04 CLOCK DEFINITIONS" $clocks_path
append_text_file $bundle_fp "05 OPERATING CONDITIONS" $operating_path
append_text_file $bundle_fp "09 ACTIVITY SETUP" $activity_setup_note

if {$activity_mode_upper eq "SAIF"} {
    append_text_file $bundle_fp "09 SAIF IMPORT / MATCH RESULT" $saif_import_report
}

append_text_file $bundle_fp "10 PRIMARY-INPUT SWITCHING ACTIVITY" $input_activity_path
append_text_file $bundle_fp "11 AVERAGE SWITCHING ACTIVITY BY TYPE" $activity_average_path
append_text_file $bundle_fp "06 FULL PROPAGATED POWER" $power_full_path
append_text_file $bundle_fp "07 LOGIC-HIERARCHY POWER" $power_logic_path
append_text_file $bundle_fp "08 POWER WITHOUT VECTORLESS PROPAGATION" $power_noprop_path
append_text_file $bundle_fp "13 POWER OPTIMIZATION" $power_opt_path
append_text_file $bundle_fp "14 HIERARCHICAL UTILIZATION" $utilization_path
append_text_file $bundle_fp "15 CLOCK UTILIZATION" $clock_util_path
append_text_file $bundle_fp "16 HIGH-FANOUT POWER CONTEXT" $high_fanout_path
append_text_file $bundle_fp "17 METHODOLOGY" $methodology_path
append_text_file $bundle_fp "18 I/O CONFIGURATION" $io_path
append_text_file $bundle_fp "19 RAM UTILIZATION" $ram_path
append_text_file $bundle_fp "20 CONTROL SETS" $control_sets_path
append_text_file $bundle_fp "97 UPLOAD MANIFEST" $upload_manifest_path

close $bundle_fp

puts $power_status_fp "DONE: 97 upload manifest"
puts $power_status_fp "OUTPUT: $upload_manifest_path"
puts $power_status_fp ""
puts $power_status_fp "DONE: 98 combined power analysis bundle"
puts $power_status_fp "OUTPUT: $bundle_path"
puts $power_status_fp ""
flush $power_status_fp

incr power_pass_count 2

# =============================================================================
# 7. Final status
# =============================================================================

puts $power_status_fp "============================================================================="
puts $power_status_fp "REPORT GENERATION COMPLETE"
puts $power_status_fp "PASS: $power_pass_count"
puts $power_status_fp "FAIL: $power_fail_count"
puts $power_status_fp "OPENED DESIGN: [current_design]"
puts $power_status_fp "IMPLEMENTATION STATUS: $impl_status"
puts $power_status_fp "ACTIVITY MODE: $activity_mode_upper"
puts $power_status_fp "OUTPUT: $out_dir"
puts $power_status_fp "MAIN BUNDLE: $bundle_path"
puts $power_status_fp "============================================================================="

close $power_status_fp

puts ""
puts "============================================================================="
puts "POWER REPORT GENERATION COMPLETE"
puts "PASS: $power_pass_count"
puts "FAIL: $power_fail_count"
puts "OPENED DESIGN: [current_design]"
puts "IMPLEMENTATION STATUS: $impl_status"
puts "ACTIVITY MODE: $activity_mode_upper"
puts "REPORT DIRECTORY:"
puts "  $out_dir"
puts "MAIN FILE TO UPLOAD:"
puts "  $bundle_path"
puts "XML POWER REPORT:"
puts "  $power_xml_path"
puts "STATUS LOG:"
puts "  $power_status_path"
puts "============================================================================="
