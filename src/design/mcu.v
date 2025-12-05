module mcu(
    input clk,
    input reset,
    input play_button,
    input next_button,
    input reverse_button,
    output play,
    output reg reset_player,
    output [1:0] song,
    output backwards,
    input song_done
);

    reg [1:0] next_song;
    reg next_play;
    reg next_backwards;
    
    dffr #(2) songFF (.clk(clk), .r(reset), .d(next_song), .q(song));
    dffr #(1) playFF (.clk(clk), .r(reset), .d(next_play), .q(play));
    dffr #(1) backFF (.clk(clk), .r(reset), .d(next_backwards), .q(backwards));
    
    always @(*) begin
        // Defaults: hold state
        next_song = song;
        next_play = play;
        next_backwards = backwards;
        reset_player = 1'b0;
        
        if (reset) begin
            next_song = 2'b0;
            next_play = 1'b0;
            next_backwards = 1'b0;
            reset_player = 1'b1;
        end
        else if (play_button) begin
            // Toggle play/pause, keep direction
            next_play = ~play;
        end
        else if (next_button) begin
            // Next song, forward direction
            next_song = song + 2'b1;
            next_play = 1'b0;
            next_backwards = 1'b0;
            reset_player = 1'b1;
        end
        else if (reverse_button) begin
            // Play backwards from end
            next_backwards = 1'b1;
            next_play = 1'b0;
            reset_player = 1'b1;
        end
        else if (song_done) begin
            // Song finished, go to next
            next_song = song + 2'b1;
            next_play = 1'b0;
            next_backwards = 1'b0;
            reset_player = 1'b1;
        end
    end
endmodule
