# Gate P0 — DNS / PKI / Connectivity

## Scope
Validare i prerequisiti non negoziabili:
- DNS forward/reverse per console e smart proxy
- PKI (issuer, CN/SAN, scadenze) su 443 console e 9090 proxy
- Connettività TCP console → proxy (porte core)

## Evidence attese (in `EVIDENCE/`)
- `dns_console.txt`
- `dns_proxies.txt`
- `pki_console.txt`
- `pki_proxies.txt`
- `reach_f2p.txt`
- `proxies_list.txt` (facoltativo ma utile)
- `git_versions.txt`

## Raccolta
Esegui dalla **console**:
```bash
cd GATES/P0_DNS_PKI_NET
./collect_p0.sh
```

## Aggiornamenti richiesti

1. Compila `SUMMARY.yaml`:

   * `context.proxies_examined`
   * `assertions.*` a `true/false` in base alle evidenze
2. Rigenera checksum:

   ```bash
   ./update_checksums.sh
   ```

## Stato del gate

`GATE_STATE.json`:

* `DRAFT` → `SUBMITTED` → `APPROVED` → `EXECUTED` (o `REWORK`)

## Checklist Submission

* [ ] Evidenze presenti
* [ ] `SUMMARY.yaml` aggiornato
* [ ] `CHECKSUMS.txt` aggiornato
* [ ] Commit & push
* [ ] Issue **Gate Submission** aperta
