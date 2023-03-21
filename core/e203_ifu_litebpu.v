`include "e203_defines.v"

module e203_ifu_litebpu(
	input  clk,
	input  rst_n,

	input  [`E203_PC_SIZE-1:0] pc,   // Current PC
	
	// from mini-decode
	input dec_i_valid, //The currently  instruction is decoded and valid
	input dec_jal,    //1 -> it is jal
	input dec_jalr,   //1 -> it is jalr
	input dec_bxx,    //1 -> it is bxx
	input [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx, //if it is jalr instruction, the value is the index or rs1 Register
	input [`E203_XLEN-1:0] dec_bjp_imm,  // the immediate value of instruction bjp
	
	// The IR index and OITF status to be used for checking dependency
	input  oitf_empty,              // oitf is empty, there is no need to judge data hazard, and there must be no data hazard between RAW and WAW
	input  ir_empty,                //
	input  ir_rs1en,                //indicating whether the rs1 operand of the currently executing instruction is valid
	input  jalr_rs1idx_cam_irrdidx, //Judging the indication signal that the IR register is written back to the target of x1
	
	// adder for next-pc 
	output bpu_wait,                //The signal of the adder, if there is data dependence, needs to wait for one cycle
	output prdt_taken,              //Indicates whether the prediction result of the branch prediction unit jumps
	output [`E203_PC_SIZE-1:0] prdt_pc_add_op1,  
	output [`E203_PC_SIZE-1:0] prdt_pc_add_op2,
	
	// The RS1 to read regfile (hardware acceleration)
	output bpu2rf_rs1_ena,           //Generate the enable signal with the first read port, which will load the rs1 index register at the same level as the IR register, thereby reading the REGFile
	input  ir_valid_clr,             //Indicates that the content in the current ir is cleared
	input  [`E203_XLEN-1:0] rf2bpu_x1, //The content of x1 at the same level as IR pulled directly from regfile
	input  [`E203_XLEN-1:0] rf2bpu_rs1 //The content of rs1 fetched from the read port of regfile
 );


	// BPU of E201 utilize very simple static branch prediction logics
	//   * JAL: The target address of JAL is calculated based on current PC value
	//          and offset, and JAL is unconditionally always jump
	//   * JALR with rs1 == x0: The target address of JALR is calculated based on
	//          x0+offset, and JALR is unconditionally always jump
	//   * JALR with rs1 = x1: The x1 register value is directly wired from regfile
	//          when the x1 have no dependency with ongoing instructions by checking
	//          two conditions:
	//            ** (1) The OTIF in EXU must be empty 
	//            ** (2) The instruction in IR have no x1 as destination register
	//          * If there is dependency, then hold up IFU until the dependency is cleared
	//   * JALR with rs1 != x0 or x1: The target address of JALR need to be resolved
	//          at EXU stage, hence have to be forced halted, wait the EXU to be
	//          empty and then read the regfile to grab the value of xN.
	//          This will exert 1 cycle performance lost for JALR instruction
	//   * Bxxx: Conditional branch is always predicted as taken if it is backward
	//          jump, and not-taken if it is forward jump. The target address of JAL
	//          is calculated based on current PC value and offset

 

	// Whether the target address is in the X0, X1 registers for special acceleration
	wire dec_jalr_rs1x0 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd0);
	wire dec_jalr_rs1x1 = (dec_jalr_rs1idx == `E203_RFIDX_WIDTH'd1);
	wire dec_jalr_rs1xn = (~dec_jalr_rs1x0) & (~dec_jalr_rs1x1);

  
	// IS rs1 to (X1 or Xn) data hazard
	wire jalr_rs1x1_dep = dec_i_valid & dec_jalr & dec_jalr_rs1x1 & ((~oitf_empty) | (jalr_rs1idx_cam_irrdidx));
	wire jalr_rs1xn_dep = dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~oitf_empty) | (~ir_empty));
	
	// IS rs1 to Xn data hazard clear
	wire jalr_rs1xn_dep_ir_clr = (jalr_rs1xn_dep & oitf_empty & (~ir_empty)) & (ir_valid_clr | (~ir_rs1en));
	
	//The first read port of the general register bank needs to be used to read the value of the xn register from the general register bank. Need to judge whether the first read port is free and there is no resource conflict
	wire rs1xn_rdrf_r; // Represents the dependency prediction in the current state;
	wire rs1xn_rdrf_set = (~rs1xn_rdrf_r) & dec_i_valid & dec_jalr & dec_jalr_rs1xn & ((~jalr_rs1xn_dep) | jalr_rs1xn_dep_ir_clr);
	wire rs1xn_rdrf_clr = rs1xn_rdrf_r;
	wire rs1xn_rdrf_ena = rs1xn_rdrf_set | rs1xn_rdrf_clr;
	wire rs1xn_rdrf_nxt = rs1xn_rdrf_set | (~rs1xn_rdrf_clr);

	//sirv_gnrl_dfflr #(1) rs1xn_rdrf_dfflrs(rs1xn_rdrf_ena, rs1xn_rdrf_nxt, rs1xn_rdrf_r, clk, rst_n);

	


	// The JAL and JALR is always jump, bxxx backward is predicted as taken  
	assign prdt_taken   = (dec_jal | dec_jalr | (dec_bxx & dec_bjp_imm[`E203_XLEN-1])); 
	
	// RF first read port
	assign bpu2rf_rs1_ena = rs1xn_rdrf_set;

	// adder operator
	assign bpu_wait = jalr_rs1x1_dep | jalr_rs1xn_dep | rs1xn_rdrf_set;
	
	assign prdt_pc_add_op1 = (dec_bxx | dec_jal) ? pc[`E203_PC_SIZE-1:0]
						 : (dec_jalr & dec_jalr_rs1x0) ? `E203_PC_SIZE'b0
						 : (dec_jalr & dec_jalr_rs1x1) ? rf2bpu_x1[`E203_PC_SIZE-1:0]
						 : rf2bpu_rs1[`E203_PC_SIZE-1:0];  

	assign prdt_pc_add_op2 = dec_bjp_imm[`E203_PC_SIZE-1:0];  

endmodule

