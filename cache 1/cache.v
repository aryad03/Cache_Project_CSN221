// DIMENSIONS-CACHE-:
// Two-way set associative
// 8 sets
// Block size = 2 bytes
// one entry in block = 1 byte

// DIMENSIONS-MAIN MEMORY-:
// 8 BLOCKS PER SET

//tag bits=3
//set bits=3
//offset bits=1

module cache(
    input [2:0]set,
    input [2:0]tag,
    input offset,
    input [7:0]data,
    input [15:0]block,
    input memRes,
    input control,
    input signal,
 //control: write=1, read=0

    output reg [7:0]data_out,
    output reg hit_out,
    output reg [2:0]set_out,
    output reg [2:0]tag_out,
    output reg offset_out,    
    output reg control_out,
    output reg evict_out,
    output reg [15:0]evict_block,
    output reg [2:0]evict_tag,
    output reg [2:0]evict_set,
    output reg memdone
);

reg [7:0]cache_memory[7:0][1:0][1:0];
reg [2:0]tag_array[7:0][1:0];
reg [0:0]valid_array[7:0][1:0];
reg [0:0]position;
reg [1:0]ways;

reg [9:0]LRU_counter[7:0][1:0];
integer i;
integer max;
integer tot_max;
integer j;

integer block_size; //in bytes
integer entry_size; //in bytes
integer no_of_entries;
integer var;
integer var2;
integer index;
integer index_end;
initial begin
    for(j = 3'b000; j <= 3'b111; j = j + 1) begin
        for(i = 0; i < 2; i = i + 1)begin
            LRU_counter[j][i] = 0;
        end
    end
end
initial begin
    memdone =1'b0;
    block_size=2;
    entry_size=1;
    no_of_entries=block_size/entry_size;
    var=1;
    j=1;
    var2=256;//2^entry size
    index=0;
    index_end=var-1;
    $readmemb("cachezero.mem",cache_memory);
    $readmemb("tagzero.mem",tag_array);
    $readmemb("validbits.mem",valid_array);
    evict_out=1'b0;
    // $strobe(tag_array[0][1]);
end

always @(signal) begin
    evict_out=1'b0;
end

always @(*) begin
    var=1;
    j=1;
    var2=256;//2^entry size
    evict_out=1'b0;
    case (memRes)
        1'b1:begin
            evict_block=15'b0;
            evict_tag=tag_array[set][max];
            // $strobe(evict_tag);
            // evict_block= cache_memory[set][max];
            for (i = no_of_entries-1; i >=0; i = i-1) begin
                evict_block+=cache_memory[set][max][i]*j;
                j=j*var2;
            end
            // $strobe(evict_block);
            evict_out=1'b1;
            evict_set=set;
            tag_array[set][max]=tag;
            valid_array[set][max]=1;
            LRU_counter[set][max]=0;

            for ( i = no_of_entries-1; i >=0; i = i - 1) begin
                if(control==1'b1 && i==offset) begin
                    cache_memory[set][max][i]= data;
                    var=var*var2;
                end
                else begin
                    cache_memory[set][max][i]= (block/var) % var2;
                    var=var*var2;
                end
            end
            data_out=cache_memory[set][max][offset];
            memdone=~memdone;
        end 
        1'b0: begin
            ways = 2'd2;
            hit_out = 1'b0;

            for(i = 0; i < ways; i = i + 1)begin
                LRU_counter[set][i] = LRU_counter[set][i] + 1; 
            end
            // $strobe(LRU_counter[0][0],LRU_counter[0][1],max);
            tot_max = LRU_counter[set][0];
            max = 0;
            for(i = 0; i < ways; i = i + 1)begin
                if(LRU_counter[set][i] >= tot_max) begin
                    tot_max = LRU_counter[set][i];
                    max = i;
                end
            end
            // $strobe(max,tot_max);
            // $strobe(memRes);
            


            for( i = 0; i < ways; i = i + 1) begin
                if(tag_array[set][i] == tag && valid_array[set][i]==1) begin
                    hit_out = 1'b1;
                    position = i;
                end
            end
            // $strobe(position,set);

            case (control)
                1'b0: begin
                    case (hit_out)
                        1'b1:begin
                            data_out = cache_memory[set][position][offset];
                            LRU_counter[set][position]=1'b0;
                        end 
                        1'b0: begin
                            control_out = control;
                            data_out = data;
                            tag_out = tag;
                            set_out = set;
                            offset_out = offset;
                            LRU_counter[set][max]=1'b0;
                        end
                        // default: data_out = 0;
                    endcase
                end
                1'b1: begin
                    case (hit_out)
                        1'b1: begin
                            cache_memory[set][position][offset] = data;
                            LRU_counter[set][position]=1'b0;
                        end
                        1'b0: begin
                            control_out = control;
                            data_out = data;
                            tag_out = tag;
                            set_out = set;
                            offset_out = offset;
                            LRU_counter[set][max]=1'b0;
                        end
                        // default: ;
                    endcase
                end
            endcase
        end
    endcase
    // $strobe(tag_array[0][0],tag_array[0][1]);
    //$strobe(LRU_counter[0][0],LRU_counter[0][1],max);
    // $strobe(tag_array[1][1]);

end


endmodule


module memory(
    input clk,
    input [2:0]set,
    input [2:0]tag,
    input offset,
    input [7:0]data,
    input control,
    input hit_in,
    input evict,
    input [15:0]evict_block,
    input [2:0]evict_tag,
    input [2:0]evict_set,
    input memdone,

    output reg [15:0]block,
    output reg [2:0]set_out,
    output reg [2:0]tag_out,
    output reg offset_out,
    output reg data_out,
    output reg control_out,
    output reg memRes,
    output reg signal
);

reg [7:0]main_memory[7:0][7:0][1:0];
integer block_size; //in bytes
integer entry_size; //in bytes
integer no_of_entries;
integer var;
integer var2;
integer j;
integer i;

initial begin
    block_size=2;
    entry_size=1;
    signal=1'b0;
    no_of_entries=block_size/entry_size;
    var2=256; //2 to the power entry size
    j=1;
    $readmemb("mainmemory.mem",main_memory);
end
always @(memdone) begin
    memRes=1'b0;
end

always @(posedge evict) begin
    var2=256; //2 to the power entry size
    j=1;
    var=1;
    // $strobe(evict_block);
    for ( i = no_of_entries-1; i >=0; i = i - 1) begin
        main_memory[evict_tag][evict_set][i]<= (evict_block/var) % var2;
        var=var*var2;
    end
    // $strobe(evict_tag,evict_set);
    // $strobe(main_memory[2][0][0]);
    signal=~signal;
end

always @(negedge clk) begin
    var2=256; //2 to the power entry size
    j=1;
    var=1;
    case (hit_in)
        1'b0: begin
            block = 16'b0;
            // $strobe(main_memory[3][0][0],main_memory[3][0][1]);
            for (i = no_of_entries-1; i >=0; i = i-1) begin
                block+=main_memory[tag][set][i]*j;
                j=j*var2;
            end
            // $strobe(block);
            control_out = control;
            data_out = data;
            tag_out = tag;
            set_out = set;
            offset_out = offset;
            memRes = 1'b1;
        end
        default: memRes = 1'b0;
    endcase
    // $strobe(main_memory[3][1][0]);
end

endmodule

module instruction_fetch(
    input clk,
    input stall,

    output reg [15:0] instruction_out
);

reg [15:0] instruction[0:1010];
integer counter;

initial begin
    counter<=0;
    $readmemb("instruction.mem",instruction);
end

always @(posedge clk) begin
    instruction_out<=instruction[counter];
    counter<=counter+1;
end

endmodule


module tb();

reg clk;
integer counter;
integer hitrate;

initial begin
    clk=0;
    counter=0;
    hitrate=0;
    #2000 $finish;
end

wire[15:0] instruction;

instruction_fetch instruction_fetch(.clk(clk),.instruction_out(instruction));

wire [7:0]data_out;
wire hit_out;
wire [2:0]set_out;
wire [2:0]tag_out;
wire offset_out;
wire control_out;
wire memdone;
wire evict;
wire [15:0]evict_block;
wire [2:0]evict_tag;
wire signal;
wire [2:0]evict_set;

cache cache(.set(instruction[3:1]),.tag(instruction[6:4]),.offset(instruction[0]),.data(instruction[14:7]),.block(block_mem),.memRes(memres_mem),.control(instruction[15]),.data_out(data_out),.hit_out(hit_out),.set_out(set_out),.tag_out(tag_out),.offset_out(offset_out),.control_out(control_out),.memdone(memdone),.evict_out(evict),.evict_block(evict_block),.evict_tag(evict_tag),.signal(signal),.evict_set(evict_set));

wire [15:0]block_mem;
wire [2:0]set_out_mem;
wire [2:0]tag_out_mem;
wire offset_mem;
wire data_out_mem;
wire control_out_mem;
wire memres_mem;

memory memory(.clk(clk),.evict_set(evict_set),.set(set_out),.memdone(memdone),.tag(tag_out),.offset(offset_mem),.data(data_out),.hit_in(hit_out),.control(control_out),.block(block_mem),.set_out(set_out_mem),.tag_out(tag_out_mem),.offset_out(offset_mem),.data_out(data_out_mem),.control_out(control_out_meme),.memRes(memres_mem),.evict(evict),.evict_block(evict_block),.evict_tag(evict_tag),.signal(signal));


always begin
    #1;
    clk=~clk;
    $strobe(hit_out,counter);
end

always begin
    #2;
    if(hit_out==1'b1) begin
        counter=counter+1;
    end
    else begin
        counter=counter;
    end
end


endmodule
