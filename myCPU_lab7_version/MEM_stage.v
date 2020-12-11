`include "mycpu.h"

module mem_stage(
    input                          clk            ,
    input                          reset          ,
    //allowin
    input                          ws_allowin     ,
    output                         ms_allowin     ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus   ,
    //to ws
    output                         ms_to_ws_valid ,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus   ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    //foward data path
    output [`FW_DATA         -1:0] ms_to_ds_fw
);

reg         ms_valid;
wire        ms_ready_go;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        dest_valid;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;

wire        inst_lw;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;

wire [ 3:0] ms_addr_low;

wire [ 7:0] lb_lbu_origin_result;
wire [15:0] lh_lhu_origin_result;

wire [31:0] lw_result;
wire [31:0] lb_result;
wire [31:0] lbu_result;
wire [31:0] lh_result;
wire [31:0] lhu_result;

assign {inst_lhu       ,  //76:76
        inst_lh        ,  //75:75
        inst_lbu       ,  //74:74
        inst_lb        ,  //73:73
        inst_lw        ,  //72:72
        dest_valid     ,  //71:71
        ms_res_from_mem,  //70:70
        ms_gr_we       ,  //69:69
        ms_dest        ,  //68:64
        ms_alu_result  ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {dest_valid     ,  //70:70
                       ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;     //check
    end
end

assign ms_addr_low[0] = (ms_alu_result[1:0] == 2'b00);
assign ms_addr_low[1] = (ms_alu_result[1:0] == 2'b01);
assign ms_addr_low[2] = (ms_alu_result[1:0] == 2'b10);
assign ms_addr_low[3] = (ms_alu_result[1:0] == 2'b11);

assign lb_lbu_origin_result = ms_addr_low[0] ? data_sram_rdata[ 7:0] :
                              ms_addr_low[1] ? data_sram_rdata[15:8] :
                              ms_addr_low[2] ? data_sram_rdata[23:16]:
                          /*ms_addr_low[3]*/   data_sram_rdata[31:24];

assign lh_lhu_origin_result = (ms_addr_low[3] || ms_addr_low[2]) ? data_sram_rdata[31:16] :
                            /*ms_addr_low[1] || ms_addr_low[0]*/   data_sram_rdata[15: 0] ;
assign lw_result  = data_sram_rdata;
assign lb_result  = {{24{lb_lbu_origin_result[ 7]}}, lb_lbu_origin_result};
assign lbu_result = {24'b0, lb_lbu_origin_result};
assign lh_result  = {{16{lh_lhu_origin_result[15]}}, lh_lhu_origin_result};
assign lhu_result = {16'b0, lh_lhu_origin_result};

assign mem_result = inst_lw  ? lw_result :
                    inst_lb  ? lb_result :
                    inst_lbu ? lbu_result:
                    inst_lh  ? lh_result :
                    inst_lhu ? lhu_result:
                               data_sram_rdata;

assign ms_final_result = ms_res_from_mem ? mem_result
                                         : ms_alu_result;

assign ms_to_ds_fw = {ms_valid & dest_valid, ms_dest, ms_final_result};

endmodule
