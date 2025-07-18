#!/usr/bin/env python3
from rdflib import Graph, Namespace, URIRef
import networkx as nx, matplotlib.pyplot as plt

EX = Namespace("http://example.org/")

# Load the three TTL graphs
g1 = Graph().parse("../1_public_ref_datasets/recalls.ttl", format="turtle")
g2 = Graph().parse("../2_chemical_property_repos/compound.ttl", format="turtle")
g3 = Graph().parse("../3_inhouse_synthetic_data/sensor.ttl", format="turtle")

# Merge
g_all = Graph()
for g in [g1, g2, g3]:
    for t in g:
        g_all.add(t)

# Create a dummy link (example)
chem = URIRef(EX["CHEMBL25"])
for s,_,_ in g1.triples((None,None,None)):
    if "CHEMBL25" in str(s):
        g_all.add((chem, EX.relatedTo, s))

g_all.serialize("linked.ttl", format="turtle")

# Plot
nxg = nx.DiGraph()
for s,p,o in g_all:
    nxg.add_edge(str(s), str(o), label=str(p))
plt.figure(figsize=(12,12))
nx.draw(nxg, node_size=50, with_labels=False)
plt.savefig("linked_graph.png")
