
// Assuming block size to be 64 B
// Entry size = 1 B

module instruction_fetch(
    input clk,

    output reg [31:0] instruction_out,
    output reg signal
);

reg [31:0] instruction[0:67234];
integer counter;

initial begin
    counter<=0;
    signal<=0;
    $readmemh("instructionfinal4.mem",instruction);
end

always @(posedge clk) begin
    instruction_out<=instruction[counter];
    counter<=counter+1;
    signal<=~signal;
end

endmodule



module cache(
    input clk,
    input [instructionlength-offsetbits-setbits-1:0]tag,
    input [setbits-1:0]set,
    input [offsetbits-1:0]offset,
    input signal,

    output reg[0:0] hit
);

parameter sets = 16;
parameter waynumber = 16;
parameter instructionlength = 24;
parameter offsetbits = 6;   // one entry = 1 byte
parameter setbits = 4;


reg [instructionlength-offsetbits-setbits-1:0] tag_array [sets-1:0] [waynumber-1:0];
reg [16:0] LRU_counter [sets-1:0] [waynumber-1:0];
reg [0:0] valid_array [sets-1:0] [waynumber-1:0];

reg [5:0] ways;
integer position;
integer max;
integer tot_max;
integer i;
integer j;

initial begin
    for(j = 0; j < sets; j = j + 1) begin
        for(i = 0; i < waynumber; i = i + 1)begin
            LRU_counter[j][i] = 0;
        end
    end
end

initial begin
    j=0;
    i=0;
    ways=waynumber;
    $readmemb("tagzerofinal.mem",tag_array);
    $readmemb("validbits.mem",valid_array);
end

always @(signal) begin
    // $strobe(tag,set,offset);
    hit=0;
    for(i = 0; i < ways; i = i + 1)begin
        LRU_counter[set][i] = LRU_counter[set][i] + 1; 
    end
    tot_max = LRU_counter[set][0];
    max = 0;
    for(i = 0; i < ways; i = i + 1)begin
        if(LRU_counter[set][i] > tot_max) begin
            tot_max = LRU_counter[set][i];
            max = i;
        end
    end
    
    for( i = 0; i < ways; i = i + 1) begin
        if(tag_array[set][i] == tag && valid_array[set][i]==1) begin
            hit = 1'b1;
            position = i;
        end
    end
    
    if(hit==1'b0) begin
        tag_array[set][max]=tag;
        LRU_counter[set][max]=0;
        valid_array[set][max]=1;
    end
    else begin
        LRU_counter[set][position]=0;
        valid_array[set][position]=1;
    end
end

endmodule

module tb();

reg clk;
integer counter;
integer variable;

initial begin
    clk=0;
    counter=0;
    variable=0;
    #18150 $finish;
end

parameter instructionlength = 24;
parameter offsetbits = 6;
parameter setbits = 4;

wire [31:0] instruction;
wire signal;

instruction_fetch instruction_fetch(.clk(clk),.instruction_out(instruction),.signal(signal));

wire hit;

cache cache(.clk(clk),.offset(instruction[offsetbits-1:0]),.set(instruction[offsetbits+setbits-1:offsetbits]),.tag(instruction[instructionlength-1:offsetbits+setbits]),.hit(hit),.signal(signal));


always begin
    #1;
    clk=~clk;
    $strobe(hit,counter,variable);
end

always begin
    #2;
    if(hit==1'b1) begin
        counter=counter+1;
        variable+=1;
    end
    else begin
        counter=counter;
        variable+=1;
    end
end

endmodule