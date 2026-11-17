# viz

The pictures page (research/CHARTER.md, Deliverables 3), served on port 8000. Generated from real runs by the scripts here; never edited by hand.

- `index.html`: the page, built by `build.py` from `page.html`, `data/*.json` and `../runs/*.json`.
- `METHOD.md`: how bytes are seen moving on this VM, with the evidence.
- `trace/`: the bytemove Valgrind tool, stage marking, reduction, counters.
- `regen.sh`: regenerates everything in one command (from the repo root; about 15 minutes, most of it tracing cc1; `SKIP_CC1=1` reuses earlier cc1 traces in the same work dir).
- Served by `python3 -m http.server 8000 --directory /home/exedev/goose/research/viz` (log: /tmp/viz-server.log).
