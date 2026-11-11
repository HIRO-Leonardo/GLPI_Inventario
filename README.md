# Instalador / Forçador de Inventário do GLPI Agent

Script para Windows que automatiza a instalação do **GLPI Agent**, atualiza máquinas que já o possuem para apontar a um novo servidor GLPI, força o envio do inventário e cria um atalho de "Links Úteis" na Área de Trabalho Pública.

## O que ele faz

1. **Eleva para Administrador** automaticamente (o `.bat` pede UAC se necessário).
2. **Libera o Ping (ICMPv4)** no Firewall do Windows, criando a regra de entrada para echo request.
3. **Remove o FusionInventory Agent**, caso esteja instalado (desinstalação silenciosa).
4. **Detecta o Windows** (versão e 32/64 bits).
5. **Verifica se o GLPI Agent já está instalado:**
   - **Já instalado:** atualiza a chave `server` no registro (`HKLM:\SOFTWARE\GLPI-Agent`), reinicia o serviço e executa `glpi-agent.bat --force` para enviar o inventário imediatamente.
   - **Não instalado:** escolhe o MSI correto (x86 ou x64) na pasta do script e instala em modo silencioso, já apontando para o servidor, com exceção de firewall e inventário imediato.
6. **Cria o atalho "Links Úteis.url"** na Área de Trabalho Pública (todos os usuários), com ícone personalizado copiado para `C:\Users\Public\Pictures\atalho`.

## Estrutura de arquivos

Todos os arquivos abaixo devem ficar **na mesma pasta**:

```
📁 pasta-do-instalador/
├── Installl.bat                 # Ponto de entrada (pede admin e chama o .ps1)
├── ForcarIventarioGLPI.ps1      # Script principal
├── GLPI-Agent-1.19-x64.msi      # Instalador 64 bits (você baixa)
├── GLPI-Agent-1.7-x86.msi       # Instalador 32 bits (você baixa)
└── links-uteis_icone.ico        # Ícone do atalho (opcional)
```

> Os arquivos `.msi` e `.ico` **não** estão neste repositório. Baixe os instaladores nas [releases oficiais do GLPI Agent](https://github.com/glpi-project/glpi-agent/releases).

## Configuração (obrigatória antes de usar)

Abra o `ForcarIventarioGLPI.ps1` e edite o bloco no topo:

```powershell
$GlpiServerUrl = "http://SEU_SERVIDOR_GLPI/front/inventory.php"
$LinksUrl      = "http://SEU_SERVIDOR_LINKS/"
```

| Variável         | Descrição                                                                 |
|------------------|---------------------------------------------------------------------------|
| `$GlpiServerUrl` | URL de inventário do seu GLPI (IP ou hostname + `/front/inventory.php`).  |
| `$LinksUrl`      | Página que será aberta pelo atalho "Links Úteis".                         |

Se as versões dos seus MSIs forem diferentes, ajuste também os nomes na seção `3.1`:

```powershell
$MsiNameX86 = "GLPI-Agent-1.7-x86.msi"
$MsiNameX64 = "GLPI-Agent-1.19-x64.msi"
```

## Como usar

1. Baixe/clone este repositório e coloque os `.msi` (e o `.ico`) na mesma pasta.
2. Edite as URLs no `.ps1`, conforme descrito acima.
3. Dê **duplo clique em `Installl.bat`** e aceite o prompt de Administrador (UAC).
4. Aguarde a mensagem "Processo concluído" e pressione uma tecla para sair.

Também é possível executar direto, em um PowerShell como Administrador:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ForcarIventarioGLPI.ps1
```

### Implantação em várias máquinas

Coloque a pasta em um compartilhamento de rede (ou use GPO / ferramenta de distribuição) e execute o `Installl.bat` em cada estação. O script é idempotente: em máquinas que já têm o agente, apenas atualiza o servidor e reenvia o inventário.

## Requisitos

- Windows 7 ou superior (usa `Get-WmiObject` por compatibilidade com PowerShell 2.0/3.0).
- Permissão de Administrador.
- Acesso de rede da estação ao servidor GLPI.
- Plugin/recurso de inventário nativo habilitado no servidor GLPI.

## Avisos de segurança

- O script usa `ExecutionPolicy Bypass` / `Unrestricted` apenas no escopo do processo, sem alterar a política permanente da máquina.
- Ele **abre o Ping (ICMPv4) no firewall**. Remova essa etapa do `.ps1` se não quiser esse comportamento.
- Ele **desinstala o FusionInventory Agent** sem pedir confirmação.
- Revise o código antes de rodar em produção e teste primeiro em uma máquina isolada.

## Solução de problemas

| Sintoma                                         | Causa provável / solução                                                              |
|-------------------------------------------------|---------------------------------------------------------------------------------------|
| "O arquivo MSI NÃO foi encontrado"              | O `.msi` não está na mesma pasta ou o nome difere do configurado em `$MsiNameX64/X86`. |
| "Não foi possível encontrar a chave de registro"| O agente instalado não usa `HKLM:\SOFTWARE\GLPI-Agent` (versão/arquitetura diferente). |
| Inventário não aparece no GLPI                  | Confira a URL do servidor, firewall e se o GLPI aceita inventário nativo.             |
| Atalho sem ícone                                | O arquivo `links-uteis_icone.ico` não estava na pasta do script.                      |

## Autor

**Leonardo Teixeira**
- GitHub: [@HIRO-Leonardo](https://github.com/HIRO-Leonardo)
- LinkedIn: [Leonardo Teixeira](https://www.linkedin.com/in/leonardo-teixeira-desenvolvedor/)

## Licença

Distribuído sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.
