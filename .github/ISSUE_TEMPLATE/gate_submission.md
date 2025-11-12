---
name: Gate Submission
about: Invio pacchetto per revisione AI
title: "[SUBMIT] Gate P0"
labels: ["gate","review"]
---

## Gate
P0 — DNS/PKI/Connettività

## Summary.yaml
```yaml
(incolla qui il contenuto di GATES/P0_DNS_PKI_NET/SUMMARY.yaml)
```

## Evidenze

* EVIDENCE/dns_console.txt
* EVIDENCE/dns_proxies.txt
* EVIDENCE/pki_console.txt
* EVIDENCE/pki_proxies.txt
* EVIDENCE/reach_f2p.txt
* EVIDENCE/git_versions.txt
* CHECKSUMS.txt

## Richiesta di validazione (formato vincolato)

Rispondi esclusivamente con il seguente blocco:

```
=== REVIEW ===
Verdict: APPROVE | CHANGES_REQUESTED
Findings:
- [OK/ISSUE] <punto, citando file e riga>
Mandatory changes (if any):
- <azione puntuale + file di prova richiesto>
Optional improvements:
- <suggerimento non bloccante>
=== END ===
```
