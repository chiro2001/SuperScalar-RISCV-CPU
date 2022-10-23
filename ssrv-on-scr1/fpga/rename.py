import os
with open("svh.files") as f:
  for line in f.readlines():
    l = line.replace("\n", "")
    c = f"mv {l}.svh {l}.h"
    print(c)
    os.system(c)