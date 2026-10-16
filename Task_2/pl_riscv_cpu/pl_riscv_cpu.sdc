# --------------------------------------------------------------------------
# pl_riscv_cpu.sdc : Timing constraints for the pipelined RISC-V processor
#
# Without this file Quartus finds no user clock and silently falls back to
#    "derive_clocks -period 1.0"
# i.e. it times the design as if the clock ran at 1000 MHz, which is why
# every corner reported a large negative setup slack and a negative
# minimum-pulse-width slack.
#
# The processor is constrained at 50 MHz (20 ns).  Its critical path is the
# execute -> PC loop (forwarded ALU result -> ALU -> JALR/branch target ->
# PCNext -> PC), which needs ~17.5 ns on the slow 1200mV/85C corner on this
# Cyclone IV device, so 50 MHz is the frequency this structure closes at.
# --------------------------------------------------------------------------

create_clock -name clk -period 20.000 -waveform {0.000 10.000} [get_ports {clk}]

# Derive per-clock setup/hold uncertainty for the constrained clock.
derive_clock_uncertainty
