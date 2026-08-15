# Reproducible Intel Quartus/TimeQuest reference flow for the asynchronous FIFO.
#
# Run from any directory:
#   quartus_sta -t scripts/run_sta.tcl
#
# Optional environment overrides:
#   ASYNC_FIFO_STA_FAMILY="Cyclone V"
#   ASYNC_FIFO_STA_DEVICE="5CEFA4F23C6"
#
# This is a module-level CDC/STA reference flow. The selected FPGA is an
# analysis vehicle only; no board pins or external I/O budgets are assigned.

package require ::quartus::project
package require ::quartus::sta

proc env_or_default {name default_value} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $default_value
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file dirname $script_dir]
set build_dir [file join $repo_root build quartus_sta]
set report_dir [file join $build_dir reports]
set project_name async_fifo_sta

set target_family [env_or_default ASYNC_FIFO_STA_FAMILY "Cyclone V"]
set target_device [env_or_default ASYNC_FIFO_STA_DEVICE "5CEFA4F23C6"]

set rtl_files [list \
  [file join $repo_root rtl reset_sync.sv] \
  [file join $repo_root rtl sync_2ff.sv] \
  [file join $repo_root rtl gray_counter.sv] \
  [file join $repo_root rtl async_fifo.sv]]
set sdc_file [file join $repo_root constraints async_fifo.sdc]

foreach source_file [concat $rtl_files [list $sdc_file]] {
  if {![file isfile $source_file]} {
    error "run_sta.tcl: required source file not found: $source_file"
  }
}

file mkdir $build_dir
file mkdir $report_dir
cd $build_dir

puts "INFO: run_sta.tcl: repository = $repo_root"
puts "INFO: run_sta.tcl: target     = $target_family / $target_device"
puts "INFO: run_sta.tcl: build      = $build_dir"

project_new -overwrite $project_name -revision $project_name
set_global_assignment -name FAMILY $target_family
set_global_assignment -name DEVICE $target_device
set_global_assignment -name TOP_LEVEL_ENTITY async_fifo
set_global_assignment -name NUM_PARALLEL_PROCESSORS 4
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files

foreach rtl_file $rtl_files {
  set_global_assignment -name SYSTEMVERILOG_FILE $rtl_file
}
set_global_assignment -name SDC_FILE $sdc_file
export_assignments
project_close

set quartus_bin_dir [file dirname [file normalize [info nameofexecutable]]]
set quartus_sh [file join $quartus_bin_dir quartus_sh]
if {![file executable $quartus_sh]} {
  error "run_sta.tcl: quartus_sh not found next to quartus_sta: $quartus_sh"
}

if {[catch {exec $quartus_sh --flow compile $project_name 2>@1} compile_result]} {
  puts $compile_result
  error "run_sta.tcl: Quartus compilation failed"
}
puts $compile_result

project_open $project_name -revision $project_name
create_timing_netlist
read_sdc
update_timing_netlist

report_clocks \
  -file [file join $report_dir clocks.rpt]
report_clock_transfers \
  -file [file join $report_dir clock_transfers.rpt]
report_exceptions \
  -file [file join $report_dir exceptions.rpt]
report_max_skew -npaths 50 -detail path_only \
  -file [file join $report_dir max_skew.rpt]
report_net_delay -nworst 50 \
  -file [file join $report_dir net_delay.rpt]
report_metastability -nchains 100 \
  -file [file join $report_dir metastability.rpt]
report_ucp -summary \
  -file [file join $report_dir unconstrained_paths.rpt]

delete_timing_netlist
project_close

puts "INFO: run_sta.tcl: CDC/STA flow completed successfully"
puts "INFO: run_sta.tcl: reports written to $report_dir"
