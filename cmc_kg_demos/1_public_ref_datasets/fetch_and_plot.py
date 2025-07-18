#!/usr/bin/env python3
import requests, pandas as pd
from rdflib import Graph, URIRef, Literal, Namespace
import networkx as nx
import matplotlib.pyplot as plt
import re

# Fetch latest 50 recall events from OpenFDA
resp = requests.get("https://api.fda.gov/drug/enforcement.json?limit=50").json()
records = resp.get("results", [])
df = pd.DataFrame(records)[["product_description","recalling_firm","report_date"]]
# Clean your datasets
control_char_re = re.compile(r"[\x00-\x1F\x7F]")
df = df.applymap(
    lambda v: control_char_re.sub(" ", v) if isinstance(v, str) else v
)
#df = df.to_datetime(df["report_date"], errors='coerce')
df.to_csv("recalls.csv", index=False)

# Build an RDF graph
g = Graph()
EX = Namespace("http://example.org/fda/")
for _, row in df.iterrows():
    subj = URIRef(EX[row["product_description"].replace(" ","_")])
    g.add((subj, EX.recallingFirm, Literal(row["recalling_firm"])))
    g.add((subj, EX.eventDate, Literal(row["report_date"])))
g.serialize("recalls.ttl", format="turtle")

# Convert RDF to NetworkX and plot
nxg = nx.DiGraph()
for s,p,o in g:
    nxg.add_edge(str(s), str(o), label=str(p))
plt.figure(figsize=(8,8))
pos = nx.spring_layout(nxg)
nx.draw(nxg, pos, with_labels=True, node_size=500, font_size=8)
plt.savefig("recalls_graph.png")
