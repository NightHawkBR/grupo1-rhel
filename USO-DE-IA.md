# Declaração de uso de IA generativa

**Grupo 1 · Red Hat Enterprise Linux** · CP02 · Sistemas Operacionais Linux · FIAP · 2026
Período de uso: 15/09/2026 a 23/09/2026

## Resumo

Usamos **Claude (Anthropic)** como assistente durante todo o trabalho: para planejar, redigir documentos, escrever o script e diagnosticar erros durante a execução. **A IA não teve acesso à máquina virtual.** Todos os comandos foram digitados e executados pelo grupo na VM, e todas as saídas em `evidencias/` e todos os prints em `prints/` vêm dessa execução. Quando o resultado real contradisse o que a IA tinha escrito, **valeu o resultado real**, e o documento foi corrigido. A seção "Erros da IA detectados" lista esses casos.

## Onde a IA foi usada

| Ferramenta | Onde foi usada | Quem revisou | O que foi alterado após revisão |
|---|---|---|---|
| Claude (Anthropic) | Plano de execução (`docs/GUIA-GRUPO1-RHEL.md`) | Matheus Silva | Reescrito depois da execução com o que foi feito de fato: porta 6969, rede NAT + Host-Only, remoção do Cockpit, drop-in `01-`, política DEFAULT |
| Claude (Anthropic) | Guia de instalação (`INSTALL.md`) | Matheus Silva | Todos os valores trocados pelos obtidos na VM (UUIDs, tamanhos, saídas de `lsblk`, `vgs`, `luksDump`, `kdumpctl`); passos corrigidos onde o instalador real diferia do previsto |
| Claude (Anthropic) | Script `ssh-audit-harden.sh` (v1.0.0 e v1.1.0) | Matheus Silva | v1.0.0 executada na VM (evidências 21–30). Os achados dessa execução geraram a v1.1.0, validada na VM em 23/09 (evidência 31) |
| Claude (Anthropic) | Roteiro, notas do apresentador e geração dos slides | Matheus Silva | Demonstrações ao vivo trocadas por prints reais; slide de KDUMP e slides de história acrescentados; tempos refeitos |
| Claude (Anthropic) | Esqueleto e redação da pesquisa (`docs/pesquisa.md`), figuras e modelo ABNT do PDF | Matheus Silva `<confirmar após a leitura>` | Fatos de fora do laboratório conferidos em fontes primárias em 23/09/2026 (o que mudou: Insights → Lightspeed, ELC → ELCP, ML-DSA experimental no OpenSSH 10.4). Uma revisão independente,/ feita por outra instância de IA, cruzou cada afirmação com as evidências e apontou 11 problemas de rastreabilidade, todos corrigidos |
| Claude (Anthropic) | Diagnóstico de erros durante a execução (comandos digitados errado, mensagens do sistema) | Matheus Silva | Cada correção foi aplicada e conferida na própria VM antes de seguir |

## O que foi feito pelo grupo, sem IA

- Criação da VM, instalação do RHEL e todas as decisões tomadas nas telas do instalador.
- Execução de **todos** os comandos na VM, digitados à mão.
- Captura das 33 evidências em texto e dos prints de tela.
- As decisões de projeto: porta 6969, manter o `noexec` em `/var/tmp` depois do teste, manter a política DEFAULT depois do teste com FUTURE, KDUMP em automático, VM com 2 GB por causa do host de 8 GB.
- A guarda dos segredos: passphrases, chave privada SSH e backup do cabeçalho do LUKS nunca passaram pela IA nem pelo repositório.

## Erros da IA detectados na validação

Estes casos mostram por que nada entrou no repositório sem ser executado antes.

| O que a IA propôs | O que a VM mostrou | Correção | Evidência |
|---|---|---|---|
| `update-crypto-policies --set DEFAULT:NO-SHA1` | `NO-SHA1.pmod not found`: o submódulo não existe no RHEL 10.2 | Mantida a DEFAULT, que já recusa SHA-1 em assinaturas | `12`, `19` |
| Política `FUTURE` para ganhar criptografia pós-quântica | O cliente OpenSSH do Windows não conectou (*no matching key exchange method*) | Voltamos à DEFAULT e descobrimos que ela já oferece ML-KEM | `18`, `19`, print `04` |
| Drop-in de hardening com prefixo `99-` | `X11Forwarding` continuava `yes`: o `50-redhat.conf` é lido antes e, no OpenSSH, vale o primeiro valor | Renomeado para `01-`; a v1.1.0 passou a apontar o arquivo de origem | `21`, `22`, `23`, prints `05` e `06` |
| `--apply` da v1.0.0 sem `--porta` | Revisando o código após o achado acima: o drop-in seria regravado sem a linha `Port`, e o sshd voltaria à 22, fechada no firewall | v1.1.0 preserva a porta atual | `31` |
| "`noexec` em `/var/tmp` quebra o `dnf`" (afirmação comum em guias) | 147 pacotes atualizados e `reinstall bash` sem erro | `noexec` mantido; a afirmação virou "conflito previsto que não aconteceu" | `06b`, `06c` |
| Comando com `*` em `/root/luks/` sob `sudo` | A expansão é feita pelo shell do usuário, que não lê `/root` | Comando refeito dentro de `sudo sh -c '…'` | — |
| Descrição da evidência `09` como anterior à remoção do Cockpit | O arquivo já mostrava só `dhcpv6-client` | Descrição corrigida no `INSTALL.md` | `09` |
| Descrição da evidência `22` com uma saída de `sshd -T` | O arquivo contém só a lista dos drop-ins | Descrição corrigida; a linha do `50-redhat.conf` passou a ser citada pelo print | `22`, print `06` |

## Como verificamos

- **Na VM:** toda afirmação técnica do `INSTALL.md` e da apresentação tem um arquivo correspondente em `evidencias/` ou em `prints/`.
- **No script:** `bash -n` e `shellcheck` sem avisos. Além disso, execução real na VM: auditoria, aplicação, rollback, idempotência e erro de uso.
- **Fatos externos** (datas da história da Red Hat, ciclo de vida, mecanismo do kdump com LUKS, algoritmos pós-quânticos): conferidos em fontes primárias ou de referência, citadas nos slides e na pesquisa. Exemplos: sala de imprensa da Red Hat, LWN e as notas de versão do OpenSSH.

## Limites desta declaração

- A IA redigiu a maior parte do texto dos documentos. O grupo responde pelo conteúdo e sabe explicar cada decisão, mas a redação não é integralmente nossa.
- O teste do script v1.1.0 contra um `sshd` simulado foi feito pela IA, fora da VM. O teste que vale como evidência é o da VM (`31`).
