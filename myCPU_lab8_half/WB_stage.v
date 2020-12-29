`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc      ,
    output [ 3:0] debug_wb_rf_wen  ,
    output [ 4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata,
    //foward data path
    output [`FW_DATA         -1:0] ws_to_ds_fw
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        dest_valid;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ms_result;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire [ 2:0] cp0_choose;
wire        mtc0_we;
wire        ws_is_mfc0;
wire        ws_is_mtc0;
wire        ws_ex;
wire        ws_bd;
wire        eret_flush;
wire        ex_flush;
wire [ 4:0] ws_excode;
wire [ 5:0] ext_int_in;
wire [ 7:0] cp0_waddr;
wire [31:0] ws_badvaddr;
wire [31:0] cp0_result;
wire [ 2:0] ws_ex_type;

assign mtc0_we = ws_valid && ws_is_mtc0 && !ws_ex;
assign ws_ex = (ws_ex_type != 3'b0 && ws_valid) ? 1'b1 : 1'b0;
assign ws_excode = (ws_ex_type == `SYSCALL) ? 5'h08 : 5'h00;
assign ex_flush = (ws_ex || eret_flush) && ws_valid;

assign {ws_ex_type     ,  //87:87
        eret_flush     ,  //84:84
        cp0_waddr      ,  //83:76
        cp0_choose     ,  //75:73
        ws_is_mtc0     ,  //72:72
        ws_is_mfc0     ,  //71:71
        dest_valid     ,  //70:70
        ws_gr_we       ,  //69:69
        ws_dest        ,  //68:64
        ms_result,        //63:32
        ws_pc             //31:0
       } = ms_to_ws_bus_r;

assign ws_final_result = ws_is_mfc0 ? cp0_result : ms_result;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

assign ws_to_ds_fw = {ws_valid & dest_valid, ws_dest, ws_final_result};

cp0_regs ws_cp0_regs(
    .clk        (clk)     ,
    .reset      (reset)   ,
    .mtc0_we    (mtc0_we)  ,
    .ws_ex      (ws_ex)  ,
    .ws_bd      (ws_bd)  ,
    .eret_flush (eret_flush) ,
    .cp0_choose (cp0_choose) ,
    .ws_excode  (ws_excode)  ,
    .ext_int_in (ext_int_in) ,
    .cp0_waddr  (cp0_waddr)  ,
    .cp0_wdata  (ms_result)  ,
    .ws_pc      (ws_pc)      ,
    .ws_badvaddr(ws_badvaddr),
    .cp0_rdata  (cp0_result)
);

endmodule
