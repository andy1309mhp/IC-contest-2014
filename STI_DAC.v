module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output	reg	so_data, so_valid;

output  reg oem_finish;
output odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output reg [4:0] oem_addr;
output [7:0] oem_dataout;

//==============================================================================
reg[3:0] state,next_state;
parameter IDLE = 4'b0000;
parameter ODD1 = 4'b0001;
parameter EVEN1 = 4'b0010;
parameter ODD2 = 4'b0011;
parameter EVEN2 = 4'b0100;
parameter ODD3 = 4'b0101;
parameter EVEN3 = 4'b0110;
parameter ODD4 = 4'b0111;
parameter EVEN4 = 4'b1000;

//==============================================================================

reg[1:0] mem_state,n_mem_state;

parameter MEM_FORWARD = 2'b00;
parameter MEM_INV = 2'b01;

//==============================================================================
reg[31:0] in_buf;
reg[8:0] cnt;
reg[8:0] load_cnt;
reg so_valid_delay;
reg[13:0] pat_cnt;
//==============================================================================
reg [7:0] mem_buff;
reg [3:0] mem_cnt;
reg [3:0] mem_addr,n_mem_addr;
reg [4:0] n_oem_addr;
reg [3:0] wr_cnt;
reg [8:0] mem_fin;
reg n_flag;
reg n_pi_end;
wire flag;




always@(posedge clk or posedge reset)begin
	if(reset)begin
		state<=IDLE;
		mem_state<=MEM_FORWARD;
	end
	else begin
		state<=next_state;
		mem_state<=n_mem_state;
	end
end



////////////////////////////////////STI Control/////////////////////////////////
always@(posedge clk or posedge reset)begin
	if(reset)begin
		so_valid<=0;
		cnt<=0;
		so_data<=0;
		so_valid<=0;
		pat_cnt<=0;
	end
	else begin
		if(so_valid_delay)begin
			so_valid<=1;
			cnt<=0;
			pat_cnt<=pat_cnt+1;
			if(pi_msb)begin
				case(pi_length)
					2'b00:begin
						if(pi_low) 
						    so_data<=in_buf[15];
						else
							so_data<=in_buf[7];
					end
					2'b01:so_data<=in_buf[15];
					2'b10:so_data<=in_buf[23];
					2'b11:so_data<=in_buf[31];
				endcase
			end
			else begin
				if(pi_length==2'b00)begin
					if(pi_low)
						so_data<=in_buf[8];
					else
						so_data<=in_buf[0];
				end
				else
					so_data<=in_buf[cnt];
			end
		end
		else begin
			case(pi_length)
				2'b00:begin
					if(cnt==7 || !so_valid)begin
						so_valid<=0;
						cnt<=0;
						so_data<=0;
						pat_cnt<=pat_cnt;
					end
					else begin
						so_valid<=so_valid;
						cnt<=cnt+1;
						pat_cnt<=pat_cnt+1;
						if(pi_msb)begin
							if(pi_low)
								so_data<=in_buf[14-cnt];
							else
								so_data<=in_buf[6-cnt];
						end
						else begin
							if(pi_low)
								so_data<=in_buf[cnt+9];
							else
								so_data<=in_buf[cnt+1];
						end
					end
				end
				2'b01:begin
					if(cnt==15 || !so_valid)begin
						so_valid<=0;
						cnt<=0;
						so_data<=0;
						pat_cnt<=pat_cnt;
					end
					else begin
						so_valid<=so_valid;
						cnt<=cnt+1;
						pat_cnt<=pat_cnt+1;
						if(pi_msb)begin
							so_data<=in_buf[14-cnt];
						end
						else begin
							so_data<=in_buf[cnt+1];
						end
					end
				end
				2'b10:begin
					if(cnt==23 || !so_valid)begin
						so_valid<=0;
						cnt<=0;
						so_data<=0;
						pat_cnt<=pat_cnt;
					end
					else begin
						so_valid<=so_valid;
						cnt<=cnt+1;
						pat_cnt<=pat_cnt+1;
						if(pi_msb)begin
							so_data<=in_buf[22-cnt];
						end
						else begin
							so_data<=in_buf[cnt+1];
						end
					end
				end
				2'b11:begin
					if(cnt==31 || !so_valid)begin
						so_valid<=0;
						cnt<=0;
						so_data<=0;
						pat_cnt<=pat_cnt;
					end
					else begin
						so_valid<=so_valid;
						cnt<=cnt+1;
						pat_cnt<=pat_cnt+1;
						if(pi_msb)begin
							so_data<=in_buf[30-cnt];
						end
						else begin
							so_data<=in_buf[cnt+1];
						end
					end	
				end
			endcase
		end
	end
end



always@(posedge clk or posedge reset)begin
	if(reset)begin
		so_valid_delay<=0;
	end
	else begin
		if(load)begin
			so_valid_delay<=1;
		end
		else begin
			so_valid_delay<=0;
		end
	end
end







always@(*)begin
	case(pi_length)
		2'b00:begin //8 bit
			in_buf = pi_data;
		end
		2'b01:begin //16 bit
			in_buf = pi_data;
		end
		2'b10:begin //24 bit
			if(pi_fill==0)begin
				in_buf = {8'h00,pi_data};
			end
			else begin
				in_buf = {pi_data,8'h00};
			end
		end
		2'b11:begin // 32bit
			if(pi_fill==0)begin
				in_buf = {16'h0000,pi_data};
			end
			else begin
				in_buf = {pi_data,16'h0000};
			end
		end
	endcase
end









//////////////////////////////////DAC controll//////////////////////////

assign oem_dataout = {mem_buff[7:1],so_data};

assign odd1_wr = (state == ODD1 && mem_cnt==7)?1:0;
assign even1_wr = (state == EVEN1 && mem_cnt==7)?1:0; 
assign odd2_wr = (state == ODD2 && mem_cnt == 7)?1:0; 
assign even2_wr = (state == EVEN2 && mem_cnt == 7)?1:0;
assign odd3_wr = (state == ODD3 && mem_cnt == 7)?1:0;
assign even3_wr = (state == EVEN3 && mem_cnt == 7)?1:0; 
assign odd4_wr = (state == ODD4 && mem_cnt == 7)?1:0; 
assign even4_wr = (state == EVEN4 && mem_cnt == 7)?1:0;


assign flag = ((mem_cnt==7) && mem_addr==7)?1:0;

always@(*)begin
	case(state)
		IDLE:begin
			if(so_valid)begin
				next_state = ODD1;
				n_mem_addr = 0;
				n_oem_addr = 0;
			end
			else begin
				next_state = IDLE;
				n_mem_addr = 0;
				n_oem_addr = 0;
			end
		end
		ODD1:begin
			if(oem_addr != 31)begin
				if(mem_cnt==7)begin
					if(mem_addr == 7)begin
						next_state = ODD1;
						n_mem_addr = 0;
						n_oem_addr = oem_addr+1;
					end
					else if(mem_state == MEM_INV)begin
						next_state = EVEN1;
						n_mem_addr = mem_addr+1;
						n_oem_addr = oem_addr+1;
					end
					else begin
						next_state = EVEN1;
						n_mem_addr = mem_addr+1;
						n_oem_addr = oem_addr;
					end
				end
				else begin
					next_state = ODD1;
					n_mem_addr = mem_addr;
					n_oem_addr = oem_addr;
				end
			end
			else begin
				if(mem_cnt == 7)begin
					next_state = ODD2;
					n_mem_addr = 0;
					n_oem_addr = 0;
				end
			end
		end
		EVEN1:begin
			if(mem_cnt == 7)begin
				if(mem_addr == 7)begin
					next_state = EVEN1;
					n_mem_addr = 0;
					n_oem_addr = oem_addr+1;
				end
				else if(mem_state == MEM_INV)begin
					next_state = ODD1;
					n_mem_addr = n_mem_addr+1;
					n_oem_addr = oem_addr;
				end
				else begin
					next_state = ODD1;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr+1;
				end
			end
			else begin
				next_state = EVEN1;
				n_mem_addr = mem_addr;
				n_oem_addr = oem_addr;
			end
		end	
		ODD2:begin
			if(oem_addr != 31)begin
				if(mem_cnt==7)begin
					if(mem_addr == 7)begin
						next_state = ODD2;
						n_oem_addr = oem_addr+1;
						n_mem_addr = 0;
					end
					else if(mem_state == MEM_INV)begin
						next_state = EVEN2;
						n_mem_addr = mem_addr+1;
						n_oem_addr = oem_addr+1;
					end
					else begin
						next_state = EVEN2;
						n_oem_addr = oem_addr;
						n_mem_addr = mem_addr+1;
					end
				end
				else begin
					next_state = ODD2;
					n_oem_addr = oem_addr;
					n_mem_addr = mem_addr;
				end
			end
			else begin
				if(mem_cnt==7)begin
					next_state = ODD3;
					n_oem_addr = 0;
					n_mem_addr = 0;
				end
			end
		end
		EVEN2:begin
			if(mem_cnt == 7)begin
				if(mem_addr == 7)begin
					next_state = EVEN2;
					n_mem_addr = 0;
					n_oem_addr = oem_addr+1;
				end
				else if(mem_state == MEM_INV)begin
					next_state = ODD2;
					n_mem_addr = n_mem_addr+1;
					n_oem_addr = oem_addr;
				end
				else begin
					next_state = ODD2;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr+1;
				end
			end
			else begin
				next_state = EVEN2;
				n_mem_addr = mem_addr;
				n_oem_addr = oem_addr;
			end
		end
		ODD3:begin
			if(oem_addr != 31)begin
				if(mem_cnt==7)begin
					if(mem_addr == 7)begin
						next_state = ODD3;
						n_oem_addr = oem_addr+1;
						n_mem_addr = 0;
					end
					else if(mem_state == MEM_INV)begin
						next_state = EVEN3;
						n_mem_addr = mem_addr+1;
						n_oem_addr = oem_addr+1;
					end
					else begin
						next_state = EVEN3;
						n_oem_addr = oem_addr;
						n_mem_addr = mem_addr+1;
					end
				end
				else begin
					next_state = ODD3;
					n_oem_addr = oem_addr;
					n_mem_addr = mem_addr;
				end
			end
			else begin
				if(mem_cnt==7)begin
					next_state = ODD4;
					n_oem_addr = 0;
					n_mem_addr = 0;
				end
			end
		end
		EVEN3:begin
            if(mem_cnt == 7)begin
				if(mem_addr == 7)begin
					next_state = EVEN3;
					n_mem_addr = 0;
					n_oem_addr = oem_addr+1;
				end
				else if(mem_state == MEM_INV)begin
					next_state = ODD3;
					n_mem_addr = n_mem_addr+1;
					n_oem_addr = oem_addr;
				end
				else begin
					next_state = ODD3;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr+1;
				end
			end
			else begin
				next_state = EVEN3;
				n_mem_addr = mem_addr;
				n_oem_addr = oem_addr;
			end
		end
		ODD4:begin
			if(mem_cnt==7)begin
				if(mem_addr == 7)begin
					next_state = ODD4;
					n_mem_addr = 0;
					n_oem_addr = oem_addr+1;
				end
				else if(mem_state == MEM_INV)begin
					next_state = EVEN4;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr+1;
				end
				else begin
					next_state = EVEN4;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr;
				end
			end
			else begin
				if(mem_cnt==7)begin
					next_state = ODD4;
					n_mem_addr = mem_addr;
					n_oem_addr = 0;
				end
			end
		end
		EVEN4:begin
			if(mem_cnt == 7)begin
				if(mem_addr == 7)begin
					next_state = EVEN4;
					n_mem_addr = 0;
					n_oem_addr = oem_addr+1;
				end
				else if(mem_state == MEM_INV)begin
					next_state = ODD4;
					n_mem_addr = n_mem_addr+1;
					n_oem_addr = oem_addr;
				end
				else begin
					next_state = ODD4;
					n_mem_addr = mem_addr+1;
					n_oem_addr = oem_addr+1;
				end
			end
			else begin
				next_state = EVEN4;
				n_mem_addr = mem_addr;
				n_oem_addr = oem_addr;
			end
		end
		        
	endcase
end


always@(posedge clk or posedge reset)begin
	if(reset)
		mem_addr <= 0;
	else 
		mem_addr <= n_mem_addr;
end

always@(posedge clk or posedge reset)begin
	if(reset)begin
		mem_buff<=0;
		mem_cnt<=0;
	end
	else begin
		if(so_valid || n_pi_end)begin
			mem_buff[7-mem_cnt]<=so_data;
			if(mem_cnt==7)begin
				//mem_buff<=0;
				mem_cnt<=0;
			end
			else begin
				//mem_buff[7-mem_cnt]<=so_data;
				mem_cnt<=mem_cnt+1;
			end	
		end
		else begin
            mem_buff<=0;
			mem_cnt<=0;
		end
	end
end


always@(posedge clk or posedge reset)begin
	if(reset)begin
		oem_addr<=0;
	end
	else begin
		oem_addr<=n_oem_addr;
	end
end


always@(posedge clk or posedge reset)begin
	if(reset)begin
		oem_finish<=0;
	end
	else begin
		if(mem_fin == 255 & mem_cnt == 7)begin
			oem_finish<=1;
		end
		else begin
			oem_finish<=oem_finish;
		end
	end
end

always@(posedge clk or posedge reset)begin
	if(reset)begin
		mem_fin<=0;
	end
	else begin
		if(mem_fin==255)begin
			mem_fin<=mem_fin;
		end
		else begin
			if(mem_cnt==7)begin
				mem_fin<=mem_fin+1;
			end
			else begin
				mem_fin<=mem_fin;
			end
		end
	end
end



always@(*)begin
	case(mem_state)
		MEM_FORWARD:begin
			if(flag)begin
				n_mem_state = MEM_INV;
			end
			else begin
				n_mem_state = mem_state;
			end
		end
		MEM_INV:begin
			if(flag)begin
				n_mem_state = MEM_FORWARD;
			end
			else begin
				n_mem_state = mem_state;
			end
		end
	endcase
end


always@(posedge clk or posedge reset)begin
	if(reset)begin
		n_pi_end<=0;
	end
	else begin
		n_pi_end<=pi_end;
	end
end


endmodule

