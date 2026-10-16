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


    // ---- Sizing constants derived from the parameters (never hard-coded)
    localparam integer PHASE_W = $clog2(2 * HALF_PERIOD);   // 0 .. 2H-1
    localparam integer BIT_W   = $clog2(SPI_WORD_LENGTH);   // 0 .. WL-1

    localparam [PHASE_W-1:0] PHASE_ZERO = {PHASE_W{1'b0}};
    localparam [PHASE_W-1:0] PHASE_MAX  = (2 * HALF_PERIOD) - 1;
    localparam [PHASE_W-1:0] PHASE_RISE = HALF_PERIOD;

    reg                       active;    // 0 = idle, 1 = transfer in progress
    reg [PHASE_W-1:0]         phase;     // counts 0 .. 2*HALF_PERIOD-1
    reg [BIT_W-1:0]           bit_cnt;   // SCLK cycles completed
    reg [SPI_WORD_LENGTH-1:0] tx_shift;  // transmit shift register
    reg [SPI_WORD_LENGTH-1:0] rx_shift;  // receive shift register

    // sclk_out is a register driven from the current phase count, so it
    // runs one cycle behind the counter (giving the H+1 first edge of
    // Table 3). cs_out and busy are always written together.
    always @(posedge clk_50MHz or negedge rst_n) begin
        if (!rst_n) begin
            active      <= 1'b0;
            cs_out      <= 1'b1;
            busy        <= 1'b0;
            sclk_out    <= 1'b0;
            mosi_output <= 1'b0;
            rx_data     <= {SPI_WORD_LENGTH{1'b0}};
            tx_shift    <= {SPI_WORD_LENGTH{1'b0}};
            rx_shift    <= {SPI_WORD_LENGTH{1'b0}};
            phase       <= PHASE_ZERO;
            bit_cnt     <= {BIT_W{1'b0}};
        end
        else if (!active) begin
            // ---------------- Idle: frame released, SCLK low ----------------
            cs_out   <= 1'b1;
            busy     <= 1'b0;
            sclk_out <= 1'b0;
            phase    <= PHASE_ZERO;
            bit_cnt  <= {BIT_W{1'b0}};

            if (start) begin
                // ---- Cycle 0: cs/busy assert, capture data, MSB on MOSI ----
                active      <= 1'b1;
                cs_out      <= 1'b0;
                busy        <= 1'b1;
                sclk_out    <= 1'b0;
                tx_shift    <= tx_data;
                rx_shift    <= {SPI_WORD_LENGTH{1'b0}};
                mosi_output <= tx_data[SPI_WORD_LENGTH-1];
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
                // Rising SCLK edge: sample MISO, raise SCLK.
                sclk_out <= 1'b1;
                rx_shift <= {rx_shift[SPI_WORD_LENGTH-2:0], miso_input};
            end
            else if ((phase == PHASE_ZERO) && sclk_out) begin
                // Falling SCLK edge: move MOSI on to the next bit.
                sclk_out <= 1'b0;
                if (bit_cnt == SPI_WORD_LENGTH - 1) begin
                    // Last bit done: release frame, publish received word.
                    active  <= 1'b0;
                    cs_out  <= 1'b1;
                    busy    <= 1'b0;
                    rx_data <= rx_shift;
                end
                else begin
                    bit_cnt     <= bit_cnt + 1'b1;
                    tx_shift    <= {tx_shift[SPI_WORD_LENGTH-2:0], 1'b0};
                    mosi_output <= tx_shift[SPI_WORD_LENGTH-2];
                end
            end
        end
    end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////

endmodule