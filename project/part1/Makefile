SIM-MOCK = simv-mock
SIM = simv
MOCK-FILELIST = mock-filelist.f
FILELIST = filelist.f

.PHONY = sim sim_mock clean run download_weights

download_weights:
	wget -O model_best.pth.tar https://storage.googleapis.com/ece284-project/part1_model_best.pth.tar

sim_mock:
	iverilog -o $(SIM-MOCK) -f $(MOCK-FILELIST)
	vvp $(SIM-MOCK)
	gtkwave core_tb.vcd &

sim:
	iverilog -o $(SIM) -f $(FILELIST)
	vvp $(SIM)
	gtkwave core_tb.vcd &

clean:
	rm -f $(SIM) $(SIM-MOCK) *.vcd

run: clean sim
