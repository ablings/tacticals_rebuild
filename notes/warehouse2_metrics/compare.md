## Hall (same domain as the old study): the 5 % check
| metric | old | new | diff % | |
|---|---|---|---|---|
| route SpawnA -> centre novault_sprint | 3.13 | 3.13 | +0.0 | OK |
| route SpawnA -> centre vault_sprint | 3.13 | 3.13 | +0.0 | OK |
| route SpawnA -> centre path_len | 62.5 | 62.5 | +0.0 | OK |
| route SpawnB -> centre novault_sprint | 3.13 | 3.13 | +0.0 | OK |
| route SpawnB -> centre vault_sprint | 3.13 | 3.13 | +0.0 | OK |
| route SpawnB -> centre path_len | 62.5 | 62.5 | +0.0 | OK |
| route spawn -> spawn path | 123.3 | 123.3 | +0.0 | OK |
| route per-piece time from A, worst |  | W04 | +0.0 | OK |
| route per-piece time from B, worst |  | W04 | +0.0 | OK |
| exposure mean | 43.8 | 43.8 | +0.0 | OK |
| exposure p10 | 30.2 | 30.3 | +0.3 | OK |
| exposure p90 | 54.7 | 54.7 | +0.0 | OK |
| exposure min | 6.7 | 6.7 | +0.0 | OK |
| exposure max | 60.6 | 60.7 | +0.2 | OK |
| exposure 10-stud band, worst |  | band -57 | +0.8 | OK |
| spawn-to-spawn sight % | 0.0 | 0.0 | +0.0 | OK |
| spawn view SpawnA floor seen % | 22.76 | 22.97 | +0.9 | OK |
| spawn view SpawnA sees centre | False | False | +0.0 | OK |
| spawn view SpawnB floor seen % | 21.81 | 21.78 | -0.1 | OK |
| spawn view SpawnB sees centre | False | False | +0.0 | OK |
| cover distance mean_walls | 3.96 | 3.96 | -0.0 | OK |
| cover distance max_pieces | 19.61 | 19.61 | +0.0 | OK |
| cover distance mean_tall | 6.83 | 6.83 | +0.0 | OK |
| footprint % all | 6.9 | 6.9 | +0.0 | OK |

## Hall + both yards (new space; informative)
| metric | old | new | diff % | |
|---|---|---|---|---|
| route SpawnA -> centre novault_sprint | 3.13 | 3.1 | -1.0 | OK |
| route SpawnA -> centre vault_sprint | 3.13 | 3.1 | -1.0 | OK |
| route SpawnA -> centre path_len | 62.5 | 62.0 | -0.8 | OK |
| route SpawnB -> centre novault_sprint | 3.13 | 3.15 | +0.6 | OK |
| route SpawnB -> centre vault_sprint | 3.13 | 3.15 | +0.6 | OK |
| route SpawnB -> centre path_len | 62.5 | 63.0 | +0.8 | OK |
| route spawn -> spawn path | 123.3 | 123.3 | +0.0 | OK |
| route per-piece time from A, worst |  | W04 | +0.0 | OK |
| route per-piece time from B, worst |  | W04 | +0.0 | OK |
| exposure mean | 43.8 | 40.2 | -8.2 | OUT |
| exposure p10 | 30.2 | 25.2 | -16.6 | OUT |
| exposure p90 | 54.7 | 52.0 | -4.9 | OK |
| exposure min | 6.7 | 5.1 | -23.9 | OUT |
| exposure max | 60.6 | 56.4 | -6.9 | OUT |
| exposure 10-stud band, worst |  | band 53 | +8.8 | OUT |
| spawn-to-spawn sight % | 0.0 | 0.0 | +0.0 | OK |
| spawn view SpawnA floor seen % | 22.76 | 21.76 | -4.4 | OK |
| spawn view SpawnA sees centre | False | False | +0.0 | OK |
| spawn view SpawnB floor seen % | 21.81 | 21.34 | -2.1 | OK |
| spawn view SpawnB sees centre | False | False | +0.0 | OK |
| cover distance mean_walls | 3.96 | 4.04 | +2.0 | OK |
| cover distance max_pieces | 19.61 | 25.4 | +29.5 | OUT |
| cover distance mean_tall | 6.83 | 7.83 | +14.7 | OUT |
| footprint % all | 6.9 | 5.0 | -27.5 | OUT |

## The yards (new space behind the open doors)
- floor: hall 9234 sq studs; each yard ~528 sq studs of open apron (dead end, behind each team's spawn)
- north (B's end) yard: 120 sample cells; from the yard a player sees 22.4 % of the hall floor on average (max 43.4 %, through the 20-wide door); from the hall's end third the yard is 22.3 % visible
- south (A's end) yard: 100 sample cells; from the yard a player sees 22.5 % of the hall floor on average (max 42.7 %, through the 20-wide door); from the hall's end third the yard is 23.2 % visible
- routes: the yards are dead ends behind the spawns: every route between the spawns and to the centre is unchanged (table above)
- hall exposure bands with the doors open (denominator now includes yard cells, so not comparable 1:1): [[-57, 35.4], [-47, 40.5], [-37, 41.9], [-27, 43.2], [-17, 44.2], [-7, 46.1], [3, 45.4], [13, 43.0], [23, 43.2], [33, 41.0], [43, 37.0], [53, 32.1]]
