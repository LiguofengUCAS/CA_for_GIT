`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en                    ,
    output [ 3:0] inst_sram_wen                   ,
    output [31:0] inst_sram_addr                  ,
    output [31:0] inst_sram_wdata                 ,
    input  [31:0] inst_sram_rdata                 ,
    //flush
    input                          ex_flush       ,
    input                          ws_ex          ,
    //exception return addr from ws
    input  [`WS_TO_FS_BUS_EX -1:0] ex_return
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
assign {br_taken,br_target} = br_bus;

wire       adel_fs;
wire [3:0] fs_ex_type;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_ex_type,    //67:64
                       fs_inst   ,    //63:32
                       fs_pc     };   //31:0
wire        eret_flush;
wire [31:0] epc;

assign {eret_flush, epc} = ex_return;
//assign ex_return = {eret_flush, epc};  in ws


// pre-IF stage
assign to_fs_valid  = ~reset;
assign seq_pc       = fs_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc; 

// IF stage
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ex_flush;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if(ex_flush) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if(ws_ex) begin
        fs_pc <= 32'hbfc0037c;
    end
    else if(eret_flush) begin
        fs_pc <= epc - 3'h4;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata;

//IF ADEL
assign adel_fs = (fs_pc[1:0] != 2'b0) ? 1'b1 : 1'b0;

assign fs_ex_type = adel_fs ? `ADEL_IF : 4'b0;

endmodule
