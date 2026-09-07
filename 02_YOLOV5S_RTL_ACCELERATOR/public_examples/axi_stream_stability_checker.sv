`timescale 1ns/1ps

// Independent public example. This is not production accelerator RTL.
module axi_stream_stability_checker #(
    parameter integer DATA_WIDTH = 32,
    parameter integer KEEP_WIDTH = DATA_WIDTH / 8
) (
    input  wire                  aclk,
    input  wire                  aresetn,
    input  wire [DATA_WIDTH-1:0] tdata,
    input  wire [KEEP_WIDTH-1:0] tkeep,
    input  wire                  tlast,
    input  wire                  tvalid,
    input  wire                  tready
);

`ifdef FORMAL_OR_ASSERTION
    // Once VALID is asserted, payload must remain stable until accepted.
    property p_payload_stable_while_stalled;
        @(posedge aclk) disable iff (!aresetn)
        tvalid && !tready |=> tvalid && $stable({tdata, tkeep, tlast});
    endproperty

    assert property (p_payload_stable_while_stalled);
`endif

endmodule

