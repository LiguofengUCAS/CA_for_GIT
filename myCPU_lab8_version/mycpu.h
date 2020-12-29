`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD       33      //check
    `define FS_TO_DS_BUS_WD 64
    `define DS_TO_ES_BUS_WD 175
    `define ES_TO_MS_BUS_WD 129
    `define MS_TO_WS_BUS_WD 121
    `define WS_TO_RF_BUS_WD 39
    `define FW_DATA         39      //is_mfc0, is_load, foward data and register number
    `define WS_TO_FS_BUS_EX 33
    
    `define COUNT        8'b01001000  //$9
    `define COMPARE      8'b01011000  //$11
    `define STATUS       8'b01100000  //$12
    `define CAUSE        8'b01101000  //$13
    `define EPC          8'b01110000  //$14

    `define SYSCALL         3'b001

`endif
