#!/usr/bin/env python3
"""Fix the ungroomed HepData export binning to match groomed."""
import numpy as np

# Load both files
f_g = np.load("hepdata_export_groomed.npz", allow_pickle=True)
f_u = np.load("hepdata_export_ungroomed.npz", allow_pickle=True)

# Expected edges for all slices
GROOMED_EDGES = np.array([-10., -4.5, -4., -3.5, -3., -2.5, -2., -1.5, -1., -0.5, 0.])

# Process all pt slices (pt0, pt1, pt2)
out = {}

for pt_idx in range(3):
    key_prefix = f"pt{pt_idx}"

    # Read ungroomed data
    u_value = f_u[f"{key_prefix}__value"]
    u_stat = f_u[f"{key_prefix}__stat"]
    u_syst_up = f_u[f"{key_prefix}__syst_up"]
    u_syst_down = f_u[f"{key_prefix}__syst_down"]
    u_total_up = f_u[f"{key_prefix}__total_up"]
    u_total_down = f_u[f"{key_prefix}__total_down"]
    u_true_pythia = f_u[f"{key_prefix}__true_pythia"]

    # Create expanded arrays with zeros for missing bins
    expanded_value = np.zeros(10)
    expanded_stat = np.zeros(10)
    expanded_syst_up = np.zeros(10)
    expanded_syst_down = np.zeros(10)
    expanded_total_up = np.zeros(10)
    expanded_total_down = np.zeros(10)
    expanded_true_pythia = np.zeros(10)

    # Map ungroomed bins (indices 0-5) to groomed positions (indices 4-9)
    # Ungroomed bins were: [-10,-2.5], [-2.5,-2], [-2,-1.5], [-1.5,-1], [-1,-0.5], [-0.5,0]
    # These are bins 4-9 in the full 10-bin groomed structure
    bin_map = [4, 5, 6, 7, 8, 9]

    for i, groomed_bin in enumerate(bin_map):
        expanded_value[groomed_bin] = u_value[i]
        expanded_stat[groomed_bin] = u_stat[i]
        expanded_syst_up[groomed_bin] = u_syst_up[i]
        expanded_syst_down[groomed_bin] = u_syst_down[i]
        expanded_total_up[groomed_bin] = u_total_up[i]
        expanded_total_down[groomed_bin] = u_total_down[i]
        expanded_true_pythia[groomed_bin] = u_true_pythia[i]

    # Store in output
    out[f"{key_prefix}__edges"] = GROOMED_EDGES
    out[f"{key_prefix}__value"] = expanded_value
    out[f"{key_prefix}__stat"] = expanded_stat
    out[f"{key_prefix}__syst_up"] = expanded_syst_up
    out[f"{key_prefix}__syst_down"] = expanded_syst_down
    out[f"{key_prefix}__total_up"] = expanded_total_up
    out[f"{key_prefix}__total_down"] = expanded_total_down
    out[f"{key_prefix}__true_pythia"] = expanded_true_pythia

# Copy over all other arrays (correlations, systematics) unchanged
for key in f_u.keys():
    if not any(f"pt{i}" in key for i in range(3)):
        out[key] = f_u[key]

# Save
np.savez("hepdata_export_ungroomed.npz", **out)
print("✓ Fixed hepdata_export_ungroomed.npz")

# Verify
f_check = np.load("hepdata_export_ungroomed.npz", allow_pickle=True)
print(f"✓ pt0__edges: {f_check['pt0__edges']}")
print(f"✓ pt0__value ({len(f_check['pt0__value'])} bins): {f_check['pt0__value']}")
