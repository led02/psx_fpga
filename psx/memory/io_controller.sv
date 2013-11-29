
module io_controller(input  logic clk, rst,
		     
		     input logic [31:0]  addr,
		     input logic [31:0]  data_i,
		     input logic 	 wen, ren,
		     input logic [ 3:0]  ben,
		     output logic 	 ack,
		     output logic [31:0] data_o,
		     
		     /* GPU signals */
		     output logic 	 to_gp0, to_gp1,
		     output logic [31:0] gp0, gp1,
		     output logic 	 gpu_ren,
		     input logic 	 gpu_rdy,
		     input logic 	 gpu_fifo_full,
		     input logic [31:0]  gpu_stat, gpu_read,

		     /* MDEC signals */
		     //output logic [31:0] mdec_cmd_param,
		     //output logic [31:0] mdec_ctrl_rst,
		     //input logic [31:0]  mdec_data_response,
		     //input logic [31:0]  mdec_stat,

		     /* CONTROLLER & MEMORY CARD */
		     //input logic [ 7:0]  controller_rx_data,
		     //output logic [ 7:0] controller_tx_data,
		     //input logic 	 controller_ack,

		     /* DMA */
		     output logic [31:0] DMA_DPCR_o,
		     output logic [95:0] DMA0_CTRL,
		     output logic [95:0] DMA1_CTRL,
		     output logic [95:0] DMA2_CTRL,
		     output logic [95:0] DMA3_CTRL,
		     output logic [95:0] DMA4_CTRL,
		     output logic [95:0] DMA5_CTRL,
		     output logic [95:0] DMA6_CTRL,
		     input logic [ 6:0]  DMA_MADR_incr,
		     input logic [ 6:0]  DMA_MADR_decr,
		     input logic [ 6:0]  DMA_MADR_new,
		     input logic [ 6:0]  DMA_BCR_decr, 
		     input logic [ 6:0]  DMA_IRQ,
		     input logic [31:0]  DMA0_MADR,
		     input logic [31:0]  DMA1_MADR,
		     input logic [31:0]  DMA2_MADR,
		     input logic [31:0]  DMA3_MADR,
		     input logic [31:0]  DMA4_MADR,
		     input logic [31:0]  DMA5_MADR,
		     input logic [31:0]  DMA6_MADR,
		     
		     /* TIMER SIGNALS */
		     input logic 	 hblank, vblank,
		     input logic 	 dotclock,

		     output logic [10:0] interrupts
		     );

   /* PARAMETERS */         // 18'h   1    F    8    0  ~
   localparam HW_ADDR_HEADER = 18'b0001_1111_1000_000;

   /* states */
   localparam IDLE  = 5'b00001;
   localparam READ  = 5'b00010;
   localparam LATCH = 5'b00100;
   localparam WRITE = 5'b01000;
   localparam WAIT  = 5'b10000;

   /* Memory Mapped I/O Virtual Addresses */
   localparam MEM_CTRL_1_ADDR = 32'h1F80_1000;

   localparam JOY_DATA = 32'h1F80_1040;
   localparam JOY_STAT = 32'h1F80_1044;
   localparam JOY_MODE = 32'h1F80_1048;
   localparam JOY_CTRL = 32'h1F80_104A;
   localparam JOY_BAUD = 32'h1F80_104E;
   localparam SIO_DATA = 32'h1F80_1050;
   localparam SIO_STAT = 32'h1F80_1054;
   localparam SIO_MODE = 32'h1F80_1058;
   localparam SIO_CTRL = 32'h1F80_105A;
   localparam SIO_MISC = 32'h1F80_105C;
   localparam SIO_BAUD = 32'h1F80_105E;

   localparam RAM_SIZE = 32'h1F80_1060;

   localparam I_STAT_ADDR = 32'h1F80_1070;
   localparam I_MASK_ADDR = 32'h1F80_1074;

   localparam DMA0_ADDR = 32'h1F80_1080;
   localparam DMA1_ADDR = 32'h1F80_1090;
   localparam DMA2_ADDR = 32'h1F80_10A0;
   localparam DMA3_ADDR = 32'h1F80_10B0;
   localparam DMA4_ADDR = 32'h1F80_10C0;
   localparam DMA5_ADDR = 32'h1F80_10D0;
   localparam DMA6_ADDR = 32'h1F80_10E0;
   localparam DPCR_ADDR = 32'h1F80_10F0;
   localparam DICR_ADDR = 32'h1F80_10F4;

   localparam TIMER0_ADDR = 32'h1F80_1100;
   localparam TIMER1_ADDR = 32'h1F80_1110;
   localparam TIMER2_ADDR = 32'h1F80_1120;

   localparam GPU_READ_GP0 = 32'h1F80_1810;
   localparam GPU_STAT_GP1 = 32'h1F80_1814;

   /* PSX I/O REGISTERS */
   // - Memory Control 1
   reg [31:0] MEM_CTRL_1 [0:8];    // 0x1F801000 - 0x1F801023
   // - Peripheral I/O
   reg [31:0] PERIPHERAL_IO [0:7]; // 0x1F801040 - 0x1F80105F
   // - Memory Control 2
   reg [31:0] MEM_CTRL_2;          // 0x1F801060
   // - Interrupt Control
   reg [31:0] I_STAT;              // 0x1F801070
   reg [31:0] I_MASK;              // 0x1F801074
   // - DMA Registers
   reg [31:0] DMA0 [0:2];          // 0x1F801080
   reg [31:0] DMA1 [0:2];          // 0x1F801090
   reg [31:0] DMA2 [0:2];          // 0x1F8010A0
   reg [31:0] DMA3 [0:2];          // 0x1F8010B0
   reg [31:0] DMA4 [0:2];          // 0x1F8010C0
   reg [31:0] DMA5 [0:2];          // 0x1F8010D0
   reg [31:0] DMA6 [0:2];          // 0x1F8010E0
   reg [31:0] DMA_DPCR;            // 0x1F8010F0
   reg [31:0] DMA_DICR;            // 0x1F8010F4
   // - Timers
   reg [31:0] DOT_CLK_VALUE;       // 0x1F801100
   reg [31:0] DOT_CLK_CMODE;       //  - Dotclock
   reg [31:0] DOT_CLK_TARGT;
   reg [31:0] HZT_CLK_VALUE;       // 0x1F801110
   reg [31:0] HZT_CLK_CMODE;       //  - Horizontal Retrace
   reg [31:0] HZT_CLK_TARGT;
   reg [31:0] CLK_1_8_VALUE;       // 0x1F801120
   reg [31:0] CLK_1_8_CMODE;       //  - 1/8 System Clock
   reg [31:0] CLK_1_8_TARGT;
   
   /* Internal Lines */
   reg 	      timer_wen, timer_ren;
   reg 	      int_wen;
   reg 	      dma_irq_wen;

   reg [31:0] DMA_DICR_new;
   
   reg [4:0]  curr_state, next_state;
   
   wire [31:0] shift_addr;

   reg [31:0]  data_out;
   reg 	       ack_out;

   reg 	       to_gp0_o, to_gp1_o;
   reg [31:0]  gp0_o, gp1_o;
   reg 	       gpu_ren_o;
   
   assign shift_addr = {HW_ADDR_HEADER, addr[17:0]};

   assign data_o = data_out;
   assign ack = ack_out;

   assign interrupts = I_STAT[10:0];

   assign to_gp0 = to_gp0_o;
   assign to_gp1 = to_gp1_o;
   assign gp0 = gp0_o;
   assign gp1 = gp1_o;
   assign gpu_ren = gpu_ren_o;

   /* DMA outputs */
   assign DMA_DPCR_o = DMA_DPCR;
   assign DMA0_CTRL = {DMA0[2], DMA0[1], DMA0[0]};
   assign DMA1_CTRL = {DMA1[2], DMA1[1], DMA1[0]};
   assign DMA2_CTRL = {DMA2[2], DMA2[1], DMA2[0]};
   assign DMA3_CTRL = {DMA3[2], DMA3[1], DMA3[0]};
   assign DMA4_CTRL = {DMA4[2], DMA4[1], DMA4[0]};
   assign DMA5_CTRL = {DMA5[2], DMA5[1], DMA5[0]};
   assign DMA6_CTRL = {DMA6[2], DMA6[1], DMA6[0]};
   
   /* TIMER CONTROLLER */
   psx_timers timers(.sys_clk      (clk),
		     .rst          (rst),
		     .dotclock     (dotclock),
		     .hblank       (hblank),
		     .vblank       (vblank),
		     .timer_sel    (addr[7:0]),
		     .wen          (timer_wen),
		     .ren          (timer_ren),
		     .data_i       (data_i[15:0]),
		     .ben          (ben[1:0]),
		     .timer0_value (DOT_CLK_VALUE[15:0]),
		     .timer0_cmode (DOT_CLK_CMODE[15:0]),
		     .timer0_targt (DOT_CLK_TARGT[15:0]),
		     .timer1_value (HZT_CLK_VALUE[15:0]),
		     .timer1_cmode (HZT_CLK_CMODE[15:0]),
		     .timer1_targt (HZT_CLK_TARGT[15:0]),
		     .timer2_value (CLK_1_8_VALUE[15:0]),
		     .timer2_cmode (CLK_1_8_CMODE[15:0]),
		     .timer2_targt (CLK_1_8_TARGT[15:0]));

   /* DMA INTERRUPT CONTROLLER */
   dma_interrupts d_interrupts(.sys_clk (clk),
			       .rst     (rst),
			       .irqs    (DMA_IRQ),
			       .wen     (dma_irq_wen),
			       .ben     (ben),
			       .DICR_i  (data_i),
			       .DICR_o  (DMA_DICR));
   
   /* PSX INTERRUPT CONTROLLER */
   psx_interrupts p_interrupts(.sys_clk    (clk),
			       .rst        (rst),
			       .wen        (int_wen),
			       .ben        (ben[1:0]),
			       .irq_vblank (),
			       .irq_gpu    (),
			       .irq_cdrom  (),
			       .irq_dma    (~DMA_DICR[31]),
			       .irq_timer0 (DOT_CLK_CMODE[10]),
			       .irq_timer1 (HZT_CLK_CMODE[10]),
			       .irq_timer2 (CLK_1_8_CMODE[10]),
			       .irq_ctlmem (),
			       .irq_sio    (),
			       .irq_spu    (),
			       .irq_ctrl   (),
			       .addr       (addr[2]),
			       .data_i     (data_i[15:0]),
			       .stat_o     (I_STAT),
			       .mask_o     (I_MASK));
   
   
   always @ (posedge clk, posedge rst) begin
      /* set registers to default values on reset */
      if (rst) begin
	 /* Memory Control 1 */          // --(all 4 bytes)--
	 MEM_CTRL_1[0] <= 32'h1F00_0000; // Expansion 1 base addr
	 MEM_CTRL_1[1] <= 32'h1F80_2000; // Expansion 2 base addr
	 MEM_CTRL_1[2] <= 32'h0013_243F; // Expansion 1 delay & size
	 MEM_CTRL_1[3] <= 32'h0000_3022; // Expansion 3 delay & size
	 MEM_CTRL_1[4] <= 32'h0013_243F; // BIOS ROM delay & size
	 MEM_CTRL_1[5] <= 32'h2009_31E1; // SPU delay & size
	 MEM_CTRL_1[6] <= 32'h0002_0843; // CDROM delay & size
	 MEM_CTRL_1[7] <= 32'h0007_0777; // Expansion 2 delay & size
	 MEM_CTRL_1[8] <= 32'h0003_1125; // Common delay
	 /* Peripheral I/O */
	 PERIPHERAL_IO[0] <= 32'd0; // JOY_DATA(1/4)
	 PERIPHERAL_IO[1] <= 32'd0; // JOY_STAT(4)
	 PERIPHERAL_IO[2] <= 32'd0; // JOY_MODE(2) & JOY_CTRL(2)
	 PERIPHERAL_IO[3] <= 32'd0; // --------(2) & JOY_BAUD(2)
	 PERIPHERAL_IO[4] <= 32'd0; // SIO_DATA(1/4)
	 PERIPHERAL_IO[5] <= 32'd0; // SIO_STAT(4)
	 PERIPHERAL_IO[6] <= 32'd0; // SIO_MODE(2) & SIO_CTRL(2)
	 PERIPHERAL_IO[7] <= 32'd0; // SIO_MISC(2) & SIO_BAUD(2)
	 /* Memory Control 2 */
	 MEM_CTRL_2 <= 32'h0000_0B88; // (4)
	 /* DMA Registers */
	 DMA0[0] <= 32'd0; DMA0[1] <= 32'd0; DMA0[2] <= 32'd0;	 
	 DMA1[0] <= 32'd0; DMA1[1] <= 32'd0; DMA1[2] <= 32'd0;
	 DMA2[0] <= 32'd0; DMA2[1] <= 32'd0; DMA2[2] <= 32'd0;
	 DMA3[0] <= 32'd0; DMA3[1] <= 32'd0; DMA3[2] <= 32'd0;
	 DMA4[0] <= 32'd0; DMA4[1] <= 32'd0; DMA4[2] <= 32'd0;
	 DMA5[0] <= 32'd0; DMA5[1] <= 32'd0; DMA5[2] <= 32'd0;
	 DMA6[0] <= 32'd0; DMA6[1] <= 32'd0; DMA6[2] <= 32'd0;
	 DMA_DPCR <= 32'h07654321;
      end 
      else begin
	 if (curr_state == WRITE) begin
	    case (addr)
	      /* Memory Control 1 */
	      MEM_CTRL_1_ADDR + 8'h00: begin
		 if (ben[3]) MEM_CTRL_1[0][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[0][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h04: begin
		 if (ben[3]) MEM_CTRL_1[1][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[1][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h08: begin
		 if (ben[3]) MEM_CTRL_1[2][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[2][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h0C: begin
		 if (ben[3]) MEM_CTRL_1[3][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[3][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[3][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[3][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h10: begin
		 if (ben[3]) MEM_CTRL_1[4][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[4][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[4][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[4][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h14: begin
		 if (ben[3]) MEM_CTRL_1[5][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[5][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[5][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[5][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h18: begin
		 if (ben[3]) MEM_CTRL_1[6][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[6][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[6][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[6][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h1C: begin
		 if (ben[3]) MEM_CTRL_1[7][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[7][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[7][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[7][ 7: 0] <= data_i[ 7: 0];
	      end
	      MEM_CTRL_1_ADDR + 8'h20: begin
		 if (ben[3]) MEM_CTRL_1[8][31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_1[8][23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_1[8][15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_1[8][ 7: 0] <= data_i[ 7: 0];
	      end

	      /* PERIPHERAL IO (controllers & memory cards) */
	      JOY_DATA: begin
		 if (ben[3]) PERIPHERAL_IO[0][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[0][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      JOY_STAT: begin
		 if (ben[3]) PERIPHERAL_IO[1][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[1][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      JOY_MODE: begin
		 if (ben[3]) PERIPHERAL_IO[2][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[2][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      JOY_BAUD - 8'h02: begin
		 if (ben[3]) PERIPHERAL_IO[3][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[3][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[3][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[3][ 7: 0] <= data_i[ 7: 0];
	      end
	      SIO_DATA: begin
		 if (ben[3]) PERIPHERAL_IO[4][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[4][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[4][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[4][ 7: 0] <= data_i[ 7: 0];
	      end
	      SIO_STAT: begin
		 if (ben[3]) PERIPHERAL_IO[5][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[5][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[5][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[5][ 7: 0] <= data_i[ 7: 0];
	      end
	      SIO_MODE: begin
		 if (ben[3]) PERIPHERAL_IO[6][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[6][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[6][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[6][ 7: 0] <= data_i[ 7: 0];
	      end
	      SIO_MISC: begin
		 if (ben[3]) PERIPHERAL_IO[7][31:24] <= data_i[31:24];
		 if (ben[2]) PERIPHERAL_IO[7][23:16] <= data_i[23:16];
		 if (ben[1]) PERIPHERAL_IO[7][15: 8] <= data_i[15: 8];
		 if (ben[0]) PERIPHERAL_IO[7][ 7: 0] <= data_i[ 7: 0];
	      end

	      /* RAM Size */
	      RAM_SIZE: begin
		 if (ben[3]) MEM_CTRL_2[31:24] <= data_i[31:24];
		 if (ben[2]) MEM_CTRL_2[23:16] <= data_i[23:16];
		 if (ben[1]) MEM_CTRL_2[15: 8] <= data_i[15: 8];
		 if (ben[0]) MEM_CTRL_2[ 7: 0] <= data_i[ 7: 0];
	      end

	      /* DMA0 - MDECin */
	      DMA0_ADDR + 4'h0: begin
		 if (ben[3]) DMA0[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA0[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA0[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA0[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA0_ADDR + 4'h4: begin
		 if (ben[3]) DMA0[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA0[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA0[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA0[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA0_ADDR + 4'h8: begin
		 if (ben[3]) DMA0[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA0[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA0[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA0[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA1 - MDECout */
	      DMA1_ADDR + 4'h0: begin
		 if (ben[3]) DMA1[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA1[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA1[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA1[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA1_ADDR + 4'h4: begin
		 if (ben[3]) DMA1[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA1[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA1[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA1[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA1_ADDR + 4'h8: begin
		 if (ben[3]) DMA1[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA1[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA1[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA1[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA2 - GPU */
	      DMA2_ADDR + 4'h0: begin
		 if (ben[3]) DMA2[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA2[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA2[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA2[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA2_ADDR + 4'h4: begin
		 if (ben[3]) DMA2[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA2[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA2[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA2[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA2_ADDR + 4'h8: begin
		 if (ben[3]) DMA2[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA2[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA2[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA2[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA3 - CDROM */
	      DMA3_ADDR + 4'h0: begin
		 if (ben[3]) DMA3[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA3[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA3[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA3[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA3_ADDR + 4'h4: begin
		 if (ben[3]) DMA3[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA3[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA3[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA3[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA3_ADDR + 4'h8: begin
		 if (ben[3]) DMA3[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA3[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA3[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA3[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA4 - SPU */
	      DMA4_ADDR + 4'h0: begin
		 if (ben[3]) DMA4[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA4[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA4[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA4[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA4_ADDR + 4'h4: begin
		 if (ben[3]) DMA4[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA4[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA4[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA4[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA4_ADDR + 4'h8: begin
		 if (ben[3]) DMA4[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA4[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA4[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA4[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA5 - PIO */
	      DMA5_ADDR + 4'h0: begin
		 if (ben[3]) DMA5[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA5[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA5[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA5[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA5_ADDR + 4'h4: begin
		 if (ben[3]) DMA5[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA5[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA5[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA5[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA5_ADDR + 4'h8: begin
		 if (ben[3]) DMA5[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA5[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA5[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA5[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA6 - OTC */
	      DMA6_ADDR + 4'h0: begin
		 if (ben[3]) DMA6[0][31:24] <= data_i[31:24];
		 if (ben[2]) DMA6[0][23:16] <= data_i[23:16];
		 if (ben[1]) DMA6[0][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA6[0][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA6_ADDR + 4'h4: begin
		 if (ben[3]) DMA6[1][31:24] <= data_i[31:24];
		 if (ben[2]) DMA6[1][23:16] <= data_i[23:16];
		 if (ben[1]) DMA6[1][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA6[1][ 7: 0] <= data_i[ 7: 0];
	      end
	      DMA6_ADDR + 4'h8: begin
		 if (ben[3]) DMA6[2][31:24] <= data_i[31:24];
		 if (ben[2]) DMA6[2][23:16] <= data_i[23:16];
		 if (ben[1]) DMA6[2][15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA6[2][ 7: 0] <= data_i[ 7: 0];
	      end
	      /* DMA Control Register */
	      DPCR_ADDR: begin
		 if (ben[3]) DMA_DPCR[31:24] <= data_i[31:24];
		 if (ben[2]) DMA_DPCR[23:16] <= data_i[23:16];
		 if (ben[1]) DMA_DPCR[15: 8] <= data_i[15: 8];
		 if (ben[0]) DMA_DPCR[ 7: 0] <= data_i[ 7: 0];
	      end
		 

	      default: begin
		 // don't care about unused addresses
	      end
	      
	    endcase // case (addr)
	 end
	 else begin
	    /* DMA MADR registers */
	    if (DMA_MADR_new[0]) DMA0[0] <= DMA0_MADR;
	    else begin
	       if (DMA_MADR_incr[0]) DMA0[0] <= DMA0[0] + 32'h4;
	       if (DMA_MADR_decr[0]) DMA0[0] <= DMA0[0] - 32'h4;
	    end
	    if (DMA_MADR_new[1]) DMA1[0] <= DMA1_MADR;
	    else begin
	       if (DMA_MADR_incr[1]) DMA1[0] <= DMA1[0] + 32'h4;
	       if (DMA_MADR_decr[1]) DMA1[0] <= DMA1[0] - 32'h4;
	    end
	    if (DMA_MADR_new[2]) DMA2[0] <= DMA2_MADR;
	    else begin
	       if (DMA_MADR_incr[2]) DMA2[0] <= DMA2[0] + 32'h4;
	       if (DMA_MADR_decr[2]) DMA2[0] <= DMA2[0] - 32'h4;
	    end
	    if (DMA_MADR_new[3]) DMA3[0] <= DMA3_MADR;
	    else begin
	       if (DMA_MADR_incr[3]) DMA3[0] <= DMA3[0] + 32'h4;
	       if (DMA_MADR_decr[3]) DMA3[0] <= DMA3[0] - 32'h4;
	    end
	    if (DMA_MADR_new[4]) DMA4[0] <= DMA4_MADR;
	    else begin
	       if (DMA_MADR_incr[4]) DMA4[0] <= DMA4[0] + 32'h4;
	       if (DMA_MADR_decr[4]) DMA4[0] <= DMA4[0] - 32'h4;
	    end
	    if (DMA_MADR_new[5]) DMA5[0] <= DMA5_MADR;
	    else begin
	       if (DMA_MADR_incr[5]) DMA5[0] <= DMA5[0] + 32'h4;
	       if (DMA_MADR_decr[5]) DMA5[0] <= DMA5[0] - 32'h4;
	    end
	    if (DMA_MADR_new[6]) DMA6[0] <= DMA6_MADR;
	    else begin
	       if (DMA_MADR_incr[6]) DMA6[0] <= DMA6[0] + 32'h4;
	       if (DMA_MADR_decr[6]) DMA6[0] <= DMA6[0] - 32'h4;
	    end
	    /* DMA BCR registers */
	    if (DMA_BCR_decr[0]) 
	      DMA0[1][31:16] <= (DMA0[1][31:16] - 
				 {10'b0, DMA0[1][0], DMA0[1][1], DMA0[1][2], 
				  DMA0[1][3], DMA0[1][4], DMA0[1][5]});
	    if (DMA_BCR_decr[1]) 
	      DMA1[1][31:16] <= (DMA1[1][31:16] - 
				 {10'b0, DMA1[1][0], DMA1[1][1], DMA1[1][2], 
				  DMA1[1][3], DMA1[1][4], DMA1[1][5]});
	    if (DMA_BCR_decr[2]) 
	      DMA2[1][31:16] <= (DMA2[1][31:16] - 
				 {10'b0, DMA2[1][0], DMA2[1][1], DMA2[1][2], 
				  DMA2[1][3], DMA2[1][4], DMA2[1][5]});
	    if (DMA_BCR_decr[3]) 
	      DMA3[1][31:16] <= (DMA3[1][31:16] - 
				 {10'b0, DMA3[1][0], DMA3[1][1], DMA3[1][2], 
				  DMA3[1][3], DMA3[1][4], DMA3[1][5]});
	    if (DMA_BCR_decr[4]) 
	      DMA4[1][31:16] <= (DMA4[1][31:16] - 
				 {10'b0, DMA4[1][0], DMA4[1][1], DMA4[1][2], 
				  DMA4[1][3], DMA4[1][4], DMA4[1][5]});
	    if (DMA_BCR_decr[5]) 
	      DMA5[1][31:16] <= (DMA5[1][31:16] - 
				 {10'b0, DMA5[1][0], DMA5[1][1], DMA5[1][2], 
				  DMA5[1][3], DMA5[1][4], DMA5[1][5]});
	    if (DMA_BCR_decr[6]) 
	      DMA6[1][31:16] <= (DMA6[1][31:16] - 
				 {10'b0, DMA6[1][0], DMA6[1][1], DMA6[1][2], 
				  DMA6[1][3], DMA6[1][4], DMA6[1][5]});
	 end
      end 
   end


   /* Latch output value */
   always @ (posedge clk, posedge rst) begin
      if (rst) begin
	 data_out <= 32'b0;
      end
      else begin
	 if (curr_state == LATCH) begin
	    // lots of cases

	    case (addr)
	      /* Memory Control 1 */
	      MEM_CTRL_1_ADDR + 8'h00:
		data_out <= MEM_CTRL_1[0];
	      MEM_CTRL_1_ADDR + 8'h04:
		data_out <= MEM_CTRL_1[1];
	      MEM_CTRL_1_ADDR + 8'h08:
		data_out <= MEM_CTRL_1[2];
	      MEM_CTRL_1_ADDR + 8'h0C:
		data_out <= MEM_CTRL_1[3];
	      MEM_CTRL_1_ADDR + 8'h10:
		data_out <= MEM_CTRL_1[4];
	      MEM_CTRL_1_ADDR + 8'h14:
		data_out <= MEM_CTRL_1[5];
	      MEM_CTRL_1_ADDR + 8'h18:
		data_out <= MEM_CTRL_1[6];
	      MEM_CTRL_1_ADDR + 8'h1C:
		data_out <= MEM_CTRL_1[7];
	      MEM_CTRL_1_ADDR + 8'h20:
		data_out <= MEM_CTRL_1[8];

	      /* Timers */
	      TIMER0_ADDR + 4'h0:
		data_out <= DOT_CLK_VALUE;
	      TIMER0_ADDR + 4'h4:
		data_out <= DOT_CLK_CMODE;
	      TIMER0_ADDR + 4'h8:
		data_out <= DOT_CLK_TARGT;
	      TIMER1_ADDR + 4'h0:
		data_out <= HZT_CLK_VALUE;
	      TIMER1_ADDR + 4'h4:
		data_out <= HZT_CLK_CMODE;
	      TIMER1_ADDR + 4'h8:
		data_out <= HZT_CLK_TARGT;
	      TIMER2_ADDR + 4'h0:
		data_out <= CLK_1_8_VALUE;
	      TIMER2_ADDR + 4'h4:
		data_out <= CLK_1_8_CMODE;
	      TIMER2_ADDR + 4'h8:
		data_out <= CLK_1_8_TARGT;

	      /* Interrupts */
	      I_STAT_ADDR:
		data_out <= I_STAT;
	      I_MASK_ADDR:
		data_out <= I_MASK;

	      /* GPU */
	      GPU_READ_GP0:
		data_out <= gpu_read;
	      GPU_STAT_GP1:
		data_out <= gpu_stat;
	      

	      default:
		data_out <= 32'b0;
	    endcase // case (addr)
	 end
      end
   end
   
   /* FSM next state logic */
   always @ (posedge clk, posedge rst) begin
      if (rst) begin
	 curr_state <= IDLE;
      end
      else begin
	 curr_state <= next_state;
      end
   end

   /* FSM */
   always_comb begin
      /* Defaults */
      next_state = curr_state;

      ack_out = 1'b0;
      timer_wen = 1'b0;
      timer_ren = 1'b0;
      int_wen = 1'b0;
      dma_irq_wen = 1'b0;

      to_gp0_o = 1'b0;
      to_gp1_o = 1'b0;
      gp0_o = 32'b0;
      gp1_o = 32'b0;
      gpu_ren_o = 1'b0;
      
      case (curr_state)
	IDLE: begin
	   if (ren) begin
	      next_state = READ;  
	   end
	   else if (wen) begin
	      next_state = WRITE;
	   end
	   else begin
	      next_state = IDLE;
	   end
	end // case: IDLE

	READ: begin
	   // branch to special read cases
	   case (addr)
	     
	     
	     default: begin
		next_state = LATCH;
	     end
	   endcase
	end
	LATCH: begin
	   /* if a timer address -> pull timer_ren high
	    * - should be during READ state, but we need a delay */
	   if (addr == TIMER0_ADDR + 0 ||
	       addr == TIMER0_ADDR + 4 ||
	       addr == TIMER0_ADDR + 8 ||
	       addr == TIMER1_ADDR + 0 ||
	       addr == TIMER1_ADDR + 4 ||
	       addr == TIMER1_ADDR + 8 ||
	       addr == TIMER2_ADDR + 0 ||
	       addr == TIMER2_ADDR + 4 ||
	       addr == TIMER2_ADDR + 8  ) begin
	      timer_ren = 1'b1;
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	   else if (addr == GPU_READ_GP0) begin
	      if (gpu_rdy) begin
		 gpu_ren_o = 1'b1;
		 ack_out = 1'b1;
		 next_state = WAIT;
	      end
	      else begin
		 next_state = LATCH;
	      end
	   end
	   else begin
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	end

	WRITE: begin
	   // branch to special write cases
	   
			       
	   /* in interrupt address -> pull int_wen high */
	   if (addr == I_STAT_ADDR || addr == I_MASK_ADDR) begin
	      int_wen = 1'b1;
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	   /* dma irq address */
	   else if (addr == DICR_ADDR) begin
	      dma_irq_wen = 1'b1;
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	   /* if a timer address -> pull timer_wen high */
	   else if (addr == TIMER0_ADDR + 0 ||
	       addr == TIMER0_ADDR + 4 ||
	       addr == TIMER0_ADDR + 8 ||
	       addr == TIMER1_ADDR + 0 ||
	       addr == TIMER1_ADDR + 4 ||
	       addr == TIMER1_ADDR + 8 ||
	       addr == TIMER2_ADDR + 0 ||
	       addr == TIMER2_ADDR + 4 ||
	       addr == TIMER2_ADDR + 8  ) begin
	      timer_wen = 1'b1;
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	   /* gpu address */
	   else if (addr == GPU_READ_GP0) begin
	      if (~gpu_fifo_full) begin
		 gp0_o = data_i;
		 to_gp0_o = 1'b1;
		 ack_out = 1'b1;
		 next_state = WAIT;
	      end
	      else begin
		 next_state = WRITE;
	      end
	   end
	   else if (addr == GPU_STAT_GP1) begin
	      gp1_o = data_i;
	      to_gp1_o = 1'b1;
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	   else begin
	      ack_out = 1'b1;
	      next_state = WAIT;
	   end
	end

	WAIT: begin
	   ack_out = 1'b1;
	   if (~ren && ~wen) begin
	      next_state = IDLE;
	   end
	   else begin
	      next_state = WAIT;
	   end
	end
	
      endcase // case (curr_state)

   end

endmodule // io_controller
