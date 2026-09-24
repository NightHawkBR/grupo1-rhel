# Layout LVM sobre LUKS pelo console do instalador

Caminho alternativo à etapa 4 do `INSTALL.md` · Grupo 1 · RHEL 10

> **Status:** este caminho **não foi o usado** na instalação do grupo. O laboratório foi instalado pelo Anaconda gráfico (seção 4 do `INSTALL.md`), que nomeia o container `luks-<uuid>` em vez de `cryptlvm`. O procedimento fica como alternativa documentada e testável — útil se o mouse não responder na VM ou para reinstalar com layout idêntico.

Constrói o esquema inteiro por linha de comando no console do Anaconda e usa a interface gráfica apenas para **atribuir pontos de montagem** a volumes que já existem. Não exige mouse no passo crítico, é reproduzível caractere a caractere e a saída de cada comando serve de evidência.

**Pré-requisito:** VM iniciada pela ISO, no instalador. Não abra *Destino da instalação* antes de terminar o console — se já abriu, veja a seção "Se o instalador não enxergar o layout novo".

---

## Convenções

| Notação | Significado |
|---|---|
| `Ctrl+Alt+F2` | vai para o console (shell root, sem senha) |
| `Ctrl+Alt+F6` | volta para a interface gráfica do Anaconda |
| `Ctrl+Alt+F1` | tela principal do instalador (log) |

⚠️ **O console usa layout de teclado americano.** Vale para a passphrase do LUKS e para qualquer caractere especial: `A-Z`, `a-z`, `0-9`, `-`, `_`, `.` são seguros; `ç`, acentos e símbolos que mudam de posição no ABNT2, não.

---

## 1. Conferir o alvo

```bash
lsblk
```

**Esperado:** `sda` com 60 GiB e `sdb` **ausente** — o segundo disco entra só depois da instalação. Se aparecer `sdb`, desligue a VM e remova-o antes de continuar; errar o disco aqui apaga o disco errado.

```bash
parted -s /dev/sda print
```

---

## 2. Limpar tentativas anteriores

Se esta é a primeira tentativa, pule para a etapa 3. Se você já tentou instalar antes, o disco tem VG e LUKS ativos que impedem o reparticionamento:

```bash
vgchange -an
cryptsetup close cryptlvm 2>/dev/null
dmsetup remove_all
wipefs -a /dev/sda
```

**Esperado:** `wipefs` lista as assinaturas removidas. Se reclamar que o dispositivo está em uso, repita `dmsetup remove_all` e tente de novo.

---

## 3. Tabela de partições GPT

```bash
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart boot xfs 1025MiB 2049MiB
parted -s /dev/sda mkpart pv_luks 2049MiB 100%
parted -s /dev/sda print
```

**Esperado:**

```
Number  Start   End     Size    File system  Name      Flags
 1      1049kB  1075MB  1074MB               ESP       boot, esp
 2      1075MB  2148MB  1074MB               boot
 3      2148MB  64.4GB  62.3GB               pv_luks
```

As partições 1 e 2 ficam **fora** da criptografia. A 3 é o container.

> Os nomes (`ESP`, `boot`, `pv_luks`) são rótulos GPT, não sistemas de arquivos. Nenhum filesystem é criado aqui de propósito — quem formata é o Anaconda, na etapa 8.

---

## 4. Container LUKS2

```bash
cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 --key-size 512 --hash sha512 \
  --pbkdf argon2id /dev/sda3
```

Confirme com `YES` em maiúsculas e digite a passphrase duas vezes.

🔴 **Anote a passphrase agora, em papel.** Não existe recuperação.

```bash
cryptsetup luksDump /dev/sda3
```

**Esperado:** `Version: 2`, um keyslot ocupado, PBKDF `argon2id`.

> Se o `luksFormat` falhar por falta de memória, acrescente `--pbkdf-memory 262144` (256 MiB) ao comando. O ambiente do instalador divide os 4 GB da VM com o próprio Anaconda.

---

## 5. Abrir o container

```bash
cryptsetup open /dev/sda3 cryptlvm
ls -l /dev/mapper/cryptlvm
```

---

## 6. LVM dentro do container

```bash
pvcreate /dev/mapper/cryptlvm
vgcreate vg_sistema /dev/mapper/cryptlvm
vgs
```

**Esperado:** `vg_sistema` com `VSize` em torno de 57,9 GiB.

```bash
lvcreate -L 15G -n lv_root   vg_sistema
lvcreate -L  8G -n lv_var    vg_sistema
lvcreate -L  5G -n lv_varlog vg_sistema
lvcreate -L  3G -n lv_vartmp vg_sistema
lvcreate -L 10G -n lv_home   vg_sistema
lvcreate -L  3G -n lv_tmp    vg_sistema
lvcreate -L  4G -n lv_swap   vg_sistema
```

### Conferência obrigatória

```bash
vgs -o vg_name,vg_size,vg_free
lvs -o lv_name,lv_size
lsblk
```

**Esperado:** `VFree` em torno de **9,9 GiB**. Os sete volumes somam 48 G; o que sobra é o espaço reservado para snapshot. Se o `VFree` vier perto de zero, algum tamanho foi digitado errado — corrija agora com `lvremove` e `lvcreate`, é muito mais barato do que depois da instalação.

O `lsblk` deve mostrar um único nó `crypt`, com o VG abaixo dele:

```
sda
├─sda1
├─sda2
└─sda3
  └─cryptlvm
    ├─vg_sistema-lv_root
    ├─vg_sistema-lv_var
    └─...
```

---

## 7. Fechar o container antes de voltar

```bash
vgchange -an vg_sistema
cryptsetup close cryptlvm
lsblk
```

**Por que fechar:** com o container trancado, o Anaconda o descobre como dispositivo criptografado existente e oferece o botão *Desbloquear*. É esse fluxo que faz o instalador registrar a passphrase e gravar corretamente o `/etc/crypttab` e o `rd.luks.uuid` na linha de comando do kernel. Se você entregar o VG já aberto, o instalador pode montar tudo e ainda assim gerar um sistema que não desbloqueia no boot.

---

## 8. Voltar à interface e atribuir os pontos de montagem

`Ctrl+Alt+F6`

1. *Destino da instalação* → selecione o disco → **Personalizado** → **Pronto**
2. Na tela de particionamento manual, o `sda3` aparece como dispositivo criptografado trancado → clique em **Desbloquear** e informe a passphrase
3. Os sete volumes lógicos aparecem sob `vg_sistema`. Para cada um, selecione e preencha:

| Volume | Ponto de montagem | Sistema de arquivos | Reformatar |
|---|---|---|---|
| `sda1` | `/boot/efi` | EFI System Partition | ✔ |
| `sda2` | `/boot` | xfs | ✔ |
| `vg_sistema-lv_root` | `/` | xfs | ✔ |
| `vg_sistema-lv_var` | `/var` | xfs | ✔ |
| `vg_sistema-lv_varlog` | `/var/log` | xfs | ✔ |
| `vg_sistema-lv_vartmp` | `/var/tmp` | xfs | ✔ |
| `vg_sistema-lv_home` | `/home` | xfs | ✔ |
| `vg_sistema-lv_tmp` | `/tmp` | xfs | ✔ |
| `vg_sistema-lv_swap` | — | swap | ✔ |

4. **Não toque** no campo *Criptografar* de nenhum volume — a criptografia já existe, no nível certo
5. **Não altere tamanhos nem o grupo de volume** — qualquer mudança aqui pode fazer o Anaconda recriar o layout
6. **Pronto** → confira o resumo: deve haver apenas formatação de sistemas de arquivos, **nenhuma** criação de partição, de VG ou de LUKS
7. *Aceitar alterações* → instale

> Teclado funciona em toda essa tela: `Tab` circula os campos, `Espaço` marca caixas, `Enter` aciona botões.

---

## 9. Validar depois do primeiro boot

```bash
lsblk -f
cryptsetup luksDump /dev/sda3 | head -20
pvs ; vgs ; lvs
cat /etc/crypttab
grep -o 'rd.luks.uuid=[^ ]*' /proc/cmdline
blkid -s UUID -o value /dev/sda3
```

Os dois últimos comandos precisam bater: o UUID em `rd.luks.uuid` tem que ser o mesmo do `sda3`. Se não estiver lá, o sistema só subiu porque você digitou a passphrase — e vai quebrar na próxima regeneração do initramfs.

---

## Se o instalador não enxergar o layout novo

O Anaconda varre o armazenamento uma vez, na inicialização. Se você abriu *Destino da instalação* antes de mexer no console, ele trabalha com a leitura antiga.

Procure o botão de **reexaminar discos** na tela de destino. Se não houver, reinicie a VM e entre no instalador de novo — **o layout permanece gravado no disco**, nada se perde. Foi exatamente para isso que a etapa 7 fechou o container: ao reiniciar, o `sda3` volta a aparecer trancado e o fluxo da etapa 8 funciona igual.

---

## Evidências

O sistema de arquivos do instalador vive em RAM e some no reboot, então não adianta redirecionar saída para arquivo aqui. Duas opções:

- capture a tela do console (no VirtualBox, **Visualizar → Captura de tela**) depois do `lsblk` e do `vgs` da etapa 6 — vira a evidência do "antes"
- ou rode o `coletar-evidencias.sh` depois do primeiro boot, que é o que a rubrica realmente cobra

---

## Comandos, na sequência, sem comentário

Para conferência rápida durante a execução:

```bash
lsblk
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart boot xfs 1025MiB 2049MiB
parted -s /dev/sda mkpart pv_luks 2049MiB 100%
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --pbkdf argon2id /dev/sda3
cryptsetup open /dev/sda3 cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate vg_sistema /dev/mapper/cryptlvm
lvcreate -L 15G -n lv_root   vg_sistema
lvcreate -L  8G -n lv_var    vg_sistema
lvcreate -L  5G -n lv_varlog vg_sistema
lvcreate -L  3G -n lv_vartmp vg_sistema
lvcreate -L 10G -n lv_home   vg_sistema
lvcreate -L  3G -n lv_tmp    vg_sistema
lvcreate -L  4G -n lv_swap   vg_sistema
vgs -o vg_name,vg_size,vg_free
lvs
vgchange -an vg_sistema
cryptsetup close cryptlvm
```
