`timescale 1ns/1ps

// Generic count-and-data scoreboard example. No project vectors are included.
module scoreboard_skeleton #(
    parameter integer DATA_WIDTH = 32,
    parameter integer EXPECTED_COUNT = 16
) (
    input  wire                  clk,
    input  wire                  reset_n,
    input  wire                  actual_valid,
    input  wire [DATA_WIDTH-1:0] actual_data,
    output reg                   test_done,
    output reg                   test_passed
);

    reg [DATA_WIDTH-1:0] expected [0:EXPECTED_COUNT-1];
    integer index;
    integer mismatch_count;

    initial begin
        index = 0;
        mismatch_count = 0;
        test_done = 1'b0;
        test_passed = 1'b0;
        // Populate expected[] with a reviewed public fixture when used.
    end

    always @(posedge clk) begin
        if (!reset_n) begin
            index <= 0;
            mismatch_count <= 0;
            test_done <= 1'b0;
            test_passed <= 1'b0;
        end
        else if (actual_valid && !test_done) begin
            if (actual_data !== expected[index])
                mismatch_count <= mismatch_count + 1;

            if (index == EXPECTED_COUNT-1) begin
                test_done <= 1'b1;
                test_passed <= (mismatch_count == 0) &&
                               (actual_data === expected[index]);
            end
            else begin
                index <= index + 1;
            end
        end
    end

endmodule

