/// Copyright by Syntacore LLC © 2016-2018. See LICENSE for details
/// @file       <scr1_top_tb_ahb.sv>
/// @brief      SCR1 top testbench AHB
///

`include "define.v"
`include "scr1_arch_description.h"
`include "scr1_ahb.h"
`ifdef SCR1_IPIC_EN
`include "scr1_ipic.h"
`endif // SCR1_IPIC_EN

`define ALTERA_MEMORY
`timescale 1 ns/ 10 ps

module scr1_top_tb_ahb (
`ifdef VERILATOR
    input logic clk
`endif // VERILATOR
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam                          SCR1_MEM_SIZE       = 1024*1024;
localparam logic [`SCR1_XLEN-1:0]   SCR1_EXIT_ADDR      = 32'h000000F8;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                                   rst_n;
`ifndef VERILATOR
logic                                   clk         = 1'b0;
`endif // VERILATOR
logic                                   rtc_clk     = 1'b0;
`ifdef SCR1_IPIC_EN
logic [SCR1_IRQ_LINES_NUM-1:0]          irq_lines;
`else // SCR1_IPIC_EN
logic                                   ext_irq     = 1'b0;
`endif // SCR1_IPIC_EN
logic                                   soft_irq    = 1'b0;
logic [31:0]                            fuse_mhartid;
integer                                 imem_req_ack_stall;
integer                                 dmem_req_ack_stall;

logic                                   test_mode   = 1'b0;
`ifdef SCR1_DBGC_EN
logic                                   trst_n;
logic                                   tck;
logic                                   tms;
logic                                   tdi;
logic                                   tdo;
logic                                   tdo_en;
`endif // SCR1_DBGC_EN

// Instruction Memory Interface
logic   [3:0]                           imem_hprot;
logic   [2:0]                           imem_hburst;
logic   [2:0]                           imem_hsize;
logic   [1:0]                           imem_htrans;
logic   [SCR1_AHB_WIDTH-1:0]            imem_haddr;
logic                                   imem_hready;
logic   [SCR1_AHB_WIDTH-1:0]            imem_hrdata;
logic                                   imem_hresp;

// Memory Interface
logic   [3:0]                           dmem_hprot;
logic   [2:0]                           dmem_hburst;
logic   [2:0]                           dmem_hsize;
logic   [1:0]                           dmem_htrans;
logic   [SCR1_AHB_WIDTH-1:0]            dmem_haddr;
logic                                   dmem_hwrite;
logic   [SCR1_AHB_WIDTH-1:0]            dmem_hwdata;
logic                                   dmem_hready;
logic   [SCR1_AHB_WIDTH-1:0]            dmem_hrdata;
logic                                   dmem_hresp;

int unsigned                            f_results;
int unsigned                            f_info;
string                                  s_results;
string                                  s_info;
`ifdef VERILATOR
logic [255:0]                           test_file;
`else // VERILATOR
string                                  test_file;
`endif // VERILATOR

bit                                     test_running;
int unsigned                            tests_passed;
int unsigned                            tests_total;

bit [1:0]                               rst_cnt;
bit                                     rst_init;


`ifndef VERILATOR
always #5   clk     = ~clk;         // 100 MHz
always #500 rtc_clk = ~rtc_clk;     // 1 MHz
`endif // VERILATOR

// Reset logic
assign rst_n = &rst_cnt;

always_ff @(posedge clk) begin
    if (rst_init)       rst_cnt <= '0;
    else if (~&rst_cnt) rst_cnt <= rst_cnt + 1'b1;
end


`ifdef SCR1_DBGC_EN
initial begin
    trst_n  = 1'b0;
    tck     = 1'b0;
    tdi     = 1'b0;
    #900ns trst_n   = 1'b1;
    #500ns tms      = 1'b1;
    #800ns tms      = 1'b0;
    #500ns trst_n   = 1'b0;
    #100ns tms      = 1'b1;
end
`endif // SCR1_DBGC_EN

//-------------------------------------------------------------------------------
// Run tests
//-------------------------------------------------------------------------------


initial begin
    //$value$plusargs("imem_pattern=%h", imem_req_ack_stall);
    //$value$plusargs("dmem_pattern=%h", dmem_req_ack_stall);
    imem_req_ack_stall = 32'hffffffff;
	dmem_req_ack_stall = 32'hffffffff;
	//$value$plusargs("test_info=%s", s_info);
    //$value$plusargs("test_results=%s", s_results);
    s_info = "../build/test_info";
	s_results="../build/test_results";
	
    fuse_mhartid = 0;

    f_info      = $fopen(s_info, "r");
    f_results   = $fopen(s_results, "a");
end

reg [7:0] start_char;

always_ff @(posedge clk) begin
    if (test_running) begin
        rst_init <= 1'b0;
`ifdef USE_SSRV
        if (i_top.i_core_top.i_pipe_top.i_ssrv.jump_vld & (i_top.i_core_top.i_pipe_top.i_ssrv.jump_pc==SCR1_EXIT_ADDR) & (i_top.i_core_top.i_pipe_top.i_ssrv.i_mprf.rfbuf_length==0) & ~rst_init & &rst_cnt) begin
`else
        if ((i_top.i_core_top.i_pipe_top.curr_pc == SCR1_EXIT_ADDR) & ~rst_init & &rst_cnt) begin
`endif
            bit test_pass;
            test_running <= 1'b0;
`ifdef USE_SSRV
            test_pass = i_top.i_core_top.i_pipe_top.i_ssrv.i_mprf.r[10]==0;
`else
            test_pass = (i_top.i_core_top.i_pipe_top.i_pipe_mprf.mprf_int[10] == 0);
`endif			
            tests_total     += 1;
            tests_passed    += test_pass;
            $fwrite(f_results, "%s\t\t%s\n", test_file, (test_pass ? "PASS" : "__FAIL"));
            if (test_pass) $display("---%s Test PASS\n\n\n",test_file);//$write("\033[0;32mTest passed\033[0m\n");
            else begin $display("---%s Test FAIL\n\n\n",test_file);  end//$write("\033[0;31mTest failed\033[0m\n");
        end
    end else begin
`ifdef VERILATOR
        if ($fgets(test_file,f_info)) begin
`else // VERILATOR
        if (!$feof(f_info)) begin
            $fscanf(f_info, "%s\n", test_file);
			start_char = test_file[0];
			//$display("---test file is %s ",test_file);
			while((start_char=="#") & ($feof(f_info)==0)) begin
			    $fscanf(f_info, "%s\n", test_file);
				start_char = test_file[0];
			    //$display("---test file is %s ,%d",test_file,$feof(f_info));				
			end
			if (start_char!="#") begin
			    test_file = {"../build/",test_file};
`endif // VERILATOR
            // Launch new test
`ifdef SCR1_TRACE_LOG_EN
                i_top.i_core_top.i_pipe_top.i_tracelog.test_name = test_file;
`endif

`ifndef ALTERA_MEMORY
			    i_memory_tb.test_file = test_file;
                i_memory_tb.test_file_init = 1'b1;
`endif
                $display("\n\n\n---Begin testing: %s ",test_file);
			    //$write("\033[0;34m---Test: %s\033[0m\n", test_file);
                test_running <= 1'b1;
                rst_init <= 1'b1;
            end 
        end else begin
            // Exit
            $display("\n#--------------------------------------");
            $display("# Summary: %0d/%0d tests passed", tests_passed, tests_total);
            $display("#--------------------------------------\n");
            $fclose(f_info);
            $fclose(f_results);
            $stop(1);//$finish();
        end
    end
end

//-------------------------------------------------------------------------------
// Core instance
//-------------------------------------------------------------------------------
scr1_top_ahb i_top (
    // Reset
    .pwrup_rst_n            (rst_n                  ),
    .rst_n                  (rst_n                  ),
    .cpu_rst_n              (rst_n                  ),
`ifdef SCR1_DBGC_EN
    .ndm_rst_n_out          (),
`endif // SCR1_DBGC_EN

    // Clock
    .clk                    (clk                    ),
    .rtc_clk                (rtc_clk                ),

    // Fuses
    .fuse_mhartid           (fuse_mhartid           ),
`ifdef SCR1_DBGC_EN
    .fuse_idcode            (`SCR1_TAP_IDCODE       ),
`endif // SCR1_DBGC_EN

    // IRQ
`ifdef SCR1_IPIC_EN
    .irq_lines              (irq_lines              ),
`else // SCR1_IPIC_EN
    .ext_irq                (ext_irq                ),
`endif // SCR1_IPIC_EN
    .soft_irq               (soft_irq               ),

    // DFT
    .test_mode              (1'b0                   ),
    .test_rst_n             (1'b1                   ),

`ifdef SCR1_DBGC_EN
    // JTAG
    .trst_n                 (trst_n                 ),
    .tck                    (tck                    ),
    .tms                    (tms                    ),
    .tdi                    (tdi                    ),
    .tdo                    (tdo                    ),
    .tdo_en                 (tdo_en                 ),
`endif // SCR1_DBGC_EN

    // Instruction Memory Interface
    .imem_hprot         (imem_hprot     ),
    .imem_hburst        (imem_hburst    ),
    .imem_hsize         (imem_hsize     ),
    .imem_htrans        (imem_htrans    ),
    .imem_hmastlock     (),
    .imem_haddr         (imem_haddr     ),
    .imem_hready        (imem_hready    ),
    .imem_hrdata        (imem_hrdata    ),
    .imem_hresp         (imem_hresp     ),

    // Data Memory Interface
    .dmem_hprot         (dmem_hprot     ),
    .dmem_hburst        (dmem_hburst    ),
    .dmem_hsize         (dmem_hsize     ),
    .dmem_htrans        (dmem_htrans    ),
    .dmem_hmastlock     (),
    .dmem_haddr         (dmem_haddr     ),
    .dmem_hwrite        (dmem_hwrite    ),
    .dmem_hwdata        (dmem_hwdata    ),
    .dmem_hready        (dmem_hready    ),
    .dmem_hrdata        (dmem_hrdata    ),
    .dmem_hresp         (dmem_hresp     )
);

//-------------------------------------------------------------------------------
// Memory instance
//-------------------------------------------------------------------------------


`ifdef ALTERA_MEMORY

ssrv_memory i_memory_tb(

    .clk                    (clk        ),
	.rst                    (~rst_n     ),

    // Instruction Memory Interface
    // .imem_hprot             (imem_hprot ),
    // .imem_hburst            (imem_hburst),
    .imem_hsize             (imem_hsize ),
    .imem_htrans            (imem_htrans),
    .imem_haddr             (imem_haddr ),
    .imem_hready            (imem_hready),
    .imem_hrdata            (imem_hrdata),
    .imem_hresp             (imem_hresp ),

    // Data Memory Interface
    // .dmem_hprot             (dmem_hprot ),
    // .dmem_hburst            (dmem_hburst),
    .dmem_hsize             (dmem_hsize ),
    .dmem_htrans            (dmem_htrans),
    .dmem_haddr             (dmem_haddr ),
    .dmem_hwrite            (dmem_hwrite),
    .dmem_hwdata            (dmem_hwdata),
    .dmem_hready            (dmem_hready),
    .dmem_hrdata            (dmem_hrdata),
    .dmem_hresp             (dmem_hresp )
);


`else

scr1_memory_tb_ahb #(
    .SCR1_MEM_POWER_SIZE    ($clog2(SCR1_MEM_SIZE))
) i_memory_tb (
    // Control
    .rst_n                  (rst_n),
    .clk                    (clk),
`ifdef SCR1_IPIC_EN
    .irq_lines              (irq_lines),
`endif // SCR1_IPIC_EN
    .imem_req_ack_stall_in  (imem_req_ack_stall),
    .dmem_req_ack_stall_in  (dmem_req_ack_stall ),

    // Instruction Memory Interface
    // .imem_hprot             (imem_hprot ),
    // .imem_hburst            (imem_hburst),
    .imem_hsize             (imem_hsize ),
    .imem_htrans            (imem_htrans),
    .imem_haddr             (imem_haddr ),
    .imem_hready            (imem_hready),
    .imem_hrdata            (imem_hrdata),
    .imem_hresp             (imem_hresp ),

    // Data Memory Interface
    // .dmem_hprot             (dmem_hprot ),
    // .dmem_hburst            (dmem_hburst),
    .dmem_hsize             (dmem_hsize ),
    .dmem_htrans            (dmem_htrans),
    .dmem_haddr             (dmem_haddr ),
    .dmem_hwrite            (dmem_hwrite),
    .dmem_hwdata            (dmem_hwdata),
    .dmem_hready            (dmem_hready),
    .dmem_hrdata            (dmem_hrdata),
    .dmem_hresp             (dmem_hresp )
);

`endif//ALTERA_MEMORY

endmodule : scr1_top_tb_ahb
