module mcu(
    input clk,
    input reset,
    input play_button,
    input next_button,
    output play,
    reg reset_player,
    output [1:0] song,
    input song_done
);

    // Implementation goes here!
    
    reg [1:0] next_song;
    reg next_play;
    
    dffr #(2) songFF (
        .clk(clk),
        .r(reset),
        .d(next_song),
        .q(song)
    );
    
    dffr playFF (
        .clk(clk),
        .r(reset),
        .d(next_play),
        .q(play)
    );
    
    always @(*) begin
        if (reset) begin
            next_song = 2'b0;
            next_play = 0;
            reset_player = 1;
        end
        else if (play_button) begin
            next_song = song;
            next_play = ~play;
            reset_player = 0;
        end
        else if (next_button) begin
            next_song = song + 2'b1;
            next_play = 0;
            reset_player = 1;
        end
        else if (song_done) begin
            next_song = song + 2'b1;
            next_play = 0;
            reset_player = 1;
        end
        else begin
            next_song = song;
            next_play = play;
            reset_player = 0;
        end
    end
endmodule
