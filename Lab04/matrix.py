import numpy as np 
import struct

def hex_to_float(hex_str):
    return struct.unpack('!f', bytes.fromhex(hex_str))[0]

def float_to_hex(f):
    return format(struct.unpack('!I', struct.pack('!f', f))[0], '08x')

def parse_hex_matrix(hex_list, shape):
    float_list = [hex_to_float(h) for h in hex_list]
    return np.array(float_list).reshape(shape)

def softmax(x):
    e_x = np.exp(x - np.max(x, axis=1, keepdims=True))
    return e_x / np.sum(e_x, axis=1, keepdims=True)

# read costom input.txt
file_path = "input.txt"
with open(file_path, "r") as file:
    lines = [line.strip() for line in file if line.strip()]

N = int(lines[0])  # pat num

output_lines = [str(N), ""]

for case_id in range(N):
    print(f"\n========== Test Case {case_id + 1} ==========")
    case_start = 1 + case_id * 21
    hex_in_str = []
    hex_k_weight = []
    hex_q_weight = []
    hex_v_weight = []
    hex_out_weight = []

    for i in range(20):
        line = lines[case_start + 1 + i]
        tokens = line.split()
        if i < 16:
            hex_in_str.append(tokens[0])
            hex_k_weight.append(tokens[1])
            hex_q_weight.append(tokens[2])
            hex_v_weight.append(tokens[3])
            hex_out_weight.append(tokens[4])
        else:
            hex_in_str.append(tokens[0])

    in_str = parse_hex_matrix(hex_in_str, (5, 4))
    k_weight = parse_hex_matrix(hex_k_weight, (4, 4))
    q_weight = parse_hex_matrix(hex_q_weight, (4, 4))
    v_weight = parse_hex_matrix(hex_v_weight, (4, 4))
    out_weight = parse_hex_matrix(hex_out_weight, (4, 4))

    K = np.dot(in_str, k_weight.T)
    Q = np.dot(in_str, q_weight.T)
    V = np.dot(in_str, v_weight.T)

    Q_head1 = Q[:, :2]; Q_head2 = Q[:, 2:]
    K_head1 = K[:, :2]; K_head2 = K[:, 2:]

    score1 = np.dot(Q_head1, K_head1.T)
    score2 = np.dot(Q_head2, K_head2.T)

    one_div_sqrt2 = hex_to_float('3f3504f3')
    scaled_score1 = score1 * one_div_sqrt2
    scaled_score2 = score2 * one_div_sqrt2

    softmax_score1 = softmax(scaled_score1)
    softmax_score2 = softmax(scaled_score2)

    V_head1 = V[:, :2]
    V_head2 = V[:, 2:]
    HEAD_OUT1 = np.dot(softmax_score1, V_head1)
    HEAD_OUT2 = np.dot(softmax_score2, V_head2)

    HEAD_OUT = np.concatenate((HEAD_OUT1, HEAD_OUT2), axis=1)
    final_res = np.dot(HEAD_OUT, out_weight.T)

    final_res_hex = np.vectorize(float_to_hex)(final_res)

    output_lines.append(str(case_id + 1))
    for row in final_res_hex:
        for val in row:
            output_lines.append(val)
    output_lines.append("")

    print("\n# final_res (Scientific Notation):")
    print(final_res)
    print("\n# final_res (Hex):")
    print(final_res_hex)

with open("output2.txt", "w") as f:
    f.write("\n".join(output_lines))

print("\noutput2.txt generated")
