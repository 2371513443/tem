
module ds18b20_top(
   input                       sys_clk     , //时钟信号 50MHz
   input                       sys_rst_n   , //复位信号，低有效
   output             [05:00]  dig_sel     , //
   output             [07:00]  dig_seg     , //
   output                      tx          ,
   inout                       dq           //总线
);
wire        [13:0]              temp_data_r     ;
wire                            temp_sign       ;
reg         [ 7:0 ]             data            ;
wire							rdreq			;
wire							wrreq			;
wire							empty			;
wire							full			;
wire		[ 7:0 ]			    data_in			;
reg								send_flag		;
reg								flag			;
reg			[ 3:0 ]				cnt_byte		;
wire                            temp_over       ;
wire        [19:0]              temp            ;
reg		    [25:00]			    cnt             ;	
wire						    add_cnt         ;
wire						    end_cnt         ;
assign temp[3:0]   =temp_data_r%10;
assign temp[7:4]   =temp_data_r/10%10;
assign temp[11:8]  =temp_data_r/100%10;
assign temp[15:12] =temp_data_r/1000%10;
assign temp[19:16] =temp_data_r/10000%10;
parameter TIME_1S = 26'd49999999;
ds18b20_ctrl u_ds18b20_ctrl(
    .sys_clk     (sys_clk     ),
    .sys_rst_n   (sys_rst_n   ),
    .temp_data_r (temp_data_r ),
    .temp_sign   (temp_sign   ),
    .temp_over   (temp_over   ),
    .dq          (dq          )
);

seg_driver u_seg_driver(
.Clk    (sys_clk    ),
.Rst_n  (sys_rst_n  ),
.point  (6'b111011  ),
.data_in(temp_data_r),
.sign   (temp_sign  ),
.dig_sel(dig_sel),
.dig_seg(dig_seg)
);

uart_tx u_uart_tx(
.sys_clk     (sys_clk     ),
.sys_rst_n   (sys_rst_n   ),
.start_flag_x(rdreq       ),
.baud_rate   (115200      ),
.data        (data_in     ),
.over_flag   (over_flag   ),
.tx          (tx          )
);

tx_fifo	tx_fifo_inst (
	.aclr ( ~sys_rst_n  ),
	.clock ( sys_clk),
	.data ( data ),
	.rdreq ( rdreq ),
	.wrreq ( wrreq ),
	.empty ( empty ),
	.full ( full ),
	.q ( data_in ),
	.usedw ( usedw_sig )
	);

assign rdreq = over_flag && ~empty;
assign wrreq = ~full && send_flag && flag;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        send_flag <= 0;
    end
    else if(cnt_byte==11)begin
        send_flag <= 0;
    end
    else if(cnt_byte==0&&end_cnt)begin
        send_flag <= ~send_flag;
    end
    else begin
        send_flag <= send_flag;
    end
end

always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        cnt <= 0;
    end 
    else if(add_cnt)begin 
        if(end_cnt)begin 
            cnt <= 0;
        end
        else begin 
            cnt <= cnt + 1;
        end 
    end
end 
assign add_cnt = 1;
assign end_cnt = add_cnt && cnt == TIME_1S ;

//数据计数器
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        cnt_byte <= 0;
    end
    else if(cnt_byte == 11) begin
        cnt_byte <= 0;
    end
    else if(send_flag==0)begin
        cnt_byte <= 0;
    end
    else if(send_flag) begin
        cnt_byte <= cnt_byte + 1;
    end
end
always @(*) begin
    if(!sys_rst_n) begin
        flag = 0;
    end
    else if(!send_flag) begin
        flag = 0;
    end
    else if(cnt_byte<5) begin
        flag = 1;
    end
    else if(cnt_byte==5&&temp_sign==1)begin
        flag = 1;
    end
    else if(cnt_byte==6&&data>48)begin
        flag = 1;
    end
    else if(cnt_byte>6)begin
        flag = 1;
    end
    else begin
        flag = 0;
    end
end
always @(*) begin
    if(!sys_rst_n) begin
        data =0;
    end
    else if(send_flag) begin
        case (cnt_byte)
            0 : data = 116;//t
            1 : data = 101;//e
            2 : data = 109;//m
            3 : data = 112;//p
            4 : data = 58 ;//:
            5 : data = 45 ;//-
            6 : data = temp[19:16] +  48 ;
            7 : data = temp[15:12] +  48 ;
            8 : data = temp[11:8]  +  48 ;
            9 : data = 46 ;//.
            10: data = temp[7:4]   +  48 ;
            11: data = temp[3:0]   +  48 ;
            default: data =0;
        endcase
    end
end
endmodule

