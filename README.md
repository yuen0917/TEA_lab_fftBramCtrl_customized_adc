# FFT-BRAM-CTRL and CUSTOMIZED_ADC

這是一份用於將FFT的輸出數據寫入BRAM的控制器，以及一個用於讀取ADC數據的模塊

## FFT-BRAM-CTRL

這是一個用於將FFT的輸出數據寫入BRAM的控制器，它會透過AXI Stream接口接收FFT的輸出數據，並將其寫入BRAM

### 整體架構

- 使用AXI Stream接口接收FFT的輸出數據
- 將FFT的輸出數據寫入BRAM
- 會分成8個通道，每個通道的數據為256bit
- 每個通道的數據會分成實部和虛部，實部和虛部各為24bit，但會以32bit的形式寫入BRAM(最高的8bit為sign extension)
- 每次寫入address會增加4，寫入8次後，address會歸零

### 接口說明

- clk: 時鐘信號
- rst_n: 重置信號
- s_axis_tdata: AXI Stream接口的數據信號
- s_axis_tvalid: AXI Stream接口的數據有效信號
- s_axis_tlast: AXI Stream接口的數據最後一個信號
- s_axis_tready: AXI Stream接口的數據準備好信號
- bram_addr: BRAM的地址信號
- bram_din_re: BRAM的實部數據信號
- bram_din_im: BRAM的虛部數據信號
- bram_we: BRAM的write enable信號
- bram_en: BRAM的enable信號
- bram_rst: BRAM的重置信號
