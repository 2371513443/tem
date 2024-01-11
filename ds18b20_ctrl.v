
module ds18b20_ctrl(
   input                       sys_clk     , //时钟信号 50MHz
   input                       sys_rst_n   , //复位信号，低有效

   output     [13:0]           temp_data_r ,//温度数据十进制
   output reg                  temp_sign   ,//温度正负符号
   output reg                  temp_over   ,
   inout                       dq           //总线

);
//参数定义
parameter TIME_1US               = 5'd24          ;
parameter TIME_750MS             = 20'd749_999    ;
parameter IDLE                   = 4'd0           ;
parameter RESET_PULSES           = 4'd1           ;
parameter PRESENCE_PULSES        = 4'd2           ;
parameter WR_RCC_CMD             = 4'd3           ;
parameter WAIT_750MS             = 4'd4           ;
parameter RESET_PULSES_2         = 4'd5           ;
parameter PRESENCE_PULSES_2      = 4'd6           ;
parameter WR_RCC_CMD_2           = 4'd7           ;
parameter RD_TEMP                = 4'd8           ;
parameter CC44              = 16'b0100010011001100;
parameter CCBE              = 16'b1011111011001100;
        
//信号定义
reg    [4:0 ]   cnt_1us                           ;
reg    [19:0]   cnt_us                            ;
reg            dq_out,dq_en                       ;
wire           dq_in                              ;
wire            end_cnt_us                        ;
assign          dq=dq_en?dq_out:1'bz              ;
assign          dq_in=dq                          ;
reg             clk_us                            ;
reg    [3:0 ]   state_c                           ;
reg    [3:0 ]   state_n                           ;
reg    [3:0 ]   bit_num                           ; 
reg             start_flag                        ;
reg    [15:0]   data                              ;
reg    [15:0]   data_r                            ;
reg    [20:0]   temp_data                         ;//温度数据
//逻辑组成
assign temp_data_r=temp_data/100;
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        cnt_1us <= 5'd0;
    end 
    else if(cnt_1us==TIME_1US)begin 
        cnt_1us <= 5'd0;
    end 
    else begin 
        cnt_1us <= cnt_1us + 1'd1;
    end 
end
//微秒计数器
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        clk_us <= 1'd0;
    end 
    else if(cnt_1us==TIME_1US)begin 
        clk_us <= ~clk_us;
    end 
    else begin 
        clk_us <= clk_us;
    end 
end
//微秒时钟
always @(posedge clk_us or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        cnt_us <= 20'd0;
    end 
    else if(end_cnt_us)begin 
        cnt_us <= 20'd0;
    end 
    else begin 
        cnt_us <= cnt_us + 1'd1;
    end 
end
always @(posedge sys_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        temp_over <= 1'b0;
    end
    else if(state_c==RD_TEMP&&cnt_us==64&&bit_num==15)begin
        temp_over <= 1'b1;
    end
    else begin
        temp_over <= 1'b0;
    end
end
assign end_cnt_us=(cnt_us==499&&(state_c==RESET_PULSES||state_c==RESET_PULSES_2||state_c==PRESENCE_PULSES||state_c==PRESENCE_PULSES_2))||(state_c==RD_TEMP&&cnt_us==64)||(cnt_us==74&&(state_c==WR_RCC_CMD||state_c==WR_RCC_CMD_2))||state_c==IDLE||(state_c==WAIT_750MS&&cnt_us==TIME_750MS);
//一段状态机
always @(posedge clk_us or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        state_c <= IDLE;
    end 
    else begin 
        state_c <= state_n;
    end 
end

//取下降沿为开始信号
always @(posedge clk_us or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        start_flag <= 1'b0;
    end
    else if(state_c==PRESENCE_PULSES||PRESENCE_PULSES_2)begin
        if(cnt_us==70&&dq_in==0)begin
            start_flag <= 1'b1;
        end
        else begin
            start_flag <= start_flag;
        end
    end
    else begin
        start_flag <= 1'b0;
    end
end
//bit计数器
always @(posedge clk_us or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        bit_num <= 4'd0;
    end
    else if(state_c==WR_RCC_CMD||WR_RCC_CMD_2||RD_TEMP)begin
        if((state_c==WR_RCC_CMD&&cnt_us==74)||(state_c==WR_RCC_CMD_2&&cnt_us==74)||(state_c==RD_TEMP&&cnt_us==64))begin
            bit_num <= bit_num + 1'd1;
        end
        else begin
            bit_num <= bit_num;
        end
    end
    else begin
        bit_num <= 4'd0;
    end
end
//二段状态机
always @(*)begin 
    case (state_c)
        IDLE             :begin
            state_n = RESET_PULSES;
        end
        RESET_PULSES     :begin
            if(cnt_us==499)begin
                state_n = PRESENCE_PULSES;
            end
            else begin
                state_n = RESET_PULSES;
            end
        end
        PRESENCE_PULSES  :begin
            if(start_flag==1 &&cnt_us==499)begin
                state_n = WR_RCC_CMD;
            end
            else if(start_flag==0&&cnt_us==499)begin
                state_n = IDLE;
            end
            else begin
                state_n = PRESENCE_PULSES;
            end
        end
        WR_RCC_CMD       :begin
            if(cnt_us==74&&bit_num==15)begin
                state_n = WAIT_750MS;
            end
            else begin
                state_n = WR_RCC_CMD;
            end
        end
        WAIT_750MS       :begin
            if(cnt_us==TIME_750MS)begin
                state_n = RESET_PULSES_2;
            end
            else begin
                state_n = WAIT_750MS;
            end
        end
        RESET_PULSES_2   :begin
            if(cnt_us==499)begin
                state_n = PRESENCE_PULSES_2;
            end
            else begin
                state_n = RESET_PULSES_2;
            end
        end
        PRESENCE_PULSES_2:begin
            if(start_flag==1&&cnt_us==499)begin
                state_n = WR_RCC_CMD_2;
            end
            else if(start_flag==0&&cnt_us==499)begin
                state_n = IDLE;
            end
            else begin
                state_n = PRESENCE_PULSES_2;
            end
        end
        WR_RCC_CMD_2     :begin
            if(cnt_us==74&&bit_num==15)begin
                state_n = RD_TEMP;
            end
            else begin
                state_n = WR_RCC_CMD_2;
            end
        end
        RD_TEMP          :begin
            if(cnt_us==64&&bit_num==15)begin
                state_n = IDLE;
            end
            else begin
                state_n = RD_TEMP;
            end
        end
        default: state_n = IDLE;
    endcase
end
//三段状态机
always @(*) begin
    if(!sys_rst_n)begin
            dq_out=1'b0;
            dq_en =1'b0;
    end
    case (state_c)
        IDLE             :begin
            dq_out=1'b0;
            dq_en =1'b0;
        end
        RESET_PULSES     :begin
            dq_out=1'b0;
            dq_en =1'b1;
        end
        PRESENCE_PULSES  :begin
            dq_out=1'b0;
            dq_en =1'b0;
        end
        WR_RCC_CMD       :begin
            if(cnt_us>62)begin
               dq_out=1'b0;
               dq_en =1'b0; 
            end
            else if(cnt_us<=1)begin
                dq_out=1'b0;
                dq_en =1'b1; 
            end
            else if(CC44[bit_num]==0)begin
                dq_out=1'b0;
                dq_en =1'b1; 
            end
            else if(CC44[bit_num]==1)begin
                dq_out=1'b0;
                dq_en =1'b0; 
            end
        end
        WAIT_750MS       :begin
            dq_out=1'b1;
            dq_en =1'b1;
        end
        RESET_PULSES_2   :begin
            dq_out=1'b0;
            dq_en =1'b1;
        end
        PRESENCE_PULSES_2:begin
            dq_out=1'b0;
            dq_en =1'b0;
        end
        WR_RCC_CMD_2     :begin
            if(cnt_us>62)begin
               dq_out=1'b0;
               dq_en =1'b0; 
            end
            else if(cnt_us<=1)begin
                dq_out=1'b0;
                dq_en =1'b1; 
            end
            else if(CCBE[bit_num]==0)begin
                dq_out=1'b0;
                dq_en =1'b1; 
            end
            else if(CCBE[bit_num]==1)begin
                dq_out=1'b0;
                dq_en =1'b0; 
            end
        end
        RD_TEMP          :begin
            if(cnt_us<=2)begin
                    dq_out=1'b0;
                    dq_en =1'b1;
                end
            else begin
                dq_out=1'b0;
                dq_en =1'b0;
            end
        end
        default: begin
            dq_out=1'b0;
            dq_en =1'b0;
        end
    endcase
end
//获取输入dq
always @(posedge clk_us or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        data <= 16'd0;
    end
    else if(state_c==RD_TEMP)begin
        if(cnt_us==14)begin
            data[bit_num] <= dq_in;
        end
        else begin
            data <= data;
        end
    end
    else begin
        data <= 16'd0;
    end
end
//将补码转换为原码
always @(posedge clk_us or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        data_r <= 16'd0;
    end 
    else if(state_c==IDLE)begin
        data_r <= 16'd0;
    end
    else if((data[15]==1)&&state_c==RD_TEMP&&cnt_us==20&&bit_num==15)begin 
        data_r <= ~data + 1;
    end 
    else if((data[15]==0)&&state_c==RD_TEMP&&cnt_us==20&&bit_num==15)begin
        data_r <= data;
    end
    else begin
        data_r <= data_r;
    end
end
//获取温度值
always @(posedge clk_us or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
        temp_data <= 21'd0; 
    end
    else if(state_c==RD_TEMP&&cnt_us==63&&bit_num==15)begin
        temp_data <= data_r[0]*625+data_r[1]*1250+data_r[2]*2500+data_r[3]*5000+data_r[4]*10000+data_r[5]*20000+data_r[6]*40000+data_r[7]*80000+data_r[8]*160000+data_r[9]*320000+data_r[10]*640000;
    end
    else begin
        temp_data <= temp_data ;
    end
end
//获取符号位
always @(posedge sys_clk or negedge sys_rst_n)begin 
    if(!sys_rst_n)begin
        temp_sign <= 1'b0;
    end 
    else if(state_c==RD_TEMP&&cnt_us==63&&bit_num==15)begin 
        temp_sign <= data[15];
    end 
    else begin 
        temp_sign <= temp_sign ;
    end 
end

endmodule

