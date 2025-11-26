SIM-MOCK = simv-mock
SIM = simv
MOCK-FILELIST = mock-filelist.f
FILELIST = filelist.f
MODEL = "VGG16_project_part1"

.PHONY = sim sim_mock clean run download_weights

# Download trained weights if needed
download_weights:
	mkdir -p result/$(MODEL)
	wget -O result/$(MODEL)/model_best.pth.tar https://storage.googleapis.com/ece284-project/part1_model_best.pth.tar

# Run the Mock simulation (using mock_core.v)
sim_mock:
	iverilog -o $(SIM-MOCK) -f $(MOCK-FILELIST)
	vvp $(SIM-MOCK)
	gtkwave core_tb.vcd &

# Run the Real simulation (using real core.v in verilog folder)
sim:
	iverilog -o $(SIM) -f $(FILELIST)
	vvp $(SIM)
	gtkwave core_tb.vcd &

# Cleanup generated files
clean:
	rm -f $(SIM) $(SIM-MOCK) *.vcd

# Default target to clean and run the real simulation
run: clean sim