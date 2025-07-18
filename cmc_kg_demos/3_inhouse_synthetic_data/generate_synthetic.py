#!/usr/bin/env python3
import pandas as pd, numpy as np
from rdflib import Graph, Namespace, Literal, URIRef
import networkx as nx, matplotlib.pyplot as plt

# Generate synthetic batch sensor data
times = pd.date_range("2025-01-01", periods=48, freq="H")
df = pd.DataFrame({
    "timestamp": times,
    "temperature": np.random.normal(37, 0.5, len(times)),
    "pH": np.random.normal(7, 0.1, len(times))
})
df.to_csv("sensor_data.csv", index=False)

# Build RDF graph
g = Graph()
EX = Namespace("http://example.org/sensor/")

for _, r in df.iterrows():
    # 1. Get ISO‐style timestamp (no space by default)
    ts_iso = r["timestamp"].isoformat()            # "2025-01-01T00:00:00"
    
    # 2. Swap colons for hyphens → "2025-01-01T00-00-00"
    clean_ts = ts_iso.replace(":", "-")

    # 3. Build a Turtle‐safe, human‐readable URI
    subj = URIRef(f"{EX}reading_{clean_ts}")

    # 4. Add triples
    g.add((subj, EX.timestamp, Literal(ts_iso)))
    g.add((subj, EX.temperature, Literal(r["temperature"])))
    g.add((subj, EX.pH, Literal(r["pH"])))

# Serialize out
g.serialize("sensor.ttl", format="turtle")

# Plot the graph
nxg = nx.DiGraph()
for s, p, o in g:
    nxg.add_edge(str(s), str(o), label=str(p))

plt.figure(figsize=(10, 10))
nx.draw(nxg, node_size=20, with_labels=False)
plt.savefig("sensor_graph.png")
