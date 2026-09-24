# Guia de execução — Grupo 1 · Red Hat Enterprise Linux

Checkpoint 02 — Ambiente Linux · Instalação segura, LVM sobre LUKS, SSH e Shell

**Recorte do grupo:** subscrição, ciclo de vida de 10 anos, Red Hat Insights
**Script do grupo:** `ssh-audit-harden.sh` — auditoria e hardening do OpenSSH
**Peso:** Instalação 30 · Script 20 · Documentação 20 · SSH 15 · Apresentação 15

> **Status (22/09/2026): trabalho de VM concluído.** Este guia foi o **plano** de execução. O registro do que foi feito de fato, com valores reais e saídas obtidas, está no `INSTALL.md`. As diferenças entre o plano e a execução foram incorporadas aqui:
>
> | Planejado | Executado | Por quê |
> |---|---|---|
> | Porta 2222 | **Porta 6969** | Escolha do grupo; mesma proteção |
> | Drop-in `99-hardening-...` | **`01-hardening-grupo1.conf`** | `50-redhat.conf` define `X11Forwarding yes` e o OpenSSH usa o primeiro valor lido |
> | `update-crypto-policies --set DEFAULT:NO-SHA1` | **DEFAULT mantida** | `NO-SHA1` não existe no RHEL 10.2; DEFAULT já recusa SHA-1 e já oferece ML-KEM pós-quântico |
> | `noexec` em `/var/tmp` quebraria o `dnf` | **Não quebrou** | 147 pacotes atualizados e `reinstall bash` sem erro; `noexec` mantido |
> | `ssh-copy-id` | **`type ... \| ssh ...` no PowerShell** | O Windows não tem `ssh-copy-id` |
> | Uma placa de rede | **NAT + Host-Only** | NAT para `dnf`, Host-Only para o SSH |
> | Script v1.0.0 | **v1.1.0** | Correções vindas dos testes no servidor (seção 10) |

---

## Sumário

1. [Ordem de ataque e divisão do grupo](#1-ordem-de-ataque-e-divisão-do-grupo)
2. [Estrutura do repositório](#2-estrutura-do-repositório)
3. [Fase 1 — ISO, subscrição e hash](#3-fase-1--iso-subscrição-e-hash)
4. [Fase 2 — Criação da VM](#4-fase-2--criação-da-vm)
5. [Fase 3 — Diagrama do particionamento (marco D-14)](#5-fase-3--diagrama-do-particionamento-marco-d-14)
6. [Fase 4 — Instalação com LVM sobre LUKS](#6-fase-4--instalação-com-lvm-sobre-luks)
7. [Fase 5 — Pós-instalação: opções de montagem](#7-fase-5--pós-instalação-opções-de-montagem)
8. [Fase 6 — Segundo disco, ciclo de vida do LVM e snapshot](#8-fase-6--segundo-disco-ciclo-de-vida-do-lvm-e-snapshot)
9. [Fase 7 — SSH endurecido](#9-fase-7--ssh-endurecido)
10. [Fase 8 — O script do grupo](#10-fase-8--o-script-do-grupo)
11. [Fase 9 — Coleta de evidências](#11-fase-9--coleta-de-evidências)
12. [Fase 10 — Documento de pesquisa](#12-fase-10--documento-de-pesquisa)
13. [Fase 11 — Apresentação e as cinco perguntas](#13-fase-11--apresentação-e-as-cinco-perguntas)
14. [Bônus: até 10 pontos extras](#14-bônus-até-10-pontos-extras)
15. [Armadilhas conhecidas](#15-armadilhas-conhecidas)
16. [Checklist final de entrega](#16-checklist-final-de-entrega)

---

## 1. Ordem de ataque e divisão do grupo

A tentação é todo mundo fazer a instalação junto e deixar documento e script para o fim. Isso é o que faz grupo perder ponto em documentação (20) e script (20), que somados valem mais que a instalação (30).

Sugestão de papéis (ajuste ao tamanho do grupo — **todos precisam apresentar algo**):

| Papel | Responsabilidade | Entregável dono |
|---|---|---|
| **Infra** | VM, particionamento, LUKS, LVM, segundo disco | INSTALL.md + evidências de disco |
| **SSH** | Chaves, sshd, firewalld, SELinux, banner, logs | Seção SSH + demo ao vivo |
| **Dev** | `ssh-audit-harden.sh`, shellcheck, testes | Script + evidência de execução |
| **Pesquisa** | Subscrição, ciclo de 10 anos, Insights, referências | PDF de 12–20 páginas |
| **Apresentação** | Slides, cronometragem, as 5 perguntas + gabarito | .pptx/PDF + gabarito D-2 |

Todo mundo commita no repositório. **Histórico distribuído é critério de nota** — combine commits pequenos e frequentes desde o dia 1, não um push gigante na véspera.

---

## 2. Estrutura do repositório

Crie isso hoje, antes de instalar qualquer coisa. Repositório vazio no D-18 já é um marco cumprido.

```
grupo1-rhel/
├── README.md                  # o que é, quem é o grupo, como navegar
├── INSTALL.md                 # guia reproduzível (o entregável 03)
├── USO-DE-IA.md               # declaração obrigatória de uso de IA
├── docs/
│   ├── pesquisa.pdf           # entregável 01
│   ├── pesquisa.md            # fonte do PDF
│   └── diagrama-particionamento.png
├── apresentacao/
│   ├── grupo1-rhel.pptx
│   ├── grupo1-rhel.pdf
│   └── gabarito-comentado.pdf # entregue ao professor 48h antes
├── scripts/
│   ├── ssh-audit-harden.sh
│   └── coletar-evidencias.sh
└── evidencias/
    ├── 01-disco/
    ├── 02-sistema-selinux/
    ├── 03-ssh-firewall/
    └── 04-script/
```

`USO-DE-IA.md` é exigência explícita do enunciado. Modelo mínimo:

```markdown
# Declaração de uso de IA generativa

| Ferramenta | Onde foi usada | Quem revisou | O que foi alterado após revisão |
|---|---|---|---|
| Claude (Anthropic) | Rascunho do guia de instalação e do script | <nome> | Ajustada a faixa de ClientAliveInterval; validado em VM real |

Todo conteúdo gerado foi verificado contra a documentação oficial da Red Hat
e testado no laboratório do grupo antes de entrar no repositório.
```

---

## 3. Fase 1 — ISO, subscrição e hash

O RHEL é o único dos seis que exige subscrição — e isso **é** o recorte de pesquisa do seu grupo. Aproveite: cada passo aqui vira parágrafo do documento.

1. Crie conta em `developers.redhat.com` e ative a **Red Hat Developer Subscription for Individuals** (gratuita, uso em desenvolvimento, limite de sistemas definido pelos termos vigentes — confirme o número atual na página oficial e cite a URL na pesquisa).
2. Baixe a ISO **Binary DVD** do RHEL 10 (x86_64).
3. Confira o hash. A página de download publica o SHA-256:

```bash
sha256sum rhel-10.x-x86_64-dvd.iso
# compare caractere a caractere com o valor publicado
```

Guarde a saída em `evidencias/01-disco/00-hash-iso.txt`. O enunciado pede o passo 2 explicitamente.

4. Depois de instalar, registre o sistema:

```bash
subscription-manager register --username <usuario>
subscription-manager status
subscription-manager repos --list-enabled
dnf repolist
```

> **Ponto de apresentação:** mostre `subscription-manager status` funcionando e explique o que acontece com um RHEL não registrado — sem repositório, sem errata, sem CVE corrigido. É exatamente o contraste com Rocky/Alma do os grupos de Rocky e AlmaLinux.

---

## 4. Fase 2 — Criação da VM

Configuração exigida pelo enunciado, em VirtualBox (adapte se usar KVM/VMware):

| Item | Valor | Onde |
|---|---|---|
| Tipo | Red Hat (64-bit) | Nova VM |
| Memória | 4096 MB (executado com **2048 MB** — host de 8 GB) | Sistema → Placa-mãe |
| **EFI** | **Habilitado** | Sistema → Placa-mãe → *Habilitar EFI* |
| vCPU | 2 | Sistema → Processador |
| Disco principal | 60 GB, VDI, dinâmico | Armazenamento |
| Adaptador 1 | **NAT** — internet para registro e `dnf` | Rede |
| Adaptador 2 | **Host-Only** — SSH a partir do notebook (`192.168.56.103`) | Rede |
| Dispositivo apontador | **Tablet USB** (com controlador USB habilitado) | Sistema → Placa-mãe |

Nunca Bridge. Host-Only sozinha **não tem internet** — foi o que travou o registro no laboratório. NAT sozinha exige redirecionamento de portas para o SSH. As duas juntas resolvem, e o dia da apresentação não depende da rede da faculdade.

**Não adicione o segundo disco agora.** Ele entra na Fase 6, depois da instalação — é isso que torna o exercício de LVM realista.

---

## 5. Fase 3 — Diagrama do particionamento (marco D-14)

Este marco não é opcional e vem **antes** de instalar. Desenhe (draw.io, Excalidraw ou até Mermaid no README) e submeta.

```
/dev/sda (60 GB, GPT/UEFI)
│
├── sda1   1 GB    FAT32   /boot/efi          [ FORA da criptografia ]
├── sda2   1 GB    xfs     /boot              [ FORA da criptografia ]
└── sda3  ~58 GB   LUKS2   container criptografado
        └── /dev/mapper/luks-abd2ecaa-...  (PV)
            └── VG vg_sistema
                ├── lv_root     15 G  /          xfs
                ├── lv_var       8 G  /var       xfs   nodev
                ├── lv_varlog    5 G  /var/log   xfs   nodev,nosuid,noexec
                ├── lv_vartmp    3 G  /var/tmp   xfs   nodev,nosuid,noexec
                ├── lv_home     10 G  /home      xfs   nodev,nosuid
                ├── lv_tmp       3 G  /tmp       xfs   nodev,nosuid,noexec
                ├── lv_swap      4 G  swap
                └── ~10 G livres  → snapshots e emergência
```

Junto do desenho, entregue a **tabela de justificativas**. O professor cobra "a justificativa de cada decisão" em 5 minutos de apresentação:

| Decisão | Justificativa | Risco aceito |
|---|---|---|
| LVM sobre LUKS (um container) | Uma passphrase no boot; todo LV novo já nasce criptografado; VG inteiro protegido | Se o header do LUKS corromper, perde-se tudo — daí o backup do header |
| `/boot` fora do LUKS | GRUB precisa ler kernel e initramfs antes de existir chave | Kernel e initramfs em claro: adulteração offline é possível (mitigável com Secure Boot / bônus) |
| `/var/log` separado | Log cheio não derruba `/`; protege integridade da trilha de auditoria | Mais um ponto de "disco cheio" para monitorar |
| `/tmp` e `/var/tmp` separados com `noexec` | Diretórios com sticky bit graváveis por todos são o vetor clássico de escalonamento | `dnf`/RPM extraem em `/var/tmp` — pode quebrar atualização |
| ~10 G livres no VG | Sem espaço livre não há snapshot nem socorro a volume cheio | "Desperdício" aparente de disco |

> Documentar o conflito que você **realmente** encontrou vale mais nota do que copiar a tabela do slide. Teste `noexec` em `/var/tmp` e registre o que quebrou.

---

## 6. Fase 4 — Instalação com LVM sobre LUKS

### O ponto em que a maioria dos grupos erra

Existem duas formas de combinar LUKS e LVM, e elas são **opostas**:

- **LUKS sobre LVM** (errado para este trabalho): você marca "Criptografar" em cada volume lógico. Resultado: vários containers, várias passphrases, `/boot` e metadados do VG expostos.
- **LVM sobre LUKS** (o que o enunciado pede): a criptografia fica **na partição física**, e o volume group inteiro vive dentro dela. Uma passphrase, um container.

No Anaconda, a diferença está em **onde** você marca o checkbox *Encrypt*.

> ### ⚠️ "Encrypt my data" some quando eu marco Custom — e está certo
>
> Não é falha da ISO nem da VM. O checkbox *Encrypt my data* pertence **exclusivamente ao particionamento automático**. Assim que você escolhe *Custom* em *Storage Configuration*, ele desaparece da tela, por desenho do instalador.
>
> Com particionamento manual, a criptografia é definida **dentro da tela Manual Partitioning**, e é lá que se escolhe o nível:
>
> - checkbox *Encrypt* no **volume lógico** (painel da direita) → criptografa aquele LV → **LUKS sobre LVM** ✖
> - checkbox *Encrypt* na janela **Configure Volume Group** (*Modify...*) → criptografa o **volume físico**, e com ele todos os LVs que vivem dentro → **LVM sobre LUKS** ✔
>
> A passphrase não é pedida no começo: o Anaconda a solicita **ao sair do particionamento**, quando você clica em *Done*.
>
> Ou seja: o esquema que o trabalho pede continua 100% possível — só não passa pela tela de destino. Vale citar isso na apresentação: é exatamente o tipo de detalhe que separa quem instalou de quem leu tutorial.

### Passo a passo no instalador gráfico

1. Boot pela ISO → *Install Red Hat Enterprise Linux*.
2. Idioma, teclado, fuso (`America/Sao_Paulo`), rede e hostname (ex.: `rhel-grupo1`).
3. **Software Selection → Minimal Install** (ou *Server*, sem GUI). O enunciado exige sem interface gráfica.
4. **Installation Destination**:
   - Selecione o disco de 60 GB.
   - Em *Storage Configuration*, marque **Custom**.
   - *Encrypt my data* some da tela — **esperado**. Siga em frente.
   - *Done*.
5. Abre a tela **Manual Partitioning**. Escolha o esquema **LVM** no seletor e crie os pontos de montagem com o botão `+`:

| Mount Point | Capacidade | Device Type | File System |
|---|---|---|---|
| `/boot/efi` | 1 GiB | Standard Partition | EFI System Partition |
| `/boot` | 1 GiB | Standard Partition | xfs |
| `/` | 15 GiB | LVM | xfs |
| `/var` | 8 GiB | LVM | xfs |
| `/var/log` | 5 GiB | LVM | xfs |
| `/var/tmp` | 3 GiB | LVM | xfs |
| `/home` | 10 GiB | LVM | xfs |
| `/tmp` | 3 GiB | LVM | xfs |
| swap | 4 GiB | LVM | swap |

6. 🔴 **Configure o Volume Group uma única vez** — este é o passo que substitui o *Encrypt my data*: selecione o volume LVM recém-criado → botão *Modify...* ao lado de *Volume Group* →
   - Nome: `vg_sistema`
   - **Encrypt: marcado** ← é *aqui* que nasce o container único
   - *Size policy*: deixe em **Automatic** por enquanto (ver passo 8)
   - *Save*
7. **Sempre preencha a *Desired Capacity*** ao criar cada ponto de montagem. Campo em branco faz o Anaconda entregar **todo** o espaço livre àquele volume — e o próximo `+` falha com *"Não foi possível alocar o esquema de partição solicitado"*.
8. Depois que **todos** os volumes existirem com os tamanhos corretos, volte em *Modify...* do Volume Group e troque a *Size policy* para **As large as possible** → *Save*.
   - Com *Automatic*, o VG encolhe para caber exatamente nos volumes e sobra **zero** espaço livre — foi o que produziu o `rhel (0 B livre)` do layout automático.
   - Com *As large as possible*, o VG passa a ocupar os ~58 GiB do container: os sete volumes somam 48 G e sobram ~10 GiB livres **dentro do VG**, que é onde o snapshot precisa deles.
   - A troca vai por último de propósito: com o VG já esticado ao máximo, o contador *Espaço disponível* do rodapé zera e adicionar volumes novos fica confuso.
9. **Não marque** o *Encrypt* do painel da direita em nenhum volume lógico. Marcar ali cria um LUKS por LV — o esquema oposto ao que o trabalho pede.
10. Renomeie os volumes lógicos (`lv_root`, `lv_var`, `lv_varlog`, `lv_vartmp`, `lv_home`, `lv_tmp`, `lv_swap`) no campo *Name*.
11. Confirme que `/boot` e `/boot/efi` **não** estão com *Encrypt* marcado e continuam como *Standard Partition*.
12. *Done* → agora sim surge a caixa de **passphrase do LUKS**. Digite duas vezes, **anote em lugar seguro** e clique em *Save Passphrase*.
    - ⚠️ Nessa caixa o layout de teclado não pode ser trocado — ela usa o layout inglês. Se sua passphrase tem `ç`, `ã` ou símbolos que mudam de posição no ABNT2, você vai descobrir na hora do primeiro boot. Use só `[A-Za-z0-9]` e alguns símbolos seguros (`-`, `_`, `.`).
13. Revise o **Summary of Changes** — procure por uma linha de criação de LUKS em `sda3` e **nenhuma** em volumes individuais → *Accept Changes*.
12. Crie o usuário administrativo nominal (ex.: `nighthawk`) e **defina uma senha de root forte** — o enunciado exige `PermitRootLogin no` no SSH, não conta root desabilitada no sistema. Não crie usuário genérico compartilhado.
13. Instale, reinicie, retire a ISO.

> **Se o *Encrypt* da janela Configure Volume Group estiver cinza (indisponível):** é porque o VG já foi materializado com volumes dentro. Apague todos os pontos de montagem LVM criados (botão `-`), recrie o primeiro deles e configure o VG com *Encrypt* **antes** de adicionar os demais. A ordem importa: VG criptografado primeiro, volumes depois.

> Se a sua ISO abrir o instalador web em vez do gráfico clássico e ele não oferecer layout customizado completo, há um caminho alternativo: no console do instalador (`Ctrl+Alt+F2`) monte o layout à mão com `parted`, `cryptsetup luksFormat --type luks2`, `pvcreate`, `vgcreate`, `lvcreate`, e depois volte ao instalador para apenas **atribuir pontos de montagem** aos volumes já criados. Documente qual caminho vocês usaram.

### Validação imediata (primeiro boot)

```bash
lsblk -f
cryptsetup luksDump /dev/sda3 | head -30
pvs ; vgs ; lvs
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS
getenforce            # precisa responder Enforcing
```

O `lsblk` correto se parece com isto — repare que existe **um** nó `crypt` e o VG vem **abaixo** dele:

```
sda3          crypto_LUKS
└─luks-abd2ecaa-...   LVM2_member
  ├─vg_sistema-lv_root   xfs   /
  ├─vg_sistema-lv_var    xfs   /var
  ...
```

Se você vir `crypt` repetido dentro de cada LV, o esquema está invertido: refaça. Corrigir isso depois custa reinstalação.

### 🔴 Antes de continuar

```bash
# backup do header do LUKS — sem isso, um setor ruim apaga tudo
mkdir -p /root/luks
cryptsetup luksHeaderBackup /dev/sda3 --header-backup-file /root/luks/sda3-header.img
chmod 600 /root/luks/sda3-header.img
# copie para FORA da VM
```

E tire o **snapshot 1 — instalação limpa** no hipervisor. Você vai quebrar o ambiente; todo mundo quebra.

---

## 7. Fase 5 — Pós-instalação: opções de montagem

O Anaconda não aplica `nodev,nosuid,noexec`. Isso é trabalho manual — e é o que o enunciado chama de "segurança é configuração, não instalação".

```bash
cp /etc/fstab /etc/fstab.bak-$(date +%F)
vi /etc/fstab
```

Ajuste a quarta coluna:

```
/dev/mapper/vg_sistema-lv_home    /home      xfs  defaults,nodev,nosuid          0 0
/dev/mapper/vg_sistema-lv_tmp     /tmp       xfs  defaults,nodev,nosuid,noexec   0 0
/dev/mapper/vg_sistema-lv_vartmp  /var/tmp   xfs  defaults,nodev,nosuid,noexec   0 0
/dev/mapper/vg_sistema-lv_varlog  /var/log   xfs  defaults,nodev,nosuid,noexec   0 0
/dev/mapper/vg_sistema-lv_var     /var       xfs  defaults,nodev                 0 0
UUID=<uuid-do-boot>               /boot      xfs  defaults,nodev,nosuid          0 0
```

Aplique sem reiniciar e valide:

```bash
mount -o remount /home /tmp /var/tmp /var/log /var /boot
findmnt -o TARGET,OPTIONS
```

### Teste que prova que a opção funciona (isso vai para a evidência)

```bash
printf '#!/bin/bash\necho executou\n' > /tmp/teste.sh
chmod +x /tmp/teste.sh
/tmp/teste.sh          # esperado: Permission denied
bash /tmp/teste.sh     # observação honesta: isto ainda funciona
rm -f /tmp/teste.sh
```

> **Ouro para a apresentação:** `noexec` impede a execução direta do binário, mas não impede `bash script.sh`, porque quem executa é o interpretador, não o arquivo. Um grupo que explica essa limitação demonstra domínio; um grupo que apresenta `noexec` como bala de prata leva a pergunta do professor na veia.

### O conflito que você deve documentar

`noexec` em `/var/tmp` pode quebrar operações do `dnf`/RPM que extraem e executam scriptlets ali. Teste de verdade:

```bash
dnf -y update
dnf -y reinstall bash
```

Se quebrar, você tem duas saídas: remover o `noexec` de `/var/tmp` e justificar, ou manter e documentar o procedimento de remontagem temporária durante manutenção:

```bash
mount -o remount,exec /var/tmp && dnf -y update && mount -o remount,noexec /var/tmp
```

Qualquer uma das duas dá nota. Copiar a tabela sem testar, não.

> **Resultado no laboratório:** o `dnf update` de 147 pacotes e o `reinstall bash` passaram **sem erro** com `noexec` em `/var/tmp`. Decisão: manter o `noexec`, com a remontagem acima documentada como contingência. Testar e não encontrar o conflito é resultado — e mais forte do que repetir o aviso dos guias. (Evidências: `06b-teste-noexec.txt`, `06c-dnf-com-noexec.txt`.)

---

## 8. Fase 6 — Segundo disco, ciclo de vida do LVM e snapshot

Desligue a VM, adicione o disco de **20 GB**, ligue de novo.

```bash
lsblk        # deve aparecer sdb, 20G, sem partição
```

### 8.1 O segundo disco também precisa ser criptografado

Se você fizer `pvcreate /dev/sdb` direto, metade do seu VG fica em claro — e alguém vai perguntar isso na apresentação.

```bash
cryptsetup luksFormat --type luks2 /dev/sdb
cryptsetup open /dev/sdb cryptdados
cryptsetup status cryptdados
```

Para não digitar uma segunda passphrase a cada boot, use um **arquivo de chave** guardado dentro do sistema já criptografado:

```bash
mkdir -p /etc/luks-keys && chmod 700 /etc/luks-keys
dd if=/dev/urandom of=/etc/luks-keys/dados.key bs=512 count=8
chmod 600 /etc/luks-keys/dados.key
cryptsetup luksAddKey /dev/sdb /etc/luks-keys/dados.key
cryptsetup luksDump /dev/sdb | grep -A2 Keyslots
```

`/etc/crypttab` (use o UUID, não `/dev/sdb`, que pode mudar de nome):

```bash
blkid -s UUID -o value /dev/sdb
echo "cryptdados UUID=<uuid> /etc/luks-keys/dados.key luks" >> /etc/crypttab
```

### 8.2 Estender o VG e exercitar o ciclo de vida

```bash
pvcreate /dev/mapper/cryptdados
vgextend vg_sistema /dev/mapper/cryptdados
vgs ; pvs

# novo volume no disco novo
lvcreate -L 8G -n lv_dados vg_sistema /dev/mapper/cryptdados
mkfs.xfs /dev/vg_sistema/lv_dados
mkdir -p /srv/dados
echo "/dev/mapper/vg_sistema-lv_dados /srv/dados xfs defaults,nodev,nosuid,nofail 0 0" >> /etc/fstab
mount /srv/dados
df -h /srv/dados

# crescimento a quente — com o filesystem montado e em uso
lvextend -L +5G /dev/vg_sistema/lv_dados
xfs_growfs /srv/dados
df -h /srv/dados
```

> **Escolha consciente:** crescer `/var` para dentro do segundo disco cria dependência de boot (o `/var` passaria a precisar do `cryptdados` destravado bem cedo no boot, e a chave está em `/etc`). Por isso o guia cresce um volume novo em `/srv/dados` e usa `nofail`. Explique essa decisão — ela mostra que o grupo pensou na ordem de inicialização, não só nos comandos.
>
> Lembre também que **XFS só cresce, nunca encolhe**. `lvreduce` em XFS destrói dados. Isso costuma ser uma boa pergunta dissertativa.

### 8.3 Snapshot — a justificativa do espaço livre

```bash
lvcreate -s -L 2G -n snap_root /dev/vg_sistema/lv_root
lvs -o +lv_when_full,origin,data_percent
# para inspecionar um snapshot XFS é obrigatório nouuid
mkdir -p /mnt/snap && mount -o ro,nouuid /dev/vg_sistema/snap_root /mnt/snap
ls /mnt/snap
umount /mnt/snap && lvremove -y /dev/vg_sistema/snap_root
```

Isso prova na prática por que VG a 100% é problema, e não otimização.

**Snapshot 2 no hipervisor** depois desta fase.

---

## 9. Fase 7 — SSH endurecido

### Regra de ouro, repetida porque vale 15 pontos

Abra **duas** sessões e mantenha o console do VirtualBox aberto como terceira via. Nunca feche a sessão atual antes de validar a nova em paralelo.

### 9.1 Grupo dedicado e chave ed25519

```bash
# no servidor
groupadd ssh-admins
usermod -aG ssh-admins nighthawk
id nighthawk
```

```powershell
# no notebook (PowerShell COMUM, não como Administrador)
ssh-keygen -t ed25519 -a 100 -C "grupo1-rhel"      # caminho: só Enter · passphrase: nova, protege a chave
ssh nighthawk@192.168.56.103                         # primeiro acesso por senha; aceite a impressão digital
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh nighthawk@192.168.56.103 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
ssh nighthawk@192.168.56.103 "echo login por chave OK"
```

O Windows não tem `ssh-copy-id`; o `type ... | ssh` faz o mesmo. A chave precisa estar no **notebook que roda a VM**: a rede Host-Only não existe fora dele.

Só siga adiante depois que o login por chave funcionar. Se você desabilitar senha antes disso, perdeu o acesso.

### 9.2 Porta não padrão: SELinux e firewalld **antes** do sshd

A ordem importa. Mudar a porta no `sshd_config` primeiro é o jeito clássico de se trancar do lado de fora.

```bash
dnf install -y policycoreutils-python-utils
semanage port -a -t ssh_port_t -p tcp 6969
semanage port -l | grep ssh          # evidência

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="6969" protocol="tcp" accept limit value="10/m"'
firewall-cmd --permanent --remove-service=ssh
firewall-cmd --permanent --remove-service=cockpit   # vinha aberto pelo perfil de instalação
firewall-cmd --reload
firewall-cmd --list-all              # evidência
```

Usar **só** a rich rule com `limit` (sem `--add-port` em paralelo) é o que faz o limite de taxa valer de fato — uma regra de aceite simples para a mesma porta anula o efeito do limite.

### 9.3 Banner legal

```bash
cat > /etc/issue.net <<'EOF'
***************************************************************************
                        AVISO DE ACESSO RESTRITO
Este sistema é de uso exclusivamente autorizado. Toda atividade é
registrada e monitorada. O acesso ou uso não autorizado é proibido e
sujeito às sanções da Lei 12.737/2012 (art. 154-A do Código Penal).
Ao prosseguir, você declara estar autorizado e concorda com o monitoramento.
***************************************************************************
EOF
chmod 644 /etc/issue.net
```

### 9.4 Configuração do sshd em drop-in

No RHEL, `/etc/ssh/sshd_config` começa com um `Include /etc/ssh/sshd_config.d/*.conf`. Editar um drop-in é mais limpo que mexer no arquivo principal (e é o que o script do grupo faz).

> 🔴 **O nome do arquivo importa.** O OpenSSH usa o **primeiro** valor obtido para cada diretiva e lê os drop-ins em ordem alfabética. O RHEL 10 traz `40-redhat-crypto-policies.conf` e `50-redhat.conf`, e este último define `X11Forwarding yes`. No laboratório o drop-in nasceu como `99-...` e o `X11Forwarding` ficou `yes` apesar do `no` escrito — o script do grupo detectou. Por isso o prefixo é **`01-`**.

```bash
cat > /etc/ssh/sshd_config.d/01-hardening-grupo1.conf <<'EOF'
Port 6969
AllowGroups ssh-admins
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
HostbasedAuthentication no
IgnoreRhosts yes
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
MaxSessions 4
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
GatewayPorts no
PermitUserEnvironment no
Compression no
LogLevel VERBOSE
Banner /etc/issue.net
EOF
chmod 600 /etc/ssh/sshd_config.d/01-hardening-grupo1.conf
restorecon -Rv /etc/ssh

sshd -t && systemctl restart sshd    # NUNCA sem o -t antes; restart porque a porta mudou
ss -tulpn | grep 6969
```

Abra a **segunda sessão** agora: `ssh -p 6969 nighthawk@<ip>`. Só depois que ela entrar, feche a primeira.

> Se a porta não subir mesmo com o `sshd_config` correto, verifique se a sua instalação usa ativação por socket: `systemctl is-enabled sshd.socket`. Quando o socket do systemd é quem escuta, a diretiva `Port` é ignorada e a porta se define em um drop-in de `sshd.socket` com `ListenStream=` vazio seguido de `ListenStream=6969`. Confira antes de culpar o SELinux.

### 9.5 Criptografia: o jeito Red Hat

O enunciado pede `update-crypto-policies` aplicado e algoritmos legados removidos. No RHEL, a política do sistema é a fonte da verdade — definir `Ciphers`/`MACs` na mão no `sshd_config` sobrepõe a política e é justamente o que a Red Hat desaconselha.

O que aconteceu no laboratório, e virou o bônus do grupo:

1. `update-crypto-policies --set DEFAULT:NO-SHA1` → **`NO-SHA1.pmod not found`**. O submódulo não existe no RHEL 10.2; a DEFAULT já recusa SHA-1 em assinaturas (o journal registra *"SHA1 in signatures is disabled for RSA keys"*).
2. `--set FUTURE` → o servidor passou a oferecer **só** troca de chaves híbrida pós-quântica (`mlkem768x25519-sha256`, `mlkem768nistp256-sha256`, `mlkem1024nistp384-sha384`) e o cliente do Windows falhou com *"no matching key exchange method found"*.
3. De volta à DEFAULT: ela **já oferece** os mesmos três ML-KEM, ao lado dos clássicos. A negociação real com o Windows caiu em `curve25519-sha256`.
4. **Decisão:** manter DEFAULT. Limite: a autenticação (`ssh-ed25519`) continua clássica.

```bash
update-crypto-policies --show                                   # DEFAULT
sshd -T | grep -i kexalgorithms | tr ',' '\n' | grep -i mlkem    # os três ML-KEM
```

Passo a passo completo no `INSTALL.md`, seção 10. Evidências: `13`, `14`, `17`, `18`, `19`.

### 9.6 Evidências de acesso (exigidas)

```bash
# 1. acesso por chave funcionando
ssh -p 6969 nighthawk@<ip> 'hostname; date'

# 2. tentativa por senha corretamente bloqueada
ssh -p 6969 -o PubkeyAuthentication=no -o PreferredAuthentications=password nighthawk@<ip>
# esperado: Permission denied (publickey)

# 3. usuário fora do grupo bloqueado
useradd teste-negado
ssh -p 6969 teste-negado@<ip>
# esperado: Permission denied

# 4. registro no journald
journalctl -u sshd -S "-30 min" --no-pager | tail -40
```

> No RHEL 10 o OpenSSH foi dividido em binários especializados (`sshd`, `sshd-session`, `sshd-auth`), então parte das mensagens de autenticação aparece com essa origem no journal. Não se assuste se o `grep sshd` clássico devolver menos linhas do que você esperava — use `journalctl -u sshd` e `_COMM=sshd-session`.

**Snapshot 3 — SSH configurado.**

---

## 10. Fase 8 — O script do grupo

O arquivo `ssh-audit-harden.sh` (v1.1.0) implementa o que o enunciado pede para o Grupo 1 e os requisitos comuns aos seis grupos:

| Requisito | Onde está |
|---|---|
| `set -euo pipefail` após o shebang | linha 36, logo após o cabeçalho |
| Mínimo 5 funções, nada solto no corpo | 23 funções, tudo sob `main` |
| `getopts`/`case`, `-h` e `--help` | `processar_parametros()` |
| Privilégio via `EUID`, dependência via `command -v` | `verificar_privilegio()`, `verificar_dependencias()` |
| Log com timestamp e INFO/WARN/ERROR em `/var/log/` | `log()` → `/var/log/ssh-audit-harden.log` |
| Saídas 0/1/2/3 | constantes `EXIT_*` |
| Idempotência | `gerar_dropin()` produz saída determinística; `cmp -s` evita reescrita |
| Sem segredo no código | nenhuma chave ou senha embutida |
| `trap` + `mktemp` | `limpar()` com `trap limpar EXIT` |
| shellcheck sem erros | validado |
| Reversibilidade | `--rollback` restaura o último backup |
| Português | comentários e mensagens |
| 12+ diretivas comparadas com `sshd -T` | 20 diretivas + `AllowGroups` + `Port` |
| Validação com `sshd -t` e restauração automática | `validar_e_recarregar()` |
| Precedência de drop-ins (v1.1.0) | `origem_diretiva()`, `verificar_pos_aplicacao()` |
| Porta preservada sem `--porta` (v1.1.0) | `portas_atuais()` em `gerar_dropin()` |

### Como testar e gerar a evidência

```bash
scp -P 6969 ssh-audit-harden.sh nighthawk@192.168.56.103:/tmp/
ssh -p 6969 nighthawk@192.168.56.103
sudo install -o root -g root -m 0750 /tmp/ssh-audit-harden.sh /usr/local/sbin/
S=/usr/local/sbin/ssh-audit-harden.sh     # caminho completo: sudo pode não ter /usr/local/sbin no PATH

# 1. ajuda e versão
sudo $S --help
sudo $S --version

# 2. auditoria com a configuração padrão (antes do hardening) — deve achar coisas
sudo $S --audit ; echo "exit=$?"     # exit=1

# 3. aplicação
sudo $S --apply --porta 6969 ; echo "exit=$?"

# 4. idempotência: rodar de novo não muda nada
sudo $S --apply --porta 6969 ; echo "exit=$?"
# log deve dizer: "Configuracao ja esta na baseline. Nada a fazer (idempotente)."

# 5. auditoria limpa
sudo $S --audit ; echo "exit=$?"     # exit=0

# 6. rollback
sudo $S --rollback ; echo "exit=$?"

# 7. erros de uso
sudo $S --parametro-que-nao-existe ; echo "exit=$?"   # exit=2
```

Grave tudo com `script`:

```bash
script -q -c "sudo ssh-audit-harden.sh --audit" evidencias/04-script/audit-antes.txt
```

**Para os 4 pontos de "execução ao vivo":** o roteiro mais convincente é rodar `--audit` mostrando a configuração já endurecida (tudo CONFORME, exit 0), então quebrar de propósito uma diretiva **dentro do próprio drop-in** (`sudo sed -i 's/^MaxAuthTries 3/MaxAuthTries 10/' /etc/ssh/sshd_config.d/01-hardening-grupo1.conf && sudo systemctl reload sshd`), rodar `--audit` de novo (NAO-CONFORME, exit 1), rodar `--apply` e mostrar a correção. Três minutos, história completa, impossível de confundir com slide decorado.

> **Atualização (22/09):** a apresentação foi montada com **prints** (notebook de 8 GB). O slide 22 mostra o achado real (`X11Forwarding`) com print e evidências 21–28. ⚠️ Se o enunciado dá pontos específicos para **execução ao vivo do script**, os prints podem não valer esses pontos: confirme com o professor ou rode só o script ao vivo (VM mínima, com navegador e Docker fechados; roteiro no slide oculto 35).

> ⚠️ Não quebre com um arquivo novo: um `98-quebra.conf` é lido **depois** do `01-` e não muda nada; um `00-quebra.conf` é lido **antes** e o `--apply` não consegue corrigir (a v1.1.0 avisa e aponta o arquivo).

### Comparação obrigatória no relatório

Cada grupo precisa comparar seu script com a ferramenta de mercado equivalente. Para o nosso, compare com:

- **ssh-audit** (projeto open source) — faz varredura remota de algoritmos; seu script faz leitura local da configuração efetiva. Escopos diferentes, complementares.
- **OpenSCAP / `oscap`** com perfil CIS ou STIG — cobre o sistema inteiro, inclusive SSH, mas não corrige com rollback granular.
- **Ansible Role de hardening** (ex.: `ansible-lockdown`) — idempotente por natureza e escalável para frota; seu script é autocontido e não exige infraestrutura.

Uma tabela com "o que o meu faz melhor / o que a ferramenta faz melhor" é meio slide e meia página de relatório.

---

## 11. Fase 9 — Coleta de evidências

O enunciado é explícito: **texto é preferido a print**, porque pode ser conferido.

> **Como ficou no laboratório:** as evidências foram gravadas uma a uma por redirecionamento, numa pasta única `~/evidencias/` numerada de `01` a `30`, e copiadas ao notebook com `scp -P 6969 -r`. A lista completa, com o que cada arquivo prova, está no `INSTALL.md`, seção 12. O script abaixo continua útil para recoletar tudo de uma vez.

Crie `scripts/coletar-evidencias.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DESTINO="${1:-/tmp/evidencias-$(date +%F)}"
mkdir -p "${DESTINO}"/{01-disco,02-sistema-selinux,03-ssh-firewall,04-script}

# 01 - disco, LUKS e LVM
{ lsblk -f; echo; cryptsetup luksDump /dev/sda3; echo; pvs; vgs; lvs; } \
    > "${DESTINO}/01-disco/layout.txt"
findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS > "${DESTINO}/01-disco/montagens.txt"
{ cat /etc/fstab; echo "--- crypttab ---"; cat /etc/crypttab; } \
    > "${DESTINO}/01-disco/fstab-crypttab.txt"

# 02 - sistema e SELinux
{ cat /etc/os-release; echo; uname -r; echo; getenforce; echo; sestatus; } \
    > "${DESTINO}/02-sistema-selinux/sistema.txt"
subscription-manager status > "${DESTINO}/02-sistema-selinux/subscricao.txt" 2>&1 || true

# 03 - SSH e firewall
sshd -T                       > "${DESTINO}/03-ssh-firewall/sshd-T.txt"
systemctl status sshd --no-pager > "${DESTINO}/03-ssh-firewall/sshd-status.txt" 2>&1
firewall-cmd --list-all       > "${DESTINO}/03-ssh-firewall/firewalld.txt"
ss -tulpn                     > "${DESTINO}/03-ssh-firewall/portas.txt"
semanage port -l | grep ssh   > "${DESTINO}/03-ssh-firewall/selinux-porta.txt"
update-crypto-policies --show > "${DESTINO}/03-ssh-firewall/crypto-policy.txt"

echo "Evidências em ${DESTINO}"
```

Rode como root, copie para `evidencias/` no repositório e commite. **Toda afirmação do documento precisa ter evidência correspondente** — quando escrever "o SELinux permaneceu em Enforcing", o arquivo com `getenforce` tem que existir.

---

## 12. Fase 10 — Documento de pesquisa

12 a 20 páginas, mínimo 8 referências, 4 delas primárias. Estrutura sugerida para o recorte **subscrição · ciclo de 10 anos · Insights**:

| Seção | Páginas | Conteúdo |
|---|---|---|
| 1. Introdução | 1 | Por que RHEL domina banco, telecom e governo |
| 2. Modelo de subscrição | 3–4 | O que se compra (não é licença de software, é acesso a errata, suporte, certificação e indenização de propriedade intelectual); tipos de subscrição; Developer Subscription; `subscription-manager` na prática; o que acontece com um RHEL sem registro |
| 3. Ciclo de vida de 10 anos | 3–4 | Full Support → Maintenance Support → ELS; EUS para versões menores; o que significa backport de correção sem troca de versão do pacote; comparação com o ciclo de ~13 meses do Fedora (Grupo 5) e com o modelo contínuo do CentOS Stream (upstream continuo) |
| 4. Red Hat Insights | 3–4 | Arquitetura (client, upload, regras), o que detecta (vulnerabilidade, conformidade, advisor, patch, malware), o que ele **envia** para a Red Hat e como isso é tratado — a discussão de privacidade e telemetria é o que diferencia o trabalho |
| 5. RHEL vs. rebuilds | 2 | O contexto de 2023 (fim do acesso público ao código-fonte dos pacotes) e como isso originou o RESF/Rocky e a mudança da AlmaLinux para compatibilidade de ABI |
| 6. Aplicação prática | 2–3 | O que foi instalado e configurado no laboratório, com referência às evidências |
| 7. Conclusão + referências | 1–2 | |

**Referências primárias** (as 4 obrigatórias saem daqui):

- `access.redhat.com/support/policy/updates/errata` — política e datas do ciclo de vida
- `docs.redhat.com` — documentação do RHEL 10 (instalação, segurança, criptografia de disco, política de criptografia)
- `access.redhat.com/products/red-hat-insights` e a documentação do Insights
- `developers.redhat.com/products/rhel/download` — termos da Developer Subscription
- Notas de lançamento do RHEL 10 em `docs.redhat.com`

**Secundárias:** LWN, artigos técnicos da própria Red Hat (blog), CIS Benchmark para RHEL, manual do `cryptsetup`, RFC do ed25519 (RFC 8709).

⚠️ **Datas e números mudam.** Não copie "10 anos = 5 + 5" de um blog: abra a página oficial de ciclo de vida, veja as datas do RHEL 10 e cite a URL com data de acesso. Conteúdo tecnicamente errado é penalizado independentemente da origem — e esse é justamente o tipo de fato que envelhece.

---

## 13. Fase 11 — Apresentação e as cinco perguntas

### Divisão dos 30 minutos (cronometrada, −2 pontos por minuto excedido)

| Tempo | Bloco | Quem | Dica |
|---|---|---|---|
| 5:40 | RHEL: história, subscrição, ciclo, Insights | Pesquisa | Um número forte por slide, não parágrafos |
| 4:40 | Esquema de particionamento | Infra | O diagrama grande e a tabela de justificativas |
| 7 min | Instalação LVM/LUKS | Infra | **Prints da instalação** (slides 12–13) — sem vídeo: o notebook de 8 GB não grava a VM com folga; instalar ao vivo em 7 min é risco puro |
| 5:20 | SSH endurecido | SSH | **Prints** (slide 19): chave entra, senha é negada, journal mostra o `teste-negado`. Ao vivo só se o professor pedir (slide oculto 35) |
| 4:20 | Script | Dev | **Prints** do achado real (slide 22); roteiro quebra→detecta→corrige da Fase 8 só se for ao vivo |
| 3 min | As 5 perguntas | Apresentação | Mentimeter ou mão levantada |

Ensaie uma vez com cronômetro. O bloco que sempre estoura é o de pesquisa.

### Rascunho das cinco perguntas

Ajuste ao que vocês realmente apresentarem — pergunta sobre conteúdo não apresentado é anulada.

**Múltipla escolha 1.** Por que `/boot` fica fora do container LUKS no esquema apresentado?
a) Porque o XFS não pode ser criptografado
b) **Porque o GRUB precisa ler o kernel e o initramfs antes de existir qualquer chave de decriptação** ✔
c) Porque o `/boot` não contém dados sensíveis
d) Porque o UEFI exige partições não criptografadas em todo o disco
*Comentário: a) e c) são falsas de fato; d) confunde a exigência do ESP (FAT32, não criptografado) com o `/boot`, que poderia ser criptografado se o GRUB suportasse o formato — o limitante é a cadeia de boot.*

**Múltipla escolha 2.** Um administrador aplica `noexec` em `/tmp`. Qual afirmação é correta?
a) Nenhum código consegue mais ser executado a partir de `/tmp`
b) **Um script em `/tmp` ainda pode rodar via `bash /tmp/script.sh`, porque quem executa é o interpretador** ✔
c) `noexec` impede a escrita de arquivos em `/tmp`
d) `noexec` só funciona se o SELinux estiver em Permissive
*Comentário: mede se a turma entendeu a limitação real do controle.*

**Múltipla escolha 3.** A porta do SSH foi alterada para 6969, o `sshd_config` está correto e o `firewalld` libera a porta, mas o serviço não sobe. Qual a causa mais provável no RHEL com SELinux em Enforcing?
a) O kernel bloqueia portas acima de 1024
b) **A porta 6969 não recebeu o rótulo `ssh_port_t` via `semanage port -a`** ✔
c) O `sshd` só aceita portas listadas em `/etc/services`
d) O `firewalld` precisa ser desativado para portas não padrão
*Comentário: d) é a "solução" errada que muita gente aplica na prática.*

**Dissertativa 1.** O volume group foi criado ocupando 100% do espaço disponível e, meses depois, `/var/log` encheu durante um incidente. Explique, em até três linhas, por que a decisão de não deixar espaço livre transformou um problema operacional em um problema de resposta a incidente.

**Dissertativa 2.** Seu servidor usa LVM sobre LUKS com uma única passphrase digitada no console. Explique em até três linhas por que esse desenho é inadequado para um datacenter com centenas de servidores e cite uma alternativa.

Entregue o **gabarito comentado 48 horas antes**. Nos slides: pergunta em um slide, resposta comentada no seguinte.

---

## 14. Bônus: até 10 pontos extras

Ordenados por custo-benefício para o seu grupo:

1. **Clevis + Tang (NBDE)** — ~2 h. Resolve exatamente a dissertativa 2 e é *a* resposta Red Hat para desbloqueio automático. `dnf install clevis clevis-luks clevis-dracut tang`; um servidor Tang em segunda VM; `clevis luks bind -d /dev/sda3 tang '{"url":"http://<ip-tang>"}'`; `dracut -fv --regenerate-all`; reinicie e mostre o boot sem digitar passphrase. Demonstração de altíssimo impacto.
2. **OpenSCAP** — ~1 h. `dnf install openscap-scanner scap-security-guide`; `oscap xccdf eval --profile cis_server_l1 --report relatorio.html /usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml`. Gera relatório HTML que serve de anexo do documento e de slide.
3. **Kickstart** — ~2 h. Pegue `/root/anaconda-ks.cfg` do sistema instalado, ajuste o bloco de `part`/`logvol`/`autopart --encrypted`, e demonstre reinstalação reproduzível. Casa com "guia reproduzível".
4. **SFTP em chroot** — ~1 h. Grupo `sftp-only`, `Match Group sftp-only` com `ChrootDirectory` e `ForceCommand internal-sftp`.
5. **2FA** — ~1,5 h. `google-authenticator` via PAM combinado com chave (`AuthenticationMethods publickey,keyboard-interactive`).
6. **TPM2** — depende de o hipervisor expor TPM virtual; no VirtualBox é possível, mas teste antes de prometer no slide.

Faça **um** bem feito. Dois pela metade rendem menos que um completo com evidência.

---

## 15. Armadilhas conhecidas

| Sintoma | Causa provável | Saída |
|---|---|---|
| Passphrase do LUKS "errada" no primeiro boot | A caixa do instalador usa layout inglês; caracteres do ABNT2 saíram diferentes | Sem backup do header, é reinstalar. Por isso a recomendação de passphrase só com ASCII simples |
| `lsblk` mostra `crypt` dentro de cada LV | Encrypt marcado por volume, não no volume group | Reinstalar — não há conversão simples |
| SSH não sobe na porta nova | Falta `semanage port -a -t ssh_port_t` | `ausearch -m avc -ts recent` mostra a negação |
| SSH na porta certa mas inacessível de fora | Regra do firewalld não recarregada, ou NAT sem redirecionamento | `firewall-cmd --list-all`, `ss -tulpn` |
| `dnf` quebra depois do fstab | `noexec` em `/var/tmp` | Documentar o conflito e escolher (ver Fase 5) |
| Boot para em emergency mode | Erro de digitação no `/etc/fstab` | Sempre `mount -a` antes de reiniciar; `nofail` em volumes não críticos |
| Nota descontada em −10 | SELinux desligado em algum momento | `getenforce` nas evidências de cada fase, nunca `setenforce 0` |
| "Repositório com 1 commit" | Todo mundo trabalhou local e um só subiu | Commits diários por integrante desde o D-18 |

---

## 16. Checklist final de entrega

- [ ] `getenforce` = **Enforcing** em todas as evidências
- [ ] `lsblk -f` mostra um único nó `crypt` com o VG dentro
- [ ] `cryptsetup luksDump` confirma **LUKS2**
- [ ] `findmnt` mostra `nodev`/`nosuid`/`noexec` conforme a tabela
- [ ] Segundo disco criptografado, no VG, com evidência de `lvextend` + `xfs_growfs`
- [ ] Snapshot criado, montado e removido (evidência do espaço livre)
- [ ] `sshd -T` sem `passwordauthentication yes` e sem `permitrootlogin yes`
- [ ] Evidência dos **três** cenários: chave OK, senha negada, usuário fora do grupo negado
- [ ] `shellcheck ssh-audit-harden.sh` sem saída
- [ ] `--help`, `--audit`, `--apply` (2×, idempotente), `--rollback` gravados em texto
- [ ] Log do script existe em `/var/log/ssh-audit-harden.log`
- [ ] Pesquisa com ≥ 8 referências, ≥ 4 primárias, com data de acesso
- [ ] `INSTALL.md` que outra pessoa consegue seguir do zero
- [ ] `USO-DE-IA.md` preenchido
- [ ] Gabarito comentado enviado **48 h** antes
- [ ] Apresentação ensaiada em ≤ 30 min, com todos os integrantes falando
- [ ] Commits distribuídos entre os integrantes
- [ ] Tudo executado apenas nas VMs do grupo — nada de rede da FIAP, do trabalho ou de terceiros
