module reg_judge(
    input [11:0]  reg_code_ID    ,    //ID用到的源操作数所在寄存器及其有效性
    //input [5 :0]  reg_code_EXE ,   //EXE, MEM, WB参与的目的操作数所在寄存器及其有效性
    //input [5 :0]  reg_code_MEM ,
    input [5 :0]  reg_code_WB    ,
    input         ds_allow_in     ,
    output        real_ds_allowin
);
    wire [1:0] reg_ID_valid  ;
    //wire       reg_EXE_valid ;
    //wire       reg_MEM_valid ;
    wire       reg_WB_valid  ;

    assign reg_ID_valid  = reg_code_ID  [11:10];
    //assign reg_EXE_valid = reg_code_EXE [5]    ;
    //assign reg_MEM_valid = reg_code_MEM [5]    ;
    assign reg_WB_valid  = reg_code_WB  [5]    ;

    //wire ID_EXE_11;
    //wire ID_MEM_11;
    wire ID_WB_11 ;
    //wire ID_EXE_10;
    //wire ID_MEM_10;
    wire ID_WB_10 ;
    //wire ID_EXE_01;
    //wire ID_MEM_01;
    wire ID_WB_01 ;
    //wire ID_EXE_00;
    //wire ID_MEM_00;
    //wire ID_WB_00 ;

    //assign ID_EXE_11 = ((reg_code_ID[9:5] == reg_code_EXE[4:0] || reg_code_ID[4:0] == reg_code_EXE[4:0] && reg_EXE_valid) && (reg_ID_valid[1] && reg_ID_valid[0]))? 1'b0 : 1'b1;
    //assign ID_MEM_11 = ((reg_code_ID[9:5] == reg_code_MEM[4:0] || reg_code_ID[4:0] == reg_code_MEM[4:0] && reg_MEM_valid) && (reg_ID_valid[1] && reg_ID_valid[0]))? 1'b0 : 1'b1;
    assign ID_WB_11  = ((reg_code_ID[9:5] == reg_code_WB [4:0] || reg_code_ID[4:0] == reg_code_WB [4:0] && reg_WB_valid ) && (reg_ID_valid[1] && reg_ID_valid[0]))?   1'b0 : 1'b1;

    //assign ID_EXE_10 = ((reg_code_ID[9:5] == reg_code_EXE[4:0] && reg_EXE_valid) && (reg_ID_valid[1] && ~reg_ID_valid[0]))? 1'b0 : 1'b1;
    //assign ID_MEM_10 = ((reg_code_ID[9:5] == reg_code_MEM[4:0] && reg_MEM_valid) && (reg_ID_valid[1] && ~reg_ID_valid[0]))? 1'b0 : 1'b1;
    assign ID_WB_10  = ((reg_code_ID[9:5] == reg_code_WB [4:0] && reg_WB_valid ) && (reg_ID_valid[1] && ~reg_ID_valid[0]))? 1'b0 : 1'b1;

    //assign ID_EXE_01 = ((reg_code_ID[4:0] == reg_code_EXE[4:0] && reg_EXE_valid) && (~reg_ID_valid[1] && reg_ID_valid[0]))? 1'b0 : 1'b1;
    //assign ID_MEM_01 = ((reg_code_ID[4:0] == reg_code_MEM[4:0] && reg_MEM_valid) && (~reg_ID_valid[1] && reg_ID_valid[0]))? 1'b0 : 1'b1;
    assign ID_WB_01  = ((reg_code_ID[4:0] == reg_code_WB [4:0] && reg_WB_valid ) && (~reg_ID_valid[1] && reg_ID_valid[0]))? 1'b0 : 1'b1;

    //assign ID_EXE_00 = 1'b1;
    //assign ID_MEM_00 = 1'b1;
    //assign ID_WB_00  = 1'b1;

    //wire ID_EXE;
    //wire ID_MEM;
    wire ID_WB ;

    //assign ID_EXE = ID_EXE_11 && ID_EXE_10 && ID_EXE_01;
    //assign ID_MEM = ID_MEM_11 && ID_MEM_10 && ID_MEM_01;
    assign ID_WB  = ID_WB_11  && ID_WB_10  && ID_WB_01 ;

    assign real_ds_allowin = ID_WB && ds_allow_in;

endmodule