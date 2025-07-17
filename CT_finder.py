''' 
Usage:
    1. Modify the "latency", "upper_bound", "lower_bound", "step", "reverse", "dummy_dir", and "lab_source_dir" variables.
    2. Modify the "performance_func" function to the desired performance calculation.
    3. Run the script using Python 3

Dependencies:
    - Python 3
    - Standard Python libraries
    - External commands: dcnxt_shell(for synthesis), vcs(for gate-level simulation)
'''

import os
import re
import csv
import subprocess
import time
import shutil
import threading
import concurrent.futures

# ==================================================
# Configuration
# ==================================================
latency = 1  # Latency of the design
upper_bound = 8.1
lower_bound = 4.0
step = 0.1
reverse = True  # if True, the cycle times will be in descending order
dummy_dir = os.path.expanduser('~/dummy_dir')  # Dummy directory to store temporary files for different cycle times
lab_source_dir = os.path.expanduser('~/Final_Project_2025/')  # Path to the lab files, e.g., ~/Lab04/Exercise
max_workers = 50  # Number of parallel synthesis processes
design_name = "CPU"  # Design name, replace with your design name

# ==================================================
# Performance Calculation
# ==================================================
def performance_func(area, cycle_time, latency):
    return (area) * (cycle_time**2) * (latency**2)


# ==================================================
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[1;33m"
RESET = "\033[0m"

def print_sep(text, total_length=100, end="\n"):
    text_length = len(re.sub(r'\033\[\d+m', '', text))
    eq_length = (total_length - text_length - 2) // 2
    separator = "-" * eq_length + " " + text + " " + "-" * eq_length
    if len(separator) < total_length:
        separator += "-"
    print(separator, end=end)

def check_synthesis_result(syn_working_dir, syn_log, design_name):
    timing_report = os.path.join(syn_working_dir, f"Report/{design_name}.timing")
    area_report = os.path.join(syn_working_dir, f"Report/{design_name}.area")
    power_report = os.path.join(syn_working_dir, f"Report/{design_name}.power")

    success = True
    error_msg = ""
    area = None
    cycle_time = None

    # Check for latch
    if "Latch" in syn_log:
        success = False
        error_msg += "There is Latch in this design. "

    # Check for width mismatch
    if "mismatch" in syn_log.lower():
        success = False
        error_msg += "Width Mismatch Error. "

    # Check for error
    if "Error" in syn_log:
        success = False
        error_msg += "There is Error in syn.log. "

    # Check timing violations
    try:
        with open(timing_report, 'r', encoding='utf-8', errors='replace') as f:
            timing_content = f.read()
            if "violated" in timing_content.lower():
                success = False
                error_msg += "Timing (violated). "

    except Exception as e:
        success = False
        error_msg += f"Failed to read timing report: {str(e)}. "

    # Extract area
    try:
        with open(area_report, 'r', encoding='utf-8', errors='replace') as f:
            area_content = f.read()
            area_match = re.search(r"Total cell area:\s*([+-]?[0-9]+([.][0-9]+)?)", area_content)
            if area_match:
                area = float(area_match.group(1))
    except Exception as e:
        success = False
        error_msg += f"Failed to read area report: {str(e)}. "

    # Extract power information (optional)
    try:
        with open(power_report, 'r', encoding='utf-8', errors='replace') as f:
            power_content = f.read()
            dynamic_match = re.search(r"Total Dynamic Power\s*=\s*([+-]?[0-9]+([.][0-9]+)?)", power_content)
            leakage_match = re.search(r"Cell Leakage Power\s*=\s*([+-]?[0-9]+([.][0-9]+)?)", power_content)

            if dynamic_match:
                dynamic_power = dynamic_match.group(1)

            if leakage_match:
                leakage_power = leakage_match.group(1)
    except Exception:
        # Power information is optional
        pass

    # Calculate gate count if needed
    gate_count = area / 9.9792 if area is not None else None

    return success, area, error_msg

def run_synthesis(cycle, cycle_dir):
    syn_command = 'dcnxt_shell -f syn.tcl -x "set_host_options -max_cores 8" -output_log_file syn.log'
    syn_working_dir = os.path.join(cycle_dir, '02_SYN')

    process = subprocess.run(
        syn_command,
        shell=True,
        cwd=syn_working_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        encoding='utf-8',
        errors='replace'
    )

    output = process.stdout + process.stderr
    
    # Read the syn.log file
    syn_log_path = os.path.join(syn_working_dir, 'syn.log')
    try:
        with open(syn_log_path, 'r', encoding='utf-8', errors='replace') as f:
            syn_log = f.read()
    except Exception as e:
        syn_log = f"Error reading syn.log: {str(e)}"
    
    # Check synthesis result
    success, area, error_msg = check_synthesis_result(syn_working_dir, syn_log, design_name)
    
    if area is not None and latency is not None:
        performance = performance_func(area, cycle, latency)
    else:
        performance = None

    result = {
        "Cycle Time": cycle,
        "Area": area,
        "Performance": performance,
        "Latency": latency,
        "Success": "Yes" if success else "No",
        "Error": error_msg.strip(),
        "Directory": cycle_dir
    }

    return result

def run_gatesim(cycle, cycle_dir):
    pattern_path = os.path.join(cycle_dir, '00_TESTBED', 'PATTERN.v')
    if not os.path.exists(pattern_path):
        print(f"Pattern file not found: {pattern_path}")
        return False
    else:
        with open(pattern_path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = re.sub(r"`define CYCLE_TIME\s*[\d\.]+", f"`define CYCLE_TIME {cycle}", content)

        with open(pattern_path, 'w', encoding='utf-8') as f:
            f.write(content)

    gatesim_command = 'vcs -timescale=1ns/1fs -j8 -sverilog +v2k -full64 -Mupdate -R -debug_access+all -f "filelist.f" -o "simv" -l "vcs.log" -P /usr/cad/synopsys/verdi/2019.06//share/PLI/VCS/linux64/novas.tab /usr/cad/synopsys/verdi/2019.06//share/PLI/VCS/linux64/pli.a -v ~iclabTA01/UMC018_CBDK/CIC/Verilog/fsa0m_a_generic_core_30.lib.src +define+FUNC +define+GATE +neg_tchk +nowarnNTCDSN'
    gatesim_working_dir = os.path.join(cycle_dir, '03_GATE')

    error_ignore_list = ["-lerrorinf", "Total errors:"]

    process = subprocess.run(
        gatesim_command,
        shell=True,
        cwd=gatesim_working_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        encoding='utf-8',
        errors='replace'
    )

    output = process.stdout + process.stderr

    success = False

    if "congratulations" in output.lower():
        error_found = False
        for line in output.splitlines():
            if "error" in line.lower():
                if not any(ignore_item in line for ignore_item in error_ignore_list):
                    error_found = True
                    break

        if not error_found:
            success = True

    return success


def main():
    start_time = time.time()

    if not os.path.exists(dummy_dir):
        os.makedirs(dummy_dir)
    else:
        shutil.rmtree(dummy_dir)
        os.makedirs(dummy_dir)

    original_dir = os.path.join(dummy_dir, 'original')
    os.system(f"cp -r {lab_source_dir} {original_dir}")
    print_sep(f"Original directory copied, you can modify your design safely")


    if reverse:
        print_sep(f"Running synthesis with cycle times from {upper_bound} to {lower_bound} with step {step}")
        print_sep(f"Max workers: {max_workers}")
    else:
        print_sep(f"Running synthesis with cycle times from {lower_bound} to {upper_bound} with step {step}")
        print_sep(f"Max workers: {max_workers}")

    cycle_times = [round(x / 100.0, 2) for x in range(int(lower_bound * 100), int(upper_bound * 100) + 1, int(step * 100))]
    if reverse:
        cycle_times = list(reversed(cycle_times))

    # Prepare directories
    cycle_dirs = {}
    for cycle in cycle_times:
        cycle_dir_name = f"cycle_{cycle}"
        cycle_dir = os.path.join(dummy_dir, cycle_dir_name)
        cycle_dirs[cycle] = cycle_dir
        if os.path.exists(cycle_dir):
            shutil.rmtree(cycle_dir)
        # Do not copy yet

    # Copy original to each cycle directory in parallel
    def copy_original(cycle, cycle_dir):
        shutil.copytree(original_dir, cycle_dir)

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        copy_futures = []
        for cycle in cycle_times:
            cycle_dir = cycle_dirs[cycle]
            future = executor.submit(copy_original, cycle, cycle_dir)
            copy_futures.append(future)
        concurrent.futures.wait(copy_futures)


    # Modify syn.tcl for each cycle time
    for cycle in cycle_times:
        cycle_dir = cycle_dirs[cycle]
        syn_tcl_path = os.path.join(cycle_dir, '02_SYN', 'syn.tcl')
        with open(syn_tcl_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        with open(syn_tcl_path, 'w', encoding='utf-8') as f:
            for line in lines:
                if line.strip().startswith("set CYCLE"):
                    f.write(f"set CYCLE {cycle}\n")
                else:
                    f.write(line)

    best_performance = [None]
    best_result = [None]
    best_directory = [None]
    lock = threading.Lock()

    results = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_cycle = {}
        for cycle in cycle_times:
            cycle_dir = cycle_dirs[cycle]
            future = executor.submit(run_synthesis, cycle, cycle_dir)
            future_to_cycle[future] = (cycle, cycle_dir)

        for future in concurrent.futures.as_completed(future_to_cycle):
            cycle, cycle_dir = future_to_cycle[future]
            try:
                result = future.result()
                area_str = f"{result['Area']:7.2f}" if result['Area'] is not None else "   N/A"
                performance_str = f"{result['Performance']:15.2f}" if result['Performance'] is not None else "        N/A"

                if result["Error"]:
                    print(f"Cycle Time: {result['Cycle Time']:3.2f}, Area: {area_str}, Performance: {performance_str}, "
                          f"Latency: {result['Latency']:6d}, {RED}Error: {result['Error']}{RESET}")
                else:
                    print(f"Cycle Time: {result['Cycle Time']:3.2f}, Area: {area_str}, Performance: {performance_str}, "
                          f"Latency: {result['Latency']:6d}, {GREEN}Success!{RESET}")


                # Synchronize access to the best performance
                with lock:
                    if result["Success"] == "Yes" and result["Performance"] is not None:
                        if best_performance[0] is None or result["Performance"] < best_performance[0]:
                            if best_directory[0] and os.path.exists(best_directory[0]):
                                shutil.rmtree(best_directory[0])

                            best_performance[0] = result["Performance"]
                            best_result[0] = result
                            best_directory[0] = cycle_dir
                        else:  # Not the best result
                            shutil.rmtree(cycle_dir)
                    else:  # Failure
                        shutil.rmtree(cycle_dir)

                # Collect the result
                results.append(result)

            except Exception as exc:
                print(f"Cycle Time {cycle} generated an exception: {exc}")
                if os.path.exists(cycle_dir):
                    shutil.rmtree(cycle_dir)

    results.sort(key=lambda x: x['Cycle Time'])

    with open("results.csv", "w", newline="", encoding="utf-8") as csvfile:
        fieldnames = ["Cycle Time", "Area", "Performance", "Latency", "Success", "Error"]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for result in results:
            writer.writerow({k: v for k, v in result.items() if k != "Directory"})

    # Print the best result
    print_sep(f"Total time: {time.time() - start_time} seconds")
    print_sep("Synthesis results saved to results.csv")
    if best_result[0] is not None:
        print(f"The best synthesis directory is retained at: {best_directory[0]}")
        print(f"Best result: Cycle Time: {best_result[0]['Cycle Time']}, Area: {best_result[0]['Area']}, Performance: {best_result[0]['Performance']}, Latency: {best_result[0]['Latency']}")

    if best_result[0] is not None:    
        print_sep("Running gate-level simulation")
        success = run_gatesim(best_result[0]['Cycle Time'], best_directory[0])
        if success:
            print_sep(f"Gate-level simulation {GREEN}PASSED!!{RESET}")
        else:
            print_sep(f"Gate-level simulation {RED}FAILED!!{RESET}")
    else:
        print_sep("No best result found, skip gate-level simulation")

if __name__ == "__main__":
    main()

