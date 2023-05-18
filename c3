# Import required modules
import subprocess
import re
import math

# Define function to run Abaqus and extract data from output file
def run_abaqus(input_file):
    # Call Abaqus with input file and redirect output to file
    subprocess.run(["abaqus", "cae", "noGUI=" + input_file, ">>", "abaqus_output.txt"], shell=True)
    
    # Read output file and extract relevant data
    with open("abaqus_output.txt", "r") as f:
        output = f.read()
        
        # Extract maximum axial force and moment from output
        axial_force = re.findall("MAXIMUM FORCE =\s+(\d+.\d+)", output)[0]
        moment = re.findall("MAXIMUM MOMENT =\s+(\d+.\d+)", output)[0]
        
    return axial_force, moment

# Define function to calculate equivalent thickness
def calc_equiv_thickness(d, t_conc, t_steel, f_conc, f_steel):
    # Calculate area of concrete and steel components
    a_conc = (d - t_steel) * t_conc
    a_steel = t_steel * d
    
    # Calculate equivalent thickness using formula
    equiv_thickness = (a_conc * f_conc + a_steel * f_steel) / (f_conc + f_steel)
    
    return equiv_thickness

# Define function to calculate optimal aspect ratio
def calc_optimal_aspect_ratio(equiv_thickness, f_steel, h_min, h_max, w_min, w_max):
    # Define function to calculate section properties given aspect ratio
    def calc_section_props(aspect_ratio):
        # Calculate dimensions of concrete and steel components
        h_conc = aspect_ratio * w_conc
        t_steel = h_steel * f_steel / (f_steel + f_conc)
        h_steel = d - h_conc
        t_conc = h_conc / aspect_ratio
        
        # Calculate area and moment of inertia of section
        a = h_conc * w_conc + h_steel * w_steel
        i = (w_conc * h_conc ** 3 / 12) + (w_steel * h_steel ** 3 / 12) + (w_conc * h_conc * (h_conc / 2 + h_steel)) ** 2 + (w_steel * h_steel * (d - h_steel / 2 - h_conc)) ** 2
        
        return a, i
    
    # Define dimensions of concrete and steel components
    w_conc = equiv_thickness / f_steel
    h_steel = h_max - equiv_thickness
    h_conc = h_min
    t_conc = equiv_thickness / h_min
    t_steel = (d - h_min) / math.ceil((d - h_min) / h_steel)
    
    # Calculate section properties for different aspect ratios
    aspect_ratios = [round(i * 0.1, 1) for i in range(1, 21)]
    section_props = [calc_section_props(ar) for ar in aspect_ratios]
    
    # Calculate force reduction factors for different aspect ratios
    axial_forces = []
    moments = []
    for a, i in section_props:
        # Define input file for Abaqus
        input_file = "abaqus_input.inp"
        with open(input_file, "w") as f:
            f.write("*HEADING\n")
            f.write("Composite
