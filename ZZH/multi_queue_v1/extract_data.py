import re

with open('a.txt','r') as f:
    iperf_output = f.read()
matches = re.findall(r'\[SUM\].*?(\d+\.\d+)\sMbits/sec', iperf_output)
if matches:
    with open("output.txt", "w") as file:
        for value in matches:
            file.write(value + "\n")
