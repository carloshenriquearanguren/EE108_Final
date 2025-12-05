module song_reader (
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input beat,
    input backwards,
    output song_done,

    output reg [5:0] note0, output reg [5:0] duration0, output reg load_note0,
    output reg [5:0] note1, output reg [5:0] duration1, output reg load_note1,
    output reg [5:0] note2, output reg [5:0] duration2, output reg load_note2
);

    localparam S_IDLE       = 3'd0;
    localparam S_READ       = 3'd1;
    localparam S_WAIT_ROM   = 3'd2;
    localparam S_PARSE      = 3'd3;
    localparam S_WAIT_TIME  = 3'd4;
    localparam S_DONE       = 3'd5;

    wire [2:0] state;
    wire [6:0] note_index;
    wire [5:0] wait_counter;
    wire [1:0] next_voice_q;
    wire backwards_latched;  // Latch direction at song start

    reg [2:0] next_state;
    reg [6:0] next_note_index;
    reg [5:0] next_wait_counter;
    reg [1:0] next_next_voice;
    reg next_backwards_latched;
    reg done;

    dffr #(3) state_ff (.clk(clk), .r(reset), .d(next_state), .q(state));
    dffr #(7) note_idx_ff (.clk(clk), .r(reset), .d(next_note_index), .q(note_index));
    dffr #(6) wait_cnt_ff (.clk(clk), .r(reset), .d(next_wait_counter), .q(wait_counter));
    dffr #(2) voice_ff (.clk(clk), .r(reset), .d(next_next_voice), .q(next_voice_q));
    dffr #(1) back_latch_ff (.clk(clk), .r(reset), .d(next_backwards_latched), .q(backwards_latched));

    // --- ROM Interface ---
    wire [8:0] addr = {song, note_index};
    wire [15:0] rom_out;
    song_rom rom_inst (.clk(clk), .addr(addr), .dout(rom_out));

    // --- Parsing Logic ---
    wire is_wait_cmd = rom_out[15];
    wire [5:0] cmd_val = rom_out[14:9];
    wire [5:0] cmd_dur = rom_out[8:3];
    
    // End detection
    wire is_end_marker = (!is_wait_cmd && cmd_val == 6'd0 && cmd_dur == 6'd0);
    wire at_start = (note_index == 7'd0);
    
    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        next_note_index = note_index;
        next_wait_counter = wait_counter;
        next_next_voice = next_voice_q;
        next_backwards_latched = backwards_latched;
        done = 1'b0;

        load_note0 = 0; note0 = 0; duration0 = 0;
        load_note1 = 0; note1 = 0; duration1 = 0;
        load_note2 = 0; note2 = 0; duration2 = 0;

        case (state)
            S_IDLE: begin
                // Latch direction and set starting position
                next_backwards_latched = backwards;
                next_note_index = backwards ? 7'd127 : 7'd0;
                next_next_voice = 2'd0;
                if (play) next_state = S_READ;
            end

            S_READ:     next_state = S_WAIT_ROM;
            S_WAIT_ROM: next_state = S_PARSE;

            S_PARSE: begin
                if (!play) begin
                    // Paused - stay here
                    next_state = S_PARSE;
                end 
                else if (backwards_latched && at_start) begin
                    // Going backwards and reached start
                    next_state = S_DONE;
                end
                else if (!backwards_latched && is_end_marker) begin
                    // Going forward and hit end marker
                    next_state = S_DONE;
                end 
                else if (is_wait_cmd) begin
                    // WAIT command
                    next_wait_counter = cmd_val;
                    next_state = S_WAIT_TIME;
                end 
                else if (cmd_val == 6'd0 && cmd_dur == 6'd0) begin
                    // Empty slot - skip it
                    if (backwards_latched) begin
                        if (note_index > 0) begin
                            next_note_index = note_index - 7'd1;
                            next_state = S_READ;
                        end else begin
                            next_state = S_DONE;
                        end
                    end else begin
                        next_note_index = note_index + 7'd1;
                        next_state = S_READ;
                    end
                end
                else begin
                    // NOTE command - dispatch to voice
                    case (next_voice_q)
                        2'd0: begin note0 = cmd_val; duration0 = cmd_dur; load_note0 = 1; end
                        2'd1: begin note1 = cmd_val; duration1 = cmd_dur; load_note1 = 1; end
                        2'd2: begin note2 = cmd_val; duration2 = cmd_dur; load_note2 = 1; end
                        default: begin note0 = cmd_val; duration0 = cmd_dur; load_note0 = 1; end
                    endcase
                    
                    next_next_voice = (next_voice_q == 2'd2) ? 2'd0 : next_voice_q + 2'd1;
                    
                    // Move to next address
                    if (backwards_latched) begin
                        if (note_index > 0) begin
                            next_note_index = note_index - 7'd1;
                            next_state = S_READ;
                        end else begin
                            next_state = S_DONE;
                        end
                    end else begin
                        next_note_index = note_index + 7'd1;
                        next_state = S_READ;
                    end
                end
            end

            S_WAIT_TIME: begin
                if (play && beat) begin
                    if (wait_counter <= 6'd1) begin
                        // Move to next address
                        if (backwards_latched) begin
                            if (note_index > 0) begin
                                next_note_index = note_index - 7'd1;
                                next_state = S_READ;
                            end else begin
                                next_state = S_DONE;
                            end
                        end else begin
                            next_note_index = note_index + 7'd1;
                            next_state = S_READ;
                        end
                    end else begin
                        next_wait_counter = wait_counter - 6'd1;
                    end
                end
            end

            S_DONE: begin
                done = 1'b1;
                next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    assign song_done = done;

endmodule
