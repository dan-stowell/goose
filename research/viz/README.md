# viz

The pictures page (research/CHARTER.md, Deliverables 3), served on port 8000. Generated from real runs by the scripts here; never edited by hand.

- `index.html`: the page, built by `build.py` from `page.html`, `data/*.json` and `../runs/*.json`.
- `METHOD.md`: how bytes are seen moving on this VM, with the evidence.
- `trace/`: the bytemove Valgrind tool, stage marking, reduction, counters; `trace/run.sh` regenerates everything.
- Served by `python3 -m http.server 8000 --directory /home/exedev/goose/research/viz` (log: /tmp/viz-server.log).
