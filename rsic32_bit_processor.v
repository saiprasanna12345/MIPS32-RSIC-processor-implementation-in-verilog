`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 21.07.2023 12:12:02
// Design Name:
// Module Name: mips_32_pipeline
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module mips_32_pipeline(clk1,clk2);

input clk1,clk2;        //alternative clocks for diff modules

reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;
reg [31:0] EX_MEM_IR, EX_MEM_B, EX_MEM_ALU_OUT;
reg EX_MEM_COND;
reg [31:0] MEM_WB_IR, MEM_WB_ALU_OUT, MEM_WB_LMD;

reg [2:0] ID_EX_TYPE, EX_MEM_TYPE, MEM_WB_TYPE;

reg [31:0] Reg [31:0];      //REG bank 32*32
reg [31:0] mem[0:1023];     //memory 1024*32 bit

parameter

ADD = 6'b000000,
SUB = 6'b000001,
AND = 6'b000010,
OR = 6'b000011,
SLT = 6'b000100,
MUL = 6'b000101,
HLT = 6'b111111,

LW = 6'b001000,
SW = 6'b001001,
ADDI = 6'b001010,
SUBI = 6'b001011,
SLTI = 6'b001100,
BNEQZ = 6'b001101,
BEQZ = 6'b001110;

parameter

RR_ALU = 3'b000,
RM_ALU = 3'b001,
LOAD = 3'b010,
STORE = 3'b011,
BRANCH = 3'b100,
HALT = 3'b101;

reg HALTED;

reg TAKEN_BRANCH;


//INSTRUCTION FETCH STAGE

always @ (posedge clk1)
begin
    if (HALTED == 1'b0)
    begin                                   //checking opcode for branching or not.
        if (((EX_MEM_IR[31:26] == BNEQZ ) && (EX_MEM_COND == 1'b0)) || ((EX_MEM_IR[31:26] == BEQZ ) && (EX_MEM_COND == 1'b1)))
            begin
               IF_ID_IR <= #2 mem [EX_MEM_ALU_OUT];
               TAKEN_BRANCH <= #2 1'b1;
               IF_ID_NPC <= #2 EX_MEM_ALU_OUT +1;
               PC <= #2 EX_MEM_ALU_OUT +1;            
            end
           
        else
            begin
                IF_ID_IR <= #2 mem[PC];
                IF_ID_NPC <= #2 PC +1;
                PC <= #2 PC + 1;
            end
   
    end

end


//INSTRUCTION DECODE STAGE


always @ (posedge clk2)
begin
    if (HALTED == 1'b0)
        begin
        if (IF_ID_IR [25:21] == 5'b0)
            ID_EX_A <= 32'b0;
           
            else
            ID_EX_A <= #2 Reg [IF_ID_IR [25:21]];       //rs (source1) loading using adress present in opcode
       
        if (IF_ID_IR [20:16] == 5'b0)
            ID_EX_B  <= 32'b0;
           
            else
            ID_EX_B  <= #2 Reg [IF_ID_IR [20:16]];       //rt (source2) loading using adress present in opcode
           
        end
   
    ID_EX_IR <= #2 IF_ID_IR ;
    ID_EX_NPC <= #2 IF_ID_NPC;
    ID_EX_IMM <= #2 {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};       //sign bit extension
   
   
    case (IF_ID_IR [31:26])
            ADD, SUB, AND, OR ,SLT ,MUL : ID_EX_TYPE <= #2 RR_ALU;
            ADDI ,SUBI ,SLTI : ID_EX_TYPE <= #2 RM_ALU ;
            LW : ID_EX_NPC <= #2 LOAD ;
            SW : ID_EX_TYPE <= #2 STORE ;
            BNEQZ ,BEQZ  : ID_EX_TYPE <= #2 BRANCH ;
            HLT : ID_EX_TYPE  <= #2 HALT ;
            default: ID_EX_TYPE <= #2 3'bxxx;       //invalid opcode
           
    endcase

end

//EXECUTE STATE

always @ (posedge clk1)
begin
    if (HALTED == 1'b0)
        begin
            EX_MEM_TYPE <= #2 ID_EX_TYPE ;
            EX_MEM_IR <= #2 ID_EX_IR ;
            TAKEN_BRANCH <= #2 1'b0;
        end
       
       
     case (ID_EX_TYPE)
        RR_ALU : begin
       
                case (ID_EX_IR [31:26])         //opcode
                   
                    ADD :   EX_MEM_ALU_OUT <= #2 ID_EX_A  + ID_EX_B ;
                    SUB :   EX_MEM_ALU_OUT <= #2 ID_EX_A  - ID_EX_B ;
                    AND :   EX_MEM_ALU_OUT <= #2 ID_EX_A  & ID_EX_B ;
                    OR :    EX_MEM_ALU_OUT <= #2 ID_EX_A  | ID_EX_B ;
                    SLT :   EX_MEM_ALU_OUT <= #2 ID_EX_A  < ID_EX_B ;
                    MUL :   EX_MEM_ALU_OUT <= #2 ID_EX_A  * ID_EX_B ;
                    default :   EX_MEM_ALU_OUT <= #2 32'hxxxxxxxx ;
                endcase
                end
           
        RM_ALU : begin
                    case (ID_EX_IR [31:26])
                   
                    ADDI :  EX_MEM_ALU_OUT <= #2 ID_EX_A  + ID_EX_IMM ;
                    SUBI :  EX_MEM_ALU_OUT <= #2 ID_EX_A  - ID_EX_IMM ;
                    SLTI :  EX_MEM_ALU_OUT <= #2 ID_EX_A  < ID_EX_IMM ;
                    default :   EX_MEM_ALU_OUT <= #2 32'hxxxxxxxx ;
                    endcase
                    end

        LOAD ,STORE :
                    begin
                        EX_MEM_ALU_OUT <= #2 ID_EX_A  + ID_EX_IMM ;
                        EX_MEM_B <= #2 ID_EX_B ;
                    end
                       
        BRANCH : begin
                    EX_MEM_ALU_OUT <= #2 ID_EX_NPC + ID_EX_IMM ;
                    EX_MEM_COND <= #2 (ID_EX_A == 0);
                   
                 end
                endcase
end


//MEMORY STAGE

always @ (posedge clk2)
begin
   
       if (HALTED == 1'b0)
            begin
               MEM_WB_TYPE  <= #2 EX_MEM_TYPE ;
               MEM_WB_IR <= #2 EX_MEM_IR ;
               
               case (EX_MEM_TYPE )
                        RR_ALU ,RM_ALU :       MEM_WB_ALU_OUT <= #2 EX_MEM_ALU_OUT ;
                        LOAD           :       MEM_WB_LMD <= #2 mem [EX_MEM_ALU_OUT] ;
                        STORE          :       if (TAKEN_BRANCH ==0)            // if we want to store we  should not branch.
                                                mem[EX_MEM_ALU_OUT ] <= #2 EX_MEM_B ;
       
               endcase
            end

end


// WRITE BACK STAGE

always @ (posedge clk1)
begin

    if (TAKEN_BRANCH  ==1'b0)
   
        case(MEM_WB_TYPE )
                RR_ALU      :       Reg [MEM_WB_IR [15:11]] <= #2 MEM_WB_ALU_OUT ;
                RM_ALU      :       Reg [MEM_WB_IR [15:11]] <= #2 MEM_WB_ALU_OUT;
                LOAD        :       Reg [MEM_WB_IR [15:11]] <= #2 MEM_WB_LMD ;
                HALT        :       HALTED <= #2 1'b1;
        endcase
       
end
endmodule
