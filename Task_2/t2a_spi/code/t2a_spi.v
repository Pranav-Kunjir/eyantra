/*
eYRC26-27: Logic Quest
Task 2A: SPI Master Module
Description : Parameterizable SPI master controller supporting all 4 SPI
              modes (via CPOL/CPHA), configurable bit order (MSB/LSB
              first), and configurable word length. Derives SCLK by
              dividing down the 50MHz input clock (HALF_PERIOD sets the
              divide ratio). On `start`, shifts tx_data out on MOSI while
              simultaneously shifting MISO into rx_data; `busy` is high
              for the duration and `cs_out` is driven low for the transfer.
Parameters:
  CPOL             - Clock polarity (0: idle low, 1: idle high)        [default: 0]
  CPHA             - Clock phase (0: sample leading edge,
                      1: sample trailing edge)                        [default: 0]
  LSB_FIRST        - Bit order (0: MSB first, 1: LSB first)           [default: 0]
  SPI_WORD_LENGTH  - Number of bits per transfer                      [default: 8]
  HALF_PERIOD      - clk_50MHz cycles per SCLK half-period.
                      SCLK freq = 50MHz / (2 x HALF_PERIOD)           [default: 25 -> 1MHz]
Ports:
  clk_50MHz    (in )  1 bit               - System clock (50MHz)
  rst_n        (in )  1 bit               - Active-low async reset
  start        (in )  1 bit               - Pulse high (sampled in IDLE) to begin transfer
  tx_data      (in )  SPI_WORD_LENGTH     - Data word to transmit on MOSI
  miso_input   (in )  1 bit               - Serial data in from SPI slave
  sclk_out     (out)  1 bit               - SPI serial clock, idles at CPOL
  cs_out       (out)  1 bit               - Chip select, active-low during transfer
  mosi_output  (out)  1 bit               - Serial data out to SPI slave
  rx_data      (out)  SPI_WORD_LENGTH     - Data received from MISO (valid once busy=0)
  busy         (out)  1 bit               - High for the duration of an active transfer
*/

module t2a_spi
#(
    parameter CPOL             = 1'b0,
    parameter CPHA             = 1'b0,
    parameter LSB_FIRST        = 1'b0,
    parameter SPI_WORD_LENGTH  = 8,
    parameter HALF_PERIOD      = 25   // clk_50MHz cycles per half sclk period
)
(
    input wire clk_50MHz,
    input wire rst_n,

    input wire start,
    input wire [SPI_WORD_LENGTH-1:0] tx_data,
    input wire miso_input,

    output reg sclk_out,
    output reg cs_out,
    output reg mosi_output,

    output reg [SPI_WORD_LENGTH-1:0] rx_data,
    output reg busy
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

    // ------------------------------------------------------------------
    // Width / constant sizing, all derived from the parameters.
    //   * BIT_W is forced to at least 1 so SPI_WORD_LENGTH == 1 does not
    //     create a zero-width bit_cnt.
    //   * PHASE_MOD is deliberately kept 32 bits wide and the needed bits
    //     are then taken with an exact-width part-select.  This keeps the
    //     constant math from being reported as a value truncation.
    // ------------------------------------------------------------------
    localparam integer PHASE_W = (HALF_PERIOD < 1) ? 1 : $clog2(2 * HALF_PERIOD);
    localparam integer BIT_W   = (SPI_WORD_LENGTH <= 1) ? 1 : $clog2(SPI_WORD_LENGTH);

    localparam [31:0]        PHASE_MOD  = 2 * HALF_PERIOD;
    localparam [PHASE_W-1:0] PHASE_ZERO = {PHASE_W{1'b0}};
    localparam [PHASE_W-1:0] PHASE_MAX  = PHASE_MOD[PHASE_W-1:0] - 1'b1;
    localparam [PHASE_W-1:0] PHASE_RISE = PHASE_MOD[PHASE_W:1];

    // Last bit index in an exact BIT_W-bit field (BIT_W >= 1 always).
    localparam [31:0]        BIT_LAST_32 = SPI_WORD_LENGTH - 1;
    localparam [BIT_W-1:0]   BIT_LAST    = BIT_LAST_32[BIT_W-1:0];

    // One-bit views of the configuration parameters.  Parameters may be
    // overridden with wider integer values, and using a wide value directly
    // in a conditional test (or as ~CPOL) silently truncates/extends it, so
    // everything below works on these explicit 1-bit aliases.
    localparam CPOL_B      = CPOL[0];
    localparam CPHA_B      = CPHA[0];
    localparam LSB_FIRST_B = LSB_FIRST[0];

    localparam SCLK_IDLE   = CPOL_B ? 1'b1 : 1'b0;
    localparam SCLK_ACTIVE = CPOL_B ? 1'b0 : 1'b1;

    reg                       active;    // 0 = idle, 1 = transfer in progress
    reg [PHASE_W-1:0]         phase;     // counts 0 .. 2*HALF_PERIOD-1
    reg [BIT_W-1:0]           bit_cnt;   // bit index currently being handled
    reg [SPI_WORD_LENGTH-1:0] tx_shift;  // transmit shift register
    reg [SPI_WORD_LENGTH-1:0] rx_shift;  // receive shift register

    // Combinational next state of the receive shift register and both the
    // load and next state of the transmit shift register.  Both LSB_FIRST
    // and SPI_WORD_LENGTH are constants, so only the selected path is
    // elaborated: no operand is implicitly extended, no [WL-2:0] range is
    // needed, and a 1-bit word stays legal.  tx_shift is loaded pre-shifted,
    // so its first bit is always the next MOSI bit and every stored bit is
    // actually used.
    wire [SPI_WORD_LENGTH-1:0] tx_next;
    wire [SPI_WORD_LENGTH-1:0] tx_load;
    wire [SPI_WORD_LENGTH-1:0] rx_next;
    generate
        if (SPI_WORD_LENGTH > 1) begin : g_multibit
            if (LSB_FIRST_B) begin : g_lsb
                assign tx_load = {1'b0, tx_data[SPI_WORD_LENGTH-1:1]};
                assign tx_next = {1'b0, tx_shift[SPI_WORD_LENGTH-1:1]};
                assign rx_next = {miso_input, rx_shift[SPI_WORD_LENGTH-1:1]};
            end
            else begin : g_msb
                assign tx_load = {tx_data[SPI_WORD_LENGTH-2:0], 1'b0};
                assign tx_next = {tx_shift[SPI_WORD_LENGTH-2:0], 1'b0};
                assign rx_next = {rx_shift[SPI_WORD_LENGTH-2:0], miso_input};
            end
        end
        else begin : g_singlebit
            assign tx_load = tx_data;
            assign tx_next = tx_shift;
            assign rx_next = miso_input;
        end
    endgenerate

    // First bit presented on MOSI, and the next bit presented after a shift.
    wire mosi_first = LSB_FIRST_B ? tx_data[0] : tx_data[SPI_WORD_LENGTH-1];
    wire mosi_bit   = LSB_FIRST_B ? tx_shift[0] : tx_shift[SPI_WORD_LENGTH-1];

    // sclk_out is a register driven from the current phase count, so it
    // runs one cycle behind the counter (giving the H+1 first edge of
    // Table 3).  CPOL parks SCLK at the idle level and CPHA selects whether
    // data is sampled on the leading (0) or trailing (1) edge.  cs_out and
    // busy are always written together.
    always @(posedge clk_50MHz or negedge rst_n) begin
        if (!rst_n) begin
            active      <= 1'b0;
            cs_out      <= 1'b1;
            busy        <= 1'b0;
            sclk_out    <= SCLK_IDLE;
            mosi_output <= 1'b0;
            rx_data     <= {SPI_WORD_LENGTH{1'b0}};
            tx_shift    <= {SPI_WORD_LENGTH{1'b0}};
            rx_shift    <= {SPI_WORD_LENGTH{1'b0}};
            phase       <= PHASE_ZERO;
            bit_cnt     <= {BIT_W{1'b0}};
        end
        else if (!active) begin
            // --------- Idle: frame released, SCLK parked at CPOL ---------
            cs_out   <= 1'b1;
            busy     <= 1'b0;
            sclk_out <= SCLK_IDLE;
            phase    <= PHASE_ZERO;
            bit_cnt  <= {BIT_W{1'b0}};

            if (start) begin
                // ---- Cycle 0: cs/busy assert, capture data, 1st bit out ----
                active      <= 1'b1;
                cs_out      <= 1'b0;
                busy        <= 1'b1;
                sclk_out    <= SCLK_IDLE;
                tx_shift    <= tx_load;
                rx_shift    <= {SPI_WORD_LENGTH{1'b0}};
                mosi_output <= mosi_first;
                phase       <= PHASE_ZERO;
                bit_cnt     <= {BIT_W{1'b0}};
            end
        end
        else begin
            // ---------------------- Active transfer ----------------------
            if (phase == PHASE_MAX)
                phase <= PHASE_ZERO;
            else
                phase <= phase + 1'b1;

            if (phase == PHASE_RISE) begin
                // -------------------- Leading SCLK edge --------------------
                sclk_out <= SCLK_ACTIVE;
                if (CPHA_B) begin
                    // CPHA=1: MOSI changes on the leading edge; the very
                    // first bit was already presented when the frame began.
                    if (bit_cnt != {BIT_W{1'b0}}) begin
                        tx_shift    <= tx_next;
                        mosi_output <= mosi_bit;
                    end
                end
                else begin
                    // CPHA=0: MISO is sampled on the leading edge.
                    rx_shift <= rx_next;
                end
            end
            else if ((phase == PHASE_ZERO) && (sclk_out == SCLK_ACTIVE)) begin
                // -------------------- Trailing SCLK edge -------------------
                sclk_out <= SCLK_IDLE;
                if (bit_cnt == BIT_LAST) begin
                    // Last bit done: release the frame, publish the word.
                    active  <= 1'b0;
                    cs_out  <= 1'b1;
                    busy    <= 1'b0;
                    rx_data <= CPHA_B ? rx_next : rx_shift;
                end
                else begin
                    bit_cnt <= bit_cnt + 1'b1;
                    if (CPHA_B) begin
                        // CPHA=1: MISO is sampled on the trailing edge.
                        rx_shift <= rx_next;
                    end
                    else begin
                        // CPHA=0: MOSI advances on the trailing edge.
                        tx_shift    <= tx_next;
                        mosi_output <= mosi_bit;
                    end
                end
            end
        end
    end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule
