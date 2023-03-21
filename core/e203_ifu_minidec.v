`include "e203_defines.v"
module e203_ifu_minidec(
	//IR stage --- input instruction to decoder
	input [`E203_INSTR_SIZE-1:0] instr,
	
	
	// operand
	output dec_rs1en, //Instruction needs to read source operand 1
	output dec_rs2en, //Instruction needs to read source operand 2
	output [`E203_RFIDX_WIDTH-1:0] dec_rs1idx, //register index of source operand 1
	output [`E203_RFIDX_WIDTH-1:0] dec_rs2idx, //register index of source operand 2
	
	// operate
	output dec_mul,    // is a multiplication instruction
	output dec_mulhsu, // The instruction is mulh or mulhsu or mulhu，it will put the upper 32 bits of the result into the destination register
	output dec_div,    // is a division instruction 
	output dec_divu,   // is an unsigned division instruction 
	output dec_rem,    // is a remainder instruction
	output dec_remu,   // is am unsigned remainder 
	
	// 32 or 16
	output dec_rv32,   //1->32 bits instruction，0->16 bits instruction
	
	// jump
	output dec_bjp,    //1-> jump instruction，(jal,jalr,bxx)
	output dec_jal,    //1 -> it is jal
	output dec_jalr,   //1 -> it is jalr
	output dec_bxx,    //1 -> it is bxx
	output [`E203_RFIDX_WIDTH-1:0] dec_jalr_rs1idx, //if it is jalr instruction, the value is the index or rs1 Register
	output [`E203_XLEN-1:0] dec_bjp_imm  // the immediate value of instruction bjp
	
	
	
	
);

endmodule
