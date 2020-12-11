`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    //foward data path
    output [`FW_DATA           :0] es_to_ds_fw
    //data path for HI LO
    //output [`HILO_WB         -1:0] hilo_to_wb,
);

reg         es_valid      ;
wire        es_ready_go   ;



reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        dest_valid    ;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire        inst_lw;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_sw;
wire        inst_sb;
wire        inst_sh;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_swl;
wire        inst_swr;

wire [ 3:0] es_addr_low;

wire        swl_0;
wire        swl_1;
wire        swl_2;
wire        swl_3;
wire        swr_0;
wire        swr_1;
wire        swr_2;
wire        swr_3;

wire [31:0] mult_src1;
wire [31:0] mult_src2;
wire [63:0] mult_result;
wire [ 1:0] mult_op;
wire [ 1:0] div_op;
wire [31:0] div_src1;
wire [31:0] div_src2;
wire [63:0] div_result;
wire [63:0] divu_result;

reg  s_axis_divisor_tvalid ;
wire s_axis_divisor_tready ;
reg  s_axis_dividend_tvalid;
wire s_axis_dividend_tready;
wire m_axis_dout_tvalid    ;  //signed div

reg  s_axis_divisor_u_tvalid;
wire s_axis_divisor_u_tready ;
reg  s_axis_dividend_u_tvalid;
wire s_axis_dividend_u_tready;
wire m_axis_dout_u_tvalid    ;//unsigned div

reg  div_is_running;
wire div_block;

always@(posedge clk) begin
    if(reset) begin
        div_is_running <= 1'b0;
    end
    else if((div_op[1] || div_op[0])   && es_valid) begin
            div_is_running <= 1'b1;
    end
    else if((!div_op[1] && !div_op[0]) && es_valid) begin
            div_is_running <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_divisor_tvalid <= 1'b0;
    end
    else if(div_op[0] && !div_is_running) begin
        s_axis_divisor_tvalid <= 1'b1;
    end
    else if(s_axis_divisor_tready && s_axis_divisor_tvalid) begin
        s_axis_divisor_tvalid <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_dividend_tvalid <= 1'b0;
    end
    else if(div_op[0] && !div_is_running) begin
        s_axis_dividend_tvalid <= 1'b1;
    end
    else if(s_axis_dividend_tready && s_axis_dividend_tvalid) begin
        s_axis_dividend_tvalid <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_divisor_u_tvalid <= 1'b0;
    end
    else if(div_op[1] && !div_is_running) begin
        s_axis_divisor_u_tvalid <= 1'b1;
    end
    else if(s_axis_divisor_u_tready && s_axis_divisor_u_tvalid) begin
        s_axis_divisor_u_tvalid <= 1'b0;
    end
end

always@(posedge clk) begin
    if(reset) begin
        s_axis_dividend_u_tvalid <= 1'b0;
    end
    else if(div_op[1] && !div_is_running) begin
        s_axis_dividend_u_tvalid <= 1'b1;
    end
    else if(s_axis_dividend_u_tready && s_axis_dividend_u_tvalid) begin
        s_axis_dividend_u_tvalid <= 1'b0;
    end
end

assign div_block = !m_axis_dout_tvalid && div_op[0] || !m_axis_dout_u_tvalid && div_op[1];
assign es_ready_go = !div_block;

wire [31:0] HI_in;
wire [31:0] LO_in;
wire [31:0] HI_out;
wire [31:0] LO_out;
wire        HI_wen;
wire        LO_wen;
wire [ 1:0] HI_LO_mv;

wire [31:0] es_result;


assign {inst_swl       ,  //156:156
        inst_swr       ,  //155:155
        inst_lwl       ,  //154:154
        inst_lwr       ,  //153:153
        inst_sw        ,  //152:152
        inst_sb        ,  //151:151
        inst_sh        ,  //150:150
        inst_lhu       ,  //149:149
        inst_lh        ,  //148:148
        inst_lbu       ,  //147:147
        inst_lb        ,  //146:146
        inst_lw        ,  //145:145
        HI_LO_mv       ,  //144:143
        mult_op        ,  //142:141
        div_op         ,  //140:139
        HI_wen         ,  //138:138
        LO_wen         ,  //137:137
        dest_valid     ,  //136:136
        es_alu_op      ,  //135:124
        es_load_op     ,  //123:123
        es_src1_is_sa  ,  //122:122
        es_src1_is_pc  ,  //121:121
        es_src2_is_imm ,  //120:120
        es_src2_is_8   ,  //119:119
        es_gr_we       ,  //118:118
        es_mem_we      ,  //117:117
        es_dest        ,  //116:112
        es_imm         ,  //111:96
        es_rs_value    ,  //95 :64
        es_rt_value    ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;

assign es_result = (HI_LO_mv[1]) ? HI_out :
                   (HI_LO_mv[0]) ? LO_out :
                             es_alu_result;

wire        es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_rt_value    ,  //110:79
                       inst_lwl       ,  //78:78
                       inst_lwr       ,  //77:77
                       inst_lhu       ,  //76:76
                       inst_lh        ,  //75:75
                       inst_lbu       ,  //74:74
                       inst_lb        ,  //73:73
                       inst_lw        ,  //72:72
                       dest_valid     ,  //71:71
                       es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_result  ,      //63:32
                       es_pc             //31:0
                      };


assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

wire   logic_op;
assign logic_op = es_alu_op[4] | es_alu_op[5] | es_alu_op[6] | es_alu_op[7];

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = (es_src2_is_imm && !logic_op)? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     (es_src2_is_imm &&  logic_op)? {{16{0}}         , es_imm[15:0]} :
                      es_src2_is_8                ?   32'd8                          :
                                                      es_rt_value;

assign mult_src1 = es_rs_value;
assign mult_src2 = es_rt_value;
assign div_src1  = es_rs_value;
assign div_src2  = es_rt_value;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),        //check
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result)
    );

assign es_addr_low[0] = (es_alu_result[1:0] == 2'b00);
assign es_addr_low[1] = (es_alu_result[1:0] == 2'b01);
assign es_addr_low[2] = (es_alu_result[1:0] == 2'b10);
assign es_addr_low[3] = (es_alu_result[1:0] == 2'b11);

assign swl_0 = inst_swl && (es_addr_low[0]);
assign swl_1 = inst_swl && (es_addr_low[1]);
assign swl_2 = inst_swl && (es_addr_low[2]);
assign swl_3 = inst_swl && (es_addr_low[3]);

assign swr_0 = inst_swr && (es_addr_low[0]);
assign swr_1 = inst_swr && (es_addr_low[1]);
assign swr_2 = inst_swr && (es_addr_low[2]);
assign swr_3 = inst_swr && (es_addr_low[3]);

assign data_sram_en    = 1'b1;

assign data_sram_wen   = es_mem_we && es_valid ? 
                        (inst_sw ?  4'hf : 
                         inst_sb ?  es_addr_low :
                         swl_0   ?  4'h1        :
                         swl_1   ?  4'h3        :
                         swl_2   ?  4'h7        :
                         swl_3   ?  4'hf        :
                         swr_0   ?  4'hf        :
                         swr_1   ?  4'he        :
                         swr_2   ?  4'hc        :
                         swr_3   ?  4'h8        :
                      /* inst_sh */ {{2{es_addr_low[3] | es_addr_low[2]}}, 
                                    {2{es_addr_low[1] | es_addr_low[0]}}}) : 4'h0;

assign data_sram_addr  = es_alu_result;

assign data_sram_wdata = inst_sb ? {     4{es_rt_value[ 7:0]}}  :
                         inst_sh ? {     2{es_rt_value[15:0]}}  :
                         swl_0   ? {     4{es_rt_value[31:24]}} :
                         swl_1   ? {     2{es_rt_value[31:16]}} :
                         swl_2   ? {8'h00, es_rt_value[31:8]}   :
                         swr_1   ? {es_rt_value[23:0], 8'h00}   :
                         swr_2   ? {     2{es_rt_value[15: 0]}} :
                         swr_3   ? {     4{es_rt_value[ 7: 0]}} :
        /*inst_sw | swl_3 | swr_0*/        es_rt_value          ;
                         

assign es_to_ds_fw = {es_load_op, es_valid & dest_valid, es_dest, es_result};

assign HI_in = (mult_op[1] || mult_op[0]) ? mult_result[63:32] :
               (div_op[0]               ) ? div_result [31:0 ] :
               (div_op[1]               ) ? divu_result[31:0 ] :
                                            es_rs_value        ;
assign LO_in = (mult_op[1] || mult_op[0]) ? mult_result[31:0 ] :
               (div_op[0]               ) ? div_result [63:32] :
               (div_op[1]               ) ? divu_result[63:32] :
                                            es_rs_value        ;

reg_HI_LO HI_LO(
    .clk        (clk  ) ,
    .HI_wen     (HI_wen),
    .LO_wen     (LO_wen),
    .HI_data_in (HI_in) ,
    .LO_data_in (LO_in) ,
    .HI_data_out(HI_out),
    .LO_data_out(LO_out)
);

mult mult_32_64(
    .mult_src1  (mult_src1),
    .mult_src2  (mult_src2),
    .mult_op    (mult_op  ),
    .mult_result(mult_result)
);

div div_32_64(
    .aclk                  (clk),
    .s_axis_divisor_tdata  (div_src2),
    .s_axis_divisor_tready (s_axis_divisor_tready),
    .s_axis_divisor_tvalid (s_axis_divisor_tvalid),
    .s_axis_dividend_tdata (div_src1),
    .s_axis_dividend_tready(s_axis_dividend_tready),
    .s_axis_dividend_tvalid(s_axis_dividend_tvalid),
    .m_axis_dout_tdata     (div_result),
    .m_axis_dout_tvalid    (m_axis_dout_tvalid)
);

divu divu_32_64(
    .aclk                  (clk),
    .s_axis_divisor_tdata  (div_src2),
    .s_axis_divisor_tready (s_axis_divisor_u_tready),
    .s_axis_divisor_tvalid (s_axis_divisor_u_tvalid),
    .s_axis_dividend_tdata (div_src1),
    .s_axis_dividend_tready(s_axis_dividend_u_tready),
    .s_axis_dividend_tvalid(s_axis_dividend_u_tvalid),
    .m_axis_dout_tdata     (divu_result),
    .m_axis_dout_tvalid    (m_axis_dout_u_tvalid)
);

endmodule

//HI LO register
module reg_HI_LO(
    input  clk                            ,
    input  HI_wen                         ,
    input  LO_wen                         ,
    input  [31:0] HI_data_in , LO_data_in ,
    output [31:0] HI_data_out, LO_data_out
);
    reg [31:0] HI, LO;

    always@(posedge clk) begin
        if(HI_wen) begin
            HI <= HI_data_in;
        end

        if(LO_wen) begin
            LO <= LO_data_in;
        end
    end

    assign HI_data_out = HI;
    assign LO_data_out = LO;
endmodule

//mult IP
module mult(
    input  [31:0] mult_src1  ,
    input  [31:0] mult_src2  ,
    input  [ 1:0] mult_op    ,  //[1:1] for unsigned, [0:0] for signed
    output [63:0] mult_result
);
    wire [63:0] unsigned_prod;
    wire [63:0] signed_prod  ;

    assign unsigned_prod = mult_src1 * mult_src2;
    assign signed_prod   = $signed(mult_src1) * $signed(mult_src2);

    assign mult_result = (mult_op[1] && !mult_op[0]) ? unsigned_prod :
                                                       signed_prod   ;
endmodule
