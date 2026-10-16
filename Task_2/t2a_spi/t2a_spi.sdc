# --------------------------------------------------------------------------
# t2a_spi.sdc : Timing constraints for the t2a_spi SPI master
#
# The board drives clk_50MHz at 50 MHz (20 ns period).  Without this file
# Quartus finds no user clock and silently falls back to
#    "derive_clocks -period 1.0"
# i.e. it times the design as if the clock ran at 1000 MHz, which is why
# every corner reported a large negative setup slack and a negative
# minimum-pulse-width slack.
# --------------------------------------------------------------------------

create_clock -name clk_50MHz -period 20.000 -waveform {0.000 10.000} [get_ports {clk_50MHz}]

# The reset is asynchronous and has no synchroniser in this design.
set_false_path -from [get_ports {rst_n}]

# Derive per-clock setup/hold uncertainty for the constrained clock.
derive_clock_uncertainty
