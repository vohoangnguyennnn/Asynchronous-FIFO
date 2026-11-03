# Async FIFO CDC constraints for Intel Quartus TimeQuest.
#
# Scope:
#   - Module-level educational/reference flow; no board I/O constraints.
#   - Default periods match verification/async_fifo_tb.sv.
#   - Override WR_CLK_PERIOD_NS, RD_CLK_PERIOD_NS, or CDC_MARGIN before
#     read_sdc when integrating this FIFO into another design.
#
# This file intentionally uses the TimeQuest extensions set_net_delay and
# set_max_skew. Do not add a broad set_clock_groups or set_false_path exception
# between clk_wr and clk_rd: those cuts take precedence over max-skew analysis
# in supported Quartus Standard device flows and can silently disable the
# physical requirement that preserves Gray-code coherency. Instead, targeted
# max/min delay exceptions below define the asynchronous CDC paths.

if {![info exists WR_CLK_PERIOD_NS]} {
  set WR_CLK_PERIOD_NS 10.000
}
if {![info exists RD_CLK_PERIOD_NS]} {
  set RD_CLK_PERIOD_NS 14.000
}
if {![info exists CDC_MARGIN]} {
  set CDC_MARGIN 0.800
}

if {$WR_CLK_PERIOD_NS <= 0.0 || $RD_CLK_PERIOD_NS <= 0.0} {
  error "async_fifo.sdc: clock periods must be positive"
}
if {$CDC_MARGIN <= 0.0 || $CDC_MARGIN > 1.0} {
  error "async_fifo.sdc: CDC_MARGIN must be in the range (0.0, 1.0]"
}

set clk_wr_port [get_ports -nowarn {clk_wr}]
set clk_rd_port [get_ports -nowarn {clk_rd}]
set arst_n_port [get_ports -nowarn {arst_n}]

if {[get_collection_size $clk_wr_port] != 1} {
  error "async_fifo.sdc: expected exactly one clk_wr port"
}
if {[get_collection_size $clk_rd_port] != 1} {
  error "async_fifo.sdc: expected exactly one clk_rd port"
}
if {[get_collection_size $arst_n_port] != 1} {
  error "async_fifo.sdc: expected exactly one arst_n port"
}

create_clock -name clk_wr -period $WR_CLK_PERIOD_NS $clk_wr_port
create_clock -name clk_rd -period $RD_CLK_PERIOD_NS $clk_rd_port
derive_clock_uncertainty

# arst_n drives only the asynchronous clear pins of the reset synchronizers.
# No blanket reset false path is added: the locally synchronized reset outputs
# and their recovery/removal paths must remain visible to TimeQuest.

# Post-synthesis register collections. Two patterns cover async_fifo as the
# timing top-level or instantiated below one or more wrapper hierarchies.
set wr_gray_lower [get_registers -nowarn -no_duplicates {
  wr_counter|gray_ptr[*]
  *|wr_counter|gray_ptr[*]
}]
set wr_gray_meta [get_registers -nowarn -no_duplicates {
  sync_wr_to_rd|ff1[*]
  *|sync_wr_to_rd|ff1[*]
}]
set rd_gray_lower [get_registers -nowarn -no_duplicates {
  rd_counter|gray_ptr[*]
  *|rd_counter|gray_ptr[*]
}]
set rd_gray_meta [get_registers -nowarn -no_duplicates {
  sync_rd_to_wr|ff1[*]
  *|sync_rd_to_wr|ff1[*]
}]

# Binary-to-Gray conversion makes gray_ptr[MSB] identical to bin_ptr[MSB].
# Quartus may legally merge those two registers and retain only the bin_ptr
# keeper name. Recover that physical launch register when exactly one Gray bit
# is absent after synthesis.
proc recover_gray_source_bus {label counter_instance gray_collection meta_collection} {
  set gray_count [get_collection_size $gray_collection]
  set meta_count [get_collection_size $meta_collection]

  if {$gray_count == $meta_count} {
    return $gray_collection
  }
  if {$gray_count != ($meta_count - 1)} {
    error "async_fifo.sdc: $label cannot recover Gray source bus ($gray_count vs $meta_count)"
  }

  set msb_index [expr {$meta_count - 1}]
  set msb_patterns [list \
    [format {%s|bin_ptr[%d]} $counter_instance $msb_index] \
    [format {*|%s|bin_ptr[%d]} $counter_instance $msb_index]]
  set merged_msb [get_registers -nowarn -no_duplicates $msb_patterns]

  if {[get_collection_size $merged_msb] != 1} {
    error "async_fifo.sdc: $label failed to match the merged Gray/binary MSB"
  }

  return [add_to_collection $gray_collection $merged_msb]
}

set wr_gray_src [recover_gray_source_bus \
  "write-to-read" "wr_counter" $wr_gray_lower $wr_gray_meta]
set rd_gray_src [recover_gray_source_bus \
  "read-to-write" "rd_counter" $rd_gray_lower $rd_gray_meta]

proc require_matching_cdc_bus {label source_collection meta_collection} {
  set source_count [get_collection_size $source_collection]
  set meta_count [get_collection_size $meta_collection]

  if {$source_count < 2} {
    error "async_fifo.sdc: $label source collection matched fewer than 2 registers"
  }
  if {$meta_count != $source_count} {
    error "async_fifo.sdc: $label source/meta widths differ ($source_count vs $meta_count)"
  }

  puts "INFO: async_fifo.sdc: $label constrained as a $source_count-bit Gray CDC bus"
}

require_matching_cdc_bus "write-to-read" $wr_gray_src $wr_gray_meta
require_matching_cdc_bus "read-to-write" $rd_gray_src $rd_gray_meta

# clk_wr and clk_rd are unrelated. Targeted max/min exceptions replace the
# fictitious inter-clock setup/hold relationship with explicit CDC budgets.
# set_net_delay below separately limits the physical data-route delay. This
# FIFO has no other register-to-register crossings between the two domains.
# At module level rd_data is an output port. When this FIFO is integrated, the
# path from the memory array to any clk_rd register that captures rd_data is a
# CDC that is safe by protocol (the entry is stable for at least two clk_rd edges
# before empty falls) and must be constrained by the integrator.
set WR_TO_RD_MAX_DELAY_NS [expr {$RD_CLK_PERIOD_NS * $CDC_MARGIN}]
set RD_TO_WR_MAX_DELAY_NS [expr {$WR_CLK_PERIOD_NS * $CDC_MARGIN}]

set_max_delay -from $wr_gray_src -to $wr_gray_meta \
  $WR_TO_RD_MAX_DELAY_NS
set_min_delay -from $wr_gray_src -to $wr_gray_meta 0.000

set_max_delay -from $rd_gray_src -to $rd_gray_meta \
  $RD_TO_WR_MAX_DELAY_NS
set_min_delay -from $rd_gray_src -to $rd_gray_meta 0.000

# Bound every Gray-bit net to the first synchronizer stage. Net delay uses the
# destination clock period to limit CDC latency, matching Intel's dual-clock
# FIFO guidance. The second synchronizer stage remains normally timed by its
# local destination clock and must not be false-pathed.
set_net_delay -from $wr_gray_src -to $wr_gray_meta -max \
  -get_value_from_clock_period dst_clock_period \
  -value_multiplier $CDC_MARGIN
set_net_delay -from $rd_gray_src -to $rd_gray_meta -max \
  -get_value_from_clock_period dst_clock_period \
  -value_multiplier $CDC_MARGIN

# Bound inter-bit arrival skew to a fraction of the source clock period. This is
# the physical requirement that prevents routed Gray bits from different source
# updates being observed as one incoherent bus value.
set WR_GRAY_MAX_SKEW_NS [expr {$WR_CLK_PERIOD_NS * $CDC_MARGIN}]
set RD_GRAY_MAX_SKEW_NS [expr {$RD_CLK_PERIOD_NS * $CDC_MARGIN}]
set_max_skew -from $wr_gray_src -to $wr_gray_meta $WR_GRAY_MAX_SKEW_NS
set_max_skew -from $rd_gray_src -to $rd_gray_meta $RD_GRAY_MAX_SKEW_NS

# Integration sign-off checklist (run after synthesis/fitting):
#   report_clocks
#   report_exceptions
#   report_clock_transfers
#   report_timing -from <Gray source bus> -to <first synchronizer stage>
#   report_max_skew
#   report_net_delay
#   report_metastability
#   report_unconstrained_paths
# External input/output delays are intentionally absent because this repository
# does not define a board, package, or upstream/downstream interface budget.
