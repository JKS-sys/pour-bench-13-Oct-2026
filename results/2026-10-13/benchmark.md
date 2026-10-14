# Pour vs Homebrew — 2026-10-13

Machine: Linux 6.18.44-fc-v114 x86_64 · Intel(R) Xeon(R) Processor @ 2.10GHz · 2 CPUs
Pour: pour 0.1.0 · Homebrew: Homebrew 7.0.9

| Package | brew cold | pour cold | speed-up | brew warm | pour warm | speed-up |
|---|---|---|---|---|---|---|
| jq | 9.61 s | 1.13 s | 8.5× | 5.33 s | 6 ms | 888.0× |
| wget | 52.08 s | 4.77 s | 10.9× | 46.17 s | 291 ms | 158.7× |
| tree | 7.56 s | 686 ms | 11.0× | 4.25 s | 4 ms | 1062.5× |
| ripgrep | 15.82 s | 1.43 s | 11.1× | 10.41 s | 11 ms | 946.2× |
| fd | 7.40 s | 847 ms | 8.7× | 3.70 s | 5 ms | 740.0× |
| bat | 42.86 s | 4.47 s | 9.6× | 37.88 s | 273 ms | 138.8× |
| sqlite | 16.01 s | 2.55 s | 6.3× | 11.19 s | 6 ms | 1864.8× |
| python@3.13 | 51.95 s | 5.92 s | 8.8× | 47.46 s | 239 ms | 198.6× |
| node | 111.52 s | 6.68 s | 16.7× | 100.86 s | 700 ms | 144.1× |
| ffmpeg | 193.21 s | 8.11 s | 23.8× | 176.82 s | 2.40 s | 73.8× |

## Everyday commands

| Command | Homebrew | Pour | speed-up |
|---|---|---|---|
| `search json` | 794 ms | 7.5 ms | 105.9× |
| `info jq` | 601 ms | 9.2 ms | 65.3× |
| `outdated` | 646 ms | 5.1 ms | 126.6× |
| `list` | 18 ms | 5.4 ms | 3.3× |

Raw timings: `results/2026-10-13/timings.tsv`. Re-run with `bash bench.sh`.
