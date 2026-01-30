# Como criar um site com Quarto

Este guia apresenta os passos necessários para construir e publicar um site pessoal utilizando Quarto.

## Pré-requisitos

Antes de iniciar, certifique-se de ter instalado:

- **Quarto CLI** (versão 1.3 ou superior)
  - Download em: https://quarto.org/docs/get-started/
- **RStudio** ou **VS Code** (opcional, mas recomendado)
- **Git** (para controle de versão e publicação)

Para verificar se o Quarto está instalado corretamente, execute no terminal:

```bash
quarto --version
```

## Estrutura do projeto

Um projeto Quarto típico possui a seguinte organização:

```
meu-site/
├── _site/                  # Pasta gerada com o site compilado
├── apresentacoes/          # Documentos de apresentação
├── cafecomr/              # Seção específica do site
├── css/                   # Folhas de estilo personalizadas
├── imagens/               # Arquivos de imagem
├── includes/              # Arquivos parciais reutilizáveis
├── projetos/              # Documentos de projetos
├── _quarto.yml            # Configuração principal do site
├── .gitignore             # Arquivos ignorados pelo Git
├── about.qmd              # Página "sobre"
├── estilo_geral.scss      # Estilos SCSS personalizados
├── foto.png               # Imagem de perfil
└── index.qmd              # Página inicial
```

## Passo 1: Criar o projeto

Abra o terminal na pasta onde deseja criar o site e execute:

```bash
quarto create-project meu-site --type website
```

Este comando criará uma estrutura básica com os arquivos essenciais.

## Passo 2: Configurar o arquivo _quarto.yml

O arquivo `_quarto.yml` é o coração do seu site. Configure-o conforme necessário:

```yaml
project:
  type: website
  output-dir: _site

website:
  title: "Meu Site Pessoal"
  navbar:
    left:
      - text: "Início"
        href: index.qmd
      - text: "Sobre"
        href: about.qmd
      - text: "Projetos"
        href: projetos/index.qmd
    right:
      - icon: github
        href: https://github.com/seu-usuario
      - icon: linkedin
        href: https://linkedin.com/in/seu-perfil

format:
  html:
    theme: cosmo
    css: css/styles.css
    toc: true
```

### Explicação dos principais campos:

- **project.type**: Define o tipo do projeto (website, book, etc)
- **output-dir**: Pasta onde os arquivos HTML serão gerados
- **website.title**: Título que aparece no site
- **navbar**: Configuração do menu de navegação
- **format.html.theme**: Tema visual (cosmo, flatly, darkly, etc)

## Passo 3: Criar a página inicial (index.qmd)

O arquivo `index.qmd` é a primeira página que os visitantes verão:

```markdown
---
title: "Bem-vindo ao Meu Site"
---

## Sobre Mim

Apresentação breve sobre você, suas áreas de interesse e objetivos.

## Últimos Projetos

Destaque dos trabalhos recentes ou conteúdos importantes.
```

## Passo 4: Criar páginas adicionais

Para cada nova página, crie um arquivo `.qmd`:

**about.qmd**
```markdown
---
title: "Sobre Mim"
---

## Formação

Detalhes sobre sua formação acadêmica.

## Experiência

Trajetória profissional e experiências relevantes.
```

## Passo 5: Organizar conteúdo em pastas

Crie pastas para organizar diferentes seções:

```bash
mkdir projetos
mkdir apresentacoes
```

Dentro de cada pasta, adicione um `index.qmd` para servir como página principal da seção.

## Passo 6: Personalizar estilos

Crie um arquivo CSS personalizado em `css/styles.css`:

```css
/* Personalização de cores */
:root {
  --cor-principal: #2c3e50;
  --cor-secundaria: #3498db;
}

/* Estilo do cabeçalho */
.navbar {
  background-color: var(--cor-principal);
}

/* Estilo de links */
a {
  color: var(--cor-secundaria);
}
```

Para estilos mais avançados, utilize SCSS criando `estilo_geral.scss`.

## Passo 7: Pré-visualizar o site localmente

Execute o comando para visualizar o site em tempo real:

```bash
quarto preview
```

O site abrirá automaticamente no navegador em `http://localhost:4200`. As alterações nos arquivos serão refletidas automaticamente.

## Passo 8: Compilar o Site

Para gerar os arquivos HTML finais:

```bash
quarto render
```

Os arquivos compilados estarão na pasta `_site/`.

## Passo 9: Preparar para publicação

Crie um repositório Git para versionar seu projeto:

```bash
git init
git add .
git commit -m "Initial commit"
```

Configure o `.gitignore` para ignorar arquivos desnecessários:

```
/.quarto/
/_site/
```

## Passo 10: Publicar o site

### Quarto Pub

1. Execute:

```bash
quarto publish quarto-pub
```

2. Crie uma conta gratuita e publique

## Dicas importantes

### Trabalhando com imagens

Armazene todas as imagens na pasta `imagens/` e referencie-as assim:

```markdown
![Descrição da imagem](imagens/foto.png)
```

### Adicionando código

Para incluir blocos de código executáveis (R, Python, etc):

````markdown
```{r}
# Código em R
dados <- read.csv("arquivo.csv")
summary(dados)
```
````

### Criando tabsets

Use abas para organizar conteúdo extenso:

```markdown
::: {.panel-tabset}

## Aba 1
Conteúdo da primeira aba

## Aba 2
Conteúdo da segunda aba

:::
```

### Configurando

Adicione metadados no cabeçalho YAML de cada página:

```yaml
---
title: "Título da Página"
description: "Descrição para mecanismos de busca"
author: "Seu Nome"
date: "2024-01-30"
---
```

## Atualizando o Site

Após fazer alterações:

1. Renderize novamente:
```bash
quarto render
```

2. Atualize o repositório:
```bash
git add .
git commit -m "Descrição das alterações"
git push
```

3. Republique (se necessário):
```bash
quarto publish
```

## Recursos

- Documentação oficial: https://quarto.org/docs/websites/
- Galeria de exemplos: https://quarto.org/docs/gallery/
- Temas disponíveis: https://quarto.org/docs/output-formats/html-themes.html

## Resolução de problemas

**Erro ao renderizar:** Verifique se todos os arquivos `.qmd` possuem cabeçalho YAML válido.

**Links quebrados:** Confirme que os caminhos dos arquivos estão corretos e usam barras normais (`/`).

**Estilos não aplicados:** Certifique-se de que o caminho do CSS está correto no `_quarto.yml`.

**Erro ao publicar:** Verifique as credenciais e permissões do repositório Git.
